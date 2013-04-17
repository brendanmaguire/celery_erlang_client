-module(celery_app_tests).

-include_lib("eunit/include/eunit.hrl").
-include_lib("amqp_client/include/amqp_client.hrl").


env_variables_to_amqp_params_with_host_test() ->
    EnvVariables = [{host, "example.com"}],
    AmqpParams = celery_app:env_variables_to_amqp_params(EnvVariables),
    ExpectedAmqpParams = #amqp_params_network{host="example.com"},
    ?assertEqual(ExpectedAmqpParams, AmqpParams).


env_variables_to_amqp_params_with_virtual_host_test() ->
    EnvVariables = [{virtual_host, <<"vh">>}],
    AmqpParams = celery_app:env_variables_to_amqp_params(EnvVariables),
    ExpectedAmqpParams = #amqp_params_network{virtual_host= <<"vh">>},
    ?assertEqual(ExpectedAmqpParams, AmqpParams).


env_variables_to_amqp_params_with_two_variables_test() ->
    EnvVariables = [{host, "example.com"}, {virtual_host, <<"vh">>}],
    AmqpParams = celery_app:env_variables_to_amqp_params(EnvVariables),
    ExpectedAmqpParams = #amqp_params_network{host="example.com",
                                              virtual_host= <<"vh">>},
    ?assertEqual(ExpectedAmqpParams, AmqpParams).


env_variables_to_amqp_params_with_no_variables_test() ->
    EnvVariables = [],
    AmqpParams = celery_app:env_variables_to_amqp_params(EnvVariables),
    ExpectedAmqpParams = #amqp_params_network{},
    ?assertEqual(ExpectedAmqpParams, AmqpParams).


env_variables_to_amqp_params_with_irrelevant_variable_test() ->
    EnvVariables = [{host, "example.com"}, {foo, bar}],
    AmqpParams = celery_app:env_variables_to_amqp_params(EnvVariables),
    ExpectedAmqpParams = #amqp_params_network{host="example.com"},
    ?assertEqual(ExpectedAmqpParams, AmqpParams).
