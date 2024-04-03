defmodule BridgeCore.Boundary.ChannelManagerTest do
  use ExUnit.Case, async: false
  import Mock
  require Logger

  alias BridgeCore.Boundary.ChannelManager
  alias BridgeCore.{Channel, AppClient, User, CloudEvent}
  alias BridgeCore.CloudEvent.Mutator.DefaultMutator
  alias BridgeCore.Sender.Connector

  @app_ref AppClient.new("01", "app-01")
  @user_ref User.new("CC-123456")
  @default_mutator_setup %{
    "mutator_module" => DefaultMutator,
    "config" => nil
  }

  setup_with_mocks([
    {Connector, [],
      [
        channel_registration: fn _application_ref, _user_ref ->
         {:ok, %{ "channel_ref" => "ref", "channel_secret" => "secret"} }
        end,
        start_router_process: fn _channel_ref, _options -> :ok end,
        stop_router_process: fn _channel_ref, _options -> :ok end,
        route_message: fn _chref, protocol_msg ->
          case protocol_msg.event_name do
            "some.event.to.fail.send1" ->
              {:error, :channel_sender_econnrefused}
            _ ->
              {:ok, %{}}
          end
        end
      ]},
      {DefaultMutator, [], [
        applies?: fn _cloud_event, _config -> true end,
        mutate: fn event, _config ->
          if event == nil do
            {:error, :mutation_error}
          else
            case event.type do
              "some.event.to.fail.mutation" ->
                {:error, :mutation_error}
              _ ->
                {:ok, event}
            end
          end
        end
      ]}
  ]) do
    :ok
  end

  test "Should start channel process" do
    channel = Channel.new("my-alias", @app_ref, @user_ref)
      |> Channel.update_credentials("ref", "secret")

    assert {:ok, refs} = Channel.get_procs(channel)
    assert ["ref"] == Enum.map(refs, fn ref -> ref.channel_ref end)

    {:ok, pid} = ChannelManager.start_link({channel, @default_mutator_setup})

    assert pid != nil

    assert Process.info(pid, :priority) == {:priority, :normal}

    Process.exit(pid, :normal)
  end

  test "Should get info on channel" do
    channel = Channel.new("my-alias", @app_ref, @user_ref)
      |> Channel.update_credentials("ref", "secret")

    {:ok, pid} = ChannelManager.start_link({channel, @default_mutator_setup})

    {:ok, {channel2, _mutator}} = ChannelManager.get_channel_info(pid)

    assert channel == channel2

    Process.exit(pid, :normal)
  end

  test "Should get info on channel, with status closed" do
    channel = Channel.new("my-alias", @app_ref, @user_ref)
              |> Channel.update_credentials("ref", "secret")

    {:ok, pid} = ChannelManager.start_link({channel, @default_mutator_setup})

    assert :ok == ChannelManager.close_channel(pid)

    {:ok, {channel2, _mutator}} = ChannelManager.get_channel_info(pid)

    assert channel.channel_alias == channel2.channel_alias
    assert :closed == channel2.status

    Process.exit(pid, :normal)
  end

  test "Should update channel" do
    channel = Channel.new("my-alias", @app_ref, @user_ref)
      |> Channel.update_credentials("ref", "secret")

    {:ok, pid} = ChannelManager.start_link({channel, @default_mutator_setup})

    {:ok, {alt_channel, _mutator}} = ChannelManager.get_channel_info(pid)

    assert channel == alt_channel

    channel = %{alt_channel | procs: [BridgeCore.Reference.new("ref2", "secret2")]}

    {:ok, channel2} = ChannelManager.update(pid, channel)
    {:ok, refs} = Channel.get_procs(channel2)
    assert ["ref2", "ref"] == Enum.map(refs, fn ref -> ref.channel_ref end)

    # now tries to update with empty procs
    assert {:error, :empty_refs} = ChannelManager.update(pid, %{channel2 | procs: []})

    Process.exit(pid, :normal)
  end

  test "Should close channel" do

    channel = Channel.new("my-alias", @app_ref, @user_ref)
      |> Channel.update_credentials("ref", "secret")

    {:ok, pid} = ChannelManager.start_link({channel, @default_mutator_setup})

    assert :ok == ChannelManager.close_channel(pid)

    Process.exit(pid, :normal)
  end

  test "Should close channel just once" do

    channel = Channel.new("my-alias", @app_ref, @user_ref)
              |> Channel.update_credentials("ref", "secret")

    {:ok, pid} = ChannelManager.start_link({channel, @default_mutator_setup})

    assert :ok == ChannelManager.close_channel(pid)

    # trying to close it again
    assert {:error, :alreadyclosed} == ChannelManager.close_channel(pid)

    Process.exit(pid, :normal)
  end

  test "Should route message" do

    channel = Channel.new("my-alias", @app_ref, @user_ref)
      |> Channel.update_credentials("ref", "secret")

    {:ok, pid} = ChannelManager.start_link({channel, @default_mutator_setup})

    {:ok, message} = CloudEvent.from("{
      \"data\": {
        \"msg\": \"Hello World\"
      },
      \"dataContentType\": \"application/json\",
      \"id\": \"1\",
      \"invoker\": \"invoker1\",
      \"source\": \"source1\",
      \"specVersion\": \"0.1\",
      \"subject\": \"my-alias\",
      \"time\": \"xxx\",
      \"type\": \"type1\"
    }")

    response = ChannelManager.deliver_message(pid, message)
    assert :ok = response

    :timer.sleep(10)
    assert_called Connector.start_router_process(:_ , :_)
    assert_called Connector.route_message(:_, :_)

    Process.exit(pid, :normal)

  end

  test "Should not send nil message" do

    channel = Channel.new("my-alias", @app_ref, @user_ref)
      |> Channel.update_credentials("ref", "secret")

    {:ok, pid} = ChannelManager.start_link({channel, @default_mutator_setup})

    response = ChannelManager.deliver_message(pid, nil)
    assert :ok = response

    :timer.sleep(10)
    assert_not_called Connector.route_message(:_, :_, :_)

    Process.exit(pid, :normal)
  end

  test "Should not send message - handle mutator fail" do

    channel = Channel.new("my-alias", @app_ref, @user_ref)
      |> Channel.update_credentials("ref", "secret")

    {:ok, pid} = ChannelManager.start_link({channel, @default_mutator_setup})

    {:ok, message} = CloudEvent.from("{
      \"data\": {
        \"msg\": \"Hello World\"
      },
      \"dataContentType\": \"application/json\",
      \"id\": \"1\",
      \"invoker\": \"invoker1\",
      \"source\": \"source1\",
      \"specVersion\": \"0.1\",
      \"subject\": \"my-alias\",
      \"time\": \"xxx\",
      \"type\": \"some.event.to.fail.mutation\"
    }")

    response = ChannelManager.deliver_message(pid, message)
    assert :ok = response

    :timer.sleep(10)
    assert_not_called Connector.route_message(:_, :_)

    Process.exit(pid, :normal)
  end

  test "Should not send message - handle send fail" do
    channel = Channel.new("my-alias", @app_ref, @user_ref)
      |> Channel.update_credentials("ref", "secret")

    {:ok, pid} = ChannelManager.start_link({channel, @default_mutator_setup})

    {:ok, message} = CloudEvent.from("{
      \"data\": {
        \"msg\": \"Hello World\"
      },
      \"dataContentType\": \"application/json\",
      \"id\": \"1\",
      \"invoker\": \"invoker1\",
      \"source\": \"source1\",
      \"specVersion\": \"0.1\",
      \"subject\": \"my-alias\",
      \"time\": \"xxx\",
      \"type\": \"some.event.to.fail.send1\"
    }")

    response = ChannelManager.deliver_message(pid, message)
    assert :ok = response

    :timer.sleep(10)
    assert_called Connector.route_message(:_, :_)

    new_message = %{message | type: "some.event.to.fail.send2"}
    new_response = ChannelManager.deliver_message(pid, new_message)
    assert :ok = new_response

    :timer.sleep(10)
    assert_called Connector.route_message(:_, :_)

    Process.exit(pid, :normal)
  end

  test "Should not send message - channel status is new" do
    channel = Channel.new("my-alias", @app_ref, User.new("CC-1989637140"))

    {:ok, pid} = ChannelManager.start_link({channel, @default_mutator_setup})

    # then tries to deliver msg
    {:ok, message} = CloudEvent.from("{
      \"data\": {
        \"msg\": \"Hello World\"
      },
      \"dataContentType\": \"application/json\",
      \"id\": \"1\",
      \"invoker\": \"invoker1\",
      \"source\": \"source1\",
      \"specVersion\": \"0.1\",
      \"subject\": \"my-alias\",
      \"time\": \"xxx\",
      \"type\": \"some.event\"
    }")

    assert :ok == ChannelManager.deliver_message(pid, message)

    :timer.sleep(10)
    assert_not_called BridgeCore.Sender.Connector.route_message(:_, :_, :_)

    Process.exit(pid, :normal)
  end

  test "Should not send message - channel status is closed" do

    channel = Channel.new("my-alias", @app_ref, @user_ref)
      |> Channel.update_credentials("ref", "secret")

    {:ok, pid} = ChannelManager.start_link({channel, @default_mutator_setup})

    # then closes channel
    ChannelManager.close_channel(pid)

    # then tries to deliver msg
    {:ok, message} = CloudEvent.from("{
      \"data\": {
        \"msg\": \"Hello World\"
      },
      \"dataContentType\": \"application/json\",
      \"id\": \"1\",
      \"invoker\": \"invoker1\",
      \"source\": \"source1\",
      \"specVersion\": \"0.1\",
      \"subject\": \"my-alias\",
      \"time\": \"xxx\",
      \"type\": \"some.event\"
    }")

    assert :ok == ChannelManager.deliver_message(pid, message)

    :timer.sleep(10)
    assert_not_called BridgeCore.Sender.Connector.route_message(:_, :_, :_)

    Process.exit(pid, :normal)
  end

  test "Should stop related process on channel close" do

    channel = Channel.new("my-alias", @app_ref, @user_ref)
              |> Channel.update_credentials("ref", "secret")

    {:ok, pid} = ChannelManager.start_link({channel, @default_mutator_setup})

    {:ok, message} = CloudEvent.from("{
      \"data\": {
        \"msg\": \"Hello World\"
      },
      \"dataContentType\": \"application/json\",
      \"id\": \"1\",
      \"invoker\": \"invoker1\",
      \"source\": \"source1\",
      \"specVersion\": \"0.1\",
      \"subject\": \"my-alias\",
      \"time\": \"xxx\",
      \"type\": \"some.event\"
    }")

    # delivers a message
    assert :ok == ChannelManager.deliver_message(pid, message)

    :timer.sleep(5)
    assert_called BridgeCore.Sender.Connector.route_message(:_, :_)

    # then closes the channel
    ChannelManager.close_channel(pid)

    :timer.sleep(5)
    assert_called BridgeCore.Sender.Connector.stop_router_process(:_, :_)

    Process.exit(pid, :normal)
  end

end
