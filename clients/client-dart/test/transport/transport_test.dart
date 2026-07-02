import 'package:channel_sender_client/channel_sender_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('transportFromString', () {
    expect(transportFromString('ws'), TransportType.ws);
    expect(transportFromString('sse'), TransportType.sse);
    expect(transportFromString('unknown'), TransportType.ws);
  });
}
