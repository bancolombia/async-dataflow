/// Represents a message in a channel with associated metadata.
///
/// The [ChannelMessage] class encapsulates the details of a message
/// including its unique identifier, correlation identifier, event type,
/// and the payload of the message.
///
/// Properties:
/// - [messageId]: A unique identifier for the message.
/// - [correlationId]: An identifier used to correlate messages.
/// - [event]: The type of event associated with the message.
/// - [payload]: The actual data or content of the message.
///
/// Constructors:
/// - [ChannelMessage]: Creates a new instance of [ChannelMessage] with the
///   specified [messageId], [correlationId], [event], and [payload].
/// - [ChannelMessage.fromMap]: Creates a new instance of [ChannelMessage]
///   from a map representation, where the keys correspond to the property
///   names.
///
/// Example:
/// ```dart
/// var message = ChannelMessage('1', '123', 'message_event', {'key': 'value'});
/// print(message); // Output: {messageId: 1, correlationId: 123, event: message_event, payload: {key: value} }
/// ```
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
