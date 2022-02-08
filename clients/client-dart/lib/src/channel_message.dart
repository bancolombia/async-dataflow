class ChannelMessage {
  final String? messageId;
  final String? correlationId;
  final String? event;
  dynamic payload;

  ChannelMessage(this.messageId, this.correlationId, this.event, this.payload);

  @override
  String toString() {
    return '{messageId: $messageId, correlationId: $correlationId, event: $event, payload: $payload }';
  }

  ChannelMessage.fromMap(dynamic map)
      : messageId = map['message_id'],
        correlationId = map['correlation_id'],
        event = map['event'],
        payload = map['payload'];
}
