%% -*- coding: utf-8 -*-
-module(ipipdb_test).
-include_lib("eunit/include/eunit.hrl").

-define(PATH, "./priv/free.ipdb").

parse_database_test() ->
    ?assertMatch({error, enoent}, ipipdb:parse_database("absent.ipdb")),
    {ok, #{meta := M, database := D}} = ipipdb:parse_database(?PATH),
    #{<<"build">> := Build} = M,
    ?assert(Build > 0),
    ?assertEqual(maps:get(<<"total_size">>, M), byte_size(D)).

api_test_() ->
    {setup,
     fun start/0,
     fun stop/1,
     fun api_tests/1}.

start() ->
    {ok, Database} = ipipdb:parse_database(?PATH),
    Database.

stop(_) ->
    ok.

api_tests(Db) ->
    IP = "118.28.1.1",
    Result = #{<<"country_name">> => <<"中国"/utf8>>,
               <<"region_name">> => <<"天津"/utf8>>,
               <<"city_name">>  => <<"天津"/utf8>>},
    [?_assertMatch({ok, #{<<"country_name">> := <<"本机地址"/utf8>>}},
                   ipipdb:lookup("127.0.0.1", Db)),
     ?_assertEqual({ok, Result}, ipipdb:lookup(IP, <<"CN">>, Db)),
     ?_assertEqual({ok, Result}, ipipdb:lookup(IP, Db)),
     ?_assertEqual({error, language_not_found},
                   ipipdb:lookup(IP, <<"EN">>, Db)),
     ?_assertEqual({error, ip_version_not_supported},
                   ipipdb:lookup("2001:250:200::", Db)),
     ?_assertError(_, ipipdb:lookup("1.1.1.1111", Db))
    ].
