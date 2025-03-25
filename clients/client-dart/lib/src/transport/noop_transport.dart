import '../model/channel_message.dart';
import 'transport.dart';

class NoopTransport implements Transport {

  @override
  Future<bool> connect() {
    throw UnsupportedError('No transport selected');
  }

  @override
  Future<void> disconnect() {
    throw UnsupportedError('No transport selected');
  }

  @override
  bool isOpen() {
    throw UnsupportedError('No transport selected');
  }

  @override
  TransportType name() {
    throw UnsupportedError('No transport selected');
  }

  @override
  Stream<ChannelMessage> get stream => throw UnsupportedError('No transport selected');

}