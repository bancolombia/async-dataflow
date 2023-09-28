import 'dart:async';
import 'dart:io';

import 'package:channel_sender_client/src/channel_message.dart';
import 'package:channel_sender_client/src/transport.dart';
import 'package:logging/logging.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';
import 'package:web_socket_channel/io.dart';

class MockStream extends Mock implements Stream {}

void main() {
  group('Transport Tests', () {
    HttpServer server;

    Logger.root.level = Level.ALL;
    Logger.root.onRecord.listen((record) {
      print(
          '${record.level.name}: (${record.loggerName}) ${record.time}: ${record.message}');
    });

    final log = Logger('TransportTest');

    test('Should send/receive auth and heartbeat', () async {
      server = await HttpServer.bind('localhost', 0);
      addTearDown(server.close);
      server.transform(WebSocketTransformer()).listen((WebSocket webSocket) {
        final channel = IOWebSocketChannel(webSocket);
        channel.stream.listen((request) {
          log.finest('--> server received: $request');
          if (request == 'Auth::SFMy') {
            channel.sink.add('["", "", "AuthOk", ""]');
          } else {
            var parts = request.split('::');
            channel.sink.add('["", "${parts[1]}", ":hb", ""]');
          }
          // channel.sink.close(5678, 'raisin');
        });
      });

      var headers = <String, dynamic>{};
      headers['Connection'] = 'upgrade';
      headers['Upgrade'] = 'websocket';
      headers['sec-websocket-version'] = '13';
      headers['sec-websocket-protocol'] = 'json_flow';
      headers['sec-websocket-key'] = 'x3JJHMbDL1EzLkh9GBhXDw==';

      final webSocket = await WebSocket.connect('ws://localhost:${server.port}',
          protocols: ['json_flow'], headers: headers);
      final channel = IOWebSocketChannel(webSocket);

      late StreamController<ChannelMessage> localStream;

      localStream = StreamController(onListen: () {
        log.finest('OnListen');
      });

      var signalSocketCloseFn = (int code, String reason) {
        log.finest('socket closed');
      };
      var signalSocketErrorFn = (error) {
        log.severe('socket error');
      };

      var transport = Transport(
          channel, localStream, signalSocketCloseFn, signalSocketErrorFn, 1000);

      expect(transport, isNotNull);
      expect(transport.isOpen(), true);
      String? hbCounter;

      localStream.stream.listen((message) {
        log.fine('Received $message');
        if (message.event == 'AuthOk') {
          transport.resetHeartbeat();
        } else if (message.event == ':hb') {
          hbCounter = message.correlationId;
          transport.pendingHeartbeatRef = null;
        }
      }, onError: (error, stacktrace) {
        log.severe(error);
      }, onDone: () {
        log.warning('Subscription for "xxxx" terminated.');
      });

      var sub1 = transport.subscribe(cancelOnErrorFlag: false);

      transport.send('Auth::SFMy');

      await Future.delayed(const Duration(seconds: 3));

      expect(hbCounter, equals('2'));
      await sub1.cancel().then((value) async {
        await webSocket.close();
        await localStream.close();
      });
    });
  });
}
