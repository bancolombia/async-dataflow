import 'package:channel_sender_client/src/model/channel_message.dart';
import 'package:channel_sender_client/src/transport/transport.dart';
import 'package:channel_sender_client/src/transport/types/noop_transport.dart';
import 'package:test/test.dart';

void main() {
  group('Noop Transport Tests', () {
    test('Noop tests', () async {
      NoopTransport transport = NoopTransport();

      expect(await transport.connect(), false);
      await transport.disconnect();
      expect(transport.isOpen(), false);
      expect(transport.name(), TransportType.none);
      expect(transport.stream, isA<Stream<ChannelMessage>>());
    });
  });
}
