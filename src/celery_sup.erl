-module(celery_sup).

-behaviour(supervisor).

-include_lib("amqp_client/include/amqp_client.hrl").

%% API
-export([start_link/0, start_link/1]).

%% Supervisor callbacks
-export([init/1]).

%% Helper macro for declaring children of supervisor
-define(CHILD(I, Type), {I, {I, start_link, []}, permanent, 5000, Type, [I]}).

%% ===================================================================
%% API functions
%% ===================================================================
start_link() ->
    start_link(#amqp_params_network{}).

start_link(AmqpParams) ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, [AmqpParams]).

%% ===================================================================
%% Supervisor callbacks
%% ===================================================================
init([AmqpParams]) ->
    {ok, Con} = start_amqp_connection(AmqpParams, 5, 2000),
    Q = <<"celery">>,
    Server = {celery, {celery, start_link, [Con, Q]},
              permanent, 2000, worker, [celery]},
    Children = [Server],
    RestartStrategy = {one_for_one, 5, 10},
    {ok, { RestartStrategy, Children} }.

%% ===================================================================
%% Internal function(s)
%% ===================================================================
start_amqp_connection(AmqpParams, RetriesLeft, Interval) ->
    case amqp_connection:start(AmqpParams) of
        {ok, Con} ->
            {ok, Con};
        Error ->
            case RetriesLeft of
                0 ->
                    Error;
                _ ->
                    timer:sleep(Interval),
                    start_amqp_connection(AmqpParams, RetriesLeft - 1, Interval)
            end
    end.
