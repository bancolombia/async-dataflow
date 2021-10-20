import Config

config :channel_sender_ex,
  secret_base:
    {"aV4ZPOf7T7HX6GvbhwyBlDM8B9jfeiwi+9qkBnjXxUZXqAeTrehojWKHkV3U0kGc", "socket auth"},
  initial_redelivery_time: 100,
  max_age: 900,
  #  message_encoder: ChannelSenderEx.Transport.Encoders.BinaryEncoder,
  message_encoder: ChannelSenderEx.Transport.Encoders.JsonEncoder,
  no_start: true,
  socket_idle_timeout: 60000,
  socket_port: 8082,
  rest_port: 8081
