import 'dart:convert';
import 'dart:typed_data';

import 'package:validators/validators.dart';

import '../model/channel_message.dart';
import 'message_decoder.dart';

class BinaryDecoder extends MessageDecoder<Uint8List> {
  final int controlByte = 255;

  final Utf8Decoder _decoder = const Utf8Decoder(allowMalformed: false);
  final int _offset = 4;

  @override
  ChannelMessage decode(Uint8List? event) {
    if (event == null || event.isEmpty) {
      throw ArgumentError('Invalid binary data; empty list');
    }

    if (event.firstOrNull != controlByte) {
      throw ArgumentError('Invalid binary data; no control byte match');
    }

    var msgIdSize = event[1];
    var corrIdSize = event[2];
    var evtNameSize = event[3];

    var messageId = _extract(event, 0, msgIdSize);
    var correlationId = _extract(event, msgIdSize, corrIdSize);
    var eventData = _extract(event, msgIdSize + corrIdSize, evtNameSize);
    var payload = _extract(event, msgIdSize + corrIdSize + evtNameSize, null);

    return ChannelMessage(
      _checkString(messageId),
      _checkString(correlationId),
      _checkString(eventData),
      _formatPayload(payload),
    );
  }

  String _extract(Uint8List data, int start, int? size) {
    var start0 = _offset + start;
    if (size == null) {
      return _decoder.convert(data, start0);
    } else {
      var size0 = start0 + size;

      return _decoder.convert(data, start0, size0);
    }
  }

  String? _checkString(String? data) {
    if (data == null) {
      return data;
    }
    var trim = data.trim();

    return trim.isEmpty ? null : data.trim();
  }

  Object? _formatPayload(String payload) {
    // check if payload is json
    if (payload.isNotEmpty) {
      return isJSON(payload) ? jsonDecode(payload) : payload;
    }

    return null;
  }
}
