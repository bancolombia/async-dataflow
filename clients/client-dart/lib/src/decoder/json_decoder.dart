import 'dart:convert';

import '../model/channel_message.dart';
import '../utils/utils.dart';
import 'message_decoder.dart';

class JsonDecoder extends MessageDecoder<String> {
  @override
  ChannelMessage decode(String event) {
    var eventAsList = jsonDecode('{"received": $event }')['received'];

    return ChannelMessage(
      checkString(eventAsList[0]),
      checkString(eventAsList[1]),
      checkString(eventAsList[2]),
      eventAsList[3],
    );
  }
}
