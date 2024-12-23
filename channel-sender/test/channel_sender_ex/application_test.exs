defmodule ChannelSenderEx.ApplicationTest do
  use ExUnit.Case
  alias ChannelSenderEx.Application, as: APP
  alias ChannelSenderEx.Transport.EntryPoint
  alias ChannelSenderEx.Utils.CustomTelemetry
  import Mock

  setup_all do
    Application.put_env(:channel_sender_ex, :config_file, "./test/channel_sender_ex/test_config_files/config1.yaml")
    on_exit(fn -> Application.delete_env(:channel_sender_ex, :config_file) end)
  end

  describe "start/2" do
    test "starts the application with no_start_param as false" do
      Application.put_env(:channel_sender_ex, :no_start, false)
      with_mocks([
        {CustomTelemetry, [], [
          custom_telemetry_events: fn() -> :ok end,
          metrics: fn() -> [] end
          ]},
        {EntryPoint, [], [start: fn() -> :ok end]},
        {Supervisor, [], [start_link: fn(_, _) -> {:ok, :c.pid(0, 250, 0)} end]},
      ]) do
        assert {:ok, _pid} = APP.start(:normal, [])
      end
    end

    test "starts the application with no_start_param as true" do
      Application.put_env(:channel_sender_ex, :no_start, true)
      with_mocks([
        {CustomTelemetry, [], [
          custom_telemetry_events: fn() -> :ok end,
          metrics: fn() -> [] end
          ]},
        {EntryPoint, [], [start: fn() -> :ok end]},
        {Supervisor, [], [start_link: fn(_, _) -> {:ok, :c.pid(0, 250, 0)} end]},
      ]) do
        assert {:ok, _pid} = APP.start(:normal, [])
      end
    end
  end

end
