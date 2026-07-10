-module(errm_json_tests).
-include_lib("eunit/include/eunit.hrl").
parse_basic_test() ->
  ?assertMatch({ok, null}, errm_json:decode(<<"null">>)),
  ?assertMatch({ok, true}, errm_json:decode(<<"true">>)),
  ?assertMatch({ok, false}, errm_json:decode(<<"false">>)).

parse_number_test() ->
  ?assertEqual({ok, 123}, errm_json:decode(<<"123">>)),
  ?assertEqual({ok, -456}, errm_json:decode(<<"-456">>)),
  ?assertEqual({ok, 1.23}, errm_json:decode(<<"1.23">>)),
  ?assertEqual({ok, -0.5}, errm_json:decode(<<"-0.5">>)),
  ?assertEqual({ok, 1.0e10}, errm_json:decode(<<"1.0e10">>)),
  ?assertEqual({ok, 1.0E-5}, errm_json:decode(<<"1.0E-5">>)).

parse_string_test() ->
  ?assertEqual({ok, <<"hello">>}, errm_json:decode(<<"\"hello\"">>)),
  ?assertEqual({ok, <<"\"quote\"">>}, errm_json:decode(<<"\"\\\"quote\\\"\"">>)),
  ?assertEqual({ok, <<"back\\slash">>}, errm_json:decode(<<"\"back\\\\slash\"">>)),
  ?assertEqual({ok, <<"new\nline">>}, errm_json:decode(<<"\"new\\nline\"">>)),
  ?assertEqual({ok, <<"Jörgen"/utf8>>}, errm_json:decode(<<"\"J\\u00F6rgen\"">>)),
  ?assertEqual({ok, <<"😀"/utf8>>}, errm_json:decode(<<"\"\\uD83D\\uDE00\"">>)).

parse_string_return_strings_test() ->
  Opts = #{return_strings => true},
  ?assertEqual({ok, "hello"}, errm_json:decode(<<"\"hello\"">>, Opts)),
  ?assertEqual({ok, "Jörgen"}, errm_json:decode(<<"\"J\\u00f6rgen\"">>, Opts)).

parse_object_test() ->
  Json = <<"{ \"name\": \"John\", \"age\": 30, \"active\": true}">>,
  Expected = #{<<"name">> => <<"John">>, <<"age">> => 30, <<"active">> => true},
  ?assertEqual({ok, Expected}, errm_json:decode(Json)).

parse_object_string_keys_test() ->
  Opts = #{return_strings => true},
  Json = <<"{ \"name\": \"John\", \"age\": 30, \"active\": true}">>,
  Expected = #{"name" => "John", "age" => 30, "active" => true},
  ?assertEqual({ok, Expected}, errm_json:decode(Json, Opts)).

parse_array_test() ->
  Json = <<"[1, \"two\", false, null]">>,
  Expected = [1, <<"two">>, false, null],
  ?assertEqual({ok, Expected}, errm_json:decode(Json)).

parse_empty_test() ->
  ?assertEqual({ok, []}, errm_json:decode(<<"[]">>)),
  ?assertEqual({ok, #{}}, errm_json:decode(<<"{}">>)).

parse_nested_test() ->
  Json = <<"{\"a\": {\"b\": [1,2,3]}, \"c\": {\"d\": true}}">>,
  Expected = #{<<"a">> => #{<<"b">> => [1,2,3]}, <<"c">> => #{<<"d">> => true}},
  ?assertEqual({ok, Expected}, errm_json:decode(Json)).

parse_trailing_garbage_test() ->
  ?assertMatch({error, {trailing_garbage, _}}, errm_json:decode(<<"{\"a\":1}\n">>)),
  ?assertMatch({error, {trailing_garbage, _}}, errm_json:decode(<<"{\"a\":1},">>)).

parse_invalid_test() ->
  ?assertMatch({error, _}, errm_json:decode(<<"{unquoted:1}">>)),
  ?assertMatch({error, _}, errm_json:decode(<<"[\"unclosed">>)),
  ?assertEqual({error, missing_number}, errm_json:decode(<<"{\"a\":1,\"b\":}">>)).

parse_depth_limit_test() ->
  Deep = list_to_binary(string:copies("[", 25) ++ "1" ++ string:copies("]", 25)),
  ?assertEqual({error, max_depth_exceeded}, errm_json:decode(Deep)),
  ?assertMatch({ok, _}, errm_json:decode(Deep, #{max_depth => 32})).

parse_stream_test() ->
  Json = <<"{\"a\":1}{\"b\":2}">>,
  {ok, Term1, Rest} = errm_json:decode_stream(Json),
  ?assertEqual(#{<<"a">> => 1}, Term1),
  {ok, Term2, <<>>} = errm_json:decode_stream(Rest),
  ?assertEqual(#{<<"b">> => 2}, Term2).


decode_lines_test() ->
  Buffer = <<"{\"a\":1}\n{\"b\":2}\n{\"c\":3}\n">>,
  Expected = [#{<<"a">> => 1}, #{<<"b">> => 2}, #{<<"c">> => 3}],
  ?assertEqual({ok, Expected, <<>>}, errm_json:decode_lines(Buffer)).

decode_lines_partial_test() ->
  Buffer = <<"{\"a\":1}\n{\"b\":2}\n{\"c\":">>,
  Expect = [#{<<"a">> => 1}, #{<<"b">> => 2}],
  ?assertEqual({ok, Expect, <<"{\"c\":">>}, errm_json:decode_lines(Buffer)).

decode_lines_empty_test() ->
  ?assertEqual({ok, [], <<>>}, errm_json:decode_lines(<<>>)).

decode_lines_with_options_test() ->
  Opts = #{return_strings => true},
  Buffer = <<"{\"a\":\"x\"}\n{\"b\":\"y\"}\n">>,
  Expect = [#{"a" => "x"}, #{"b" => "y"}],
  ?assertEqual({ok, Expect, <<>>}, errm_json:decode_lines(Buffer, Opts)).

writer_basic_test() ->
  ?assertEqual(<<"null">>, errm_json:to_binary(null)),
  ?assertEqual(<<"true">>, errm_json:to_binary(true)),
  ?assertEqual(<<"false">>, errm_json:to_binary(false)),
  ?assertEqual(<<"123">>, errm_json:to_binary(123)),
  ?assertEqual(<<"-456">>, errm_json:to_binary(-456)).

writer_string_test() ->
  ?assertEqual(<<"\"hello\"">>, errm_json:to_binary(<<"hello">>)),
  ?assertEqual(<<"\"\\\"quote\\\"\"">>, errm_json:to_binary(<<"\"quote\"">>)),
  ?assertEqual(<<"\"back\\\\slash\"">>, errm_json:to_binary(<<"back\\slash">>)),
  ?assertEqual(<<"\"new\\nline\"">>, errm_json:to_binary(<<"new\nline">>)),
  ?assertEqual(<<"\"Jörgen\"">>, errm_json:to_binary(<<"Jörgen">>)).

writer_atom_test() ->
  ?assertEqual(<<"\"hello\"">>, errm_json:to_binary('hello')),
  ?assertEqual(<<"true">>, errm_json:to_binary('true')),
  ?assertEqual(<<"null">>, errm_json:to_binary('null')).

writer_object_test() ->
  Map = #{<<"name">> => <<"John">>, <<"age">> => 30, <<"active">> => true},
  Json = errm_json:to_binary(Map),
  {ok, Map1} = errm_json:decode(Json),
  ?assertEqual(Map, Map1).

writer_array_test() ->
  List = [1, <<"two">>, false, null],
  Json = errm_json:to_binary(List),
  {ok, List1} = errm_json:decode(Json),
  ?assertEqual(List, List1).

writer_nested_test() ->
  Map = #{<<"a">> => #{<<"b">> => [1,2,3]}, <<"c">> => #{<<"d">> => true}},
  Json = errm_json:to_binary(Map),
  {ok, Map1} = errm_json:decode(Json),
  ?assertEqual(Map, Map1).



pretty_test() ->
  Map = #{<<"name">> => <<"John">>, <<"age">> => 30},
  Opts = #{pretty => true},
  Json = errm_json:to_binary(Map, Opts),
  {ok, Map1} = errm_json:decode(Json),
  ?assertEqual(Map, Map1).

pretty_indent_test() ->
  Map = #{<<"a">> => #{<<"b">> => 1}},
  Opts = #{pretty => true, indent => 4},
  Json = errm_json:to_binary(Map, Opts),
  {ok, Map1} = errm_json:decode(Json),
  ?assertEqual(Map, Map1).

pretty_empty_test() ->
  ?assertEqual(<<"{}">>, errm_json:to_binary(#{}, #{pretty => true})),
  ?assertEqual(<<"[]">>, errm_json:to_binary([],  #{pretty => true})).

roundtrip_test_() ->
  Terms = [
    null,
    true,
    false,
    42,
    -3.14,
    <<"hello">>,
    [1, 2, 3],
    #{<<"a">> => 1, <<"b">> => <<"c">>},
    #{<<"x">> => [null, true, false], <<"y">> => #{<<"z">> => 123}}
  ],
  [?_assertEqual(Term, begin {ok, T} = errm_json:decode(errm_json:to_binary(Term)), T end) || Term <- Terms].

% Ignore error here, its supposed to not pass the type-checker.
writer_unsupported_test() ->
  ?assertError({unsupported_term, _}, errm_json:to_binary({unsupported})).

parse_unicode_invalid_test() ->
  Invalid = <<"\"\\uD800\"">>,
  ?assertMatch({error, {unicode_error, _}}, errm_json:decode(Invalid)).
