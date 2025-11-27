import 'async_client_event_handler.dart';
import 'transport/transport.dart';

/// Represents the configuration for an asynchronous client connection.
///
/// This class holds various settings required to establish a connection
/// to a server using different transport methods. It includes parameters
/// such as the socket URL, channel reference, and options for binary
/// transport. Additionally, it allows for event handling and specifies
/// the heartbeat interval and retry settings.
///
/// Properties:
/// - [socketUrl]: The URL of the socket server.
/// - [channelRef]: A reference identifier for the channel.
/// - [enableBinaryTransport]: A flag indicating whether binary transport is enabled.
/// - [eventHandler]: An optional event handler for managing client events.
///   ```dart
///   class EventHandler implements AsyncClientEventHandler {
///     @override
///     void onEvent(AsyncClientEvent event) {
///       print(
///       'Event received: ${event.message}, Transport: ${event.transportType}, Channel: ${event.channelRef}',
///       );
///     }
///   }
///   ```
/// - [transports]: A list of transport types to be used (default is WebSocket and SSE).
/// - [hbInterval]: The interval for heartbeat messages in milliseconds (default is 5000).
/// - [maxRetries]: The maximum number of retry attempts for connection (optional).
/// - [sseUrl]: The URL for Server-Sent Events (optional).
/// - [maxCacheSize]: The maximum size of the deduplication cache (default is 50).
/// - [dedupCacheDisable]: A flag to disable the deduplication cache (default is false).
class AsyncConfig {
  final String socketUrl;
  final String channelRef;
  final bool enableBinaryTransport;
  final AsyncClientEventHandler? eventHandler;
  List<TransportType> transports = [TransportType.ws, TransportType.sse];
  int hbInterval = 5000;
  int? maxRetries;
  String? sseUrl;
  int maxCacheSize;
  bool dedupCacheDisable;
  String _channelSecret;

  AsyncConfig({
    required this.socketUrl,
    required this.channelRef,
    required String channelSecret,
    this.enableBinaryTransport = false,
    this.maxRetries,
    this.sseUrl,
    this.eventHandler,
    this.maxCacheSize = 50,
    this.dedupCacheDisable = false,
    int? heartbeatInterval,
    List<TransportType>? transportsProvider,
  }) : _channelSecret = channelSecret {
    hbInterval = heartbeatInterval ?? hbInterval;
    transports = transportsProvider ?? transports;
  }

  String get channelSecret => _channelSecret;

  set channelSecret(String value) {
    _channelSecret = value;
  }
}
