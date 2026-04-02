-module(mond_http_cookie).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-export([parse/1, set_header/3]).
-export_type([same_site_policy/0, attributes/0]).

-if(?OTP_RELEASE >= 27).
-define(MODULEDOC(Str), -moduledoc(Str)).
-define(DOC(Str), -doc(Str)).
-else.
-define(MODULEDOC(Str), -compile([])).
-define(DOC(Str), -compile([])).
-endif.

-type option(T) :: none | {some, T}.

-type same_site_policy() :: lax | strict | none.

-type attributes() :: {attributes,
        option(integer()),
        option(binary()),
        option(binary()),
        boolean(),
        boolean(),
        option(same_site_policy())}.

-spec same_site_to_string(same_site_policy()) -> binary().
same_site_to_string(Policy) ->
    case Policy of
        lax ->
            <<"Lax"/utf8>>;

        strict ->
            <<"Strict"/utf8>>;

        none ->
            <<"None"/utf8>>
    end.

-spec check_token(binary()) -> {ok, nil} | {error, nil}.
check_token(Token) ->
    Contains_invalid_charachter = (((mond_http_runtime:string_contains(
        Token,
        <<" "/utf8>>
    )
    orelse mond_http_runtime:string_contains(Token, <<"\t"/utf8>>))
    orelse mond_http_runtime:string_contains(Token, <<"\r"/utf8>>))
    orelse mond_http_runtime:string_contains(Token, <<"\n"/utf8>>))
    orelse mond_http_runtime:string_contains(Token, <<"\f"/utf8>>),
    case Contains_invalid_charachter of
        true ->
            {error, nil};

        false ->
            {ok, nil}
    end.

?DOC(
    " Parse a list of cookies from a header string. Any malformed cookies will be\n"
    " discarded.\n"
    "\n"
    " ## Backwards compatibility\n"
    "\n"
    " RFC 6265 states that cookies in the cookie header should be separated by a\n"
    " `;`, however this function will also accept a `,` separator to remain\n"
    " compatible with the now-deprecated RFC 2965, and any older software\n"
    " following that specification.\n"
).
-spec parse(binary()) -> list({binary(), binary()}).
parse(Cookie_string) ->
    _pipe = Cookie_string,
    _pipe@1 = mond_http_runtime:string_split(_pipe, <<";"/utf8>>),
    _pipe@2 = mond_http_runtime:list_flat_map(
        _pipe@1,
        fun(_capture) -> mond_http_runtime:string_split(_capture, <<","/utf8>>) end
    ),
    mond_http_runtime:list_filter_map(
        _pipe@2,
        fun(Pair) ->
            case mond_http_runtime:string_split_once(mond_http_runtime:string_trim(Pair), <<"="/utf8>>) of
                {ok, {<<""/utf8>>, _}} ->
                    {error, nil};

                {ok, {Key, Value}} ->
                    Key@1 = mond_http_runtime:string_trim(Key),
                    mond_http_runtime:result_try(
                        check_token(Key@1),
                        fun(_) ->
                            Value@1 = mond_http_runtime:string_trim(Value),
                            mond_http_runtime:result_try(
                                check_token(Value@1),
                                fun(_) -> {ok, {Key@1, Value@1}} end
                            )
                        end
                    );

                {error, nil} ->
                    {error, nil}
            end
        end
    ).

-spec cookie_attributes_to_list(attributes()) -> list(binary()).
cookie_attributes_to_list(Attributes) ->
    {attributes, Max_age, Domain, Path, Secure, Http_only, Same_site} = Attributes,
    _pipe = [case Max_age of
            {some, 0} ->
                {some, <<"Expires=Thu, 01 Jan 1970 00:00:00 GMT"/utf8>>};

            _ ->
                none
        end, mond_http_runtime:option_map(
            Max_age,
            fun(Max_age@1) ->
                <<"Max-Age="/utf8,
                    (erlang:integer_to_binary(Max_age@1))/binary>>
            end
        ), mond_http_runtime:option_map(
            Domain,
            fun(Domain@1) -> <<"Domain="/utf8, Domain@1/binary>> end
        ), mond_http_runtime:option_map(
            Path,
            fun(Path@1) -> <<"Path="/utf8, Path@1/binary>> end
        ), case Secure of
            true ->
                {some, <<"Secure"/utf8>>};

            false ->
                none
        end, case Http_only of
            true ->
                {some, <<"HttpOnly"/utf8>>};

            false ->
                none
        end, mond_http_runtime:option_map(
            Same_site,
            fun(Same_site@1) ->
                <<"SameSite="/utf8, (same_site_to_string(Same_site@1))/binary>>
            end
        )],
    mond_http_runtime:list_filter_map(
        _pipe,
        fun(_capture) -> mond_http_runtime:option_to_result(_capture, nil) end
    ).

-spec set_header(binary(), binary(), attributes()) -> binary().
set_header(Name, Value, Attributes) ->
    _pipe = [<<<<Name/binary, "="/utf8>>/binary, Value/binary>> |
        cookie_attributes_to_list(Attributes)],
    mond_http_runtime:string_join(_pipe, <<"; "/utf8>>).
