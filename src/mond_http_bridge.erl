-module(mond_http_bridge).

-export([
    http_parse_method/1,
    http_method_to_string/1,
    http_scheme_to_string/1,
    http_scheme_from_string/1,
    http_parse_multipart_headers/2,
    http_parse_multipart_body/2,
    http_parse_content_disposition/1,

    cookie_defaults/1,
    cookie_set_header/3,
    cookie_parse/1,

    request_to_uri/1,
    request_from_uri/1,
    request_prepend_header/3,
    request_set_body/2,
    request_map/2,
    request_path_segments/1,
    request_get_query/1,
    request_set_query/2,
    request_set_method/2,
    request_new/0,
    request_to/1,
    request_set_scheme/2,
    request_set_host/2,
    request_set_port/2,
    request_set_path/2,
    request_set_cookie/3,

    service_map_response_body/2,
    service_prepend_response_header/3,
    service_method_override/1
]).

%% Native Mond Header  = {header, Name, Value}
%% Runtime Header      = {Name, Value}

to_runtime_header({header, Name, Value}) ->
    {Name, Value};
to_runtime_header({Name, Value}) ->
    {Name, Value}.

from_runtime_header({Name, Value}) ->
    {header, Name, Value};
from_runtime_header({header, Name, Value}) ->
    {header, Name, Value}.

to_runtime_headers(Headers) ->
    [to_runtime_header(Header) || Header <- Headers].

from_runtime_headers(Headers) ->
    [from_runtime_header(Header) || Header <- Headers].

%% Native Mond Request = {request, Method, [NativeHeader], Body, Scheme, Host, Port, Path, Query}
%% Runtime Request     = {request, Method, [RuntimeHeader], Body, Scheme, Host, Port, Path, Query}

to_runtime_request({request, Method, Headers, Body, Scheme, Host, Port, Path, Query}) ->
    {request, Method, to_runtime_headers(Headers), Body, Scheme, Host, Port, Path, Query};
to_runtime_request(Request) ->
    Request.

from_runtime_request({request, Method, Headers, Body, Scheme, Host, Port, Path, Query}) ->
    {request, Method, from_runtime_headers(Headers), Body, Scheme, Host, Port, Path, Query};
from_runtime_request(Request) ->
    Request.

%% Native Mond Response = {response, Status, [NativeHeader], Body}
%% Runtime Response     = {response, Status, [RuntimeHeader], Body}

to_runtime_response({response, Status, Headers, Body}) ->
    {response, Status, to_runtime_headers(Headers), Body};
to_runtime_response(Response) ->
    Response.

from_runtime_response({response, Status, Headers, Body}) ->
    {response, Status, from_runtime_headers(Headers), Body};
from_runtime_response(Response) ->
    Response.

%% Native Mond ContentDisposition = {contentdisposition, Disposition, [NativeHeader]}
%% Runtime ContentDisposition     = {content_disposition, Disposition, [RuntimeHeader]}

from_runtime_content_disposition({content_disposition, Disposition, Parameters}) ->
    {contentdisposition, Disposition, from_runtime_headers(Parameters)}.

http_parse_method(Method) ->
    mond_http:parse_method(Method).

http_method_to_string(Method) ->
    mond_http:method_to_string(Method).

http_scheme_to_string(Scheme) ->
    mond_http:scheme_to_string(Scheme).

http_scheme_from_string(Scheme) ->
    mond_http:scheme_from_string(Scheme).

http_parse_multipart_headers(Data, Boundary) ->
    mond_http:parse_multipart_headers(Data, Boundary).

http_parse_multipart_body(Data, Boundary) ->
    mond_http:parse_multipart_body(Data, Boundary).

http_parse_content_disposition(Header) ->
    case mond_http:parse_content_disposition(Header) of
        {ok, ContentDisposition} ->
            {ok, from_runtime_content_disposition(ContentDisposition)};
        {error, _} = Error ->
            Error
    end.

cookie_defaults(Scheme) ->
    mond_http_cookie:defaults(Scheme).

cookie_set_header(Name, Value, Attributes) ->
    mond_http_cookie:set_header(Name, Value, Attributes).

cookie_parse(CookieString) ->
    from_runtime_headers(mond_http_cookie:parse(CookieString)).

request_to_uri(Request) ->
    mond_http_request:to_uri(to_runtime_request(Request)).

request_from_uri(Uri) ->
    case mond_http_request:from_uri(Uri) of
        {ok, Request} ->
            {ok, from_runtime_request(Request)};
        {error, _} = Error ->
            Error
    end.

request_prepend_header(Request, Key, Value) ->
    from_runtime_request(
        mond_http_request:prepend_header(to_runtime_request(Request), Key, Value)
    ).

request_set_body(Request, Body) ->
    from_runtime_request(mond_http_request:set_body(to_runtime_request(Request), Body)).

request_map(Request, Transform) ->
    from_runtime_request(mond_http_request:map(to_runtime_request(Request), Transform)).

request_path_segments(Request) ->
    mond_http_request:path_segments(to_runtime_request(Request)).

request_get_query(Request) ->
    case mond_http_request:get_query(to_runtime_request(Request)) of
        {ok, Query} ->
            {ok, from_runtime_headers(Query)};
        {error, _} = Error ->
            Error
    end.

request_set_query(Request, Query) ->
    from_runtime_request(
        mond_http_request:set_query(to_runtime_request(Request), to_runtime_headers(Query))
    ).

request_set_method(Request, Method) ->
    from_runtime_request(mond_http_request:set_method(to_runtime_request(Request), Method)).

request_new() ->
    from_runtime_request(mond_http_request:new()).

request_to(Url) ->
    case mond_http_request:to(Url) of
        {ok, Request} ->
            {ok, from_runtime_request(Request)};
        {error, _} = Error ->
            Error
    end.

request_set_scheme(Request, Scheme) ->
    from_runtime_request(mond_http_request:set_scheme(to_runtime_request(Request), Scheme)).

request_set_host(Request, Host) ->
    from_runtime_request(mond_http_request:set_host(to_runtime_request(Request), Host)).

request_set_port(Request, Port) ->
    from_runtime_request(mond_http_request:set_port(to_runtime_request(Request), Port)).

request_set_path(Request, Path) ->
    from_runtime_request(mond_http_request:set_path(to_runtime_request(Request), Path)).

request_set_cookie(Request, Name, Value) ->
    from_runtime_request(mond_http_request:set_cookie(to_runtime_request(Request), Name, Value)).

service_map_response_body(Service, Mapper) ->
    WrappedService = fun(ReqRuntime) ->
        ReqMond = from_runtime_request(ReqRuntime),
        RespMond = Service(ReqMond),
        to_runtime_response(RespMond)
    end,
    Wrapped = mond_http_service:map_response_body(WrappedService, Mapper),
    fun(ReqMond) ->
        ReqRuntime = to_runtime_request(ReqMond),
        RespRuntime = Wrapped(ReqRuntime),
        from_runtime_response(RespRuntime)
    end.

service_prepend_response_header(Service, Key, Value) ->
    WrappedService = fun(ReqRuntime) ->
        ReqMond = from_runtime_request(ReqRuntime),
        RespMond = Service(ReqMond),
        to_runtime_response(RespMond)
    end,
    Wrapped = mond_http_service:prepend_response_header(WrappedService, Key, Value),
    fun(ReqMond) ->
        ReqRuntime = to_runtime_request(ReqMond),
        RespRuntime = Wrapped(ReqRuntime),
        from_runtime_response(RespRuntime)
    end.

service_method_override(Service) ->
    WrappedService = fun(ReqRuntime) ->
        ReqMond = from_runtime_request(ReqRuntime),
        RespMond = Service(ReqMond),
        to_runtime_response(RespMond)
    end,
    Wrapped = mond_http_service:method_override(WrappedService),
    fun(ReqMond) ->
        ReqRuntime = to_runtime_request(ReqMond),
        RespRuntime = Wrapped(ReqRuntime),
        from_runtime_response(RespRuntime)
    end.
