import 'dart:convert';
import 'dart:typed_data';

import 'package:validators/validators.dart';

import 'channel_message.dart';
import 'message_decoder.dart';

class BinaryDecoder extends MessageDecoder<Uint8List> {

  final Utf8Decoder _decoder = Utf8Decoder(allowMalformed: false);
  final int _offset = 4;

  @override
  ChannelMessage decode(Uint8List eventData) {

    if (eventData == null || eventData.isEmpty) {
      throw ArgumentError('Invalid binary data; empty list');
    }

    if (eventData.first != 255) {
      throw ArgumentError('Invalid binary data; no control byte match');
    }

    var msgIdSize = eventData[1];
    var corrIdSize = eventData[2];
    var evtNameSize = eventData[3];

    var messageId = _extract(eventData, 0, msgIdSize);
    var correlationId = _extract(eventData, msgIdSize, corrIdSize);
    var event = _extract(eventData, msgIdSize + corrIdSize, evtNameSize);
    var payload = _extract(eventData, msgIdSize + corrIdSize + evtNameSize, null);

    return ChannelMessage(
      _checkString(messageId), 
      _checkString(correlationId),
      _checkString(event),
      _formatPayload(payload)
    );
  }

  String _extract(Uint8List data, int start, int size) {
    var _start =  _offset + start;
    if (size == null) {
      return _decoder.convert(data, _start);
    } else {
      var _size = _start + size;
      return _decoder.convert(data, _start, _size);
    }
  }

  String _checkString(String data) {
    if (data == null) {
      return data;
    } else if (data.trim().isEmpty) {
      return null;
    } else {
      return data.trim();
    }
  }

  dynamic _formatPayload(String payload) {
    // check if payload is json
    if (payload != null && payload.isNotEmpty) {
      if (isJSON(payload)) {
        return jsonDecode(payload);
      } else {
        return payload;
      }
    }
  }

}