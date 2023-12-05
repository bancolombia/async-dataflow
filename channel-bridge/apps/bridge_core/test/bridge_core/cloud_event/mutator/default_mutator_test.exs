Code.compiler_options(ignore_module_conflict: true)

defmodule BridgeCore.CloudEvent.Mutator.DefaultMutatorTest do
  use ExUnit.Case

  alias BridgeCore.CloudEvent
  alias BridgeCore.CloudEvent.Mutator.DefaultMutator

  @moduletag :capture_log

  setup_all do
    #   {:ok, _} = Application.ensure_all_started(:plug_crypto)
    :ok
  end

  setup do
    :ok
  end

  test "Should not perform mutations to cloud_event" do
    cloud_event = "{
      \"data\": {\"hello\": \"World\"},
      \"dataContentType\": \"application/json\",
      \"id\": \"1\",
      \"invoker\": \"invoker1\",
      \"source\": \"source1\",
      \"specVersion\": \"0.1\",
      \"subject\": \"foo\",
      \"time\": \"xxx\",
      \"type\": \"type1\"
    }"

    {:ok, parsed_cloud_event} = CloudEvent.from(cloud_event)

    {:ok, unmutated_cloud_event} = DefaultMutator.mutate(parsed_cloud_event)

    assert unmutated_cloud_event == parsed_cloud_event
  end
end
