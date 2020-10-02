import Config

config :channel_sender_ex,
  secret_base:
    {"aV4ZPOf7T7HX6GvbhwyBlDM8B9jfeiwi+9qkBnjXxUZXqAeTrehojWKHkV3U0kGc", "socket auth"},
  app_repo: ChannelSenderEx.Repository.ApplicationRepo,
  socket_port: 8062,
  rest_port: 8061,
  max_age: 900
