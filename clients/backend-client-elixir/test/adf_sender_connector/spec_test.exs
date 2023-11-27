Code.compiler_options(ignore_module_conflict: true)

defmodule AdfSenderConnector.SpecTest do
  use ExUnit.Case

  defmodule FakeImplementor do
    use AdfSenderConnector.Spec, option: "testable"

  end

  @moduletag :capture_log

  setup do
    {:ok, _} = Registry.start_link(keys: :unique, name: Registry.ADFSenderConnector)
    HTTPoison.start
   :ok
  end

  test "should start process" do
    options = [http_opts: [], name: "foo"]

    {:ok, pid} = FakeImplementor.start_link({:sender_url, "http://localhost:8888"}, options)

    assert is_pid(pid)
    Process.exit(pid, :normal)
  end

  test "should start process passing opts" do
    my_http_options = [
      hackney: [:insecure, pool: :some_pool],
      timeout: 10_000, recv_timeout: 10_000, max_connections: 1000,
      name: "bar"
    ]

    {:ok, pid} = FakeImplementor.start_link({:sender_url, "http://localhost:8888"}, my_http_options)
    assert is_pid(pid)
    Process.exit(pid, :normal)
  end


end
