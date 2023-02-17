defmodule EventBusAmqp.SubscriberTest do
  use ExUnit.Case, async: true

  doctest EventBusAmqp.Subscriber

  import Mock

  alias EventBusAmqp.Subscriber
  alias EventBusAmqp.Adapter.SecretManager

  @moduletag :capture_log

  setup do

    test_json = %{
      "specVersion" => "v1",
      "type" => "type1",
      "source" => "source1",
      "id" => "001",
      "time" => "",
      "invoker" => "invoker1",
      "dataContentType" => "application/json",
      "data" => %{
        "request" => %{
          "headers" => %{
            "channel" => "BLM",
            "application-id" => "abc321",
            "session-tracker" => "foo",
            "documentType" => "CC",
            "documentId" => "198961",
            "async-type" => "command",
            "target" => "some.ms",
            "operation" => "some operation"
          },
          "body" => %{
            "say" => "Hi"
          }
        },
        "response" => %{
          "errors" => [
            %{
              "reason" => "reason1",
              "domain" => "domain1",
              "code" => "code1",
              "message" => "message1",
              "type" => "type1"
            }
          ]
        }
      }
    }

    conn_config = %{
      "broker_producer_module" => "Broadway.DummyProducer",
      "broker_queue" => "x",
      "broker_url" => "amqp://user:pwd@localhost",
      "broker_producer_prefetch" => 1,
      "broker_bindings" => [],
      "broker_producer_concurrency" => 1,
      "broker_processor_concurrency" => 1,
      "broker_processor_max_demand" => 1,
    }

    {:ok, init_args: %{json: Jason.encode!(test_json), conn_config: conn_config}}
  end

  test "test initialization", %{init_args: init_args} do
    assert {:ok, pid} = Subscriber.start_link([init_args.conn_config])
    Process.exit(pid, :normal)
  end

  test "should process received messages", %{init_args: init_args}  do
    {:ok, pid} = Subscriber.start_link([init_args.conn_config])

    ref = Broadway.test_message(Subscriber, init_args.json)

    assert_receive {:ack, ^ref, [%{data: _test_event}], []}

    Process.exit(pid, :normal)
  end

  test "should process received messages, custom fn", %{init_args: init_args}  do

    config = Map.put(init_args.conn_config, "handle_message_fn", fn(msg) ->
      IO.inspect(msg)
      :ok
    end)

    {:ok, pid} = Subscriber.start_link([config])

    ref = Broadway.test_message(Subscriber, init_args.json)

    assert_receive {:ack, ^ref, [%{data: _test_event}], []}

    Process.exit(pid, :normal)
  end

end
