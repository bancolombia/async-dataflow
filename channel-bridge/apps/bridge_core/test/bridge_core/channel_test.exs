defmodule BridgeCore.ChannelTest do
  use ExUnit.Case, async: false

  import Mock
  alias BridgeCore.Channel
  alias BridgeCore.AppClient
  alias BridgeCore.User
  alias BridgeCore.CloudEvent
  alias BridgeCore.Sender.Connector

  @moduletag :capture_log

  setup_with_mocks([
    {Connector, [],
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
    {:ok, procs} = Channel.get_procs(channel)

    assert ["some_ref"] == Enum.map(procs, fn ref -> ref.channel_ref end)
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

    {:ok, new_channel} = Channel.close(channel)

    assert :closed == new_channel.status
  end

  test "Should update channel" do
    channel =
      Channel.new("my-channel", AppClient.new("my-app", nil), User.new("user1"))
      |> Channel.update_credentials("some_ref", "some_secret")
      |> Channel.update_credentials("some_ref2", "some_secret2")

    {:ok, procs} = Channel.get_procs(channel)

    assert ["some_ref2", "some_ref"] == Enum.map(procs, fn ref -> ref.channel_ref end)

  end

  test "Should decide that channel is to be closed when running state inactivity check" do
    # create a channel with an app configured for 1 second idling timeout
    channel =
      Channel.new("my-channel", AppClient.new("app01", "app nam", 1), User.new("user1"))
      |> Channel.update_credentials("some_ref", "some_secret")
      |> Channel.update_credentials("some_ref2", "some_secret2")

    assert :ready == channel.status

    # wait for 2 seconds
    :timer.sleep(2000)

    # check_state_inactivity should return :timeout
    assert :timeout == Channel.check_state_inactivity(channel)

  end

  test "Should decide that channel is not to be closed when running state inactivity check" do
    # create a channel with an app configured for 1 second idling timeout
    channel =
      Channel.new("my-channel", AppClient.new("app01", "app nam", 60), User.new("user1"))
      |> Channel.update_credentials("some_ref", "some_secret")

    assert :ready == channel.status

    # wait for 1 seconds
    :timer.sleep(1000)

    new_channel = Channel.update_last_message(channel)

    # wait for 1 seconds
    :timer.sleep(1000)

    # check_state_inactivity should return :noop
    assert :noop == Channel.check_state_inactivity(new_channel)

  end

  test "Should not close channel when running state inactivity check, on status close" do
    # create a channel with an app configured for 1 second idling timeout
    channel =
      Channel.new("my-channel", AppClient.new("app01", "app nam", 60), User.new("user1"))
      |> Channel.update_credentials("some_ref", "some_secret")

    assert :ready == channel.status

    {:ok, new_channel} = Channel.close(channel)
    assert :noop == Channel.check_state_inactivity(new_channel)


  end

  test "Should test prepare message" do
    # create a channel with an app configured for 1 second idling timeout
    channel =
      Channel.new("my-channel", AppClient.new("app01", "app nam", 60), User.new("user1"))
      |> Channel.update_credentials("some_ref", "some_secret")

    cloud_event = CloudEvent.new("1", "1", "1", "1", "1", "1", "1", "1", "1")

    {:ok, messages} = Channel.prepare_messages(channel, cloud_event)

    messages_list = messages |>  Enum.to_list()

    assert 1 == length(messages_list)
  end

  test "Should fail test prepare message, channel with no procs" do
    # create a channel with an app configured for 1 second idling timeout
    channel =
      Channel.new("my-channel", AppClient.new("app01", "app nam", 60), User.new("user1"))

    cloud_event = CloudEvent.new("1", "1", "1", "1", "1", "1", "1", "1", "1")

    assert {:error, :empty_refs} == Channel.prepare_messages(channel, cloud_event)
  end

  test "Should fail test prepare message, invalid cloud event" do
    # create a channel with an app configured for 1 second idling timeout
    channel =
      Channel.new("my-channel", AppClient.new("app01", "app nam", 60), User.new("user1"))
      |> Channel.update_credentials("some_ref", "some_secret")

    assert {:error, :invalid_message} == Channel.prepare_messages(channel, nil)
  end

end
