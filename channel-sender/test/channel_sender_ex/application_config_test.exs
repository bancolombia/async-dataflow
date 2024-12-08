defmodule ChannelSenderEx.ApplicationConfigTest do
  use ExUnit.Case
  import Mock

  alias ChannelSenderEx.ApplicationConfig

  # setup do
  #   Application.put_env(:channel_sender_ex, :config_file, "./config/config-local.yaml")
  # end

  test "Should load existent file" do
    Application.put_env(:channel_sender_ex, :config_file, "./test/channel_sender_ex/test_config_files/config1.yaml")
    map = ApplicationConfig.load()
    assert is_map(map)
    on_exit(fn ->
      Application.delete_env(:channel_sender_ex, :config_file)
    end)
  end

  test "Should load cluster config" do
    Application.put_env(:channel_sender_ex, :config_file, "./test/channel_sender_ex/test_config_files/config2.yaml")
    map = ApplicationConfig.load()
    assert is_map(map)
    on_exit(fn ->
      Application.delete_env(:channel_sender_ex, :config_file)
    end)
  end

  test "Should load default config when no file found" do
    Application.put_env(:channel_sender_ex, :config_file, "./some.yaml")
    map = ApplicationConfig.load()
    assert is_map(map)
    on_exit(fn ->
      Application.delete_env(:channel_sender_ex, :config_file)
    end)
  end

end
