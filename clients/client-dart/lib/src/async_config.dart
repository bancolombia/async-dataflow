class AsyncConfig {
  final String socketUrl;
  final String channelRef;
  final String channelSecret;
  final bool enableBinaryTransport;
  int hbInterval = 5000;
  int? maxRetries;

  AsyncConfig({
    required this.socketUrl,
    required this.channelRef,
    required this.channelSecret,
    this.enableBinaryTransport = false,
    int? heartbeatInterval,
    this.maxRetries,
  }) {
    hbInterval = heartbeatInterval ?? hbInterval;
  }
}
