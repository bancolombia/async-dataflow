class ChannelMessage {
  ChannelMessage(this.messageId, this.correlationId, this.event, this.payload);

  ChannelMessage.fromMap(Map<String, dynamic> map)
      : messageId = map['message_id'],
        correlationId = map['correlation_id'],
        event = map['event'],
        payload = map['payload'];

  final String? messageId;
  final String? correlationId;
  final String? event;
  dynamic payload;

  @override
  String toString() {
    return '{messageId: $messageId, correlationId: $correlationId, event: $event, payload: $payload }';
  }
}
