-module(dqe_aggr2).

-behaviour(dflow).

-export([init/1, describe/1, start/2, emit/3, done/2]).

-record(state, {
          aggr :: atom(),
          time :: pos_integer(),
          acc = <<>> :: binary(),
          resolution :: pos_integer()
         }).

init([Aggr, SubQ, Time]) ->
    {ok, #state{aggr = Aggr, time = Time}, SubQ}.

start({_Start, _Count}, State) ->
    {ok, State}.

describe(#state{aggr = Aggr, time = Time}) ->
    [atom_to_list(Aggr), "(", integer_to_list(round(Time/1000)), "ms)"].

%% When we get the first data we can calculate both the applied
%% time and the upwards resolution.
emit(Child, {Data, Resolution},
     State = #state{resolution = undefined, time = Time}) ->
    Time1 = dqe_time:apply_times(Time, Resolution),
    emit(Child, {Data, Resolution},
         State#state{resolution = Time1 * Resolution, time = Time1});

emit(_Child, {Data, _R},
     State = #state{aggr = Aggr, time = Time, acc = Acc}) ->
    case execute(Aggr, <<Data/binary, Acc/binary>>, Time, <<>>) of
        {Acc1, <<>>} ->
            {ok, State#state{acc = Acc1}};
        {Acc2, AccEmit} ->
            {emit, {AccEmit, State#state.resolution}, State#state{acc = Acc2}}
    end.


done(_Child, State = #state{acc = <<>>}) ->
    {done, State};

done(_Child, State = #state{aggr = Aggr, time = Time, acc = Acc}) ->
    Data = mmath_aggr:Aggr(Acc, Time),
    {done, {Data, State#state.resolution}, State#state{acc = <<>>}}.


execute(Aggr, Acc, T1, AccEmit) when byte_size(Acc) >= T1 * 9 ->
    MinSize = T1 * 9,
    <<Data:MinSize/binary, Acc1/binary>> = Acc,
    Result = mmath_aggr:Aggr(Data, T1),
    execute(Aggr, Acc1, T1, <<AccEmit/binary, Result/binary>>);

execute(_, Acc, _, AccEmit) ->
    {Acc, AccEmit}.
