defmodule ChannelBridgeEx.Entrypoint.Pubsub.MessageProcessorTest do
  use ExUnit.Case, async: false
  use Plug.Test

  alias ChannelBridgeEx.Core.CloudEvent
  alias ChannelBridgeEx.Core.CloudEvent.RoutingError
  alias ChannelBridgeEx.Entrypoint.Pubsub.MessageProcessor
  alias ChannelBridgeEx.Boundary.{ChannelManager, ChannelRegistry}

  import Mock

  setup_all do
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

    on_exit(fn ->
      Application.delete_env(:channel_bridge_ex, :event_mutator)
    end)

    {:ok, init_args: %{json: Jason.encode!(test_json), event: CloudEvent.from(test_json)}}
  end

  test "Should process valid message", %{init_args: init_args} do
    with_mocks([
      {ChannelRegistry, [], [lookup_channel_addr: fn _ref -> [{:c.pid(0, 250, 0), :ok}] end]},
      {ChannelManager, [], [deliver_message: fn _pid, _message -> :accepted end]}
    ]) do
      assert :accepted == MessageProcessor.handle_message(init_args.json)
    end
  end

  test "Should handle an empty json message", %{init_args: _init_args} do
    with_mocks([
      {ChannelRegistry, [], [lookup_channel_addr: fn _ref -> [{:c.pid(0, 250, 0), :ok}] end]},
      {ChannelManager, [], [deliver_message: fn _pid, _message -> :accepted end]}
    ]) do
      {:error, reason, _original_json} = MessageProcessor.handle_message("{}")

      assert %RoutingError{message: "Unable to extract channel alias from message"} == reason
    end
  end

  test "Should handle an invalid message", %{init_args: _init_args} do
    with_mocks([
      {ChannelRegistry, [], [lookup_channel_addr: fn _ref -> [{:c.pid(0, 250, 0), :ok}] end]},
      {ChannelManager, [], [deliver_message: fn _pid, _message -> :accepted end]}
    ]) do
      {:error, reason, _original_json} = MessageProcessor.handle_message("xxxxx")

      assert %Jason.DecodeError{data: "xxxxx", position: 0, token: nil} == reason
    end
  end

  test "Should handle no pid found", %{init_args: init_args} do
    with_mocks([
      {ChannelRegistry, [], [lookup_channel_addr: fn _ref -> :noproc end]},
      {ChannelManager, [], [deliver_message: fn _pid, _message -> :accepted end]}
    ]) do
      {:error, reason, _msg} = MessageProcessor.handle_message(init_args.json)

      assert reason == %RoutingError{message: "No process found with alias foo"}
    end
  end
end
