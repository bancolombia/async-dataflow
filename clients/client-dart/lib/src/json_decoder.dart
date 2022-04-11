import 'dart:convert';
import 'channel_message.dart';
import 'message_decoder.dart';
import 'utils.dart';

class JsonDecoder extends MessageDecoder<String> {

  @override
  ChannelMessage decode(String event) {
    
    var event_as_list = jsonDecode('{"received": $event }')['received'];

    return ChannelMessage(Utils.checkString(event_as_list[0]), 
      Utils.checkString(event_as_list[1]),
      Utils.checkString(event_as_list[2]),
      event_as_list[3]
    );
  }

}

