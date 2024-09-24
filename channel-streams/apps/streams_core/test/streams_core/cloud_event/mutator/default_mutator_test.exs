Code.compiler_options(ignore_module_conflict: true)

defmodule StreamsCore.CloudEvent.Mutator.DefaultMutatorTest do
  use ExUnit.Case

  alias StreamsCore.CloudEvent
  alias StreamsCore.CloudEvent.Mutator.DefaultMutator

  @moduletag :capture_log

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

    {:ok, non_mutated_cloud_event} = DefaultMutator.mutate(parsed_cloud_event)

    assert non_mutated_cloud_event == parsed_cloud_event
  end

  test "Should check apply rule" do
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

    assert true == DefaultMutator.applies?(parsed_cloud_event, %{})

  end

end
