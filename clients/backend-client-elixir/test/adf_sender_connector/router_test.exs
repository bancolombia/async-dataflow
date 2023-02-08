Code.compiler_options(ignore_module_conflict: true)

defmodule AdfSenderConnector.RouterTest do
  use ExUnit.Case

  alias AdfSenderConnector.Router

  @moduletag :capture_log

  setup_all do

    children = [
      AdfSenderConnector.spec(),
      AdfSenderConnector.registry_spec()
    ]

    Supervisor.start_link(children, strategy: :one_for_one)

    {:ok, pid} = Router.start_link([sender_url: "http://localhost:8082",
        http_opts: [],
        name: "bar.refX"])

    assert is_pid(pid)

    %{"process" => pid}
  end

  test "should route message", context do
    assert :ok == Router.route_message(Map.fetch!(context, "process"), "my_event_name", %{})
    # Process.exit(pid, :kill)
  end

end
