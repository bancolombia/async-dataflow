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
    {:ok, pid} = FakeImplementor.start_link([name: :demospec, sender_url: "http://localhost:8082"])
    assert is_pid(pid)
    Process.exit(pid, :kill)
  end

end
