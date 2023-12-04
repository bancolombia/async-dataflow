defmodule BridgeHelperConfigTest do
  use ExUnit.Case
  doctest BridgeHelperConfig

  setup_all do
    :ok
  end

  test "loads empty configuration" do
    assert BridgeHelperConfig.get("foo_key", "default_bar") == "default_bar"
  end

  test "loads file" do
    file = Path.dirname(__ENV__.file) <> "/test-config.yaml"
    config = BridgeHelperConfig.load(file)
    assert get_in(config, [:sender, "url"]) == "http://localhost:8081"
    assert BridgeHelperConfig.get([:sender, "url"], nil) == "http://localhost:8081"
  end

end
