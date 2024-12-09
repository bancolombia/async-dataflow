alias ChannelSenderEx.Core.Channel
alias ChannelSenderEx.Core.Channel.Data
alias ChannelSenderEx.Core.ProtocolMessage
alias ChannelSenderEx.Core.ChannelIDGenerator

app_id = "app_22929"
user_id = "user33243222"
channel_id = ChannelIDGenerator.generate_channel_id(app_id, user_id)
socket_pid = spawn(fn -> Process.sleep(:infinity) end)

defmodule Utils do
  def loop() do
    receive do
      _ -> loop()
    end
  end
end

socket_pid2 = spawn(fn -> Utils.loop() end)

message = ProtocolMessage.to_protocol_message(%{
  message_id: "32452",
  correlation_id: "1111",
  message_data: "Some_messageData",
  event_name: "event.example"
})

message_ref = make_ref()

data = %Data{
  channel: channel_id,
  application: app_id,
  user_ref: user_id,
  socket: {socket_pid2, make_ref()},
  pending_ack: %{
    message_ref => message,
    make_ref() => message,
    make_ref() => message,
    make_ref() => message,
  }
}

Benchee.run(
  %{
    "Optimized timeout impl" => fn -> Channel.connected({:timeout, {:redelivery, message_ref}}, 0, data) end,
    "Non optimized timeout impl" => fn -> Channel.connected({:timeout, {:redelivery, message_ref}}, 0, data) end,
  },

  time: 8,
#  parallel: 6,
  formatters: [{Benchee.Formatters.Console, extended_statistics: true}]
)
