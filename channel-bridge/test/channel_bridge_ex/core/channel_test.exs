Code.compiler_options(ignore_module_conflict: true)

defmodule ChannelBridgeEx.Core.ChannelTest do
  use ExUnit.Case
  # import Mock

  alias ChannelBridgeEx.Core.Channel
  alias ChannelBridgeEx.Core.AppClient
  alias ChannelBridgeEx.Core.User
  alias ChannelBridgeEx.Core.CloudEvent
  alias ChannelBridgeEx.Core.Channel.ChannelRequest

  @moduletag :capture_log

  # setup_with_mocks([
  #   {SenderClient, [],
  #   [init: fn(_args) -> :ok end,
  #    create_channel: fn(app_ref, _user_ref) ->
  #     case app_ref do
  #       "my-failing-app-ref" ->
  #         {:error, 502}
  #       _ ->
  #         {:ok, %{channel_ref: "some_channel_ref", channel_secret: "some_channel_key-dlkahsiualschfaiusfhlakshc"}}
  #     end
  #    end,
  #    deliver_message: fn(_msg) -> {:ok, %{}} end]}
  # ]) do
  #   :ok
  # end

  test "Should create new channel" do
    channel = Channel.new("my-channel", AppClient.new("my-app", nil), User.new("user1"))
    assert channel != nil
    assert %Channel{} = channel
  end

  test "Should create new channel from request" do
    request = ChannelRequest.new(%{"session-tracker" => "foo"}, %{}, %{}, %{})
    {:ok, channel} = Channel.new_from_request(request)
    assert channel != nil
    assert "default_app" == channel.application_ref.id
    assert "foo" == channel.channel_alias
    assert "undefined" == channel.user_ref.id
  end

  test "Should fail create new channel from request" do
    request = ChannelRequest.new(%{}, %{}, %{}, %{})
    {:error, :nosessionidfound} = Channel.new_from_request(request)
  end

  test "Should open channel" do
    channel =
      Channel.new("my-channel", AppClient.new("my-app", nil), User.new("user1"))
      |> Channel.open("some_ref", "some_secret")

    assert channel.status == :open
  end

  test "Should close channel" do
    {:ok, channel} =
      Channel.new("my-channel", AppClient.new("my-app", nil), User.new("user1"))
      |> Channel.open("some_ref", "some_secret")
      |> Channel.close()

    assert :closed == channel.status
  end

  test "Should not close un-intializaed channel" do
    {:error, reason} =
      Channel.new("my-channel", AppClient.new("my-app", nil), User.new("user1"))
      |> Channel.close()

    assert :neveropened == reason
  end

  test "Should not close an already closed channel" do
    {:ok, channel} =
      Channel.new("my-channel", AppClient.new("my-app", nil), User.new("user1"))
      |> Channel.open("some_ref", "some_secret")
      |> Channel.close()

    assert channel.status == :closed

    {:error, reason} = Channel.close(channel)

    assert :alreadyclosed == reason
  end

  test "Should set status in channel" do
    channel =
      Channel.new("my-channel", AppClient.new("my-app", nil), User.new("user1"))
      |> Channel.open("some_ref", "some_secret")

    assert :open == channel.status

    channel = Channel.set_status(channel, :closed, :ok)
    assert :closed == channel.status
  end

  # test "Should not deliver event on channel with status != open" do
  #   demo_event = %CloudEvent{
  #     data: %{
  #       "applicationId" => "abc321",
  #       "client" => %{
  #         "type" => "CC",
  #         "documentNumber" => "1989637100"
  #       },
  #       "channel" => "BLM",
  #       "sessionRef" => "xxxxx"
  #     },
  #     dataContentType: "application/json",
  #     id: "1",
  #     invoker: "invoker1",
  #     source: "source1",
  #     specVersion: "0.1",
  #     time: "xxx",
  #     type: "type1"
  #   }

  #   outcome = Channel.new("my-channel", AppClient.new("my-app", nil), User.new("user1"))
  #     |> Channel.deliver_event(demo_event)

  #   assert outcome == {:error, :undeliverable_ch_status}
  # end
end
