Code.compiler_options(ignore_module_conflict: true)

defmodule ChannelBridgeEx.Core.CloudEvent.Parser.DefaultParserTest do
  use ExUnit.Case

  alias ChannelBridgeEx.Core.CloudEvent.Parser.DefaultParser

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
end
