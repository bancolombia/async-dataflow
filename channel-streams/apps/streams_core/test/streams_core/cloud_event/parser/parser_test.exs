Code.compiler_options(ignore_module_conflict: true)

defmodule StreamsCore.CloudEvent.Parser.DefaultParserTest do
  use ExUnit.Case

  alias StreamsCore.CloudEvent.Parser.DefaultParser

  @moduletag :capture_log

  setup_all do
    #   {:ok, _} = Application.ensure_all_started(:plug_crypto)
    :ok
  end

  setup do
    :ok
  end

  test "Should decode JSON" do
    cloud_event = "{
      \"data\": {\"hello\": \"World\"},
      \"dataContentType\": \"application/json\",
      \"id\": \"1\",
      \"invoker\": \"invoker1\",
      \"source\": \"source1\",
      \"specVersion\": \"0.1\",
      \"time\": \"xxx\",
      \"type\": \"type1\"
    }"
    {:ok, parsed} = DefaultParser.parse(cloud_event)
    assert %{"hello" => "World"} == parsed["data"]
    assert "application/json" == parsed["dataContentType"]
  end

  test "Should handle fail decoding JSON" do
    cloud_event = "xxxxxx"
    {:error, e} = DefaultParser.parse(cloud_event)
    assert %Jason.DecodeError{position: 0, token: nil, data: "xxxxxx"} == e
  end
end
