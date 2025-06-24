import '../../channel_sender_client.dart';

/// An abstract class representing a transport mechanism for data communication.
///
/// This class defines the essential methods and properties that any transport
/// implementation must provide, including connection management and message
/// sending capabilities.
abstract class Transport {
  /// Returns the type of transport.
  TransportType name();

  /// Establishes a connection to the transport.
  ///
  /// Returns a [Future] that completes with a boolean indicating whether the
  /// connection was successful.
  Future<bool> connect();

  /// Disconnects from the transport.
  ///
  /// Returns a [Future] that completes when the disconnection process is done.
  Future<void> disconnect();

  /// Checks if the transport connection is currently open.
  ///
  /// Returns `true` if the connection is open, otherwise `false`.
  bool isOpen();

  /// Sends a message through the transport.
  ///
  /// [message] is the string to be sent.
  void send(String message);

  /// A stream of channel messages received through the transport.
  Stream<ChannelMessage> get stream;
}

/// Enum representing the different types of transport mechanisms.
enum TransportType {
  /// WebSocket transport.
  ws,

  /// Server-Sent Events transport.
  sse,

  /// No transport type specified.
  none,
}

/// Converts a string representation of a transport type to its corresponding
/// [TransportType] enum value.
///
/// If the string does not match any transport type, it defaults to [TransportType.ws].
///
/// [typeString] The string representation of the transport type.
///
/// Returns the corresponding [TransportType].
TransportType transportFromString(String typeString) {
  return TransportType.values.firstWhere(
    (type) => type.toString().split('.').last == typeString,
    orElse: () => TransportType.ws,
  );
}
