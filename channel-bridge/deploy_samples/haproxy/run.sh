cd ../../
MIX_ENV=dev1 elixir --name adfbridge-node1@127.0.0.1 -S mix run --no-halt &
MIX_ENV=dev2 elixir --name adfbridge-node2@127.0.0.1 -S mix run --no-halt &

haproxy -f deploy_samples/haproxy/haproxy.cfg