%%%-------------------------------------------------------------------
%%% @author daniel
%%% @copyright (C) 2020, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 03. sep. 2020 10:01 a. m.
%%%-------------------------------------------------------------------
-module(server_proto1).
-author("daniel").

%% API
-export([build_big_map/1, build_big_list/1]).

build_big_map(Count) -> build_big_map(0, Count, []).
build_big_map(Actual, Actual, Acc) -> maps:from_list(Acc);
build_big_map(Actual, Count, Acc) -> build_big_map(Actual + 1, Count, [ {{clave_entrada, Actual}, ["Valor de la entrada", Actual]} | Acc]).

build_big_list(Count) -> build_big_list(0, Count, []).
build_big_list(Actual, Actual, Acc) -> Acc;
build_big_list(Actual, Count, Acc) -> build_big_list(Actual + 1, Count, [ {{clave_entrada, Actual}, ["Valor de la entrada", Actual]} | Acc]).

