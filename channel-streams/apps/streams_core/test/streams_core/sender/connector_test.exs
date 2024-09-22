defmodule StreamsCore.Sender.ConnectorTest do
  use ExUnit.Case, async: false
  require Logger

  alias StreamsCore.Sender.Connector

  test "Should check channel registration operation" do
    assert {:error, :channel_sender_econnrefused} ==
       Connector.channel_registration("app_ref", "user_ref")
  end

  test "Should check starting router process operation" do
    {:ok, pid} = Connector.start_router_process("app_ref")
    assert is_pid(pid)
  end

  test "Should check routing operation" do
    assert {:error, :unknown_channel_reference} ==
       Connector.route_message("xxx", "yyy", AdfSenderConnector.Message.new("a", "hello", "evt"))
  end

  test "Should check routing operation II" do
    assert {:error, :unknown_channel_reference} ==
             Connector.route_message("www", AdfSenderConnector.Message.new("a", "hello", "evt"))
  end
end
