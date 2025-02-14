import 'transport/transport.dart';

class AsyncConfig {
  final String socketUrl;
  final String channelRef;
  final String channelSecret;
  final bool enableBinaryTransport;
  List<TransportType> transports = [TransportType.ws, TransportType.sse];
  int hbInterval = 5000;
  int? maxRetries;

  AsyncConfig({
    required this.socketUrl,
    required this.channelRef,
    required this.channelSecret,
    this.enableBinaryTransport = false,
    int? heartbeatInterval,
    this.maxRetries,
    List<TransportType>? transportsProvider,
  }) {
    hbInterval = heartbeatInterval ?? hbInterval;
    transports = transportsProvider ?? transports;
  }
}
