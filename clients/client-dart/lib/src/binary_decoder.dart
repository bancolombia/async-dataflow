import 'channel_message.dart';
import 'message_decoder.dart';

class BinaryDecoder extends MessageDecoder<List<int>> {

  @override
  ChannelMessage decode(List<int> event) {
    return ChannelMessage(null, null, null, null);
  }

}