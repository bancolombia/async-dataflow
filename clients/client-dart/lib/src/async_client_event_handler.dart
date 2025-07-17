abstract class AsyncClientEventHandler {
  void onEvent(AsyncClientEvent event);
}

class AsyncClientEvent {
  final String message;
  final String? channelRef;

  AsyncClientEvent({
    required this.message,
    this.channelRef,
  });
}
