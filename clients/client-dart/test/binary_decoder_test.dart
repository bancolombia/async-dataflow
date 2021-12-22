import 'dart:convert';
import 'dart:typed_data';

import 'package:test/test.dart';

import 'package:channel_dart_client/src/binary_decoder.dart';

void main() {
    group('Parsing binary data', () {
      test('parses binary message', () {
        final binary_message = Uint8List.fromList([255, 11, 15, 11, 109, 101, 115, 115, 97, 103, 101, 95, 105, 100, 50, 99, 111,
          114, 114, 101, 108, 97, 116, 105, 111, 110, 95, 105, 100, 50, 101, 118, 101,
          110, 116, 95, 110, 97, 109, 101, 50, 109, 101, 115, 115, 97, 103, 101, 95,
          100, 97, 116, 97, 49]);

        final msg = BinaryDecoder().decode(binary_message);
        expect(msg, isNotNull);
        expect(msg.message_id, equals('message_id2'));
        expect(msg.correlation_id, equals('correlation_id2'));
        expect(msg.event, equals('event_name2'));
        expect(msg.payload, equals('message_data1'));
      });

      test('parses binary message and json payload', () {
        var message_id = 'message_id2';
        var correlation_id = 'correlation_id2';
        var event = 'event_name2';
        var payload = '{ "hello": "world" }';

        var dataHeaders = [255, message_id.length, correlation_id.length, event.length];
        var binary_message = dataHeaders + utf8.encode(message_id) + utf8.encode(correlation_id) + utf8.encode(event)
          + utf8.encode(payload);

        final msg = BinaryDecoder().decode(Uint8List.fromList(binary_message));
        expect(msg, isNotNull);
        expect(msg.message_id, equals('message_id2'));
        expect(msg.correlation_id, equals('correlation_id2'));
        expect(msg.event, equals('event_name2'));
        expect(msg.payload, isMap);
      });

      test('handle failure parsing binary message', () {
        expect(() => BinaryDecoder().decode(Uint8List.fromList([115, 97])), throwsArgumentError);
      });

      test('handle failure parsing binary message', () {
        expect(() => BinaryDecoder().decode(Uint8List.fromList([115, 97])), throwsArgumentError);
      });

      test('parses binary frame for auth ok', () {
        final binary_message = Uint8List.fromList([255, 0, 0, 6, 65, 117, 116, 104, 79, 107]);
        final msg = BinaryDecoder().decode(binary_message);
        expect(msg, isNotNull);
        expect(msg.message_id, equals(''));
        expect(msg.correlation_id, equals(''));
        expect(msg.event, equals('AuthOk'));
        expect(msg.payload, equals(''));
      });

  });

}