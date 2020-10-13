defmodule SocketTest do
  use ExUnit.Case

  alias ChannelSenderEx.Transport.Socket
  alias ChannelSenderEx.Core.ProtocolMessage
  alias ChannelSenderEx.Core.RulesProvider.Helper
  alias ChannelSenderEx.Transport.Encoders.JsonEncoder

  @moduletag :capture_log

  @test_encoder JsonEncoder

  setup_all do
    Helper.compile(:channel_sender_ex, socket_event_bus: SocketTest)

    on_exit(fn ->
      Helper.compile(:channel_sender_ex)
    end)
  end

  setup do
    ext_message = %{
      message_id: "id_msg0001",
      correlation_id: "1111",
      message_data: "Some_messageData",
      event_name: "event.example"
    }

    message = ProtocolMessage.to_protocol_message(ext_message)
    connected_state = {"channel1", :connected, @test_encoder, {"app1", "user2"}, _pending = %{}}
    {:ok, ext_message: ext_message, message: message, connected_state: connected_state}
  end

  test "Should send message", %{
    message: message,
    ext_message: ext_message,
    connected_state: state
  } do
    from = {self(), make_ref()}
    message_to_proc = {:deliver_msg, from, message}

    result = Socket.websocket_info(message_to_proc, state)

    assert {commands, {"channel1", :connected, @test_encoder, {"app1", "user2"}, pending}} =
             result

    assert [
             {:text,
              "[\"#{ext_message.message_id}\",\"#{ext_message.correlation_id}\",\"#{
                ext_message.event_name
              }\",\"#{ext_message.message_data}\"]"}
           ] ==
             commands

    assert pending == %{ext_message.message_id => from}
  end

  test "Should send message ack", %{
    message: message,
    ext_message: %{message_id: message_id},
    connected_state: state
  } do
    from = {self(), ref = make_ref()}
    message_to_proc = {:deliver_msg, from, message}

    {_commands, state} = Socket.websocket_info(message_to_proc, state)
    result = Socket.websocket_handle({:text, "Ack::#{message_id}"}, state)

    assert {[], {"channel1", :connected, @test_encoder, {"app1", "user2"}, pending}} = result
    assert pending == %{}
    assert_receive {:ack, ^ref, ^message_id}
  end

  test "Should not fail when client re-ack message", %{
    ext_message: %{message_id: message_id},
    connected_state: state
  } do
    assert {[], {"channel1", :connected, @test_encoder, {"app1", "user2"}, %{}}} ==
             Socket.websocket_handle({:text, "Ack::#{message_id}"}, state)

    refute_receive {:ack, _, _}
  end

  test "Should send message non_retry_error on serialization error", %{
    ext_message: %{message_id: message_id},
    connected_state: state
  } do
    from = {self(), ref = make_ref()}
    message = build_non_serializable_message(message_id)
    message_to_proc = {:deliver_msg, from, message}

    result = Socket.websocket_info(message_to_proc, state)

    assert {[], {"channel1", :connected, @test_encoder, {"app1", "user2"}, %{}}} == result
    assert_receive {:non_retry_error, _error, ^ref, ^message_id}
  end

  def notify_event(_, _) do
    :ok
  end

  defp build_non_serializable_message(message_id) do
    ProtocolMessage.to_protocol_message(%{
      message_id: message_id,
      correlation_id: "1111",
      message_data: _non_serializable = {:non_serializable, 1, 2, 3},
      event_name: "event.example"
    })
  end
end
