Code.compiler_options(ignore_module_conflict: true)

defmodule BridgeCore.ChannelTest do
  use ExUnit.Case

  import Mock
  alias BridgeCore.Channel
  alias BridgeCore.AppClient
  alias BridgeCore.User
  alias BridgeCore.CloudEvent

  @moduletag :capture_log

  setup_with_mocks([
    {AdfSenderConnector, [],
     [
       channel_registration: fn application_ref, _user_ref ->
         case application_ref do
           "my-app" ->
             {:ok,
              %{
                "channel_ref" => "some_ref",
                "channel_secret" => "some_secret"
              }}

           _ ->
             {:error, %{}}
         end
       end,
       start_router_process: fn _channel_ref, _options ->
        :ok
       end,
       route_message: fn _chref, _event, protocol_msg ->
         case protocol_msg.event_name do
           "some.event.to.fail.send1" -> {:error, :channel_sender_unknown_error}
           "some.event.to.fail.send2" -> {:error, :channel_sender_econnrefused}
           _ -> :ok
         end
       end
     ]}
  ]) do
    :ok
  end

  test "Should create new channel" do
    channel = Channel.new("my-channel", AppClient.new("my-app", nil), User.new("user1"))
    assert channel != nil
    assert %Channel{} = channel
    assert channel.status == :new
    assert [] == channel.procs
  end

  test "Should update credentials and mark channel as ready" do
    channel =
      Channel.new("my-channel", AppClient.new("my-app", nil), User.new("user1"))
      |> Channel.update_credentials("some_ref", "some_secret")

    assert channel.status == :ready
    assert [{"some_ref", "some_secret"}] == channel.procs
  end

  test "Should mark channel as closed" do
    {:ok, channel} =
      Channel.new("my-channel", AppClient.new("my-app", nil), User.new("user1"))
      |> Channel.update_credentials("some_ref", "some_secret")
      |> Channel.close()

    assert :closed == channel.status
    assert [] == channel.procs
  end

  test "Should let status change from new to closed" do
    channel = Channel.new("my-channel", AppClient.new("my-app", nil), User.new("user1"))
    {:ok, channel2} = Channel.close(channel)

    assert :closed == channel2.status
    assert [] == channel2.procs
  end

  test "Should let status change from closed to closed" do
    {:ok, channel} =
      Channel.new("my-channel", AppClient.new("my-app", nil), User.new("user1"))
      |> Channel.update_credentials("some_ref", "some_secret")
      |> Channel.close()

    assert channel.status == :closed
    assert [] == channel.procs

    {:ok, channel2} = Channel.close(channel)
    assert channel2.status == :closed
    assert [] == channel2.procs

    assert channel == channel2

  end

  test "Should set status in channel" do
    channel =
      Channel.new("my-channel", AppClient.new("my-app", nil), User.new("user1"))
      |> Channel.update_credentials("some_ref", "some_secret")

    assert :ready == channel.status

    new_channel = Channel.set_status(channel, :closed, :ok)
    assert :closed == new_channel.status
  end

  test "Should update channel" do
    channel =
      Channel.new("my-channel", AppClient.new("my-app", nil), User.new("user1"))
      |> Channel.update_credentials("some_ref", "some_secret")
      |> Channel.update_credentials("some_ref2", "some_secret2")

    assert [{"some_ref2", "some_secret2"}, {"some_ref", "some_secret"}] == channel.procs
  end

end
