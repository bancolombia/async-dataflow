Code.compiler_options(ignore_module_conflict: true)

defmodule BridgeCore.CloudEvent.Mutator.WebhookMutatorTest do
  use ExUnit.Case
  import Mock

  alias BridgeCore.CloudEvent
  alias BridgeCore.CloudEvent.Mutator.WebhookMutator

  @moduletag :capture_log

  setup do
    cloud_event = "{
      \"data\": {\"hello\": \"World\"},
      \"dataContentType\": \"application/json\",
      \"id\": \"1\",
      \"invoker\": \"invoker foo ref\",
      \"source\": \"source1\",
      \"specVersion\": \"0.1\",
      \"subject\": \"foo\",
      \"time\": \"xxx\",
      \"type\": \"type1\"
    }"

    {:ok, parsed_cloud_event} = CloudEvent.from(cloud_event)

    %{raw_cloud_event: cloud_event, cloud_event: parsed_cloud_event}
  end

  test "Should resolve to apply mutations to cloud_event", %{cloud_event: cloud_event} do

    mutator_config = %{
      "applies_when" => [
        %{"key" => "$.source", "comparator" => "eq", "value" => "sdfsdf"},
        %{"operator" => "or", "key" => "$.invoker", "comparator" => "contains", "value" => "foo"},
      ],
      "webhook_headers" => ["Content-Type: application/json"],
      "webhook_method" => "POST",
      "webhook_url" => "http://localhost:3000/content/xyz"
    }

    applies_result = WebhookMutator.applies?(cloud_event, mutator_config)

    assert applies_result == true
  end

  test "Should resolve not to apply mutations to cloud_event", %{cloud_event: cloud_event} do

    mutator_config = %{
      "applies_when" => [
        %{"key" => "$.source", "comparator" => "eq", "value" => "sdfsdf"},
        %{"operator" => "or", "key" => "$.invoker", "comparator" => "not_contains", "value" => "foo"}  # this rule will be applied
      ],
      "webhook_headers" => ["Content-Type: application/json"],
      "webhook_method" => "POST",
      "webhook_url" => "http://localhost:3000/content/xyz"
    }

    applies_result = WebhookMutator.applies?(cloud_event, mutator_config)

    assert applies_result == false
  end

  test "Should perform mutations to cloud_event", %{cloud_event: cloud_event} do

    mutator_config = %{
      "applies_when" => [
        %{"key" => "$.source", "comparator" => "eq", "value" => "sdfsdf"},
        %{"operator" => "or", "key" => "$.invoker", "comparator" => "contains", "value" => "foo"},
      ],
      "webhook_headers" => ["Content-Type: application/json"],
      "webhook_method" => "POST",
      "webhook_url" => "http://localhost:3000/content/xyz"
    }

    with_mocks([
      {:httpc, [], [request: fn _url, _params, _headers, _opts ->

        {:ok,
          {{~c"HTTP/1.1", 200, ~c"OK"},
            [
              {~c"connection", ~c"keep-alive"},
              {~c"date", ~c"Fri, 22 Mar 2024 14:10:08 GMT"},
              {~c"content-length", ~c"224"},
              {~c"content-type", ~c"application/json; charset=utf-8"},
              {~c"keep-alive", ~c"timeout=5"}
            ],
            ~c"{\n  \"data\": {\"foo\": \"bar\"},\n  \"dataContentType\": \"application/json\",\n  \"id\": \"1\",\n  \"invoker\": \"invoker foo ref\",\n  \"source\": \"source1\",\n  \"specVersion\": \"0.1\",\n  \"subject\": \"foo\",\n  \"time\": \"xxx\",\n  \"type\": \"type1\"\n}"}}
      end]}
    ]) do

      {:ok, mutated_cloud_event} = WebhookMutator.mutate(cloud_event, mutator_config)

      ## assert only body is mutated
      assert mutated_cloud_event.data == %{"foo" => "bar"}
      ## other fields should remain the same
      assert mutated_cloud_event.dataContentType == cloud_event.dataContentType
      assert mutated_cloud_event.id == cloud_event.id
      assert mutated_cloud_event.invoker == cloud_event.invoker
      assert mutated_cloud_event.source == cloud_event.source
      assert mutated_cloud_event.specVersion == cloud_event.specVersion
      assert mutated_cloud_event.subject == cloud_event.subject
      assert mutated_cloud_event.time == cloud_event.time
      assert mutated_cloud_event.type == cloud_event.type

    end

  end

  test "Should fail mutations due to invalid cloud event" do

    {:noop, <<255>>} = WebhookMutator.mutate("\xFF", %{})

  end

  test "Should handle webhook fail and perform no mutations to cloud_event", %{cloud_event: cloud_event} do

    mutator_config = %{
      "applies_when" => [
        %{"key" => "$.source", "comparator" => "eq", "value" => "sdfsdf"},
        %{"operator" => "or", "key" => "$.invoker", "comparator" => "contains", "value" => "foo"},
      ],
      "webhook_headers" => ["Content-Type: application/json"],
      "webhook_method" => "POST",
      "webhook_url" => "http://localhost:3000/content/xyz"
    }

    with_mocks([
      {:httpc, [], [request: fn _url, _params, _headers, _opts ->
        {:ok,
          {{~c"HTTP/1.1", 401, ~c"unauthorized"},
            [
              {~c"connection", ~c"keep-alive"},
              {~c"date", ~c"Fri, 22 Mar 2024 14:10:08 GMT"},
              {~c"content-length", ~c"224"},
              {~c"content-type", ~c"application/json; charset=utf-8"},
              {~c"keep-alive", ~c"timeout=5"}
            ],
            ~c""}}
      end]}
    ]) do

      {:noop, mutated_cloud_event} = WebhookMutator.mutate(cloud_event, mutator_config)

      ## assert fields should remain the same
      assert mutated_cloud_event.data == %{"hello" => "World"}
      assert mutated_cloud_event.dataContentType == cloud_event.dataContentType
      assert mutated_cloud_event.id == cloud_event.id
      assert mutated_cloud_event.invoker == cloud_event.invoker
      assert mutated_cloud_event.source == cloud_event.source
      assert mutated_cloud_event.specVersion == cloud_event.specVersion
      assert mutated_cloud_event.subject == cloud_event.subject
      assert mutated_cloud_event.time == cloud_event.time
      assert mutated_cloud_event.type == cloud_event.type

    end

  end

  test "Should handle webhook failed connection and perform no mutations to cloud_event", %{cloud_event: cloud_event} do

    mutator_config = %{
      "applies_when" => [
        %{"key" => "$.source", "comparator" => "eq", "value" => "sdfsdf"},
        %{"operator" => "or", "key" => "$.invoker", "comparator" => "contains", "value" => "foo"},
      ],
      "webhook_headers" => ["Content-Type: application/json"],
      "webhook_method" => "POST",
      "webhook_url" => "http://localhost:3000/content/xyz"
    }

    with_mocks([
      {:httpc, [], [request: fn _url, _params, _headers, _opts ->
        {:failed_connect, :error}
      end]}
    ]) do

      {:noop, mutated_cloud_event} = WebhookMutator.mutate(cloud_event, mutator_config)

      ## assert fields should remain the same
      assert mutated_cloud_event.data == %{"hello" => "World"}
      assert mutated_cloud_event.dataContentType == cloud_event.dataContentType
      assert mutated_cloud_event.id == cloud_event.id
      assert mutated_cloud_event.invoker == cloud_event.invoker
      assert mutated_cloud_event.source == cloud_event.source
      assert mutated_cloud_event.specVersion == cloud_event.specVersion
      assert mutated_cloud_event.subject == cloud_event.subject
      assert mutated_cloud_event.time == cloud_event.time
      assert mutated_cloud_event.type == cloud_event.type

    end

  end

  test "Should handle webhook error and perform no mutations to cloud_event", %{cloud_event: cloud_event} do

    mutator_config = %{
      "applies_when" => [
        %{"key" => "$.source", "comparator" => "eq", "value" => "sdfsdf"},
        %{"operator" => "or", "key" => "$.invoker", "comparator" => "contains", "value" => "foo"},
      ],
      "webhook_headers" => ["Content-Type: application/json"],
      "webhook_method" => "POST",
      "webhook_url" => "http://localhost:3000/content/xyz"
    }

    with_mocks([
      {:httpc, [], [request: fn _url, _params, _headers, _opts ->
        {:error, "dummy reason"}
      end]}
    ]) do

      {:noop, mutated_cloud_event} = WebhookMutator.mutate(cloud_event, mutator_config)

      ## assert fields should remain the same
      assert mutated_cloud_event.data == %{"hello" => "World"}
      assert mutated_cloud_event.dataContentType == cloud_event.dataContentType
      assert mutated_cloud_event.id == cloud_event.id
      assert mutated_cloud_event.invoker == cloud_event.invoker
      assert mutated_cloud_event.source == cloud_event.source
      assert mutated_cloud_event.specVersion == cloud_event.specVersion
      assert mutated_cloud_event.subject == cloud_event.subject
      assert mutated_cloud_event.time == cloud_event.time
      assert mutated_cloud_event.type == cloud_event.type

    end

  end

end
