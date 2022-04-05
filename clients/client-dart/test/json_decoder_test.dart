import 'package:test/test.dart';

import 'package:channel_sender_client/src/json_decoder.dart';

void main() {
  group('Json decoding', () {
    test('should parse authOk event', () {
      final trama = '["", "", "AuthOk", ""]';

      final msg = JsonDecoder().decode(trama);
      expect(msg, isNotNull);
      expect(msg.messageId, equals(''));
      expect(msg.event, equals('AuthOk'));
      expect(msg.correlationId, equals(''));
      expect(msg.payload, equals(''));
    });

    test('should parse heartbeat event', () {
      final trama = '["", "1", ":hb", ""]';

      final msg = JsonDecoder().decode(trama);
      expect(msg, isNotNull);
      expect(msg.messageId, equals(''));
      expect(msg.event, equals(':hb'));
      expect(msg.correlationId, equals('1'));
      expect(msg.payload, equals(''));
    });

    test('should parse user event with json content', () {
      final trama =
          '["msg-id-0001","correlation-id-002","event.productCreated","{\\"code\\":\\"100\\", \\"title\\":\\"process after 5000ms\\", \\"detail\\":\\"some detail 89bd02d1da483efaa5389cbd4ca65bbd\\", \\"level\\":\\"info\\"}"]';

      final msg = JsonDecoder().decode(trama);

      expect(msg, isNotNull);
      expect(msg.messageId, equals('msg-id-0001'));
      expect(msg.correlationId, equals('correlation-id-002'));
      expect(msg.event, equals('event.productCreated'));
      expect(msg.payload, isMap);
      expect(msg.payload['code'], equals('100'));
      expect(msg.payload['title'], equals('process after 5000ms'));
      expect(msg.payload['detail'], equals('some detail 89bd02d1da483efaa5389cbd4ca65bbd'));
      expect(msg.payload['level'], equals('info'));
    });

    test('should parse user event with no json content', () {

      final trama =
          '["msg-id-0003","correlation-id-004","event.productCreated","Hello World"]';

      final msg = JsonDecoder().decode(trama);

      expect(msg, isNotNull);
      expect(msg.messageId, equals('msg-id-0003'));
      expect(msg.correlationId, equals('correlation-id-004'));
      expect(msg.event, equals('event.productCreated'));
      expect(msg.payload, equals('Hello World'));
    });

    test('should parse user event with no payload', () {

      final trama =
          '["msg-id-0003","correlation-id-004","event.productCreated",""]';

      final msg = JsonDecoder().decode(trama);

      expect(msg, isNotNull);
      expect(msg.messageId, equals('msg-id-0003'));
      expect(msg.correlationId, equals('correlation-id-004'));
      expect(msg.event, equals('event.productCreated'));
      expect(msg.payload, equals(''));
    });

    test('should parse user event with weird payload', () {

      final trama =
          '["msg-id-0003","correlation-id-004","event.productCreated",".,.,.,%%#@"]';

      final msg = JsonDecoder().decode(trama);

      expect(msg, isNotNull);
      expect(msg.messageId, equals('msg-id-0003'));
      expect(msg.correlationId, equals('correlation-id-004'));
      expect(msg.event, equals('event.productCreated'));
      expect(msg.payload, equals('.,.,.,%%#@'));
    });

  });

  

}
