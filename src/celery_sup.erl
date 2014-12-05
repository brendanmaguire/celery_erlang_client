-module(celery_sup).

-behaviour(supervisor).

-include_lib("amqp_client/include/amqp_client.hrl").

%% API
-export([start_link/0, start_link/2]).

%% Supervisor callbacks
-export([init/1]).

%% Helper macro for declaring children of supervisor
-define(CHILD(I, Type), {I, {I, start_link, []}, permanent, 5000, Type, [I]}).

%% ===================================================================
%% API functions
%% ===================================================================
start_link() ->
    start_link(#amqp_params_network{}, true).

start_link(AmqpParams, ReplyQueueDurable) ->
    supervisor:start_link(
        {local, ?MODULE}, ?MODULE, [AmqpParams, ReplyQueueDurable]).

%% ===================================================================
%% Supervisor callbacks
%% ===================================================================
init([AmqpParams, ReplyQueueDurable]) ->
    {ok, Connection} = start_amqp_connection(AmqpParams, 4, 2000),
    QueueName = <<"celery">>,
    Server = {
        celery,
        {celery, start_link, [Connection, QueueName, ReplyQueueDurable]},
        permanent,
        2000,
        worker,
        [celery]},
    Children = [Server],
    RestartStrategy = {one_for_one, 5, 10},
    {ok, { RestartStrategy, Children} }.

%% ===================================================================
%% Internal function(s)
%% ===================================================================
start_amqp_connection(AmqpParams, RetriesLeft, Interval) ->
    try
        case amqp_connection:start(AmqpParams) of
            {error, Error} ->
                retry_amqp_connection(
                    AmqpParams, RetriesLeft, Interval, {error, Error});
            Result ->
                Result
        end
    catch
        exit:Exit ->
            retry_amqp_connection(
                AmqpParams, RetriesLeft, Interval,
                {exit_exception, Exit, erlang:get_stacktrace()});
        error:Err ->
            retry_amqp_connection(
                AmqpParams, RetriesLeft, Interval,
                {error_exception, Err, erlang:get_stacktrace()})
    end.

retry_amqp_connection(_AmqpParams, RetriesLeft, _Interval, Issue)
        when RetriesLeft == 0 ->
    {error, celery_connection_error, Issue};

retry_amqp_connection(AmqpParams, RetriesLeft, Interval, Issue) ->
    lager:warning(
        "An issue occurred when starting the amqp connection. Restarting in ~p"
        " with ~p retries left. Issue: ~p", [Interval, RetriesLeft, Issue]),
    timer:sleep(Interval),
    start_amqp_connection(AmqpParams, RetriesLeft-1, Interval).
