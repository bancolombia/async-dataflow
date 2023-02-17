Code.compiler_options(ignore_module_conflict: true)

defmodule ChannelBridgeEx.Boundary.ChannelManagerTest do
  use ExUnit.Case, async: false
  import Mock

  @moduletag :capture_log
  @moduletag :channel_sender

  alias ChannelBridgeEx.Boundary.ChannelManager
  alias ChannelBridgeEx.Core.Channel
  alias ChannelBridgeEx.Core.AppClient
  alias ChannelBridgeEx.Core.User
  alias ChannelBridgeEx.Core.CloudEvent
  alias ChannelBridgeEx.Core.CloudEvent.Mutator.DefaultMutator

  setup_with_mocks([
    {AdfSenderConnector, [],
     [
       channel_registration: fn application_ref, _user_ref ->
         case application_ref do
           "app-01" ->
             {:ok,
              %{
                "channel_ref" => "some_channel_ref",
                "channel_secret" => "some_channel_key-dlkahsiualschfaiusfhlakshc"
              }}

           _ ->
             {:error, %{}}
         end
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
         case cloud_event.type do
           "some.event.to.fail.mutation" -> {:error, "some reason"}
           _ -> {:ok, cloud_event}
         end
       end
     ]}
  ]) do
    :ok
  end

  test "Should open channel process" do
    data =
      Map.new()
      |> Map.put(
        "channel",
        Channel.new("my-alias", AppClient.new("app-01", nil), User.new("CC-123456"))
      )

    {:ok, pid} = ChannelManager.start_link(data)

    assert pid != nil

    ChannelManager.open_channel(pid)

    assert Process.info(pid, :priority) == {:priority, :normal}

    # trying to re-open the same channel yields an error
    assert {:error, _} = ChannelManager.open_channel(pid)

    Process.exit(pid, :kill)
  end

  test "Should handle fail creating channel process" do
    data =
      Map.new()
      |> Map.put(
        "channel",
        Channel.new("my-alias", AppClient.new("app-02", nil), User.new("CC-123456"))
      )

    {:ok, pid} = ChannelManager.start_link(data)

    assert pid != nil

    assert {:error, _} = ChannelManager.open_channel(pid)

    assert Process.info(pid, :priority) == {:priority, :normal}

    Process.exit(pid, :kill)
  end

  test "Should close channel" do
    data =
      Map.new()
      |> Map.put(
        "channel",
        Channel.new("my-alias", AppClient.new("app-01", nil), User.new("CC-123459"))
      )

    {:ok, pid} = ChannelManager.start_link(data)
    open_response = ChannelManager.open_channel(pid)

    assert "some_channel_ref" == open_response["channel_ref"]
    assert "some_channel_key-dlkahsiualschfaiusfhlakshc" == open_response["channel_secret"]
    assert "my-alias" == open_response["session_tracker"]

    assert :ok == ChannelManager.close_channel(pid)

    # trying to re-open it again
    assert {:error, "channel was closed, cannot re-open"} == ChannelManager.open_channel(pid)

    # trying to close it again
    assert {:error, :alreadyclosed} == ChannelManager.close_channel(pid)

    Process.exit(pid, :kill)
  end

  test "Should close channel and handle error" do
    data =
      Map.new()
      |> Map.put(
        "channel",
        Channel.new("my-alias", AppClient.new("app-01", nil), User.new("CC-1234591"))
      )

    {:ok, pid} = ChannelManager.start_link(data)

    assert {:error, "channel never opened"} == ChannelManager.close_channel(pid)

    :timer.sleep(100)
    Process.exit(pid, :normal)
  end

  test "Should send message" do
    children = [
      {Task.Supervisor, name: ADFSender.TaskSupervisor}
    ]

    {:ok, _} = Supervisor.start_link(children, strategy: :one_for_one)

    data =
      Map.new()
      |> Map.put(
        "channel",
        Channel.new("my-alias", AppClient.new("app-01", nil), User.new("CC-1989637100"))
      )

    {:ok, pid} = ChannelManager.start_link(data)
    open_response = ChannelManager.open_channel(pid)

    assert "some_channel_ref" == open_response["channel_ref"]
    assert "some_channel_key-dlkahsiualschfaiusfhlakshc" == open_response["channel_secret"]
    assert "my-alias" == open_response["session_tracker"]

    {:ok, message} = CloudEvent.from("{
      \"data\": {
        \"headers\": {
          \"channel\": \"BLM\",
          \"application-id\": \"abc321\"
        },
        \"request\": {
          \"customer\": {
            \"identification\": {
              \"type\": \"CC\",
              \"number\": \"1989637100\"
            }
          }
        },
        \"response\": {
          \"msg\": \"Hello World\"
        }
      },
      \"dataContentType\": \"application/json\",
      \"id\": \"1\",
      \"invoker\": \"invoker1\",
      \"source\": \"source1\",
      \"specVersion\": \"0.1\",
      \"subject\": \"foo\",
      \"time\": \"xxx\",
      \"type\": \"type1\"
    }")

    response = ChannelManager.deliver_message(pid, message)

    assert :accepted = response

    :timer.sleep(100)
    Process.exit(pid, :kill)
  end

  test "Should not send nil message" do
    children = [
      {Task.Supervisor, name: ADFSender.TaskSupervisor}
    ]

    {:ok, _} = Supervisor.start_link(children, strategy: :one_for_one)

    data =
      Map.new()
      |> Map.put(
        "channel",
        Channel.new("my-alias", AppClient.new("app-01", nil), User.new("CC-1989637100"))
      )

    {:ok, pid} = ChannelManager.start_link(data)
    open_response = ChannelManager.open_channel(pid)

    assert "some_channel_ref" == open_response["channel_ref"]
    assert "some_channel_key-dlkahsiualschfaiusfhlakshc" == open_response["channel_secret"]
    assert "my-alias" == open_response["session_tracker"]

    response = ChannelManager.deliver_message(pid, nil)

    assert :ignored = response

    :timer.sleep(100)
    Process.exit(pid, :kill)
  end

  test "Should not send message - handle mutator fail" do
    children = [
      {Task.Supervisor, name: ADFSender.TaskSupervisor}
    ]

    {:ok, _} = Supervisor.start_link(children, strategy: :one_for_one)

    data =
      Map.new()
      |> Map.put(
        "channel",
        Channel.new("my-alias", AppClient.new("app-01", nil), User.new("CC-1989637100"))
      )

    {:ok, pid} = ChannelManager.start_link(data)
    open_response = ChannelManager.open_channel(pid)

    assert "some_channel_ref" == open_response["channel_ref"]
    assert "some_channel_key-dlkahsiualschfaiusfhlakshc" == open_response["channel_secret"]
    assert "my-alias" == open_response["session_tracker"]

    {:ok, message} = CloudEvent.from("{
      \"data\": {
        \"headers\": {
          \"channel\": \"BLM\",
          \"application-id\": \"abc321\"
        },
        \"request\": {
          \"customer\": {
            \"identification\": {
              \"type\": \"CC\",
              \"number\": \"1989637100\"
            }
          }
        },
        \"response\": {
          \"msg\": \"Hello World\"
        }
      },
      \"dataContentType\": \"application/json\",
      \"id\": \"1\",
      \"invoker\": \"invoker1\",
      \"source\": \"source1\",
      \"specVersion\": \"0.1\",
      \"subject\": \"foo\",
      \"time\": \"xxx\",
      \"type\": \"some.event.to.fail.mutation\"
    }")

    response = ChannelManager.deliver_message(pid, message)

    assert :accepted = response

    :timer.sleep(100)
    Process.exit(pid, :kill)
  end

  test "Should not send message - handle send fail" do
    children = [
      {Task.Supervisor, name: ADFSender.TaskSupervisor}
    ]

    {:ok, _} = Supervisor.start_link(children, strategy: :one_for_one)

    data =
      Map.new()
      |> Map.put(
        "channel",
        Channel.new("my-alias", AppClient.new("app-01", nil), User.new("CC-1989637100"))
      )

    {:ok, pid} = ChannelManager.start_link(data)
    open_response = ChannelManager.open_channel(pid)

    assert "some_channel_ref" == open_response["channel_ref"]
    assert "some_channel_key-dlkahsiualschfaiusfhlakshc" == open_response["channel_secret"]
    assert "my-alias" == open_response["session_tracker"]

    {:ok, message} = CloudEvent.from("{
      \"data\": {
        \"headers\": {
          \"channel\": \"BLM\",
          \"application-id\": \"abc321\"
        },
        \"request\": {
          \"customer\": {
            \"identification\": {
              \"type\": \"CC\",
              \"number\": \"1989637100\"
            }
          }
        },
        \"response\": {
          \"msg\": \"Hello World\"
        }
      },
      \"dataContentType\": \"application/json\",
      \"id\": \"1\",
      \"invoker\": \"invoker1\",
      \"source\": \"source1\",
      \"specVersion\": \"0.1\",
      \"subject\": \"foo\",
      \"time\": \"xxx\",
      \"type\": \"some.event.to.fail.send1\"
    }")

    response = ChannelManager.deliver_message(pid, message)
    assert :accepted = response

    new_message = %{message | type: "some.event.to.fail.send2"}

    new_response = ChannelManager.deliver_message(pid, new_message)
    assert :accepted = new_response

    :timer.sleep(100)
    Process.exit(pid, :kill)
  end

  test "Should not send message - channel not yet opened" do
    children = [
      {Task.Supervisor, name: ADFSender.TaskSupervisor}
    ]

    {:ok, _} = Supervisor.start_link(children, strategy: :one_for_one)

    data =
      Map.new()
      |> Map.put(
        "channel",
        Channel.new("my-alias", AppClient.new("app-01", nil), User.new("CC-1989637100"))
      )

    {:ok, pid} = ChannelManager.start_link(data)

    {:ok, message} = CloudEvent.from("{
      \"data\": {
        \"headers\": {
          \"channel\": \"BLM\",
          \"application-id\": \"abc321\"
        },
        \"request\": {
          \"customer\": {
            \"identification\": {
              \"type\": \"CC\",
              \"number\": \"1989637100\"
            }
          }
        },
        \"response\": {
          \"msg\": \"Hello World\"
        }
      },
      \"dataContentType\": \"application/json\",
      \"id\": \"1\",
      \"invoker\": \"invoker1\",
      \"source\": \"source1\",
      \"specVersion\": \"0.1\",
      \"subject\": \"foo\",
      \"time\": \"xxx\",
      \"type\": \"some.event.to.fail.mutation\"
    }")

    response = ChannelManager.deliver_message(pid, message)

    assert :accepted = response

    :timer.sleep(100)
    Process.exit(pid, :kill)
  end

  test "Should not send message - channel status is not open" do
    children = [
      {Task.Supervisor, name: ADFSender.TaskSupervisor}
    ]

    {:ok, _} = Supervisor.start_link(children, strategy: :one_for_one)

    data =
      Map.new()
      |> Map.put(
        "channel",
        Channel.new("my-alias", AppClient.new("app-01", nil), User.new("CC-1989637100"))
      )

    {:ok, pid} = ChannelManager.start_link(data)
    # opens channel
    ChannelManager.open_channel(pid)

    # then closes channel
    ChannelManager.close_channel(pid)

    # then tries to deliver msg
    {:ok, message} = CloudEvent.from("{
      \"data\": {
        \"headers\": {
          \"channel\": \"BLM\",
          \"application-id\": \"abc321\"
        },
        \"request\": {
          \"customer\": {
            \"identification\": {
              \"type\": \"CC\",
              \"number\": \"1989637100\"
            }
          }
        },
        \"response\": {
          \"msg\": \"Hello World\"
        }
      },
      \"dataContentType\": \"application/json\",
      \"id\": \"1\",
      \"invoker\": \"invoker1\",
      \"source\": \"source1\",
      \"specVersion\": \"0.1\",
      \"subject\": \"foo\",
      \"time\": \"xxx\",
      \"type\": \"some.event.to.fail.mutation\"
    }")

    response = ChannelManager.deliver_message(pid, message)

    assert :accepted = response

    :timer.sleep(100)
    Process.exit(pid, :kill)
  end

end
