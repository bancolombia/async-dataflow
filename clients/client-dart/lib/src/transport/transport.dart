import '../../channel_sender_client.dart';

abstract class Transport {
  TransportType name();
  Future<bool> connect();
  Future<void> disconnect();
  bool isOpen();
  Stream<ChannelMessage> get stream;
}

enum TransportType {
  ws,
  sse,
  none,
}

TransportType transportFromString(String typeString) {
  return TransportType.values.firstWhere(
    (type) => type.toString().split('.').last == typeString,
    orElse: () => TransportType.ws,
  );
}
