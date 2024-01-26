defmodule BridgeRabbitmq.ApplicationTest do
  use ExUnit.Case, async: true
  # use Plug.Test

  alias BridgeCore.CloudEvent
  alias BridgeCore.CloudEvent.RoutingError
  alias BridgeRabbitmq.MessageProcessor

  import Mock

  test "Should not start app twice" do
    assert {:error, {:already_started, _}} = BridgeRabbitmq.Application.start(:normal, [])
  end

  test "Should build child spec from data" do

    config = %{
      :bridge => %{
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
            "queue" => "adf_bridge_ex_queue",
            "ssl" => true,
            "username" => "guest",
            "virtualhost" => nil
          }
        }
      }
    }

    assert {
      BridgeRabbitmq.Subscriber,
      [ %{
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
          "queue" => "adf_bridge_ex_queue",
          "ssl" => true,
          "username" => "guest",
          "virtualhost" => nil
        }
      ]} == BridgeRabbitmq.Application.build_child_spec(config)

  end

  test "Should build child spec from secret credential" do

    config = %{
      :bridge => %{
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
            "queue" => "adf_bridge_ex_queue"
          }
        }
      }
    }

    with_mocks([
      {BridgeSecretManager, [], [get_secret: fn _, _ ->
          {:ok, %{ "username" => "foo", "password" => nil, "hostname" => "somehost", "port" => 4567, "virtualhost" => "/", "ssl" => false } }
      end]}
    ]) do

      assert {
        BridgeRabbitmq.Subscriber,
        [ %{
            "bindings" => [
              %{"name" => "domainEvents", "routing_key" => ["business.#"]}
            ],
            "broker_url" => "amqp://foo:@somehost",
            "processor_concurrency" => 2,
            "processor_max_demand" => 1,
            "producer_concurrency" => 1,
            "producer_prefetch" => 2,
            "queue" => "adf_bridge_ex_queue",
            "secret" => "rabbitmq-secret"
          }
        ]} == BridgeRabbitmq.Application.build_child_spec(config)

    end

  end

  test "Should handle error fetching secret credential" do

    config = %{
      :bridge => %{
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
            "queue" => "adf_bridge_ex_queue"
          }
        }
      }
    }

    with_mocks([
      {BridgeSecretManager, [], [get_secret: fn _, _ ->
          {:error, "Error fetching secret"}
      end]}
    ]) do

      assert_raise RuntimeError, "Error fetching secret", fn ->
        BridgeRabbitmq.Application.build_child_spec(config)
      end

    end

  end

end
