import 'package:channel_sender_client/channel_sender_client.dart';

class EventHandler implements AsyncClientEventHandler {
  @override
  void onEvent(AsyncClientEvent event) {
    print(
      'Event received: ${event.message}, Transport: ${event.transportType}, Channel: ${event.channelRef}',
    );
  }
}
