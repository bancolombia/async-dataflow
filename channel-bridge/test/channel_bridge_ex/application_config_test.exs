defmodule ChannelBridgeEx.ApplicationConfigTest do
  use ExUnit.Case
  # import Mock

  alias ChannelBridgeEx.ApplicationConfig

  @moduletag :capture_log

  setup do
    Application.put_env(:channel_bridge_ex, :config_file, "./config-local.yaml")

    on_exit(fn ->
      Application.delete_env(:channel_bridge_ex, :config_file)
    end)

    :ok
  end

  test "Should load rabbitmq config" do
    config = ApplicationConfig.load()
    assert nil != config

    broker_config = ApplicationConfig.get_rabbitmq_config(config)
    assert nil != broker_config
  end
end
