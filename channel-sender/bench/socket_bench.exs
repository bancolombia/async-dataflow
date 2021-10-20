alias ChannelSenderEx.Transport.Socket
alias ChannelSenderEx.Core.Security.ChannelAuthenticator
alias ChannelSenderEx.Core.RulesProvider.Helper
alias ChannelSenderEx.Transport.Encoders.JsonEncoder


Helper.compile(:channel_sender_ex)

app_id = "app_22929"
user_id = "user33243222"
{channel_id, channel_secret} = ChannelAuthenticator.create_channel(app_id, user_id)
auth_frame = {:text, "Auth::" <> channel_secret}
state = {channel_id, :connected, JsonEncoder, {app_id, user_id}, %{}}
state_pre_auth = {channel_id, :pre_auth, JsonEncoder}


Benchee.run(
  %{
#    "Noop" => fn -> for _ <- 0..1000, do: :ok end,
    "Socket / HeartBeat handle" => fn -> Socket.websocket_handle({:text, "hb::29"}, state) end,
    "ChannelAuthenticator / Authorize Channel" => fn -> ChannelAuthenticator.authorize_channel(channel_id, channel_secret) end,
    "Socket / Handle Auth" => fn ->  Socket.websocket_handle(auth_frame, state_pre_auth) end,
  },

  time: 5,
#  parallel: 6,
  formatters: [{Benchee.Formatters.Console, extended_statistics: true}]
)
