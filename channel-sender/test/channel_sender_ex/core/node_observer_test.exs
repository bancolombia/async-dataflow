defmodule ChannelSenderEx.Core.NodeObserverTest do
  use ExUnit.Case
  import ExUnit.CaptureLog

  alias ChannelSenderEx.Core.NodeObserver
  alias ChannelSenderEx.Core.{ChannelRegistry, ChannelSupervisor}

  setup do
    {:ok, pid} = NodeObserver.start_link([])

    {:ok, _} = Application.ensure_all_started(:telemetry)

    {:ok, _pid_registry} = Horde.Registry.start_link(name: ChannelRegistry, keys: :unique)

    Horde.DynamicSupervisor.start_link(name: ChannelSupervisor, strategy: :one_for_one)

    {:ok, pid: pid}
  end

  test "handles nodeup message", %{pid: pid} do
    assert capture_log(fn ->
      send(pid, {:nodeup, :some_node, :visible})
      :timer.sleep(100) # Allow some time for the message to be processed
    end) == ""
  end

  test "handles nodedown message", %{pid: pid} do
    assert capture_log(fn ->
      send(pid, {:nodedown, :some_node, :visible})
      :timer.sleep(100) # Allow some time for the message to be processed
    end) == ""
  end

end
