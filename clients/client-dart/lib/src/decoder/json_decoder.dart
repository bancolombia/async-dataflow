import 'dart:convert';

import '../model/channel_message.dart';
import '../utils/utils.dart';
import 'message_decoder.dart';

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
