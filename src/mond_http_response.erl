-module(mond_http_response).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-export([prepend_header/3, map/2]).
-export_type([response/1]).

-type response(FAV) :: {response, integer(), list({binary(), binary()}), FAV}.

-spec prepend_header(response(FBN), binary(), binary()) -> response(FBN).
prepend_header(Response, Key, Value) ->
    Headers = [{string:lowercase(Key), Value} | erlang:element(3, Response)],
    {response,
        erlang:element(2, Response),
        Headers,
        erlang:element(4, Response)}.

-spec set_body(response(any()), FBS) -> response(FBS).
set_body(Response, Body) ->
    {response, erlang:element(2, Response), erlang:element(3, Response), Body}.

-spec map(response(FBU), fun((FBU) -> FBW)) -> response(FBW).
map(Response, Transform) ->
    _pipe = erlang:element(4, Response),
    _pipe@1 = Transform(_pipe),
    set_body(Response, _pipe@1).
