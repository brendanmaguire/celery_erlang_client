%%%-------------------------------------------------------------------
%%% @author  <scor@snk-desk>
%%% @copyright (C) 2012, 
%%% @doc
%%%
%%% @end
%%% Created :  7 Mar 2012 by  <scor@snk-desk>
%%%-------------------------------------------------------------------
-module(celery).

-behaviour(gen_server).

-include("celery.hrl").
-include_lib("amqp_client/include/amqp_client.hrl").

%% API
-export([start_link/2, stop/0]).
-export([call/1, call/2, cast/1, cast/2, cast/3]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2,
         code_change/3]).

-define(SERVER, ?MODULE). 
-define(RPC_TIMEOUT, 10000).

-record(state, {channel,
                reply_queue,
                exchange,
                routing_key,
                continuations = dict:new(),
                correlation_id = 0}).

%%%===================================================================
%%% API
%%%===================================================================

%%--------------------------------------------------------------------
%% @doc
%% Starts the server
%%
%% @spec start_link() -> {ok, Pid} | ignore | {error, Error}
%% @end
%%--------------------------------------------------------------------
start_link(Connection, RoutingKey) ->
    gen_server:start_link({local, ?SERVER}, ?MODULE, [Connection, RoutingKey], []).

stop() ->
    gen_server:cast(?MODULE, stop).

%%--------------------------------------------------------------------
%% @doc
%% Call remote procedure
%%
%% @spec call(RpcClient, Payload) -> ok
%% where
%%      RpcClient = pid()
%%      Payload = binary()
%% @end
%%--------------------------------------------------------------------
call(Msg = #celery_msg{}) ->
    gen_server:call(?SERVER, {call, Msg}, ?RPC_TIMEOUT).

call(Msg = #celery_msg{}, Timeout) ->
    gen_server:call(?SERVER, {call, Msg}, Timeout).

%%--------------------------------------------------------------------
%% @doc
%% Cast asynchronous request to invoke remote procedure
%%
%% The Recipient parameter can be used if the reply should be sent to
%% a Pid other than the caller
%%
%% The RequestId parameter can be used to explicitly specify the
%% celery rpc request id which can be used by the Recipient to
%% distinguish task responses
%%--------------------------------------------------------------------
cast(Msg = #celery_msg{}) ->
    cast(Msg, self()).

cast(Msg = #celery_msg{}, Recipient) ->
    gen_server:cast(?MODULE, {request, Msg, Recipient}).

cast(Msg = #celery_msg{}, Recipient, RequestId) ->
    gen_server:cast(?MODULE, {request, Msg, Recipient, RequestId}).

%%%===================================================================
%%% gen_server callbacks
%%%===================================================================

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Initializes the server
%%
%% @spec init(Args) -> {ok, State} |
%%                     {ok, State, Timeout} |
%%                     ignore |
%%                     {stop, Reason}
%% @end
%%--------------------------------------------------------------------
init([Connection, RoutingKey]) ->
    {ok, Channel} = amqp_connection:open_channel(Connection),
    InitState = #state{channel = Channel,
		       exchange = <<>>,
		       routing_key = RoutingKey},
    process_flag(trap_exit, true),
    {ok, InitState}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling call messages
%%
%% @spec handle_call(Request, From, State) ->
%%                                   {reply, Reply, State} |
%%                                   {reply, Reply, State, Timeout} |
%%                                   {noreply, State} |
%%                                   {noreply, State, Timeout} |
%%                                   {stop, Reason, Reply, State} |
%%                                   {stop, Reason, State}
%% @end
%%--------------------------------------------------------------------
handle_call({call, Payload}, From, State) ->
    State1 = publish(Payload, From, fun gen_server:reply/2, State),
    {noreply, State1};

handle_call(_Request, _From, State) ->
    Reply = ok,
    {reply, Reply, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling cast messages
%%
%% @spec handle_cast(Msg, State) -> {noreply, State} |
%%                                  {noreply, State, Timeout} |
%%                                  {stop, Reason, State}
%% @end
%%--------------------------------------------------------------------
handle_cast({request, Payload, From}, State) ->
    State1 = publish(Payload, From, fun async_reply/2, State),
    {noreply, State1};

handle_cast({request, Payload, From, RequestId}, State) ->
    State1 = publish(Payload, From, fun async_reply/2, RequestId, State),
    {noreply, State1};

handle_cast(stop, State) ->
    {stop, normal, State};

handle_cast(_Msg, State) ->
    {noreply, State}.

async_reply(Caller, Msg) ->
    Caller ! Msg.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling all non call/cast messages
%%
%% @spec handle_info(Info, State) -> {noreply, State} |
%%                                   {noreply, State, Timeout} |
%%                                   {stop, Reason, State}
%% @end
%%--------------------------------------------------------------------
%% @private
handle_info({#'basic.consume'{}, _Pid}, State) ->
    {noreply, State};

%% @private
handle_info(#'basic.consume_ok'{}, State) ->
    {noreply, State};

%% @private
handle_info(#'basic.cancel'{}, State) ->
    {noreply, State};

%% @private
handle_info(#'basic.cancel_ok'{}, State) ->
    {noreply, State};

handle_info({#'basic.deliver'{delivery_tag = DeliveryTag,
			      consumer_tag = ConsumerTag},
	     #amqp_msg{payload = Payload}
	    },
	    State = #state{continuations = Conts,
			   channel = Chan}
	   ) ->

    {Reply} = ejson:decode(Payload),
    Result = #celery_res{
      task_id   = proplists:get_value(<<"task_id">>, Reply),
      status    = proplists:get_value(<<"status">>, Reply),
      result    = proplists:get_value(<<"result">>, Reply),
      traceback = proplists:get_value(<<"traceback">>, Reply)},
    Id = Result#celery_res.task_id,
    NewState = case dict:is_key(Id, Conts) of
        true ->
            {From, ReturnMethod} = dict:fetch(Id, Conts),
            ReturnMethod(From, Result),
            State#state{continuations = dict:erase(Id, Conts)};
        _ ->
            State
    end,

    amqp_channel:call(Chan, #'basic.ack'{delivery_tag = DeliveryTag}),
    amqp_channel:call(Chan, #'basic.cancel'{consumer_tag = ConsumerTag}),
    {noreply, NewState};

handle_info(Info, State) ->
    io:format("Info: ~p~n", [Info]),
    {noreply, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% This function is called by a gen_server when it is about to
%% terminate. It should be the opposite of Module:init/1 and do any
%% necessary cleaning up. When it returns, the gen_server terminates
%% with Reason. The return value is ignored.
%%
%% @spec terminate(Reason, State) -> void()
%% @end
%%--------------------------------------------------------------------
terminate(_Reason, #state{channel = Channel}) ->
    amqp_channel:close(Channel),
    ok.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Convert process state when code is changed
%%
%% @spec code_change(OldVsn, State, Extra) -> {ok, NewState}
%% @end
%%--------------------------------------------------------------------
code_change(OldVsn, State, Extra) ->
    io:format("Upgrading from ~p with extra data ~p~n", [OldVsn, Extra]),
    {ok, State}.

%%%===================================================================
%%% Internal functions
%%%===================================================================
publish(Payload, From, ReturnMethod, State) ->
    UUID = uuid:to_string(uuid:v4()),
    RequestId = list_to_binary("celery_rpc_" ++ UUID),
    publish(Payload, From, ReturnMethod, RequestId, State).

publish(Payload, From, ReturnMethod, RequestId, State
	= #state{channel        = Channel,
             routing_key    = RoutingKey,
             correlation_id = CorrelationId,
             continuations  = Continuations}) ->
    Props = #'P_basic'{
                correlation_id = list_to_binary(integer_to_list(CorrelationId)),
                content_type   = <<"application/json">>
            },

    Publish = #'basic.publish'{exchange    = <<"celery">>,
			       routing_key = RoutingKey,
			       mandatory   = true},

    State1 = State#state{reply_queue=RequestId},
    Payload1 = msg_to_json(Payload#celery_msg{id = RequestId}),

    setup_reply_queue(State1),
    setup_consumer(State1),

    amqp_channel:call(Channel, Publish, #amqp_msg{props   = Props,
						  payload = Payload1}),
    State1#state{correlation_id = CorrelationId + 1,
		 continuations = dict:store(RequestId, {From, ReturnMethod}, Continuations)}.
    
setup_reply_queue(#state{channel = Channel, reply_queue = Q}) ->
    #'queue.declare_ok'{} =
        amqp_channel:call(Channel,
                          #'queue.declare'{
                                queue = Q, durable = false, auto_delete = true,
                                arguments = [{<<"x-expires">>, signedint,
                                              86400000}]}).

setup_consumer(#state{channel = Chan, reply_queue = Q}) ->
    amqp_channel:call(Chan, #'basic.consume'{queue = Q}).
    

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
    ejson:encode(M).
