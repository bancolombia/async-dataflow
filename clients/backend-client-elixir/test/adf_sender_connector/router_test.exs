Code.compiler_options(ignore_module_conflict: true)

defmodule AdfSenderConnector.RouterTest do
  use ExUnit.Case

  alias AdfSenderConnector.Router

  @moduletag :capture_log

  setup do
    {:ok, _} = Registry.start_link(keys: :unique, name: Registry.ADFSenderConnector)
    HTTPoison.start
   :ok
  end

  test "should start process" do
    {:ok, pid} = Router.start_link([name: :demo, sender_url: "http://localhost:8082"])
    assert is_pid(pid)
    Process.exit(pid, :kill)
  end

  test "should handle fail to request a message delivery" do
    my_http_options = [
      timeout: 10_000, recv_timeout: 10_000, max_connections: 1000
    ]

    {:ok, pid} = Router.start_link([name: :demo2, sender_url: "http://localhost:8082", http_options: my_http_options])
    response = Router.deliver_message(pid, "a", "b", %{"hello" => "world"})
    assert {:error, :channel_sender_econnrefused} == response
    Process.exit(pid, :kill)
  end

end
