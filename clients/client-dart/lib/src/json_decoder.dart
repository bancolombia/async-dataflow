import 'dart:convert';

import 'channel_message.dart';
import 'message_decoder.dart';
import 'utils.dart';

class JsonDecoder extends MessageDecoder<String> {
  @override
  ChannelMessage decode(String event) {
    var eventAsList = jsonDecode('{"received": $event }')['received'];

    return ChannelMessage(
      Utils.checkString(eventAsList[0]),
      Utils.checkString(eventAsList[1]),
      Utils.checkString(eventAsList[2]),
      eventAsList[3],
    );
  }
}
