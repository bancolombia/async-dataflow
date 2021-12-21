import 'channel_message.dart';
import 'message_decoder.dart';
import 'dart:convert';
import 'package:validators/validators.dart';

class JsonDecoder extends MessageDecoder<String> {

  @override
  ChannelMessage decode(String event) {

    var event_as_list = _tokenize(_removeKeys(event));

    var msg = ChannelMessage(event_as_list[0], event_as_list[1], event_as_list[2], null); 
    if (isJSON(event_as_list[3])) {
      msg.payload = jsonDecode(event_as_list[3]);
    } else {
      msg.payload = event_as_list[3];
    }
    
    return msg;
  }

  String _removeKeys(String event) {
    return event.replaceAll(RegExp(r'(^\[)'), '')
      .replaceAll(RegExp(r'(]$)'), '');
  }

  List<String> _tokenize(String event) {
    return event.split(',')
      .map((e) => e.trim())
      .map((e) => e.replaceAll(RegExp(r'["]{2}'), ''))
      .map((e) => e.replaceAll(RegExp(r'^"'), ''))
      .map((e) => e.replaceAll(RegExp(r'"$'), ''))
      .toList();
  }

}