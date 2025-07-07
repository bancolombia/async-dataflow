import 'transport/transport.dart';

class AsyncConfig {
  final String socketUrl;
  final String channelRef;
  final bool enableBinaryTransport;
  List<TransportType> transports = [TransportType.ws, TransportType.sse];
  int hbInterval = 5000;
  int? maxRetries;
  String? sseUrl;
  String _channelSecret;

  AsyncConfig({
    required this.socketUrl,
    required this.channelRef,
    required String channelSecret,
    this.enableBinaryTransport = false,
    this.maxRetries,
    this.sseUrl,
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
