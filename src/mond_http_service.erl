-module(mond_http_service).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-export([map_response_body/2, prepend_response_header/3, method_override/1]).

-spec map_response_body(
    fun((FIP) -> mond_http_response:response(FIQ)),
    fun((FIQ) -> FIS)
) -> fun((FIP) -> mond_http_response:response(FIS)).
map_response_body(Service, Mapper) ->
    fun(Req) -> _pipe = Req,
        _pipe@1 = Service(_pipe),
        mond_http_response:map(_pipe@1, Mapper) end.

-spec prepend_response_header(
    fun((FIU) -> mond_http_response:response(FIV)),
    binary(),
    binary()
) -> fun((FIU) -> mond_http_response:response(FIV)).
prepend_response_header(Service, Key, Value) ->
    fun(Req) -> _pipe = Req,
        _pipe@1 = Service(_pipe),
        mond_http_response:prepend_header(_pipe@1, Key, Value) end.

-spec ensure_post(mond_http_request:request(FIY)) -> {ok,
        mond_http_request:request(FIY)} |
    {error, nil}.
ensure_post(Req) ->
    case erlang:element(2, Req) of
        post ->
            {ok, Req};

        _ ->
            {error, nil}
    end.

-spec get_override_method(mond_http_request:request(any())) -> {ok,
        mond_http:method()} |
    {error, nil}.
get_override_method(Request) ->
    mond_http_runtime:result_try(
        mond_http_request:get_query(Request),
        fun(Query_params) ->
            mond_http_runtime:result_try(
                mond_http_runtime:list_key_find(Query_params, <<"_method"/utf8>>),
                fun(Method) ->
                    mond_http_runtime:result_try(
                        mond_http:parse_method(Method),
                        fun(Method@1) -> case Method@1 of
                                put ->
                                    {ok, Method@1};

                                patch ->
                                    {ok, Method@1};

                                delete ->
                                    {ok, Method@1};

                                _ ->
                                    {error, nil}
                            end end
                    )
                end
            )
        end
    ).

-spec method_override(fun((mond_http_request:request(FJH)) -> FJJ)) -> fun((mond_http_request:request(FJH)) -> FJJ).
method_override(Service) ->
    fun(Request) -> _pipe = Request,
        _pipe@1 = ensure_post(_pipe),
        _pipe@2 = mond_http_runtime:result_try(_pipe@1, fun get_override_method/1),
        _pipe@3 = mond_http_runtime:result_map(
            _pipe@2,
            fun(_capture) ->
                mond_http_request:set_method(Request, _capture)
            end
        ),
        _pipe@4 = mond_http_runtime:result_unwrap(_pipe@3, Request),
        Service(_pipe@4) end.
