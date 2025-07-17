import 'package:channel_sender_client/channel_sender_client.dart';
import 'package:flutter_test/flutter_test.dart';

class MockAsyncClientEventHandler implements AsyncClientEventHandler {
  List<AsyncClientEvent> receivedEvents = [];

  @override
  void onEvent(AsyncClientEvent event) {
    receivedEvents.add(event);
  }
}

void main() {
  group('AsyncClientEventHandler Tests', () {
    test('should handle events correctly', () {
      final handler = MockAsyncClientEventHandler();
      final event = AsyncClientEvent(
        message: 'Test message',
        transportType: TransportType.ws,
        channelRef: 'test-channel',
      );

      handler.onEvent(event);

      expect(handler.receivedEvents.length, 1);
      expect(handler.receivedEvents.first.message, 'Test message');
      expect(handler.receivedEvents.first.transportType, TransportType.ws);
      expect(handler.receivedEvents.first.channelRef, 'test-channel');
    });

    test('should handle events with default transport type', () {
      final handler = MockAsyncClientEventHandler();
      final event = AsyncClientEvent(message: 'Test message without transport');

      handler.onEvent(event);

      expect(handler.receivedEvents.length, 1);
      expect(
        handler.receivedEvents.first.message,
        'Test message without transport',
      );
      expect(handler.receivedEvents.first.transportType, TransportType.ws);
      expect(handler.receivedEvents.first.channelRef, null);
    });
  });
}
