-module(errm_json_writer).
-export([encode/1, encode/2, encode/3, to_binary/1, to_binary/2]).
-include("include/errm_json.hrl").

-spec encode(json_term()) -> iolist().
encode(Term) ->
  encode(Term, #{}).

-spec encode(json_term(), encode_options()) -> iolist().
encode(Term, Opts) ->
  Order = maps:get(order, Opts, undefined),
  case maps:get(pretty, Opts, false) of
    true -> 
      Indent = maps:get(indent, Opts, 2),
      encode_pretty(Term, 0, Indent, Order);
    false ->
      encode_value(Term, Order)
  end.

-spec encode(json_term(), encode_options(), [atom() | binary()]) -> iolist().
encode(Term, Opts, Order) ->
  case maps:get(pretty, Opts, false) of
    true ->
      Indent = maps:get(indent, Opts, 2),
      encode_pretty(Term, 0, Indent, Order);
    false ->
      encode_value(Term, Order)
  end.

-spec to_binary(json_term()) -> binary().
to_binary(Term) ->
  to_binary(Term, #{}).

-spec to_binary(json_term(), encode_options()) -> binary().
to_binary(Term, Opts) ->
  iolist_to_binary(encode(Term, Opts)).

encode_value(Term) -> encode_value(Term, undefined).
encode_value(null, _Order) -> <<"null">>;
encode_value(true, _Order) -> <<"true">>;
encode_value(false, _Order) -> <<"false">>;
encode_value(Int, _Order)   when is_integer(Int) -> integer_to_binary(Int);
encode_value(Float, _Order) when is_float(Float) -> float_to_binary(Float);
encode_value(Bin, _Order)   when is_binary(Bin)  -> [<<"\"">>, escape_binary(Bin), <<"\"">>];
encode_value(Atom, _Order)  when is_atom(Atom)   -> encode_value(atom_to_binary(Atom, utf8));
encode_value(List, Order) when is_list(List) ->
  case List of
    [] -> encode_array([], []);
    _ ->
      case io_lib:printable_list(List) of
        true  -> encode_value(unicode:characters_to_binary(List), Order);
        false -> encode_array(List, Order)
      end
  end;
encode_value(Map, Order)   when is_map(Map)     -> encode_object(Map, Order);
encode_value(Term, _Order) -> error({unsupported_term, Term}).


-spec escape_binary(binary()) -> iolist().
escape_binary(Bin) ->
  escape_binary(Bin, []).

escape_binary(<<>>, Acc) -> lists:reverse(Acc);
escape_binary(<<$", Rest/binary>>, Acc)  -> escape_binary(Rest, [<<"\\\"">> | Acc]);
escape_binary(<<$\\, Rest/binary>>, Acc) -> escape_binary(Rest, [<<"\\\\">> | Acc]);
escape_binary(<<$\b, Rest/binary>>, Acc) -> escape_binary(Rest, [<<"\\b">>  | Acc]);
escape_binary(<<$\f, Rest/binary>>, Acc) -> escape_binary(Rest, [<<"\\f">>  | Acc]);
escape_binary(<<$\n, Rest/binary>>, Acc) -> escape_binary(Rest, [<<"\\n">>  | Acc]);
escape_binary(<<$\r, Rest/binary>>, Acc) -> escape_binary(Rest, [<<"\\r">>  | Acc]);
escape_binary(<<$\t, Rest/binary>>, Acc) -> escape_binary(Rest, [<<"\\t">>  | Acc]);
escape_binary(<<C, Rest/binary>>, Acc) when C >= 32, C =/= 127 ->
  escape_binary(Rest, [<<C>> | Acc]);
escape_binary(<<C, Rest/binary>>, Acc) ->
  escape_binary(Rest, [<<"\\u", (integer_to_hex(C))/binary>> | Acc]).

integer_to_hex(N) when N < 16 ->
    <<(hex_char(N))>>;
integer_to_hex(N) ->
    <<(integer_to_hex(N div 16))/binary, (hex_char(N rem 16))>>.


hex_char(N) when N < 10 -> $0 + N;
hex_char(N) -> $A + (N - 10).


-spec encode_object(map(), undefined | [atom() | binary()]) -> iolist().
encode_object(Map, Order) ->
    io:format("encode_object Order: ~p~n", [Order]),
    Keys = get_ordered_keys(Map, Order),
    io:format("Keys: ~p~n", [Keys]),
    Pairs = build_pairs(Keys, Map, []),
    [<<"{">>, join(reverse_iolist_list(Pairs), ","), <<"}">>].


-spec build_pairs([any()], map(), [iolist()]) -> [iolist()].
build_pairs([], _Map, Acc) -> Acc;
build_pairs([Key | Keys], Map, Acc) ->
    Value = maps:get(Key, Map),
    KeyBin = encode_key(Key),
    Pair = [encode_value(KeyBin), <<":">>, encode_value(Value)],
    build_pairs(Keys, Map, [Pair | Acc]).


%% Custom reverse for [iolist()]
-spec reverse_iolist_list([iolist()]) -> [iolist()].
reverse_iolist_list(List) ->
    reverse_iolist_list(List, []).

reverse_iolist_list([], Acc) -> Acc;
reverse_iolist_list([H | T], Acc) -> reverse_iolist_list(T, [H | Acc]).

-spec encode_array(list(), undefined | [atom() | binary()]) -> iolist().
encode_array(List, Order) ->
  Elements = map_encode_value(List, Order),
  [<<"[">>, join(Elements, ","), <<"]">>].


-spec map_encode_value([json_term()], undefined | [atom() | binary()]) -> [iolist()].
map_encode_value([], _Order) ->
    [];
map_encode_value([H | T], Order) ->
    [encode_value(H, Order) | map_encode_value(T, Order)].

-spec join([iolist()], iolist()) -> iolist().
join([], _Sep) -> [];
join([H], _Sep) -> H;
join([H | T], Sep) -> [H, Sep | join(T, Sep)].

encode_pretty(null, _Depth, _Indent, _Order) ->
  encode_value(null);
encode_pretty(true, _Depth, _Indent, _Order) ->
  encode_value(true);
encode_pretty(false, _Depth, _Indent, _Order) ->
  encode_value(false);
encode_pretty(Int, _Depth, _Indent, _Order) when is_integer(Int) ->
  encode_value(Int);
encode_pretty(Float, _Depth, _Indent, _Order) when is_float(Float) ->
  float_to_binary(Float, [{decimals, 15}, compact]);
encode_pretty(Bin, _Depth, _Indent, _Order) when is_binary(Bin) ->
  encode_value(Bin);
encode_pretty(Atom, _Depth, _Indent, _Order) when is_atom(Atom) ->
  encode_value(Atom);
encode_pretty(List, Depth, Indent, Order) when is_list(List) ->
  case List of
    [] -> encode_array_pretty([], Depth, Indent, Order);
    _ ->
      case io_lib:printable_list(List) of
        true  -> encode_value(unicode:characters_to_binary(List), Order);
        false -> encode_array_pretty(List, Depth, Indent, Order)
      end
  end;
encode_pretty(Map, Depth, Indent, Order) when is_map(Map) ->
  encode_object_pretty(Map, Depth, Indent, Order).

-spec encode_object_pretty(map(), non_neg_integer(), non_neg_integer(),
                           undefined | [atom() | binary()]) -> iolist().
encode_object_pretty(Map, Indent, Step, Order) ->
    case maps:size(Map) of
        0 -> [<<"{">>, <<"}">>];
        _ ->
            Keys = get_ordered_keys(Map, Order),
            NewIndent = Indent + Step,
            Pairs = build_pretty_pairs(Keys, Map, NewIndent, Step, Order, []),
            [<<"{\n">>, join(reverse_iolist_list(Pairs), ",\n"), <<"\n">>, indent(Indent), <<"}">>]
    end.


-spec build_pretty_pairs([any()], map(), non_neg_integer(), non_neg_integer(),
                         undefined | [atom() | binary()], [iolist()]) -> [iolist()].
build_pretty_pairs([], _Map, _Indent, _Step, _Order, Acc) -> Acc;
build_pretty_pairs([Key | Keys], Map, Indent, Step, Order, Acc) ->
    Value = maps:get(Key, Map),
    KeyBin = encode_key(Key),
    Pair = [indent(Indent), encode_value(KeyBin), <<": ">>,
            encode_pretty(Value, Indent, Step, Order)],
    build_pretty_pairs(Keys, Map, Indent, Step, Order, [Pair | Acc]).


-spec encode_array_pretty(list(), non_neg_integer(), non_neg_integer(), undefined | [atom() | binary()]) -> iolist().
encode_array_pretty([], _Indent, _Step, _Order) -> [<<"[">>, <<"]">>];
encode_array_pretty(List, Indent, Step, Order) ->
  NewIndent = Indent + Step,
  Elements = map_pretty_elements(List, NewIndent, Step, Order),
  [<<"[\n">>, join(Elements, ",\n"), <<"\n">>, indent(Indent), <<"]">>].

-spec indent(non_neg_integer()) -> iolist().
indent(N) ->
    string:chars($\s, N).

-spec encode_key(any()) -> binary().
encode_key(Key) when is_binary(Key) -> Key;
encode_key(Key) when is_atom(Key) -> atom_to_binary(Key, utf8);
encode_key(Key) -> iolist_to_binary(io_lib:format("~p", [Key])).

-spec map_pretty_elements([json_term()], non_neg_integer(), non_neg_integer(), undefined | [binary() | atom()]) -> [iolist()].
map_pretty_elements([], _Indent, _Step, _Order) ->
    [];
map_pretty_elements([H | T], Indent, Step, Order) ->
    [ [indent(Indent), encode_pretty(H, Indent, Step, Order)] | map_pretty_elements(T, Indent, Step, Order)].

-spec get_ordered_keys(map(), undefined | [atom() | binary()]) -> [any()].
get_ordered_keys(Map, undefined) ->
    maps:keys(Map);
get_ordered_keys(Map, Order) ->
    AllKeys = maps:keys(Map),
    % elp:ignore W0036
    NormalizedMap = maps:from_list([{normalize_key(K), K} || K <- AllKeys]),
    NormalizedAll = maps:keys(NormalizedMap),
    NormalizedOrder = [normalize_key(K) || K <- Order],
    OrderedNormalized = [K || K <- NormalizedOrder, lists:member(K, NormalizedAll)],
    RemainingNormalized = lists:sort(NormalizedAll -- OrderedNormalized),
    OrderedKeys = [maps:get(K, NormalizedMap) || K <- OrderedNormalized],
    RemainingKeys = [maps:get(K, NormalizedMap) || K <- RemainingNormalized],
    OrderedKeys ++ RemainingKeys.

-spec normalize_key(any()) -> binary().
normalize_key(K) when is_atom(K) -> atom_to_binary(K, utf8);
normalize_key(K) when is_binary(K) -> K;
normalize_key(K) -> iolist_to_binary(io_lib:format("~p", [K])).
