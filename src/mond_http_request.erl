-module(mond_http_request).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-export([to_uri/1, from_uri/1, prepend_header/3, set_body/2, map/2, path_segments/1, get_query/1, set_query/2, set_method/2, new/0, to/1, set_scheme/2, set_host/2, set_port/2, set_path/2, set_cookie/3]).
-export_type([request/1]).

-if(?OTP_RELEASE >= 27).
-define(MODULEDOC(Str), -moduledoc(Str)).
-define(DOC(Str), -doc(Str)).
-else.
-define(MODULEDOC(Str), -compile([])).
-define(DOC(Str), -compile([])).
-endif.

-type option(T) :: none | {some, T}.

-type uri() :: {uri,
        option(binary()),
        option(binary()),
        option(binary()),
        option(integer()),
        binary(),
        option(binary()),
        option(binary())}.

-type request(EHL) :: {request,
        mond_http:method(),
        list({binary(), binary()}),
        EHL,
        mond_http:scheme(),
        binary(),
        option(integer()),
        binary(),
        option(binary())}.

?DOC(" Return the uri that a request was sent to.\n").
-spec to_uri(request(any())) -> uri().
to_uri(Request) ->
    {uri,
        {some, mond_http:scheme_to_string(erlang:element(5, Request))},
        none,
        {some, erlang:element(6, Request)},
        erlang:element(7, Request),
        erlang:element(8, Request),
        erlang:element(9, Request),
        none}.

?DOC(" Construct a request from a URI.\n").
-spec from_uri(uri()) -> {ok, request(binary())} | {error, nil}.
from_uri(Uri) ->
    mond_http_runtime:result_try(
        begin
            _pipe = erlang:element(2, Uri),
            _pipe@1 = mond_http_runtime:option_unwrap(_pipe, <<""/utf8>>),
            mond_http:scheme_from_string(_pipe@1)
        end,
        fun(Scheme) ->
            mond_http_runtime:result_try(
                begin
                    _pipe@2 = erlang:element(4, Uri),
                    mond_http_runtime:option_to_result(_pipe@2, nil)
                end,
                fun(Host) ->
                    Req = {request,
                        get,
                        [],
                        <<""/utf8>>,
                        Scheme,
                        Host,
                        erlang:element(5, Uri),
                        erlang:element(6, Uri),
                        erlang:element(7, Uri)},
                    {ok, Req}
                end
            )
        end
    ).

?DOC(
    " Prepend the header with the given value under the given header key.\n"
    "\n"
    " Similar to `set_header` except if the header already exists it prepends\n"
    " another header with the same key.\n"
    "\n"
    " Header keys are always lowercase in `gleam_http`. To use any uppercase\n"
    " letter is invalid.\n"
).
-spec prepend_header(request(EHY), binary(), binary()) -> request(EHY).
prepend_header(Request, Key, Value) ->
    Headers = [{string:lowercase(Key), Value} | erlang:element(3, Request)],
    {request,
        erlang:element(2, Request),
        Headers,
        erlang:element(4, Request),
        erlang:element(5, Request),
        erlang:element(6, Request),
        erlang:element(7, Request),
        erlang:element(8, Request),
        erlang:element(9, Request)}.

?DOC(" Set the body of the request, overwriting any existing body.\n").
-spec set_body(request(any()), EID) -> request(EID).
set_body(Req, Body) ->
    {request,
        erlang:element(2, Req),
        erlang:element(3, Req),
        Body,
        erlang:element(5, Req),
        erlang:element(6, Req),
        erlang:element(7, Req),
        erlang:element(8, Req),
        erlang:element(9, Req)}.

?DOC(" Update the body of a request using a given function.\n").
-spec map(request(EIF), fun((EIF) -> EIH)) -> request(EIH).
map(Request, Transform) ->
    _pipe = erlang:element(4, Request),
    _pipe@1 = Transform(_pipe),
    set_body(Request, _pipe@1).

?DOC(
    " Return the non-empty segments of a request path.\n"
    "\n"
    " # Examples\n"
    "\n"
    " ```gleam\n"
    " > new()\n"
    " > |> set_path(\"/one/two/three\")\n"
    " > |> path_segments\n"
    " [\"one\", \"two\", \"three\"]\n"
    " ```\n"
).
-spec path_segments(request(any())) -> list(binary()).
path_segments(Request) ->
    _pipe = erlang:element(8, Request),
    mond_http_runtime:uri_path_segments(_pipe).

?DOC(" Decode the query of a request.\n").
-spec get_query(request(any())) -> {ok, list({binary(), binary()})} |
    {error, nil}.
get_query(Request) ->
    case erlang:element(9, Request) of
        {some, Query_string} ->
            mond_http_runtime:uri_parse_query(Query_string);

        none ->
            {ok, []}
    end.

?DOC(
    " Set the query of the request.\n"
    " Query params will be percent encoded before being added to the Request.\n"
).
-spec set_query(request(EIR), list({binary(), binary()})) -> request(EIR).
set_query(Req, Query) ->
    Query@1 = begin
        _pipe = mond_http_runtime:list_map(
            Query,
            fun(Pair) ->
                {Key, Value} = Pair,
                <<<<(mond_http_runtime:uri_percent_encode(Key))/binary, "="/utf8>>/binary,
                    (mond_http_runtime:uri_percent_encode(Value))/binary>>
            end
        ),
        _pipe@1 = mond_http_runtime:string_join(_pipe, <<"&"/utf8>>),
        {some, _pipe@1}
    end,
    {request,
        erlang:element(2, Req),
        erlang:element(3, Req),
        erlang:element(4, Req),
        erlang:element(5, Req),
        erlang:element(6, Req),
        erlang:element(7, Req),
        erlang:element(8, Req),
        Query@1}.

?DOC(" Set the method of the request.\n").
-spec set_method(request(EIV), mond_http:method()) -> request(EIV).
set_method(Req, Method) ->
    {request,
        Method,
        erlang:element(3, Req),
        erlang:element(4, Req),
        erlang:element(5, Req),
        erlang:element(6, Req),
        erlang:element(7, Req),
        erlang:element(8, Req),
        erlang:element(9, Req)}.

?DOC(
    " A request with commonly used default values. This request can be used as\n"
    " an initial value and then update to create the desired request.\n"
).
-spec new() -> request(binary()).
new() ->
    {request,
        get,
        [],
        <<""/utf8>>,
        https,
        <<"localhost"/utf8>>,
        none,
        <<""/utf8>>,
        none}.

?DOC(" Construct a request from a URL string\n").
-spec to(binary()) -> {ok, request(binary())} | {error, nil}.
to(Url) ->
    _pipe = Url,
    _pipe@1 = mond_http_runtime:uri_parse(_pipe),
    mond_http_runtime:result_try(_pipe@1, fun from_uri/1).

?DOC(" Set the scheme (protocol) of the request.\n").
-spec set_scheme(request(EJC), mond_http:scheme()) -> request(EJC).
set_scheme(Req, Scheme) ->
    {request,
        erlang:element(2, Req),
        erlang:element(3, Req),
        erlang:element(4, Req),
        Scheme,
        erlang:element(6, Req),
        erlang:element(7, Req),
        erlang:element(8, Req),
        erlang:element(9, Req)}.

?DOC(" Set the host of the request.\n").
-spec set_host(request(EJF), binary()) -> request(EJF).
set_host(Req, Host) ->
    {request,
        erlang:element(2, Req),
        erlang:element(3, Req),
        erlang:element(4, Req),
        erlang:element(5, Req),
        Host,
        erlang:element(7, Req),
        erlang:element(8, Req),
        erlang:element(9, Req)}.

?DOC(" Set the port of the request.\n").
-spec set_port(request(EJI), integer()) -> request(EJI).
set_port(Req, Port) ->
    {request,
        erlang:element(2, Req),
        erlang:element(3, Req),
        erlang:element(4, Req),
        erlang:element(5, Req),
        erlang:element(6, Req),
        {some, Port},
        erlang:element(8, Req),
        erlang:element(9, Req)}.

?DOC(" Set the path of the request.\n").
-spec set_path(request(EJL), binary()) -> request(EJL).
set_path(Req, Path) ->
    {request,
        erlang:element(2, Req),
        erlang:element(3, Req),
        erlang:element(4, Req),
        erlang:element(5, Req),
        erlang:element(6, Req),
        erlang:element(7, Req),
        Path,
        erlang:element(9, Req)}.

?DOC(
    " Set a cookie on a request, replacing any previous cookie with that name.\n"
    "\n"
    " All cookies should be stored in a single header named `cookie`.\n"
    " There should be at most one header with the name `cookie`, otherwise this\n"
    " function cannot guarentee that previous cookies with the same name are\n"
    " replaced.\n"
).
-spec set_cookie(request(EJO), binary(), binary()) -> request(EJO).
set_cookie(Req, Name, Value) ->
    {Cookies, Headers} = begin
        _pipe = mond_http_runtime:list_key_pop(erlang:element(3, Req), <<"cookie"/utf8>>),
        mond_http_runtime:result_unwrap(_pipe, {<<""/utf8>>, erlang:element(3, Req)})
    end,
    Cookies@1 = begin
        _pipe@1 = mond_http_cookie:parse(Cookies),
        _pipe@2 = mond_http_runtime:list_key_set(_pipe@1, Name, Value),
        _pipe@3 = mond_http_runtime:list_map(
            _pipe@2,
            fun(Pair) ->
                <<<<(erlang:element(1, Pair))/binary, "="/utf8>>/binary,
                    (erlang:element(2, Pair))/binary>>
            end
        ),
        mond_http_runtime:string_join(_pipe@3, <<"; "/utf8>>)
    end,
    {request,
        erlang:element(2, Req),
        [{<<"cookie"/utf8>>, Cookies@1} | Headers],
        erlang:element(4, Req),
        erlang:element(5, Req),
        erlang:element(6, Req),
        erlang:element(7, Req),
        erlang:element(8, Req),
        erlang:element(9, Req)}.
