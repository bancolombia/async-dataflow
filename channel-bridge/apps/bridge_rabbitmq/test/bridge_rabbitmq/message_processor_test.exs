defmodule BridgeRabbitmq.MessageProcessorTest do
  use ExUnit.Case, async: true
  # use Plug.Test

  alias BridgeCore.CloudEvent
  alias BridgeCore.CloudEvent.RoutingError
  alias BridgeRabbitmq.MessageProcessor

  import Mock

  setup_all do
    test_json = %{
      "specVersion" => "v1",
      "type" => "type1",
      "source" => "source1",
      "subject" => "foo",
      "id" => "001",
      "time" => "",
      "invoker" => "invoker1",
      "dataContentType" => "application/json",
      "data" => %{
        "request" => %{
          "headers" => %{
            "channel" => "ch1",
            "application-id" => "abc321",
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

    on_exit(fn ->
      Application.delete_env(:channel_bridge, :event_mutator)
    end)

    {:ok, init_args: %{json: Jason.encode!(test_json), event: CloudEvent.from(test_json)}}
  end

  test "Should process valid message", %{init_args: init_args} do
    with_mocks([
      {BridgeCore, [], [route_message: fn _alias, _cloud_event -> :ok end]}
    ]) do

      {:ok, pid } = MessageProcessor.handle_message(init_args.json)
      assert is_pid(pid)

      :timer.sleep(100)

      assert called(BridgeCore.route_message(:_, :_))
    end
  end

  test "Should handle an empty json message", %{init_args: _init_args} do
    with_mocks([
      {BridgeCore, [], [route_message: fn _alias, _cloud_event -> :ok end]}
    ]) do

      {:ok, pid } = MessageProcessor.handle_message("{}")
      assert is_pid(pid)

      :timer.sleep(100)

      assert_not_called(BridgeCore.route_message(:_, :_))
    end
  end

  test "Should handle an invalid message", %{init_args: _init_args} do
    with_mocks([
      {BridgeCore, [], [route_message: fn _alias, _cloud_event -> :ok end]}
    ]) do

      {:ok, pid } = MessageProcessor.handle_message("xxxxx")
      assert is_pid(pid)

      :timer.sleep(100)

      assert_not_called(BridgeCore.route_message(:_, :_))
    end
  end

  test "Should handle no pid found", %{init_args: init_args} do

    with_mocks([
      {BridgeCore, [], [
        route_message: fn _alias, _cloud_event -> {:error, :noproc} end
      ]}
    ]) do

      {:ok, pid } = MessageProcessor.handle_message(init_args.json)
      assert is_pid(pid)

      :timer.sleep(100)

      # assert_not_called(BridgeCore.route_message(:_, :_))
    end
  end
end
