import 'package:channel_sender_client/channel_sender_client.dart';
import 'package:channel_sender_client/src/transport/default_transport_strategy.dart';
import 'package:channel_sender_client/src/transport/transport.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class MockWSTransport extends Mock implements Transport {}
class MockSSETransport extends Mock implements Transport {}

void main() {
  late MockWSTransport mockWSTransport;
  late MockSSETransport mockSSETransport;

  setUp(() async {
    mockWSTransport = MockWSTransport();
    mockSSETransport = MockSSETransport();
  });

  group('Default Transport Strategy Tests', () {
    
    test('Handle strategy initialization with no transports', () async {

      var onTransportClose = (int code, String reason) {
        print('socket closed');
      };
      var onTransportError = (error) {
        print('socket error');
      };

      AsyncConfig config = AsyncConfig(
        socketUrl: 'ws://localhost:8787',
        channelRef: 'channelRef',
        channelSecret: 'channelSecret',
        heartbeatInterval: 1000,
        transportsProvider: [],);

      expect(() => DefaultTransportStrategy(config, 
        onTransportClose, 
        onTransportError,), 
        throwsA(isA<Exception>()),
      );
      
    });

    test('Handle strategy initialization with one transport ws', () async {

      when(() => mockWSTransport.name())
          .thenAnswer((_) => TransportType.ws);
      when(() => mockWSTransport.connect())
          .thenAnswer((_) => Future.value(true));

      var onTransportClose = (int code, String reason) {
        print('socket closed');
      };
      var onTransportError = (error) {
        print('socket error');
      };

      AsyncConfig config = AsyncConfig(
        socketUrl: 'ws://localhost:8686',
        channelRef: 'channelRef',
        channelSecret: 'channelSecret',
        heartbeatInterval: 1000,
        transportsProvider: [TransportType.ws],);

      DefaultTransportStrategy transportStrategy =  DefaultTransportStrategy.custom(config, 
        onTransportClose, 
        onTransportError,
        {
          TransportType.ws: () => mockWSTransport,
        },);
      
      expect(transportStrategy, isNotNull);
      expect(transportStrategy.getTransport(), isNotNull);
      expect(transportStrategy.getTransport().name(), TransportType.ws);
      
      expect(await transportStrategy.connect(), true);

    });

    test('Handle strategy transport switching', () async {

      when(() => mockWSTransport.name())
          .thenAnswer((_) => TransportType.ws);
      when(() => mockWSTransport.connect())
          .thenAnswer((_) => Future.value(true));
      when(() => mockWSTransport.disconnect())
          .thenAnswer((_) => Future.value());


      when(() => mockSSETransport.name())
          .thenAnswer((_) => TransportType.sse);
      when(() => mockSSETransport.connect())
          .thenAnswer((_) => Future.value(true));

      var onTransportClose = (int code, String reason) {
        print('socket closed');
      };
      var onTransportError = (error) {
        print('socket error');
      };

      AsyncConfig config = AsyncConfig(
        socketUrl: 'ws://localhost:8686',
        channelRef: 'channelRef',
        channelSecret: 'channelSecret',
        heartbeatInterval: 1000,
        transportsProvider: [TransportType.ws, TransportType.sse],);

      DefaultTransportStrategy transportStrategy =  DefaultTransportStrategy.custom(config, 
        onTransportClose, 
        onTransportError,
        {
          TransportType.ws: () => mockWSTransport,
          TransportType.sse: () => mockSSETransport,
        },);
           
      expect(await transportStrategy.connect(), true);
      expect(transportStrategy.getTransport().name(), TransportType.ws);

      // iterate
      expect(await transportStrategy.iterateTransport(), TransportType.sse);
      expect(transportStrategy.getTransport().name(), TransportType.sse);
      expect(await transportStrategy.connect(), true);

      // assert calls to mocks
      verify(() => mockWSTransport.disconnect()).called(1);
      verify(() => mockSSETransport.connect()).called(1);

    });

    test('Handle strategy transport switching with only 1 transport', () async {

      when(() => mockWSTransport.name())
          .thenAnswer((_) => TransportType.ws);
      when(() => mockWSTransport.connect())
          .thenAnswer((_) => Future.value(true));

      var onTransportClose = (int code, String reason) {
        print('socket closed');
      };
      var onTransportError = (error) {
        print('socket error');
      };

      AsyncConfig config = AsyncConfig(
        socketUrl: 'ws://localhost:8686',
        channelRef: 'channelRef',
        channelSecret: 'channelSecret',
        heartbeatInterval: 1000,
        transportsProvider: [TransportType.ws],);

      DefaultTransportStrategy transportStrategy =  DefaultTransportStrategy.custom(config, 
        onTransportClose, 
        onTransportError,
        {
          TransportType.ws: () => mockWSTransport,
        },);
           
      expect(await transportStrategy.connect(), true);
      expect(transportStrategy.getTransport().name(), TransportType.ws);

      // iterate
      expect(await transportStrategy.iterateTransport(), TransportType.ws);
      expect(transportStrategy.getTransport().name(), TransportType.ws);
      expect(await transportStrategy.connect(), true);

      // assert mocks not called
      verifyNever(() => mockWSTransport.disconnect()).called(0);

    });

    test('Handle retry connection on transport fail to connect', () async {

      when(() => mockWSTransport.name())
          .thenAnswer((_) => TransportType.ws);
      when(() => mockWSTransport.connect())
          .thenAnswer((_) => Future.value(false));

      var onTransportClose = (int code, String reason) {
        print('socket closed');
      };
      var onTransportError = (error) {
        print('socket error');
      };

      AsyncConfig config = AsyncConfig(
        socketUrl: 'ws://localhost:8686',
        channelRef: 'channelRef',
        channelSecret: 'channelSecret',
        heartbeatInterval: 1000,
        maxRetries: 2,
        transportsProvider: [TransportType.ws],);

      DefaultTransportStrategy transportStrategy =  DefaultTransportStrategy.custom(config, 
        onTransportClose, 
        onTransportError,
        {
          TransportType.ws: () => mockWSTransport,
        },);
           
      expect(await transportStrategy.connect(), false);

      // assert mocks called
      verify(() => mockWSTransport.connect()).called(3);

    });

  }); 
}
