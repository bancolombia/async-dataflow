Code.compiler_options(ignore_module_conflict: true)

defmodule ChannelBridgeEx.Core.Sender.NotificationMessageTest do
  use ExUnit.Case

  alias ChannelBridgeEx.Core.Sender.NotificationMessage

  @moduletag :capture_log

  setup_all do
    #   {:ok, _} = Application.ensure_all_started(:plug_crypto)
    :ok
  end

  setup do
    :ok
  end

  test "Should create message" do
    msg = NotificationMessage.of("chref", "msgid", "corrid", "hello_world", "eventname")
    assert msg != nil
    assert %NotificationMessage{} = msg
    assert msg.message_data == "hello_world"
  end

  test "Should create message from map" do
    msg =
      NotificationMessage.from(%{
        channel_ref: "ch_ref",
        message_id: "msgid",
        correlation_id: "corrid",
        message_data: "hello_world",
        event_name: "eventname"
      })

    assert msg != nil
    assert msg.message_data == "hello_world"
  end

  # test "Should partition message" do
  #   random = fn -> Enum.random(97..122) end
  #   msg_content =
  #     for _ <- 1..10_000 do
  #       to_string(random.())
  #     end
  #     msg_content = Enum.join(msg_content)

  #   msg = Message.new("msgid", "corrid", "evt1", "user1", msg_content)
  #   assert msg != nil
  #   chunks = Message.split_body(msg.body)
  #   assert length(chunks) == 3
  # end
end
