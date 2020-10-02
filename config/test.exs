import Config

config :channel_sender_ex,
  secret_base:
    {"aV4ZPOf7T7HX6GvbhwyBlDM8B9jfeiwi+9qkBnjXxUZXqAeTrehojWKHkV3U0kGc", "socket auth"},
  initial_redelivery_time: 100,
  app_repo: ChannelSenderEx.Repository.ApplicationRepo,
  max_age: 900
