defmodule ApplicationConfigTest do
  use ExUnit.Case
  doctest StreamsHelperConfig.ApplicationConfig

  setup_all do
    :ok
  end

  test "test loads empty config when file not found" do
    assert StreamsHelperConfig.ApplicationConfig.load("some.yaml") == %{}
  end

  test "test fails when nil passed instead of file path" do
    # assert throw
    assert_raise ArgumentError, "No configuration file specified", fn ->
      StreamsHelperConfig.ApplicationConfig.load(nil)
    end
  end

  test "test fails when no args" do
    # assert throw
    assert_raise ArgumentError, "No configuration file specified", fn ->
      StreamsHelperConfig.ApplicationConfig.load
    end
  end

  test "test loads full config" do
    config = StreamsHelperConfig.ApplicationConfig.load(Path.dirname(__ENV__.file) <> "/test-config.yaml")
    assert get_in(config, [:sender, "url"]) == "http://localhost:8081"
  end

end
