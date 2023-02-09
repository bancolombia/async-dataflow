defmodule EventBusAmqpTest do
  use ExUnit.Case
  doctest EventBusAmqp

  import Mock

  alias EventBusAmqp.Adapter.SecretManager

  @moduletag :capture_log

  setup_all do
    # {:ok, _} = Application.ensure_all_started(:registry_module)
    :ok
  end

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

    plain_config = %{
      "broker_producer_module" => "Broadway.DummyProducer",
      "broker_queue" => "x",
      "broker_username" => "user2",
      "broker_password" => "acme2",
      "broker_virtualhost" => "/vh",
      "broker_hostname" => "localhost",
      "broker_port" => 10_000,
      "broker_producer_prefetch" => 1,
      "broker_bindings" => [],
      "broker_producer_concurrency" => 1,
      "broker_processor_concurrency" => 1,
      "broker_processor_max_demand" => 1
    }

    secrets_config = %{
      "broker_producer_name" => "abc",
      "broker_producer_module" => "Broadway.DummyProducer",
      "broker_secret" => "my_aws_secret_name",
      "broker_queue" => "x",
      "broker_producer_prefetch" => 1,
      "broker_bindings" => [],
      "broker_producer_concurrency" => 1,
      "broker_processor_concurrency" => 1,
      "broker_processor_max_demand" => 1,
    }

    {:ok, init_args: %{json: Jason.encode!(test_json), plain_config: plain_config, secrets_config: secrets_config}}
  end

  test "Initialization with secret creds", %{init_args: init_args} do

    with_mocks([
      {SecretManager, [], [get_secret: fn (_a, _b) ->
        {:ok, %{"hostname" => "some-host.mq.us-east-1.amazonaws.com", "password" => "acme", "port" => "5671", "ssl" => "true", "username" => "user1", "virtualhost" => "/"}}
      end]}
    ]) do
      assert {EventBusAmqp.Subscriber, [
        %{"broker_bindings" => [],
          "broker_processor_concurrency" => 1,
          "broker_processor_max_demand" => 1,
          "broker_producer_concurrency" => 1,
          "broker_producer_name" => "abc",
          "broker_producer_prefetch" => 1,
          "broker_queue" => "x",
          "broker_secret" => "my_aws_secret_name",
          "broker_url" => "amqps://user1:acme@some-host.mq.us-east-1.amazonaws.com?verify=verify_none&server_name_indication=some-host.mq.us-east-1.amazonaws.com"
          }
        ]} = EventBusAmqp.build_child_spec(init_args.secrets_config)
    end
  end

  test "Initialization with plain creds", %{init_args: init_args} do

    assert {EventBusAmqp.Subscriber, [
      %{"broker_bindings" => [],
        "broker_hostname" => "localhost",
        "broker_password" => "acme2",
        "broker_port" => 10000,
        "broker_processor_concurrency" => 1,
        "broker_processor_max_demand" => 1,
        "broker_producer_concurrency" => 1,
        "broker_producer_prefetch" => 1,
        "broker_queue" => "x",
        "broker_username" => "user2",
        "broker_virtualhost" => "/vh"}
        ]} = EventBusAmqp.build_child_spec(init_args.plain_config)
  end

end
