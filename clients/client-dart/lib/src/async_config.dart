class AsyncConfig {
  final String socketUrl;
  final String channelRef;
  final String channelSecret;
  final bool enableBinaryTransport;
  final int heartbeatInterval;

  AsyncConfig(
      {required this.socketUrl,
      required this.channelRef,
      required this.channelSecret,
      this.enableBinaryTransport = false,
      this.heartbeatInterval = 1000});
}