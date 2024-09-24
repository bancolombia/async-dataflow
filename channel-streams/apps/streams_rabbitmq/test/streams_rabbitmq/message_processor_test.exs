defmodule StreamsRabbitmq.MessageProcessorTest do
  use ExUnit.Case, async: true
  # use Plug.Test

  alias StreamsCore.CloudEvent
  alias StreamsRabbitmq.MessageProcessor

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
      Application.delete_env(:channel_streams, :event_mutator)
    end)

    {:ok, init_args: %{json: Jason.encode!(test_json), event: CloudEvent.from(test_json)}}
  end

  test "Should process valid message", %{init_args: init_args} do
    with_mocks([
      {StreamsCore, [], [route_message: fn _alias, _cloud_event -> :ok end]}
    ]) do

      assert :ok == MessageProcessor.handle_message(init_args.json)

      :timer.sleep(100)

      assert called(StreamsCore.route_message(:_, :_))
    end
  end

  test "Should handle an empty json message", %{init_args: _init_args} do
    with_mocks([
      {StreamsCore, [], [route_message: fn _alias, _cloud_event -> :ok end]}
    ]) do

      assert_raise StreamsCore.CloudEvent.RoutingError, fn ->
        MessageProcessor.handle_message("{}")
      end

      :timer.sleep(100)

      assert_not_called(StreamsCore.route_message(:_, :_))
    end
  end

  test "Should handle an invalid message", %{init_args: _init_args} do
    with_mocks([
      {StreamsCore, [], [route_message: fn _alias, _cloud_event -> :ok end]}
    ]) do

      assert_raise StreamsCore.CloudEvent.RoutingError, fn ->
        MessageProcessor.handle_message("xxxxx")
      end

      :timer.sleep(100)

      assert_not_called(StreamsCore.route_message(:_, :_))
    end
  end

  test "Should handle no pid found", %{init_args: init_args} do

    with_mocks([
      {StreamsCore, [], [
        route_message: fn _alias, _cloud_event -> {:error, :noproc} end
      ]}
    ]) do

      assert_raise StreamsCore.CloudEvent.RoutingError, fn ->
        MessageProcessor.handle_message(init_args.json)
      end

      :timer.sleep(100)

      # assert_not_called(StreamsCore.route_message(:_, :_))
    end
  end
end
