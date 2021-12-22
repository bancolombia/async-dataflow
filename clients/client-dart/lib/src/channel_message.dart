class ChannelMessage {

  String message_id;
  String correlation_id;
  String event;
  Object payload;

  ChannelMessage(message_id, correlation_id, event, payload) {
    this.message_id = message_id;
    this.correlation_id = correlation_id;
    this.event = event;
    this.payload = payload;
  }

  @override
  String toString() {
    return '{message_id: $message_id, correlation_id: $correlation_id, event: $event, payload: $payload }';
  } 
}
