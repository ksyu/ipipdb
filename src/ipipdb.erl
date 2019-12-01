%% -*- coding: utf-8 -*-
-module(ipipdb).

-export([lookup/2]).
-export([lookup/3]).
-export([parse_database/1]).

-type ipdb() :: #{meta => map(), database => binary()}.

-spec lookup(string(), ipdb()) -> {ok, map()} | {error, atom()}.
lookup(IP, Database) ->
    lookup(IP, <<"CN">>, Database).

-spec lookup(string(), binary(), ipdb()) -> {ok, map()} | {error, atom()}.
lookup(IP, Lang, Database) ->
    {ok, Address} = inet:parse_address(IP),
    case is_supported(Address, Database) of
        true  ->
            Data = find_data(Address, Database),
            Values = split_locale(Data, Database),
            case maps:is_key(Lang, Values) of
                true -> {ok, maps:get(Lang, Values)};
                false -> {error, language_not_found}
            end;
        false ->
            {error, ip_version_not_supported}
    end.

-spec parse_database(file:name_all()) -> {ok, map()} | {error, atom()}.
parse_database(Path) ->
    case file:read_file(Path) of
        {ok, Bin} ->
            <<M:32/integer, _/binary>> = Bin,
            Meta = parse_meta(M, Bin),
            Data = binary_part(Bin, M + 4, byte_size(Bin) - M - 4),
            Node = case maps:get(<<"ip_version">>, Meta) of
                       ipv4 -> ipv4_node(0, 0, Data);
                       ipv6 -> 0
                   end,
            Database = #{meta => Meta#{<<"ipv4_node">> => Node},
                         database => Data},
            {ok, Database};
        Error -> Error
    end.

%% private
read_node(Node, Bin, Idx) ->
    <<N:32/integer>> = binary_part(Bin, Node * 8 + Idx * 4, 4),
    N.

ipv4_node(Node, Idx, Bin) when Idx < 80 ->
    N = read_node(Node, Bin, 0),
    ipv4_node(N, Idx + 1, Bin);
ipv4_node(Node, Idx, Bin) when Idx < 96 ->
    N = read_node(Node, Bin, 1),
    ipv4_node(N, Idx + 1, Bin);
ipv4_node(Node, _Idx, _Bin) ->
    Node.

parse_meta(Size, Bin) ->
    MetaBin = binary_part(Bin, 4, Size),
    Meta = jiffy:decode(MetaBin, [return_maps]),
    Meta#{<<"ip_version">> => db_version(Meta)}.

db_version(#{<<"ip_version">> := V}) when V band 1 == 1 -> ipv4;
db_version(_) -> ipv6.

find_data(Address, #{meta := Meta, database := Bin}) ->
    #{<<"node_count">> := Total,
      <<"ip_version">> := Version,
      <<"ipv4_node">>  := V4Node} = Meta,
    N = case Version of
            ipv4 -> V4Node;
            ipv6 -> 0
        end,
    Bits = list_to_binary(tuple_to_list(Address)),
    Node = find_node(Bits, N, Total, Bin),
    Offset = Node - Total + Total * 8,
    <<Size:16/integer>> = binary_part(Bin, Offset, 2),
    binary_part(Bin, Offset + 2, Size).

find_node(<<>>, Node, _, _) ->
    Node;
find_node(_, Node, Total, _Db) when Node > Total ->
    Node;
find_node(<<H:1, T/bitstring>>, Node, Total, Db) ->
    Next = read_node(Node, Db, H),
    find_node(T, Next, Total, Db).

is_supported(Address, #{meta := Meta}) ->
    #{<<"ip_version">> := Version} = Meta,
    case Version of
        ipv4 -> tuple_size(Address) == 4;
        ipv6 -> tuple_size(Address) == 8
    end.

split_locale(IPData, #{meta := Meta}) ->
    #{<<"fields">> := Fields, <<"languages">> := Langs} = Meta,
    Data = string:split(IPData, "\t", all),
    maps:map(fun(_K, V) ->
                     Items = lists:sublist(Data, V + 1, length(Fields) + 1),
                     maps:from_list(lists:zip(Fields, Items))
             end,
             Langs).
