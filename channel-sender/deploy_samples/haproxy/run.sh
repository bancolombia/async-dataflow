#!/bin/bash
cd ../../
MIX_ENV=dev elixir --name async-node0@127.0.0.1 -S mix run --no-halt &
MIX_ENV=dev1 elixir --name async-node1@127.0.0.1 -S mix run --no-halt &
MIX_ENV=dev2 elixir --name async-node2@127.0.0.1 -S mix run --no-halt &

haproxy -f deploy_samples/haproxy/haproxy.cfg