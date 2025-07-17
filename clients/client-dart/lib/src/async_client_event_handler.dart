import '../channel_sender_client.dart';

abstract class AsyncClientEventHandler {
  void onEvent(AsyncClientEvent event);
}

class AsyncClientEvent {
  final String message;
  final TransportType transportType;
  final String? channelRef;

  AsyncClientEvent({
    required this.message,
    this.transportType = TransportType.ws,
    this.channelRef,
  });
}
