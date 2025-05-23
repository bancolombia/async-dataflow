import 'dart:convert';
import 'dart:typed_data';

import 'package:channel_sender_client/src/decoder/binary_decoder.dart';
import 'package:test/test.dart';

void main() {
  group('Parsing binary data', () {
    test('parses binary message', () {
      final binaryMessage = Uint8List.fromList([
        255,
        11,
        15,
        11,
        109,
        101,
        115,
        115,
        97,
        103,
        101,
        95,
        105,
        100,
        50,
        99,
        111,
        114,
        114,
        101,
        108,
        97,
        116,
        105,
        111,
        110,
        95,
        105,
        100,
        50,
        101,
        118,
        101,
        110,
        116,
        95,
        110,
        97,
        109,
        101,
        50,
        109,
        101,
        115,
        115,
        97,
        103,
        101,
        95,
        100,
        97,
        116,
        97,
        49
      ]);

      final msg = BinaryDecoder().decode(binaryMessage);
      expect(msg, isNotNull);
      expect(msg.messageId, equals('message_id2'));
      expect(msg.correlationId, equals('correlation_id2'));
      expect(msg.event, equals('event_name2'));
      expect(msg.payload, equals('message_data1'));
    });

    test('parses binary message with json payload', () {
      var messageId = 'message_id2';
      var correlationId = 'correlation_id2';
      var event = 'event_name2';
      var payload = '{ "hello": "world" }';

      var dataHeaders = [
        255,
        messageId.length,
        correlationId.length,
        event.length
      ];
      var binaryMessage = dataHeaders +
          utf8.encode(messageId) +
          utf8.encode(correlationId) +
          utf8.encode(event) +
          utf8.encode(payload);

      final msg = BinaryDecoder().decode(Uint8List.fromList(binaryMessage));
      expect(msg, isNotNull);
      expect(msg.messageId, equals('message_id2'));
      expect(msg.correlationId, equals('correlation_id2'));
      expect(msg.event, equals('event_name2'));
      expect(msg.payload, isMap);
    });

    test('parses binary frame for auth ok', () {
      final binaryMessage =
          Uint8List.fromList([255, 0, 0, 6, 65, 117, 116, 104, 79, 107]);
      final msg = BinaryDecoder().decode(binaryMessage);
      expect(msg, isNotNull);
      expect(msg.messageId, equals(null));
      expect(msg.correlationId, equals(null));
      expect(msg.event, equals('AuthOk'));
      expect(msg.payload, isNull);
    });

    test('handle parsing wrong binary message', () {
      expect(() => BinaryDecoder().decode(Uint8List.fromList([115, 97])),
          throwsArgumentError);
    });

    test('handle parsing empty binary message ', () {
      expect(() => BinaryDecoder().decode(Uint8List.fromList([])),
          throwsArgumentError);
    });

    test('handle parsing null binary message ', () {
      expect(() => BinaryDecoder().decode(null), throwsArgumentError);
    });
  });
}
