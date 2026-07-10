-module(errm_json_writer).
-export([encode/1, encode/2, to_binary/1, to_binary/2]).
-include("include/errm_json.hrl").

-spec encode(json_term()) -> iolist().
encode(Term) ->
  encode(Term, #{}).

-spec encode(json_term(), encode_options()) -> iolist().
encode(Term, Opts) ->
  case maps:get(pretty, Opts, false) of
    true -> 
      Indent = maps:get(indent, Opts, 2),
      encode_pretty(Term, 0, Indent);
    false ->
      encode_value(Term)
  end.

-spec to_binary(json_term()) -> binary().
to_binary(Term) ->
  to_binary(Term, #{}).

-spec to_binary(json_term(), encode_options()) -> binary().
to_binary(Term, Opts) ->
  iolist_to_binary(encode(Term, Opts)).

encode_value(null) -> <<"null">>;
encode_value(true) -> <<"true">>;
encode_value(false) -> <<"false">>;
encode_value(Int)   when is_integer(Int) -> integer_to_binary(Int);
encode_value(Float) when is_float(Float) -> float_to_binary(Float);
encode_value(Bin)   when is_binary(Bin)  -> [<<"\"">>, escape_binary(Bin), <<"\"">>];
encode_value(Atom)  when is_atom(Atom)   -> encode_value(atom_to_binary(Atom, utf8));
encode_value(List) when is_list(List) ->
    case io_lib:printable_list(List) of
      true -> encode_value(unicode:characters_to_binary(List));
      false -> encode_array(List)
    end;
encode_value(Map)   when is_map(Map)     -> encode_object(Map);
encode_value(Term) -> error({unsupported_term, Term}).


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


-spec encode_object(map()) -> iolist().
encode_object(Map) ->
  Pairs = maps:fold(
    fun(Key, Value, Acc) ->
      KeyBin = case Key of
        K when is_binary(K) -> K;
        K when is_atom(K) -> atom_to_binary(K, utf8);
        K -> iolist_to_binary(io_lib:format("~p", [K]))
      end,
      [[encode_value(KeyBin), <<":">>, encode_value(Value)] | Acc]
    end,
    [],
    Map
  ),

  [<<"{">>, join(reverse_iolist_list(Pairs), ","), <<"}">>].


%% Custom reverse for [iolist()]
-spec reverse_iolist_list([iolist()]) -> [iolist()].
reverse_iolist_list(List) ->
    reverse_iolist_list(List, []).

reverse_iolist_list([], Acc) -> Acc;
reverse_iolist_list([H | T], Acc) -> reverse_iolist_list(T, [H | Acc]).
-spec encode_array(list()) -> iolist().
encode_array(List) ->
  Elements = map_encode_value(List),
  [<<"[">>, join(Elements, ","), <<"]">>].


%% Custom map that preserves [iolist()] type
-spec map_encode_value([json_term()]) -> [iolist()].
map_encode_value([]) ->
    [];
map_encode_value([H | T]) ->
    [encode_value(H) | map_encode_value(T)].

-spec join([iolist()], iolist()) -> iolist().
join([], _Sep) -> [];
join([H], _Sep) -> H;
join([H | T], Sep) -> [H, Sep | join(T, Sep)].

encode_pretty(null, _Depth, _Indent) ->
  encode_value(null);
encode_pretty(true, _Depth, _Indent) ->
  encode_value(true);
encode_pretty(false, _Depth, _Indent) ->
  encode_value(false);
encode_pretty(Int, _Depth, _Indent) when is_integer(Int) ->
  encode_value(Int);
encode_pretty(Float, _Depth, _Indent) when is_float(Float) ->
  float_to_binary(Float, [{decimals, 15}, compact]);
encode_pretty(Bin, _Depth, _Indent) when is_binary(Bin) ->
  encode_value(Bin);
encode_pretty(Atom, _Depth, _Indent) when is_atom(Atom) ->
  encode_value(Atom);
encode_pretty(List, Depth, Indent) when is_list(List) ->
  encode_array_pretty(List, Depth, Indent);
encode_pretty(Map, Depth, Indent) when is_map(Map) ->
  encode_object_pretty(Map, Depth, Indent).

-spec encode_object_pretty(map(), non_neg_integer(), non_neg_integer()) -> iolist().
encode_object_pretty(Map, Indent, Step) ->
    case maps:size(Map) of
        0 -> [<<"{">>, <<"}">>];
        _ ->
            NewIndent = Indent + Step,
            IndentStr = indent(NewIndent),
            Pairs = maps:fold(
                fun(Key, Value, Acc) ->
                    KeyBin = encode_key(Key),
                    [[IndentStr, encode_value(KeyBin), <<": ">>, encode_pretty(Value, NewIndent, Step)] | Acc]
                end,
                [],
                Map
            ),
            [<<"{\n">>, join(reverse_iolist_list(Pairs), ",\n"), <<"\n">>, indent(Indent), <<"}">>]
    end.

-spec encode_array_pretty(list(), non_neg_integer(), non_neg_integer()) -> iolist().
encode_array_pretty([], _Indent, _Step) -> [<<"[">>, <<"]">>];
encode_array_pretty(List, Indent, Step) ->
  NewIndent = Indent + Step,
  Elements = map_pretty_elements(List, NewIndent, Step),
  [<<"[\n">>, join(Elements, ",\n"), <<"\n">>, indent(Indent), <<"]">>].

-spec indent(non_neg_integer()) -> iolist().
indent(N) ->
    string:chars($\s, N).

-spec encode_key(any()) -> binary().
encode_key(Key) when is_binary(Key) -> Key;
encode_key(Key) when is_atom(Key) -> atom_to_binary(Key, utf8);
encode_key(Key) -> iolist_to_binary(io_lib:format("~p", [Key])).

-spec map_pretty_elements([json_term()], non_neg_integer(), non_neg_integer()) -> [iolist()].
map_pretty_elements([], _Indent, _Step) ->
    [];
map_pretty_elements([H | T], Indent, Step) ->
    [ [indent(Indent), encode_pretty(H, Indent, Step)] | map_pretty_elements(T, Indent, Step)].

