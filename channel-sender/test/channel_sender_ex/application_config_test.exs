defmodule ChannelSenderEx.ApplicationConfigTest do
  use ExUnit.Case

  alias ChannelSenderEx.ApplicationConfig

  test "Should load existent file" do
    env_before = Application.get_all_env(:channel_sender_ex)

    Application.put_env(
      :channel_sender_ex,
      :config_file,
      "./test/channel_sender_ex/test_config_files/config1.yaml"
    )

    map = ApplicationConfig.load()
    assert is_map(map)

    on_exit(fn -> restore_env(env_before) end)
  end

  test "Should load cluster config" do
    env_before = Application.get_all_env(:channel_sender_ex)

    Application.put_env(
      :channel_sender_ex,
      :config_file,
      "./test/channel_sender_ex/test_config_files/config2.yaml"
    )

    map = ApplicationConfig.load()
    assert is_map(map)

    on_exit(fn -> restore_env(env_before) end)
  end

  test "Should load default config when no file found" do
    env_before = Application.get_all_env(:channel_sender_ex)

    Application.put_env(:channel_sender_ex, :config_file, "./some.yaml")
    map = ApplicationConfig.load()
    assert is_map(map)

    on_exit(fn -> restore_env(env_before) end)
  end

  # ApplicationConfig.load/0 writes the whole parsed config into the app env,
  # so tests must restore the previous env to avoid leaking values
  # (e.g. :interval_minutes_count_active_channel set to nil) into other tests.
  defp restore_env(env_before) do
    current_keys = Application.get_all_env(:channel_sender_ex) |> Keyword.keys()

    (current_keys -- Keyword.keys(env_before))
    |> Enum.each(&Application.delete_env(:channel_sender_ex, &1))

    Enum.each(env_before, fn {key, value} ->
      Application.put_env(:channel_sender_ex, key, value)
    end)
  end
end
