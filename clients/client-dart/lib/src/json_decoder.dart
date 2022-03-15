import 'dart:convert';
import 'package:validators/validators.dart';
import 'channel_message.dart';
import 'message_decoder.dart';
import 'utils.dart';
class JsonDecoder extends MessageDecoder<String> {

  @override
  ChannelMessage decode(String event) {

    var event_as_list = _tokenize(_removeKeys(event));
    
    var msg = ChannelMessage(Utils.checkString(event_as_list[0]), 
      Utils.checkString(event_as_list[1]),
      Utils.checkString(event_as_list[2]),
      null);
    
    var data = Utils.checkString(event_as_list[3]);

    if (data != null) {
      if (isJSON(data)) {
        msg.payload = jsonDecode(data);
      } else {
        msg.payload = data;
      }
    }

    return msg;
  }

  String _removeKeys(String event) {
    return event.replaceAll(RegExp(r'(^\[)'), '')
      .replaceAll(RegExp(r'(]$)'), '');
  }

  List<String> _tokenize(String event) {
    return event.split(RegExp(r',(?=(?:[^\"]*\"[^\"]*\")*[^\"]*$)'))
      .map((e) => e.trim())
      .map((e) => e.replaceAll(RegExp(r'["]{2}'), ''))
      .map((e) => e.replaceAll(RegExp(r'^"'), ''))
      .map((e) => e.replaceAll(RegExp(r'"$'), ''))
      .toList();
  }

}