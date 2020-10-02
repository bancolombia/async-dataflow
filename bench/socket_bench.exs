alias ChannelSenderEx.Transport.Socket
alias ChannelSenderEx.Core.ChannelIDGenerator

app_id = "app_22929"
user_id = "user33243222"
channel_id = ChannelIDGenerator.generate_channel_id(app_id, user_id)

state = {channel_id, :connected, {app_id, user_id}, %{}}



Benchee.run(
  %{
#    "With Json parsing" => fn -> Socket.websocket_handle3({:text, "hb::29"}, state) end,
    "With IO list" => fn -> Socket.websocket_handle({:text, "hb::29"}, state) end,
  },

  time: 8,
#  parallel: 6,
  formatters: [{Benchee.Formatters.Console, extended_statistics: true}]
)
