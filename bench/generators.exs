alias ChannelSenderEx.Core.ChannelIDGenerator
alias ChannelSenderEx.Core.Security.ChannelAuthenticator

app_id = "app_22929"
user_id = "user33243222"
channel_id = ChannelIDGenerator.generate_channel_id(app_id, user_id)
token = ChannelIDGenerator.generate_token(channel_id, app_id, user_id)

Benchee.run(
  %{
    "Generate Ids uuid4/uuid3" => fn -> ChannelIDGenerator.generate_channel_id(app_id, user_id) end,
    "Generate Secret channel token" => fn -> ChannelIDGenerator.generate_token(channel_id, app_id, user_id) end,
    "Create Channel Data" => fn -> ChannelAuthenticator.create_channel(app_id, user_id) end,
    "Authorize Channel" => fn -> ChannelAuthenticator.authorize_channel(channel_id, token) end,
  },

  time: 8,
#  parallel: 12,
  formatters: [{Benchee.Formatters.Console, extended_statistics: true}]
)