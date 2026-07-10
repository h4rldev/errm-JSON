-module(errm_json).
-export([decode/1, decode/2, decode_stream/1, decode_stream/2, decode_lines/1, decode_lines/2, encode/1, encode/2, to_binary/1, to_binary/2, is_json/1]).
% elp:ignore W0020
-include("include/errm_json.hrl").


-export_type([json_term/0, parse_options/0, encode_options/0]).

-spec decode(Body :: binary()) -> {ok, Term :: json_term()} | {error, Reason :: term()}.
decode(Body) when is_binary(Body) -> decode(Body, #{}).

-spec decode(Body :: binary(), Opts :: parse_options()) -> {ok, Term :: json_term()} | {error, Reason :: term()}.
decode(Body, Opts) when is_binary(Body) ->
  case errm_json_parser:parse(Body, Opts) of
    {ok, Term, <<>>} -> {ok, Term};
    {ok, _, Rest} when byte_size(Rest) > 0 ->
      {error, {trailing_garbage, Rest}};
    {error, Reason} -> {error, Reason}
  end.

-spec decode_stream(Body :: binary()) -> {ok, Term :: json_term(), binary()} | {error, Reason :: term()}.
decode_stream(Body) when is_binary(Body) -> decode_stream(Body, #{}).

-spec decode_stream(Body :: binary(), Opts :: parse_options()) -> {ok, Term :: json_term(), binary()} | {error, Reason :: term()}.
decode_stream(Body, Opts) when is_binary(Body) ->
  errm_json_parser:parse(Body, Opts).

-spec decode_lines(Body :: binary()) -> {ok, Term :: json_term(), binary()} | {error, Reason :: term()}.
  decode_lines(Body) when is_binary(Body) -> decode_lines(Body, #{}).

-spec decode_lines(binary(), parse_options()) -> {ok, [json_term()], binary()} | {error, term()}.
decode_lines(Buffer, Opts) when is_binary(Buffer) ->
    decode_lines(Buffer, Opts, []).

decode_lines(<<>>, _Opts, Acc) ->
    {ok, lists:reverse(Acc), <<>>};
decode_lines(Buffer, Opts, Acc) ->
  case errm_json_parser:parse(Buffer, Opts) of
    {ok, Term, Rest} ->
      decode_lines(errm_json_parser:trim(Rest), Opts, [Term | Acc]);
    {error, Reason} ->
      case Acc of
        [] -> {error, Reason};
        _  -> {ok, lists:reverse(Acc), Buffer}
      end
  end.

-spec encode(Term :: json_term()) -> iolist().
  encode(Term) -> encode(Term, #{}).

-spec encode(Term :: json_term(), Opts :: encode_options()) -> iolist().
  encode(Term, Opts) -> errm_json_writer:encode(Term, Opts).

-spec to_binary(Term :: json_term()) -> binary().
  to_binary(Term) -> to_binary(Term, #{}).

-spec to_binary(Term :: json_term(), Opts :: encode_options()) -> binary().
  to_binary(Term, Opts) -> errm_json_writer:to_binary(Term, Opts).

-spec is_json(Body :: binary()) -> boolean().
is_json(Body) when is_binary(Body) ->
  case errm_json_parser:parse(Body) of
    {ok, _Term, <<>>} -> true;
    _ -> false
  end.
