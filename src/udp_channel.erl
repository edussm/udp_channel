
-module(udp_channel).

-behaviour(gen_server).

%% API
-export([start/3, start_link/3, start_link/4]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
     terminate/2, code_change/3]).

-record(state, {
    local_sock :: gen_udp:socket(),
    lastTimestamp_local :: erlang:timestamp(),
    handler :: atom(),
    npackets :: integer(),
    timeout :: integer()
}).

-define(INFO(M, P), io:format(M, P)).
-define(ERROR(M, P), io:format(M, P)).

-define(TM, erlang:system_time(millisecond)).
-define(SOCKOPTS, [binary, {active, once}]).

%%====================================================================
%% API
%%====================================================================
start_link(P1, Timeout, Handler) ->
    gen_server:start_link(?MODULE, [P1, Timeout, Handler], []).

start_link(Name, P1, Timeout, Handler) ->
    gen_server:start_link({local, Name}, ?MODULE, [P1, Timeout, Handler], []).

start(P1, Timeout, Handler) ->
    gen_server:start({local, ?MODULE}, ?MODULE, [P1, Timeout, Handler], []).

%%====================================================================
%% gen_server callbacks
%%====================================================================
init([Port, Timeout, Handler]) ->
    case gen_udp:open(Port, ?SOCKOPTS) of
    {ok, Local_Sock} ->
        ?INFO("relay started at ~p and ~p", [Port, Handler]),
        {ok, #state{
            local_sock = Local_Sock, 
            handler = Handler,
            lastTimestamp_local = ?TM,
            npackets=0,
            timeout=Timeout
        }};
    Error ->
        ?ERROR("unable to open port: ~p", [Error])
    end.

handle_call(get_timestamp, _From, State) ->
    {reply, {State#state.lastTimestamp_local, State#state.npackets}, State};
handle_call(_Request, _From, State) ->
    {reply, ok, State}.

handle_cast(stop, State) ->
    {stop, normal, State};
handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info({udp, Sock, SrcIP, SrcPort, Data},
        #state{local_sock = Sock, npackets=NPackets, handler = Handler} = State) ->
    inet:setopts(Sock, [{active, once}]),
    ?INFO("Received Packet: ~p ~n", [Data]),
    process(Sock, SrcIP, SrcPort, Data, Handler),
    {noreply, State#state{lastTimestamp_local=?TM, npackets=NPackets+1}};
handle_info(_Info, State) ->
    ?INFO("Unknown Info: ~p ~n", [_Info]),
    {noreply, State}.

terminate(_Reason, _State) ->
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%%--------------------------------------------------------------------
%%% Internal functions
%%--------------------------------------------------------------------
process(Sock, Addr, Port, Data, Handler) ->
    ?INFO("Handler ~p ~n", [Handler]),
    Handler ! {Sock, Addr, Port, Data}.

-ifdef(EUNIT).

-include_lib("eunit/include/eunit.hrl").

abc_test() -> 
    ?INFO("Testing Nothing... ~n", []).

-endif.