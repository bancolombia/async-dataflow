class ChannelMessage {
  final String? messageId;
  final String? correlationId;
  final String? event;
  final dynamic payload;

  ChannelMessage(this.messageId, this.correlationId, this.event, this.payload);

  ChannelMessage.fromMap(Map<String, dynamic> map)
      : messageId = map['message_id'],
        correlationId = map['correlation_id'],
        event = map['event'],
        payload = map['payload'];

  @override
  String toString() {
    return '{messageId: $messageId, correlationId: $correlationId, event: $event, payload: $payload }';
  }
}
