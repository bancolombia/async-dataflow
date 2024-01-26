defmodule BridgeRabbitmq.SubscriberTest do
  use ExUnit.Case, async: false

  # doctest BridgeRabbitmq.Subscriber

  alias BridgeRabbitmq.Subscriber

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

  test "should process bindings", %{init_args: init_args}  do

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

  test "should process bindings II", %{init_args: init_args}  do

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

  # test "should process received messages, custom fn", %{init_args: init_args}  do

  #   config = Map.put(init_args.conn_config, "handle_message_fn", fn(_msg) ->
  #     :ok
  #   end)

  #   {:ok, pid} = Subscriber.start_link([config])

  #   assert is_pid(pid)
  #   ref = Broadway.test_message(Subscriber, init_args.json)
  #   :timer.sleep(100)

  #   assert_receive {:ack, ^ref, [%{data: _test_event}], _}, 300

  #   Process.exit(pid, :normal)
  #   :timer.sleep(300)
  # end

end
