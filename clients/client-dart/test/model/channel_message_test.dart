import 'package:channel_sender_client/channel_sender_client.dart';
import 'package:test/test.dart';

void main() {
  test('mapper', () {
    ChannelMessage channelMessage = ChannelMessage.fromMap({
      'message_id': 'message_id',
      'correlation_id': 'correlation_id',
      'event': 'event',
      'payload': 'payload'
    });
    expect(channelMessage.messageId, 'message_id');
    expect(channelMessage.correlationId, 'correlation_id');
    expect(channelMessage.event, 'event');
    expect(channelMessage.payload, 'payload');
  });
}
