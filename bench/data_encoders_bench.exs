alias ChannelSenderEx.Core.ChannelIDGenerator
alias ChannelSenderEx.Core.Security.ChannelAuthenticator
alias ChannelSenderEx.Core.ProtocolMessage
alias ChannelSenderEx.Transport.Encoders.{BinaryEncoder, JsonEncoder}

app_id = "app_22929"
user_id = "user33243222"
channel_id = ChannelIDGenerator.generate_channel_id(app_id, user_id)
token = ChannelIDGenerator.generate_token(channel_id, app_id, user_id)

sample_object = %{
  number: 334433,
  id: UUID.uuid4(:hex),
  name: "Person Name LastName Complement",
  list_of_things: [
    %{name: "Thing1", detail: 2343, id: UUID.uuid4(:hex)},
    %{name: "Thing2", detail: 2343, id: UUID.uuid4(:hex)},
    %{name: "Thing3", detail: 2343, id: UUID.uuid4(:hex)},
    %{name: "Thing4", detail: 2343, id: UUID.uuid4(:hex)},
  ]
}

data = Jason.encode!(sample_object)

base_message = %{
  message_id: UUID.uuid4(:hex),
  correlation_id: "",
  message_data: data,
  event_name: "event.test.name.application"
}

message_to_convert = ProtocolMessage.to_protocol_message(base_message)

#{_, {_, iolist_encoded}} = BinaryEncoder.encode_message(message_to_convert)
#{_, {_, binary_encoded}} = BinaryEncoder.encode_binary(message_to_convert)
#{_, {_, json_encoded}} = JsonEncoder.encode_message(message_to_convert)
#
#{message_id, correlation_id, event_name, message_data, _} = BinaryEncoder.decode_message(binary_encoded)
#{^message_id, ^correlation_id, ^event_name, ^message_data, _} = JsonEncoder.decode_message(json_encoded)



Benchee.run(
  %{
#    "Noop" => fn -> nil end,
    "Binary encoder" => fn -> BinaryEncoder.encode_binary(message_to_convert) end,
    "IO List Encoder" => fn -> BinaryEncoder.encode_message(message_to_convert) end,
    "Json Encoder" => fn -> JsonEncoder.encode_message(message_to_convert) end,
  },

  time: 8,
  parallel: 6,
  formatters: [{Benchee.Formatters.Console, extended_statistics: true}]
)