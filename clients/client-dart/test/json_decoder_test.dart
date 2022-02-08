import 'package:test/test.dart';

import 'package:channel_dart_client/src/json_decoder.dart';

void main() {
  group('Json decoding', () {
    test('should parse authOk event', () {
      final trama = '["", "", "AuthOk", ""]';

      final msg = JsonDecoder().decode(trama);
      expect(msg, isNotNull);
      expect(msg.messageId, isNull);
      expect(msg.event, equals('AuthOk'));
      expect(msg.correlationId, isNull);
      expect(msg.payload, isNull);
    });

    test('should parse heartbeat event', () {
      final trama = '["", "1", ":hb", ""]';

      final msg = JsonDecoder().decode(trama);
      expect(msg, isNotNull);
      expect(msg.messageId, isNull);
      expect(msg.event, equals(':hb'));
      expect(msg.correlationId, equals('1'));
      expect(msg.payload, isNull);
    });

    test('should parse user event', () {
      // final json_string = '''
      // { "message_id": "001", "event": "foo.event", "correlation_id": "bar", "payload": { "hello": "world" } }
      // ''';

      final trama =
          '["001", "002", "foo.event", "{\"body\": \"Hello World\"}"]';

      final msg = JsonDecoder().decode(trama);
      expect(msg, isNotNull);
      expect(msg.messageId, equals('001'));
      expect(msg.event, equals('foo.event'));
      expect(msg.correlationId, equals('002'));
      expect(msg.payload, isMap);
    });
  });
}
