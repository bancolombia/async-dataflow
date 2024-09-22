defmodule StreamsRabbitmq.ApplicationTest do
  use ExUnit.Case, async: true
  # use Plug.Test

  import Mock

  test "Should not start app twice" do
    assert {:error, {:already_started, _}} = StreamsRabbitmq.Application.start(:normal, [])
  end

  test "Should build child spec from data" do

    config = %{
      :streams => %{
        "event_bus" => %{
          "rabbitmq" => %{
            "bindings" => [
              %{"name" => "domainEvents", "routing_key" => ["business.#"]}
            ],
            "hostname" => "localhost",
            "password" => "guest",
            "port" => 5672,
            "processor_concurrency" => 2,
            "processor_max_demand" => 1,
            "producer_concurrency" => 1,
            "producer_prefetch" => 2,
            "queue" => "adf_streams_ex_queue",
            "ssl" => true,
            "username" => "guest",
            "virtualhost" => nil
          }
        }
      }
    }

    assert {
      StreamsRabbitmq.Subscriber,
      [%{
          "bindings" => [
            %{"name" => "domainEvents", "routing_key" => ["business.#"]}
          ],
          "broker_url" => "amqps://guest:guest@localhost?verify=verify_none&server_name_indication=localhost",
          "hostname" => "localhost",
          "password" => "guest",
          "port" => 5672,
          "processor_concurrency" => 2,
          "processor_max_demand" => 1,
          "producer_concurrency" => 1,
          "producer_prefetch" => 2,
          "queue" => "adf_streams_ex_queue",
          "ssl" => true,
          "username" => "guest",
          "virtualhost" => nil
        }
      ]} == StreamsRabbitmq.Application.build_child_spec(config)

  end

  test "Should build child spec from secret credential" do

    config = %{
      :streams => %{
        "event_bus" => %{
          "rabbitmq" => %{
            "bindings" => [
              %{"name" => "domainEvents", "routing_key" => ["business.#"]}
            ],
            "secret" => "rabbitmq-secret",
            "processor_concurrency" => 2,
            "processor_max_demand" => 1,
            "producer_concurrency" => 1,
            "producer_prefetch" => 2,
            "queue" => "adf_streams_ex_queue"
          }
        }
      }
    }

    with_mocks([
      {StreamsSecretManager, [], [get_secret: fn _, _ ->
          {:ok, %{"username" => "foo", "password" => nil, "hostname" => "somehost", "port" => 4567, "virtualhost" => "/", "ssl" => false}}
      end]}
    ]) do

      assert {
        StreamsRabbitmq.Subscriber,
        [%{
            "bindings" => [
              %{"name" => "domainEvents", "routing_key" => ["business.#"]}
            ],
            "broker_url" => "amqp://foo:@somehost",
            "processor_concurrency" => 2,
            "processor_max_demand" => 1,
            "producer_concurrency" => 1,
            "producer_prefetch" => 2,
            "queue" => "adf_streams_ex_queue",
            "secret" => "rabbitmq-secret"
          }
        ]} == StreamsRabbitmq.Application.build_child_spec(config)

    end

  end

  test "Should handle error fetching secret credential" do

    config = %{
      :streams => %{
        "event_bus" => %{
          "rabbitmq" => %{
            "bindings" => [
              %{"name" => "domainEvents", "routing_key" => ["business.#"]}
            ],
            "secret" => "rabbitmq-secret",
            "processor_concurrency" => 2,
            "processor_max_demand" => 1,
            "producer_concurrency" => 1,
            "producer_prefetch" => 2,
            "queue" => "adf_streams_ex_queue"
          }
        }
      }
    }

    with_mocks([
      {StreamsSecretManager, [], [get_secret: fn _, _ ->
          {:error, "Error fetching secret"}
      end]}
    ]) do

      assert_raise RuntimeError, "Error fetching secret", fn ->
        StreamsRabbitmq.Application.build_child_spec(config)
      end

    end

  end

end
