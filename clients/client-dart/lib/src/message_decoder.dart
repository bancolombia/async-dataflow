import 'channel_message.dart';

abstract class MessageDecoder<T> {

  ChannelMessage decode(T event);

}