-module(test).

-include("include/celery.hrl").
-include("deps/amqp_client/include/amqp_client.hrl").

-export([test/0, msg_to_json/1, add/2]).

test() ->
    {ok, C} = amqp_connection:start(#amqp_params_network{}),
    {ok, Rpc} = celery:start_link(C, <<"celery">>),
    Msg = #celery_msg{task= <<"documents.tasks.add">>, args=[2,3] },
    celery:call(Rpc, Msg),
    {ok, Rpc}.

add(A, B) ->
    Msg = #celery_msg{task= <<"documents.tasks.add">>, args=[A,B] },
    celery:call(Msg).
    
msg_to_json(#celery_msg{id = Id,
			task = Task,
			args = Args,
			kwargs = Kwargs,
			retries = Retries,
			eta = Eta}) ->
    M = {[
	  {id, Id},
	  {task, Task},
	  {args, Args},
	  {kwargs, Kwargs},
	  {retries, Retries},
	  {eta, Eta}
	 ]},
    json:encode(M).
