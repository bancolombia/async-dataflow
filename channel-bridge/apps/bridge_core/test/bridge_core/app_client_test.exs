defmodule BridgeCore.AppClientTest do
  use ExUnit.Case

  alias BridgeCore.AppClient

  @moduletag :capture_log

  # setup do
  #   test_cloud_event = %{
  #     data: %{
  #       "say" => "Hi"
  #     },
  #     dataContentType: "application/json",
  #     id: "1",
  #     invoker: "invoker1",
  #     source: "source1",
  #     specVersion: "0.1",
  #     time: "xxx",
  #     type: "type1"
  #   }

  #   on_exit(fn ->
  #     Application.delete_env(:channel_bridge, :cloud_event_app_identifier)
  #   end)

  #   {:ok, init_args: %{request: test_request, cloud_event: test_cloud_event}}
  # end

  test "Should build new client" do
    client = AppClient.new("abc321", "some app")
    assert %AppClient{} = AppClient.new(nil, nil)
    assert client != nil
    assert client.id == "abc321"
    assert client.name == "some app"
  end

end
