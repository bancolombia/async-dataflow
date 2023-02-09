defmodule ChannelBridgeEx.ApplicationTest do
  use ExUnit.Case
  import Mock

  alias ChannelBridgeEx.Boundary.Telemetry.MetricsSetup

  @moduletag :capture_log

  setup_with_mocks([
    {MetricsSetup, [], [setup: fn -> :ok end]}
  ]) do
    Application.put_env(:channel_bridge_ex, :config_file, "./config.yaml")

    on_exit(fn ->
      Application.delete_env(:channel_bridge_ex, :config_file)
    end)

    :ok
  end

  test "should start" do
    # ChannelBridgeEx.Application.start(:normal, [])
  end
end
