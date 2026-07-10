-module(errm_json_parser).
-export([parse/1, parse/2, trim/1]).
-include("include/errm_json.hrl").

-type chars() :: [char()].
-type json_string() :: binary() | chars().


-spec parse(Body :: binary()) -> {ok, json_term(), binary()} | {error, Reason :: term()}.
parse(Body) when is_binary(Body) ->
  parse(Body, #{}).

-spec parse(Body :: binary(), Opts :: parse_options()) -> {ok, json_term(), binary()} | {error, Reason :: term()}.
parse(Body, Opts) ->
  parse_value(trim(Body), 0, Opts).

-spec parse_value(binary(), non_neg_integer(),  map()) ->  {ok, json_term(), binary()} | {error, Reason :: term()}.
parse_value(<<$n, $u, $l, $l, Rest/binary>>, _Depth, _Opts) ->
  {ok, null, Rest};
parse_value(<<$t, $r, $u, $e, Rest/binary>>, _Depth, _Opts) ->
  {ok, true, Rest};
parse_value(<<$f, $a, $l, $s, $e, Rest/binary>>, _Depth, _Opts) ->
  {ok, false, Rest};
parse_value(<<$", Rest/binary>>, _Depth, Opts) ->
  parse_string(Rest, [], Opts);

parse_value(<<${, Rest/binary>>, Depth, Opts) ->
  MaxDepth = maps:get(max_depth, Opts, 20),
  NewDepth = Depth + 1,
  case MaxDepth > 0 andalso NewDepth > MaxDepth of
    true -> {error, max_depth_exceeded};
    false -> parse_object(trim(Rest), #{}, NewDepth, Opts)
  end;

parse_value(<<$[, Rest/binary>>, Depth, Opts) ->
  MaxDepth = maps:get(max_depth, Opts, 20),
  NewDepth = Depth + 1,
  case MaxDepth > 0 andalso NewDepth > MaxDepth of
    true -> {error, max_depth_exceeded};
    false -> parse_array(trim(Rest), [], NewDepth, Opts)
  end;

parse_value(Bin, _Depth, _Opts) when is_binary(Bin) ->
  case parse_number(Bin) of
    {ok, Num, Rest} -> {ok, Num, Rest};
    {error, _} = Err -> Err
  end;


parse_value(Bin, _Depth, _Opts) ->
  {error, {unexpected_token, binary_to_list(Bin, 1, min(20, byte_size(Bin)))}}.



-spec parse_number(binary()) -> {ok, number() | float(), binary()} | {error, Reason :: term()}.
parse_number(Bin) ->
  split_number(Bin, <<>>).

split_number(<<C, Rest/binary>>, Acc) when
  (C >= $0 andalso C =< $9) orelse
  C =:= $. orelse C =:= $- orelse
  C =:= $+ orelse C =:= $e orelse
  C =:= $E ->
  split_number(Rest, <<Acc/binary, C>>);
split_number(Bin, Acc) ->
  case Acc of
    <<>> -> {error, missing_number};
    _ ->
      try
        case binary:match(Acc, [<<$.>>, <<$e>>, <<$E>>]) of
          nomatch -> {ok, binary_to_integer(Acc), Bin};
          _       -> {ok, binary_to_float(Acc), Bin}
        end
      catch
        error:badarg -> {error, {invalid_number, Acc}}
      end
  end.


-spec parse_string(binary(), Acc :: chars(), Opts :: map()) -> {ok, json_string(), binary()} | {error, Reason :: term()}.

parse_string(<<$\\, $u, A, B, C, D, Rest/binary>>, Acc, Opts) ->
  Hex = hex_to_int([A, B, C, D]),
  parse_string(Rest, [Hex | Acc], Opts);


parse_string(<<$\\, $", Rest/binary>>, Acc, Opts) ->
  parse_string(Rest, [$" | Acc], Opts);
parse_string(<<$\\, $\\, Rest/binary>>, Acc, Opts) ->
  parse_string(Rest, [$\\ | Acc], Opts);
parse_string(<<$\\, $/, Rest/binary>>, Acc, Opts) ->
  parse_string(Rest, [$/ | Acc], Opts);
parse_string(<<$\\, $b, Rest/binary>>, Acc, Opts) ->
  parse_string(Rest, [$\b | Acc], Opts);
parse_string(<<$\\, $f, Rest/binary>>, Acc, Opts) ->
  parse_string(Rest, [$\f | Acc], Opts);
parse_string(<<$\\, $n, Rest/binary>>, Acc, Opts) ->
  parse_string(Rest, [$\n | Acc], Opts);
parse_string(<<$\\, $r, Rest/binary>>, Acc, Opts) ->
  parse_string(Rest, [$\r | Acc], Opts);
parse_string(<<$\\, $t, Rest/binary>>, Acc, Opts) ->
  parse_string(Rest, [$\t | Acc], Opts);

parse_string(<<$", Rest/binary>>, Acc, Opts) ->
  String = combine_surrogates(reverse_chars(Acc)),
  case maps:get(return_strings, Opts, false) of
    true ->
      {ok, String, Rest};
    false ->
      case unicode:characters_to_binary(String) of
        Bin when is_binary(Bin) ->
          {ok, Bin, Rest};
        {error, _, _} = Err ->
          {error, {unicode_error, Err}};
        {incomplete, _, _} = Inc ->
          {error, {unicode_incomplete, Inc}}
      end
  end;
parse_string(<<C, Rest/binary>>, Acc, Opts) when C >= 32 ->
    parse_string(Rest, [C | Acc], Opts);
parse_string(<<C, _Rest/binary>>, _Acc, _Opts) when C < 32 ->
  {error, {invalid_control_character, C}};
parse_string(<<>>, _Acc, _Opts) ->
  {error, unclosed_string}.

-spec trim(binary()) -> binary().
trim(<<C, Rest/binary>>) when C =:= 32; C=:= 10; C =:= 13; C =:= 9 -> trim(Rest);
trim(Data) -> Data.

-spec hex_to_int([char()]) -> integer().
hex_to_int(Hex) ->
  hex_to_int(Hex, 0).

hex_to_int([], Acc) -> Acc;
hex_to_int([C | Rest], Acc) ->
  Val = case C of
    C when C >= $0, C =< $9 -> C - $0;
    C when C >= $A, C =< $F -> C - $A + 10;
    C when C >= $a, C =< $f -> C - $a + 10;
    _ -> error({invalid_hex, C})
  end,
  hex_to_int(Rest, Acc * 16 + Val).

-spec reverse_chars(chars()) -> chars().
reverse_chars(Chars) ->
    reverse_chars(Chars, []).

reverse_chars([], Acc) -> Acc;
reverse_chars([H | T], Acc) -> reverse_chars(T, [H | Acc]).

-spec parse_object(binary(), map(), non_neg_integer(), map()) -> {ok, json_term(), binary()} | {error, term()}.
parse_object(Bin, Acc, Depth, Opts) ->
    parse_object_loop(trim(Bin), Acc, Depth, Opts).

parse_object_loop(<<$}, Rest/binary>>, Acc, _Depth, _Opts) ->
    {ok, Acc, Rest};
parse_object_loop(Bin, Acc, Depth, Opts) ->
    case parse_value(trim(Bin), Depth, Opts) of
      {ok, Key, Rest} -> parse_object_key_value(trim(Rest), Key, Acc, Depth, Opts);
      {error, Reason} -> {error, Reason}
    end.

%% Handle the colon after the key
parse_object_key_value(<<$:, Rest/binary>>, Key, Acc, Depth, Opts) ->
    case parse_value(trim(Rest), Depth, Opts) of
      {ok, Value, Rest1} -> parse_object_after_value(trim(Rest1), Acc, Key, Value, Depth, Opts);
      {error, Reason} -> {error, Reason}
    end;
parse_object_key_value(Bin, _Key, _Acc, _Depth, _Opts) ->
    {error, {expected_colon, Bin}}.

%% Handle comma or closing brace after the value
parse_object_after_value(<<$,, Rest/binary>>, Acc, Key, Value, Depth, Opts) ->
    parse_object_loop(Rest, Acc#{Key => Value}, Depth, Opts);
parse_object_after_value(<<$}, Rest/binary>>, Acc, Key, Value, _Depth, _Opts) ->
    {ok, Acc#{Key => Value}, Rest};
parse_object_after_value(Other, _Acc, _Key, _Value, _Depth, _Opts) ->
    {error, {expected_comma_or_brace, Other}}.


-spec parse_array(binary(), [json_term()], non_neg_integer(), map()) -> {ok, [json_term()], binary()} | {error, term()}.
parse_array(Bin, Acc, Depth, Opts) ->
    parse_array_loop(trim(Bin), Acc, Depth, Opts).

parse_array_loop(<<$], Rest/binary>>, Acc, _Depth, _Opts) ->
    {ok, reverse_json_list(Acc), Rest};
parse_array_loop(Bin, Acc, Depth, Opts) ->
    case parse_value(trim(Bin), Depth, Opts) of
      {ok, Value, Rest1} -> parse_array_after_value(trim(Rest1), Acc, Value, Depth, Opts);
      {error, Reason} -> {error, Reason}
    end.

parse_array_after_value(<<$,, Rest/binary>>, Acc, Value, Depth, Opts) ->
    parse_array_loop(Rest, [Value | Acc], Depth, Opts);
parse_array_after_value(<<$], Rest/binary>>, Acc, Value, _Depth, _Opts) ->
    {ok, reverse_json_list([Value | Acc]), Rest};
parse_array_after_value(Other, _Acc, _Value, _Depth, _Opts) ->
    {error, {expected_comma_or_bracket, Other}}.
-spec reverse_json_list([json_term()]) -> [json_term()].
reverse_json_list(List) ->
    reverse_json_list(List, []).

reverse_json_list([], Acc) -> Acc;
reverse_json_list([H | T], Acc) -> reverse_json_list(T, [H | Acc]).

combine_surrogates([]) -> [];
combine_surrogates([H | T]) when H >= 16#D800, H =< 16#DBFF ->
    case T of
        [L | Rest] when L >= 16#DC00, L =< 16#DFFF ->
            Combined = 16#10000 + ((H - 16#D800) bsl 10) + (L - 16#DC00),
            [Combined | combine_surrogates(Rest)];
        _ ->
            [H | combine_surrogates(T)]
    end;
combine_surrogates([H | T]) ->
    [H | combine_surrogates(T)].
