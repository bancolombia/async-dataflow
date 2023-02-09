defmodule ChannelBridgeEx.Core.AppClientTest do
  use ExUnit.Case

  alias ChannelBridgeEx.Core.AppClient
  alias ChannelBridgeEx.Core.Channel.ChannelRequest

  @moduletag :capture_log

  setup do
    test_request =
      ChannelRequest.new(
        %{
          "documenttype" => "CC",
          "documentid" => "1989637100",
          "application-id" => "abc321"
        },
        nil,
        %{
          "channelAlias" => "my-alias"
        },
        nil
      )

    test_cloud_event = %{
      data: %{
        request: %{
          headers: %{
            "channel" => "BLM",
            "application-id" => "abc321",
            "session-tracker" => "foo",
            "documentType" => "CC",
            "documentId" => "198961",
            "async-type" => "command",
            "target" => "some.ms",
            "operation" => "some operation"
          },
          body: %{
            "say" => "Hi"
          }
        },
        response: %{
          "msg" => "Hello World"
        }
      },
      dataContentType: "application/json",
      id: "1",
      invoker: "invoker1",
      source: "source1",
      specVersion: "0.1",
      time: "xxx",
      type: "type1"
    }

    on_exit(fn ->
      Application.delete_env(:channel_bridge_ex, :request_app_identifier)
      Application.delete_env(:channel_bridge_ex, :cloud_event_app_identifier)
    end)

    {:ok, init_args: %{request: test_request, cloud_event: test_cloud_event}}
  end

  test "Should build new client" do
    client = AppClient.new("abc321", "some app")
    assert %AppClient{} = AppClient.new(nil, nil)
    assert client != nil
    assert client.id == "abc321"
    assert client.name == "some app"
  end

  test "Should not extract client from ch request, use fixed value", %{init_args: init_args} do
    Application.put_env(:channel_bridge_ex, :request_app_identifier, {:fixed, "abc"})
    {:ok, client} = AppClient.from_ch_request(init_args.request)
    assert client != nil
    assert client.id == "abc"
    assert client.name == ""
  end

  test "Should fail extracting client from ch request, when using fixed value", %{
    init_args: init_args
  } do
    Application.put_env(:channel_bridge_ex, :request_app_identifier, {:foo, "bar"})
    {:ok, client} = AppClient.from_ch_request(init_args.request)
    assert client != nil
    assert client.id == "default_app"
    assert client.name == ""
  end

  test "Should lookup client from ch request", %{init_args: init_args} do
    Application.put_env(
      :channel_bridge_ex,
      :request_app_identifier,
      {:lookup, "$.req_headers['application-id']"}
    )

    {:ok, client} = AppClient.from_ch_request(init_args.request)
    assert client != nil
    assert client.id == "abc321"
  end

  test "Should lookup client from cloud event", %{init_args: init_args} do
    Application.put_env(
      :channel_bridge_ex,
      :cloud_event_app_identifier,
      {:lookup, "$.data.request.headers['application-id']"}
    )

    client = AppClient.from_cloud_event(init_args.cloud_event)
    assert client != nil
    assert client.id == "abc321"
    assert client.name == ""
  end

  test "Should fail lookup client from cloud event", %{init_args: init_args} do
    Application.put_env(:channel_bridge_ex, :cloud_event_app_identifier, {:foo, "bar"})
    client = AppClient.from_cloud_event(init_args.cloud_event)
    assert client != nil
    assert client.id == "default_app"
    assert client.name == ""
  end
end
