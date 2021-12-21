import 'package:test/test.dart';

import 'package:channel_dart_client/src/json_decoder.dart';

void main() {
    group('Parsing json', () {
      test('parses json', () {
        final json_string = '''
        { "message_id": "001", "event": "foo.event", "correlation_id": "bar", "payload": { "hello": "world" } }
        ''';
        final msg = JsonDecoder().decode(json_string);
        expect(msg, isNotNull);
        expect(msg.message_id, equals('001'));
        expect(msg.event, equals('foo.event'));
        expect(msg.correlation_id, equals('bar'));
        expect(msg.payload, isMap);
      });


      test('fails to parse json', () {
        final json_string = '''
        { "hello": "world" }
        ''';
        final msg = JsonDecoder().decode(json_string);
        expect(msg, isNull);
      });
  });

}