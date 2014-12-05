-module(celery_app).

-behaviour(application).

-include_lib("amqp_client/include/amqp_client.hrl").

%% Application callbacks
-export([start/0, start/2, stop/1]).

%% Utility. Exported for testing purposes.
-export([env_variables_to_amqp_params/1]).

-define (DefaultReplyQueueDurable, true).


%% ===================================================================
%% Application callbacks
%% ===================================================================
start() ->
    application:start(celery).

start(_StartType, _StartArgs) ->
    lager:start(),

    AmqpParams = case application:get_env(celery, amqp_params) of
        {ok, EnvVariables} -> env_variables_to_amqp_params(EnvVariables);
        undefined -> #amqp_params_network{}
    end,

    ReplyQueueDurable = case application:get_env(reply_queue_durable) of
        {ok, Value} -> Value;
        undefined -> ?DefaultReplyQueueDurable
    end,

    case celery_sup:start_link(AmqpParams, ReplyQueueDurable) of
        {ok, Pid} ->
            {ok, Pid};
        Other ->
            {error, Other}
    end.


stop(_State) ->
    ok.


%% ===================================================================
%% Utility functions - only exported for testing purposes
%% ===================================================================
env_variables_to_amqp_params(EnvVariables) ->
    EnvVariablesDict = orddict:from_list(EnvVariables),

    UpdateAmqpParams = fun({AmqpIndex, AmqpField}, AmqpParams) ->
        NewAmqpParams = case orddict:is_key(AmqpField, EnvVariablesDict) of
            true ->
                EnvVariable = orddict:fetch(AmqpField, EnvVariablesDict),
                setelement(AmqpIndex, AmqpParams, EnvVariable);
            false -> AmqpParams
        end,
        NewAmqpParams
    end,

    % Record index 1 is the name of the index so record fields start at index 2
    AmqpIndexes = lists:seq(2, record_info(size, amqp_params_network)),
    AmqpFields = record_info(fields, amqp_params_network),
    IndexedAmqpFields = lists:zip(AmqpIndexes, AmqpFields),
    
    lists:foldl(UpdateAmqpParams, #amqp_params_network{}, IndexedAmqpFields).
