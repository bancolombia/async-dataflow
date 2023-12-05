Code.compiler_options(ignore_module_conflict: true)

defmodule BridgeCore.Boundary.ChannelManagerTest do
  use ExUnit.Case, async: false
  import Mock
  import ExUnit.CaptureLog
  require Logger

  alias BridgeCore.Boundary.ChannelManager
  alias BridgeCore.Channel
  alias BridgeCore.AppClient
  alias BridgeCore.User
  alias BridgeCore.CloudEvent
  alias BridgeCore.CloudEvent.Mutator.DefaultMutator

  @app_ref AppClient.new("01", "app-01")
  @user_ref User.new("CC-123456")

  setup do
    Application.put_env(:channel_bridge, :event_mutator, BridgeCore.CloudEvent.Mutator.DefaultMutator)

    on_exit(fn ->
      Application.delete_env(:channel_bridge, :event_mutator)
    end)

    :ok
  end

  setup_with_mocks([
    {AdfSenderConnector, [],
      [
        channel_registration: fn application_ref, _user_ref ->
          case application_ref do
            @app_ref ->
              {:ok,
              %{
                "channel_ref" => Base.encode64(:crypto.strong_rand_bytes(10)),
                "channel_secret" => Base.encode64(:crypto.strong_rand_bytes(20))
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
            _ -> {:ok, %{}}
          end
        end
      ]},
    {DefaultMutator, [],
      [
        mutate: fn cloud_event ->
          case cloud_event do
            nil ->
              {:ok, cloud_event}
            _ ->
              case cloud_event.type do
                "some.event.to.fail.mutation" -> {:error, "some dummy reason"}
                _ -> {:ok, cloud_event}
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

    assert [{"ref", "secret"}] == channel.procs

    {:ok, pid} = ChannelManager.start_link({channel, DefaultMutator})

    assert pid != nil

    assert Process.info(pid, :priority) == {:priority, :normal}

    Process.exit(pid, :kill)
  end

  test "Should get info on channel" do
    channel = Channel.new("my-alias", @app_ref, @user_ref)
      |> Channel.update_credentials("ref", "secret")

    {:ok, pid} = ChannelManager.start_link({channel, DefaultMutator})

    {:ok, {channel2, _mutator}} = ChannelManager.get_channel_info(pid)

    assert channel == channel2

    Process.exit(pid, :kill)
  end

  test "Should update channel" do
    channel = Channel.new("my-alias", @app_ref, @user_ref)
      |> Channel.update_credentials("ref", "secret")

    {:ok, pid} = ChannelManager.start_link({channel, DefaultMutator})

    {:ok, {alt_channel, _mutator}} = ChannelManager.get_channel_info(pid)

    assert channel == alt_channel

    channel2 = Channel.update_credentials(channel, "ref2", "secret2")
    assert [{"ref2", "secret2"}, {"ref", "secret"}] == channel2.procs

    {:ok, alt_channel} = ChannelManager.update(pid, channel2)

    assert channel2.procs == alt_channel.procs

    Process.exit(pid, :kill)
  end


  test "Should close channel" do
    channel = Channel.new("my-alias", @app_ref, @user_ref)
      |> Channel.update_credentials("ref", "secret")

    {:ok, pid} = ChannelManager.start_link({channel, DefaultMutator})

    assert :ok == ChannelManager.close_channel(pid)

    # trying to close it again
    assert {:error, :alreadyclosed} == ChannelManager.close_channel(pid)

    Process.exit(pid, :kill)
  end

  test "Should route message" do
    children = [
      {Task.Supervisor, name: ADFSender.TaskSupervisor}
    ]

    {:ok, _} = Supervisor.start_link(children, strategy: :one_for_one)

    channel = Channel.new("my-alias", @app_ref, @user_ref)
      |> Channel.update_credentials("ref", "secret")

    {:ok, pid} = ChannelManager.start_link({channel, DefaultMutator})

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

    :timer.sleep(200)

    assert called(AdfSenderConnector.route_message(:_, :_, :_))

    Process.exit(pid, :kill)
  end

  test "Should not send nil message" do
    children = [
      {Task.Supervisor, name: ADFSender.TaskSupervisor}
    ]

    {:ok, _} = Supervisor.start_link(children, strategy: :one_for_one)

    channel = Channel.new("my-alias", @app_ref, @user_ref)
      |> Channel.update_credentials("ref", "secret")

    {:ok, pid} = ChannelManager.start_link({channel, DefaultMutator})

    response = ChannelManager.deliver_message(pid, nil)

    assert :ok = response

    :timer.sleep(100)

    assert_not_called(AdfSenderConnector.route_message(:_, :_, :_))

    Process.exit(pid, :kill)
  end

  test "Should not send message - handle mutator fail" do
    children = [
      {Task.Supervisor, name: ADFSender.TaskSupervisor}
    ]

    {:ok, _} = Supervisor.start_link(children, strategy: :one_for_one)

    channel = Channel.new("my-alias", @app_ref, @user_ref)
      |> Channel.update_credentials("ref", "secret")

    {:ok, pid} = ChannelManager.start_link({channel, DefaultMutator})

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

    :timer.sleep(100)

    assert_not_called(AdfSenderConnector.route_message(:_, :_, :_))

    Process.exit(pid, :kill)
  end

  test "Should not send message - handle send fail" do
    children = [
      {Task.Supervisor, name: ADFSender.TaskSupervisor}
    ]

    {:ok, _} = Supervisor.start_link(children, strategy: :one_for_one)

    channel = Channel.new("my-alias", @app_ref, @user_ref)
      |> Channel.update_credentials("ref", "secret")

    {:ok, pid} = ChannelManager.start_link({channel, DefaultMutator})


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

    :timer.sleep(100)
    assert called(AdfSenderConnector.route_message(:_, :_, :_))


    new_message = %{message | type: "some.event.to.fail.send2"}
    new_response = ChannelManager.deliver_message(pid, new_message)
    assert :ok = new_response

    :timer.sleep(100)
    assert called(AdfSenderConnector.route_message(:_, :_, :_))

    Process.exit(pid, :kill)
  end

  test "Should not send message - channel status is new" do
    channel = Channel.new("my-alias", @app_ref, User.new("CC-1989637140"))

    {:ok, pid} = ChannelManager.start_link({channel, DefaultMutator})

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

    :timer.sleep(100)

    assert_not_called(AdfSenderConnector.route_message(:_, :_, :_))

    Process.exit(pid, :normal)
  end

  test "Should not send message - channel status is closed" do
    channel = Channel.new("my-alias", @app_ref, @user_ref)
      |> Channel.update_credentials("ref", "secret")

    {:ok, pid} = ChannelManager.start_link({channel, DefaultMutator})

    # then closes channel
    ChannelManager.close_channel(pid)

    :timer.sleep(100)

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

    :timer.sleep(200)

    assert_not_called(AdfSenderConnector.route_message(:_, :_, :_))

    Process.exit(pid, :normal)
  end

end
