import '../model/channel_message.dart';
import 'transport.dart';

class NoopTransport implements Transport {

  @override
  Future<bool> connect() {
    return Future.value(false);
  }

  @override
  Future<void> disconnect() {
    return Future.value(null);
  }

  @override
  bool isOpen() {
    return false;
  }

  @override
  TransportType name() {
    return TransportType.none;
  }

  @override
  Stream<ChannelMessage> get stream => Stream.empty();

}