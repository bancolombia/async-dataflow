defmodule ApplicationConfigTest do
  use ExUnit.Case
  doctest BridgeHelperConfig.ApplicationConfig

  setup_all do
    :ok
  end

  test "test loads empty config when file not found" do
    assert BridgeHelperConfig.ApplicationConfig.load("some.yaml") == %{}
  end

  test "test loads full config" do
    config = BridgeHelperConfig.ApplicationConfig.load(Path.dirname(__ENV__.file) <> "/test-config.yaml")
    assert get_in(config, [:sender, "url"]) == "http://localhost:8081"
  end

end
