defmodule ChannelSenderEx.ApplicationTest do
  use ExUnit.Case
  alias ChannelSenderEx.Application, as: APP
  alias ChannelSenderEx.Transport.EntryPoint
  alias ChannelSenderEx.Utils.CustomTelemetry
  import Mock

  setup_all do
    Application.put_env(
      :channel_sender_ex,
      :config_file,
      "./test/channel_sender_ex/test_config_files/config1.yaml"
    )

    on_exit(fn -> Application.delete_env(:channel_sender_ex, :config_file) end)
  end

  describe "start/2" do
    test "starts the application with no_start_param as false" do
      env_before = Application.get_all_env(:channel_sender_ex)
      Application.put_env(:channel_sender_ex, :no_start, false)
      Application.put_env(:channel_sender_ex, :traces_enable, true)

      on_exit(fn -> restore_env(env_before) end)

      with_mocks([
        {CustomTelemetry, [],
         [
           custom_telemetry_events: fn -> :ok end,
           metrics: fn -> [] end
         ]},
        {EntryPoint, [], [start: fn -> :ok end]},
        {Supervisor, [], [start_link: fn _, _ -> {:ok, :c.pid(0, 250, 0)} end]},
        {OpentelemetryPlug, [], [setup: fn -> :ok end]}
      ]) do
        assert {:ok, _pid} = APP.start(:normal, [])
      end
    end

    test "starts the application with no_start_param as true" do
      env_before = Application.get_all_env(:channel_sender_ex)
      Application.put_env(:channel_sender_ex, :no_start, true)
      Application.put_env(:channel_sender_ex, :traces_enable, false)

      on_exit(fn -> restore_env(env_before) end)

      with_mocks([
        {CustomTelemetry, [],
         [
           custom_telemetry_events: fn -> :ok end,
           metrics: fn -> [] end
         ]},
        {EntryPoint, [], [start: fn -> :ok end]},
        {Supervisor, [], [start_link: fn _, _ -> {:ok, :c.pid(0, 250, 0)} end]},
        {OpentelemetryPlug, [], [setup: fn -> :ok end]}
      ]) do
        assert {:ok, _pid} = APP.start(:normal, [])
      end
    end
  end

  # APP.start/2 runs ApplicationConfig.load/0 which writes the whole parsed
  # config into the app env; restore it to avoid leaking values into other tests.
  defp restore_env(env_before) do
    current_keys = Application.get_all_env(:channel_sender_ex) |> Keyword.keys()

    (current_keys -- Keyword.keys(env_before))
    |> Enum.each(&Application.delete_env(:channel_sender_ex, &1))

    Enum.each(env_before, fn {key, value} ->
      Application.put_env(:channel_sender_ex, key, value)
    end)
  end
end
