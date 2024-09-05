defmodule BridgeRabbitmq.SubscriberTest do
  use ExUnit.Case, async: false

  alias BridgeRabbitmq.Subscriber

  alias BridgeCore.CloudEvent.RoutingError

  import Mock

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
            "channel" => "acme",
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
      "producer_module" => "Elixir.Broadway.DummyProducer",
      # "producer_name" => "foo",
      "queue" => "x",
      "broker_url" => "amqp://guest:guest@localhost",
      "producer_prefetch" => 1,
      "bindings" => nil,
      "producer_concurrency" => 1,
      "processor_concurrency" => 1,
      "processor_max_demand" => 1,
    }

    {:ok, init_args: %{json: Jason.encode!(test_json), conn_config: conn_config}}
  end

  test "should process received messages", %{init_args: init_args}  do

    {:ok, pid} = Subscriber.start_link([init_args.conn_config])

    assert is_pid(pid)

    ref = Broadway.test_message(Subscriber, init_args.json)

    assert_receive {:ack, ^ref, [%{data: _test_event}], [] }, 300

    assert :ok == Subscriber.stop()

  end

  test "should handle fail invoking processing function", %{init_args: init_args}  do

    with_mocks([
      {BridgeRabbitmq.MessageProcessor, [], [handle_message: fn _input_json_message ->
        raise RoutingError, message: "dummy error"
      end]}
    ]) do

      {:ok, pid} = Subscriber.start_link([init_args.conn_config])

      assert is_pid(pid)

      ref = Broadway.test_message(Subscriber, init_args.json)

      assert_receive {:ack, ^ref, [%{data: _test_event}], [] }, 300

      assert :ok == Subscriber.stop()

    end

  end

  test "should process bindings"  do

    conn_config = %{
      "producer_module" => "Elixir.Broadway.DummyProducer",
      "queue" => "x",
      "broker_url" => "amqp://guest:guest@localhost",
      "producer_prefetch" => 1,
      "bindings" => [%{"name" => "x", "routing_key" => ["f"]}],
      "producer_concurrency" => 1,
      "processor_concurrency" => 1,
      "processor_max_demand" => 1,
    }

    {:ok, pid} = Subscriber.start_link([conn_config])

    assert is_pid(pid)

    assert :ok == Subscriber.stop()

  end

  test "should process bindings II"  do

    conn_config = %{
      "producer_module" => nil,
      "queue" => "x",
      "broker_url" => "amqp://guest:guest@localhost",
      "producer_prefetch" => 1,
      "bindings" => [%{"name" => "x", "routing_key" => ["f"]}],
      "producer_concurrency" => 1,
      "processor_concurrency" => 1,
      "processor_max_demand" => 1,
    }

    {:ok, pid} = Subscriber.start_link([conn_config])

    assert is_pid(pid)

    assert :ok == Subscriber.stop()

  end

end
