%
% Use this module to test the celery application. View the README.rst for more
% information on usage.
%

-module(demo).

-include("include/celery.hrl").
-include("deps/amqp_client/include/amqp_client.hrl").

-export([start_celery_app/0, msg_to_json/1, add/2, safe_add/2, async_add/2,
         async_add_with_timeout/3, async_add_with_request_id/3,
         async_add_reply_to_spawned_process/2, receive_response/1,
         receive_and_log_response/1]).

start_celery_app() ->
    celery_app:start().

add(A, B) ->
    Msg = #celery_msg{task= <<"tasks.add">>, args=[A,B]},
    celery:call(Msg).

safe_add(A, B) ->
    try add(A, B) of
        {celery_res, _, <<"SUCCESS">>, Result, _} ->
            {ok, Result};
        Failure ->
            {fail, Failure}
    catch
        exit:Exit -> {fail, Exit}
    end.

async_add(A, B) ->
    async_add_with_timeout(A, B, 10000).

async_add_with_timeout(A, B, Timeout) ->
    Msg = #celery_msg{task= <<"tasks.add">>, args=[A,B]},
    celery:cast(Msg, self()),
    receive_response(Timeout).

async_add_with_request_id(A, B, RequestId) ->
    Msg = #celery_msg{task= <<"tasks.add">>, args=[A,B]},
    celery:cast(Msg, self(), RequestId),
    receive_response(10000).

async_add_reply_to_spawned_process(A, B) ->
    Msg = #celery_msg{task= <<"tasks.add">>, args=[A,B]},
    Recipient = spawn(demo, receive_and_log_response, [10000]),
    io:format("Sent request from ~p~n", [self()]),
    celery:cast(Msg, Recipient).
    
receive_response(Timeout) ->
    receive
        Response ->
            Response
    after
        Timeout ->
            {error, timed_out}
    end.

receive_and_log_response(Timeout) ->
    io:format("Receiving response in ~p~n", [self()]),
    Response = receive_response(Timeout),
    io:format("Received response ~p in ~p~n", [Response, self()]).

msg_to_json(#celery_msg{id = Id,
            task = Task,
            args = Args,
            kwargs = Kwargs,
            retries = Retries,
            eta = Eta}) ->
    M = [
      {id, Id},
      {task, Task},
      {args, Args},
      {kwargs, Kwargs},
      {retries, Retries},
      {eta, Eta}
    ],
    json:encode(M).
