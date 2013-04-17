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
    {ok, Con} = amqp_connection:start(AmqpParams),
    Q = <<"celery">>,
    Server = {celery, {celery, start_link, [Con, Q]},
	     permanent, 2000, worker, [celery]},
    Children = [Server],
    RestartStrategy = {one_for_one, 5, 10},
    {ok, { RestartStrategy, Children} }.
