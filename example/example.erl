-module(example).
-export([main/1]).

main(_Args) ->
  file:write_file("example/example_write.json", errm_json:to_binary(#{<<"a">> => 1})),
  {ok, Conts} = file:read_file("example/example_read.json"),
  {ok, Json, _Rest} = errm_json:decode_stream(Conts),
  io:format("~p~n", [Json]),
  Opts = #{pretty => true, indent => 2, order => [<<"Acronym">>, <<"Abbrev">>]},
  file:write_file("example/example_write2.json", errm_json:to_binary(Json, Opts)).
