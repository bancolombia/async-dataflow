alias ChannelSenderEx.Core.{Channel, ChannelRegistry, ChannelSupervisor, ProtocolMessage}
test_channel_args0 = {"1", "app1", "user1"}
test_channel_args1 = {"1", "app1", "user1"}
test_channel_args2 = {"1", "app1", "user1"}


{:ok, test_channel0} = ChannelSupervisor.start_channel(test_channel_args0)

new_message = fn -> ProtocolMessage.of("id1"<> UUID.uuid4(), "test.event1", "message data aasda" <> UUID.uuid4())  end
msg0 = new_message.()
msg1 = new_message.()