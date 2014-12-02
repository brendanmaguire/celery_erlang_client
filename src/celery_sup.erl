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
        {ok, Connection} = amqp_connection:start(AmqpParams)
    catch
        exit:Exit ->
            case RetriesLeft of
                0 ->
                    {error, celery_connection_error, Exit};
                _ ->
                    timer:sleep(Interval),
                    start_amqp_connection(AmqpParams, RetriesLeft-1, Interval)
            end
    end.
