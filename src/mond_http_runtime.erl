-module(mond_http_runtime).

-export([
    identity/1,
    bool_guard/3,

    result_try/2,
    result_map/2,
    result_unwrap/2,

    option_unwrap/2,
    option_to_result/2,
    option_map/2,

    list_reverse/1,
    list_key_find/2,
    list_key_set/3,
    list_key_pop/2,
    list_flat_map/2,
    list_filter_map/2,
    list_map/2,

    string_lowercase/1,
    string_split/2,
    string_join/2,
    string_trim/1,
    string_split_once/2,
    string_append/2,
    string_pop_grapheme/1,
    string_contains/2,

    bit_array_to_string/1,

    uri_parse/1,
    uri_parse_query/1,
    uri_percent_encode/1,
    uri_path_segments/1
]).

identity(X) ->
    X.

bool_guard(Requirement, Consequence, Alternative) ->
    case Requirement of
        true -> Consequence;
        false -> Alternative()
    end.

result_try(Result, Fun) ->
    case Result of
        {ok, X} -> Fun(X);
        {error, E} -> {error, E}
    end.

result_map(Result, Fun) ->
    case Result of
        {ok, X} -> {ok, Fun(X)};
        {error, E} -> {error, E}
    end.

result_unwrap(Result, Default) ->
    case Result of
        {ok, X} -> X;
        {error, _} -> Default
    end.

option_unwrap(Option, Default) ->
    case Option of
        {some, X} -> X;
        none -> Default
    end.

option_to_result(Option, ErrorValue) ->
    case Option of
        {some, X} -> {ok, X};
        none -> {error, ErrorValue}
    end.

option_map(Option, Fun) ->
    case Option of
        {some, X} -> {some, Fun(X)};
        none -> none
    end.

list_reverse(List) ->
    lists:reverse(List).

list_map(List, Fun) ->
    lists:map(Fun, List).

list_flat_map(List, Fun) ->
    lists:append(lists:map(Fun, List)).

list_filter_map(List, Fun) ->
    list_filter_map_loop(List, Fun, []).

list_filter_map_loop([], _Fun, Acc) ->
    lists:reverse(Acc);
list_filter_map_loop([X | Rest], Fun, Acc) ->
    case Fun(X) of
        {ok, Y} -> list_filter_map_loop(Rest, Fun, [Y | Acc]);
        {error, _} -> list_filter_map_loop(Rest, Fun, Acc)
    end.

list_key_find(List, DesiredKey) ->
    list_key_find_loop(List, DesiredKey).

list_key_find_loop([], _DesiredKey) ->
    {error, nil};
list_key_find_loop([{Key, Value} | Rest], DesiredKey) ->
    case Key =:= DesiredKey of
        true -> {ok, Value};
        false -> list_key_find_loop(Rest, DesiredKey)
    end.

list_key_set(List, Key, Value) ->
    list_key_set_loop(List, Key, Value, []).

list_key_set_loop([{K, _Old} | Rest], Key, Value, Inspected) when K =:= Key ->
    lists:reverse(Inspected, [{K, Value} | Rest]);
list_key_set_loop([First | Rest], Key, Value, Inspected) ->
    list_key_set_loop(Rest, Key, Value, [First | Inspected]);
list_key_set_loop([], Key, Value, Inspected) ->
    lists:reverse([{Key, Value} | Inspected]).

list_key_pop(List, Key) ->
    list_key_pop_loop(List, Key, []).

list_key_pop_loop([], _Key, _Checked) ->
    {error, nil};
list_key_pop_loop([{K, V} | Rest], Key, Checked) when K =:= Key ->
    {ok, {V, lists:reverse(Checked, Rest)}};
list_key_pop_loop([First | Rest], Key, Checked) ->
    list_key_pop_loop(Rest, Key, [First | Checked]).

string_lowercase(String) ->
    string:lowercase(String).

string_trim(String) ->
    string:trim(String).

string_append(First, Second) ->
    <<First/binary, Second/binary>>.

string_join(Strings, Separator) ->
    iolist_to_binary(lists:join(Separator, Strings)).

string_split(String, Substring) ->
    case Substring of
        <<>> ->
            to_graphemes(String, []);
        _ ->
            binary:split(String, Substring, [global])
    end.

to_graphemes(String, Acc) ->
    case string:next_grapheme(String) of
        [Next | Rest] when is_binary(Rest) ->
            to_graphemes(Rest, [unicode:characters_to_binary([Next]) | Acc]);
        [Next | Rest] ->
            NextBin = unicode:characters_to_binary([Next]),
            RestBin = unicode:characters_to_binary(Rest),
            to_graphemes(RestBin, [NextBin | Acc]);
        _ ->
            lists:reverse(Acc)
    end.

string_split_once(String, Substring) ->
    case binary:split(String, Substring) of
        [First, Rest] -> {ok, {First, Rest}};
        _ -> {error, nil}
    end.

string_pop_grapheme(String) ->
    case string:next_grapheme(String) of
        [Next | Rest] when is_binary(Rest) ->
            {ok, {unicode:characters_to_binary([Next]), Rest}};
        [Next | Rest] ->
            {ok, {unicode:characters_to_binary([Next]), unicode:characters_to_binary(Rest)}};
        _ ->
            {error, nil}
    end.

string_contains(String, Substring) ->
    case binary:match(String, Substring) of
        nomatch -> false;
        _ -> true
    end.

bit_array_to_string(Bits) ->
    case check_utf8(Bits) of
        ok -> {ok, Bits};
        error -> {error, nil}
    end.

uri_parse(UriString) ->
    case uri_string:parse(UriString) of
        {error, _, _} ->
            {error, nil};
        UriMap ->
            Port =
                case maps:find(port, UriMap) of
                    {ok, undefined} -> none;
                    {ok, Value} -> {some, Value};
                    error -> none
                end,
            {ok,
                {uri,
                    maps_get_optional_lowercase(UriMap, scheme),
                    maps_get_optional(UriMap, userinfo),
                    maps_get_optional(UriMap, host),
                    Port,
                    maps_get_or(UriMap, path, <<>>),
                    maps_get_optional(UriMap, query),
                    maps_get_optional(UriMap, fragment)}}
    end.

maps_get_optional_lowercase(Map, Key) ->
    case maps:find(Key, Map) of
        {ok, Value} -> {some, string:lowercase(Value)};
        error -> none
    end.

maps_get_optional(Map, Key) ->
    case maps:find(Key, Map) of
        {ok, Value} -> {some, Value};
        error -> none
    end.

maps_get_or(Map, Key, Default) ->
    case maps:find(Key, Map) of
        {ok, Value} -> Value;
        error -> Default
    end.

uri_parse_query(Query) ->
    case uri_string:dissect_query(Query) of
        {error, _, _} ->
            {error, nil};
        Pairs ->
            Normalised = lists:map(
                fun
                    ({K, true}) -> {K, <<>>};
                    (Pair) -> Pair
                end,
                Pairs
            ),
            {ok, Normalised}
    end.

uri_percent_encode(Bin) ->
    uri_percent_encode(Bin, <<>>).

uri_percent_encode(<<>>, Acc) ->
    Acc;
uri_percent_encode(<<Byte, Rest/binary>>, Acc) ->
    case percent_ok(Byte) of
        true ->
            uri_percent_encode(Rest, <<Acc/binary, Byte>>);
        false ->
            <<Hi:4, Lo:4>> = <<Byte>>,
            uri_percent_encode(
                Rest,
                <<Acc/binary, $%, (dec2hex(Hi)), (dec2hex(Lo))>>
            )
    end.

percent_ok($!) -> true;
percent_ok($$) -> true;
percent_ok($') -> true;
percent_ok($() -> true;
percent_ok($)) -> true;
percent_ok($*) -> true;
percent_ok($+) -> true;
percent_ok($-) -> true;
percent_ok($.) -> true;
percent_ok($_) -> true;
percent_ok($~) -> true;
percent_ok(C) when $0 =< C, C =< $9 -> true;
percent_ok(C) when $A =< C, C =< $Z -> true;
percent_ok(C) when $a =< C, C =< $z -> true;
percent_ok(_) -> false.

dec2hex(X) when X >= 0, X =< 9 -> X + $0;
dec2hex(X) when X >= 10, X =< 15 -> X + $A - 10.

uri_path_segments(Path) ->
    remove_dot_segments(string_split(Path, <<"/">>)).

remove_dot_segments(Input) ->
    remove_dot_segments_loop(Input, []).

remove_dot_segments_loop([], Acc) ->
    lists:reverse(Acc);
remove_dot_segments_loop([Segment | Rest], Acc) ->
    NewAcc =
        case {Segment, Acc} of
            {<<>>, Current} -> Current;
            {<<".">>, Current} -> Current;
            {<<"..">>, []} -> [];
            {<<"..">>, [_ | Current]} -> Current;
            {CurrentSegment, Current} -> [CurrentSegment | Current]
        end,
    remove_dot_segments_loop(Rest, NewAcc).

check_utf8(Bits) ->
    case unicode:characters_to_list(Bits) of
        {incomplete, _, _} -> error;
        {error, _, _} -> error;
        _ -> ok
    end.
