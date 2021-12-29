import 'dart:async';
import 'dart:io';

import 'package:channel_dart_client/src/channel_message.dart';
import 'package:channel_dart_client/src/transport.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';
import 'package:logging/logging.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'transport_test.mocks.dart';

class MockStream extends Mock implements Stream {}

@GenerateMocks([IOWebSocketChannel, StreamSubscription, WebSocketSink, WebSocket])
void main() {

  var webSocketChannelMock;
  var webSocketMock;
  var webSocketSinkMock;

  setUp(() async {
    webSocketChannelMock = MockIOWebSocketChannel();
    webSocketMock = MockWebSocket();
    webSocketSinkMock = MockWebSocketSink();
  });

  tearDown(() async {
    reset(webSocketChannelMock);
    reset(webSocketMock);
    reset(webSocketSinkMock);
  });

  group('Transport Tests', () {
    
    Logger.root.level = Level.ALL;
    Logger.root.onRecord.listen((record) {
      print('${record.level.name}: ${record.time}: ${record.message}');
    });

    test('Should receive heartbeat', () async {

      var _localStream = StreamController<ChannelMessage>();
      var _simulatedStream = StreamController<ChannelMessage>();

      var _signalSocketCloseFn = (int code, String reason) {
        print('TransportTest: socket closed');
      };
      var _signalSocketErrorFn = (error) {
        print('TransportTest: socket error');
      };

      when(webSocketChannelMock.stream).thenAnswer((realInvocation) => _simulatedStream.stream);
      when(webSocketChannelMock.innerWebSocket).thenAnswer((realInvocation) => webSocketMock);
      when(webSocketMock.readyState).thenAnswer((realInvocation) => 1);
      when(webSocketChannelMock.protocol).thenAnswer((realInvocation) => 'json_flow');

      var transport = Transport(webSocketChannelMock, _localStream, _signalSocketCloseFn, _signalSocketErrorFn, 1000);
      
      expect(transport, isNotNull);
      expect(transport.isOpen(), true);
      expect(transport.getProtocol(), equals('json_flow'));

      var sub1 = transport.subscribe(cancelOnErrorFlag: false);
      sub1.onData((data) {
        expect(data, isNotNull);
        expect(data.message_id, isNull);
        expect(data.correlation_id, equals('2'));
        expect(data.event, equals(':hb'));
        expect(data.payload, isNull);
      });

      _simulatedStream.add(ChannelMessage(null, '2', ':hb', null));

    });

  });
}