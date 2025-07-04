import 'dart:async';

import 'package:channel_sender_client/src/async_client_conf.dart';
import 'package:channel_sender_client/src/async_config.dart';
import 'package:channel_sender_client/src/model/channel_message.dart';
import 'package:channel_sender_client/src/transport/transport.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AsyncClientConf Tests', () {
    late AsyncConfig config;
    late AsyncClientConf client;

    Logger.root.level = Level.ALL;
    Logger.root.onRecord.listen((record) {
      // ignore: avoid_print
      print(
        '${record.level.name}: (${record.loggerName}) ${record.time}: ${record.message}',
      );
    });

    setUp(() {
      config = AsyncConfig(
        socketUrl: 'ws://localhost:8080',
        channelRef: 'test-channel',
        channelSecret: 'test-secret',
        enableBinaryTransport: false,
        transportsProvider: [TransportType.ws],
        heartbeatInterval: 1000,
        maxRetries: 3,
      );
    });

    tearDown(() async {
      if (client != null) {
        await client.dispose();
      }
    });

    test('should initialize with correct config', () {
      client = AsyncClientConf(config);

      expect(client.isConnected, false);
      expect(client.isConnecting, false);
      expect(client.currentConnectionState, CustomConnectionState.disconnected);
    });

    test('should handle connection state changes', () async {
      client = AsyncClientConf(config);

      final states = <CustomConnectionState>[];
      final subscription = client.connectionState.listen(states.add);

      // Wait for initial state
      await Future.delayed(
        const Duration(milliseconds: 100),
      );

      // Initial state should be disconnected
      expect(states.isNotEmpty, true);
      expect(states.first, CustomConnectionState.disconnected);

      await subscription.cancel();
    });

    test('should handle app lifecycle state changes', () {
      client = AsyncClientConf(config);

      // Test different lifecycle states
      client.handleAppLifecycleStateChanged(CustomAppLifecycleState.paused);
      client.handleAppLifecycleStateChanged(CustomAppLifecycleState.resumed);
      client.handleAppLifecycleStateChanged(CustomAppLifecycleState.detached);

      // Should not throw errors
      expect(client.currentConnectionState, CustomConnectionState.disconnected);
    });

    test('should validate event filters in subscribeToMany', () {
      client = AsyncClientConf(config);

      // Test with null/empty filters
      expect(
        () => client.subscribeToMany(null, null),
        throwsArgumentError,
      );

      expect(
        () => client.subscribeToMany([], null),
        throwsArgumentError,
      );

      expect(
        () => client.subscribeToMany([''], null),
        throwsArgumentError,
      );

      expect(
        () => client.subscribeToMany(['  '], null),
        throwsArgumentError,
      );
    });

    test('should validate event name in subscribeTo', () {
      client = AsyncClientConf(config);

      // Test with empty event name
      expect(
        () => client.subscribeTo('', null),
        throwsArgumentError,
      );

      expect(
        () => client.subscribeTo('  ', null),
        throwsArgumentError,
      );
    });

    test('should create valid regex patterns for messagesMatching', () {
      client = AsyncClientConf(config);

      final stream = client.messagesMatching('event.*');
      expect(stream, isA<Stream<ChannelMessage>>());

      final wildcardStream = client.messagesMatching('user.*.created');
      expect(wildcardStream, isA<Stream<ChannelMessage>>());
    });

    test('should provide current transport information', () {
      client = AsyncClientConf(config);

      expect(client.currentTransportType, isA<String>());
      expect(client.currentTransport, isA<Transport>());
    });

    test('should handle connectivity state stream', () async {
      client = AsyncClientConf(config);

      final connectivityStates = <ConnectivityResult>[];
      final subscription =
          client.connectivityState.listen(connectivityStates.add);

      // Wait for initial state
      await Future.delayed(
        const Duration(milliseconds: 100),
      );

      // Should have initial state
      expect(connectivityStates.isNotEmpty, true);

      await subscription.cancel();
    });

    test('should provide onDisconnected stream', () async {
      client = AsyncClientConf(config);

      final disconnectEvents = <void>[];
      final subscription = client.onDisconnected.listen(disconnectEvents.add);

      // Initially should be disconnected
      await Future.delayed(
        const Duration(milliseconds: 100),
      );
      expect(disconnectEvents.isNotEmpty, true);

      await subscription.cancel();
    });

    test('should provide messagesWithConnectionState stream', () async {
      client = AsyncClientConf(config);

      final messagesWithState = <MessageWithState>[];
      final subscription = client.messagesWithConnectionState.take(1).listen(
            messagesWithState.add,
            onError: (e) {}, // Ignore errors for this test
          );

      // Stream should be available
      expect(
          client.messagesWithConnectionState, isA<Stream<MessageWithState>>());

      await subscription.cancel();
    });

    test('should handle manual disconnect', () async {
      client = AsyncClientConf(config);

      final result = await client.disconnect();
      expect(result, true);
      expect(client.currentConnectionState, CustomConnectionState.disconnected);
    });

    test('should handle dispose correctly', () async {
      client = AsyncClientConf(config);

      await client.dispose();

      // After dispose, should be in disconnected state
      expect(client.currentConnectionState, CustomConnectionState.disconnected);
    });

    test('MessageWithState should store message and state', () {
      final message = ChannelMessage(
        '1',
        '2',
        'test.event',
        'test data',
      );

      final messageWithState = MessageWithState(
        message,
        CustomConnectionState.connected,
      );

      expect(messageWithState.message, equals(message));
      expect(messageWithState.connectionState, CustomConnectionState.connected);
    });

    test('should handle connection state enum values', () {
      expect(CustomConnectionState.values.length, 4);
      expect(CustomConnectionState.values,
          contains(CustomConnectionState.disconnected));
      expect(CustomConnectionState.values,
          contains(CustomConnectionState.connecting));
      expect(CustomConnectionState.values,
          contains(CustomConnectionState.connected));
      expect(CustomConnectionState.values,
          contains(CustomConnectionState.disconnecting));
    });

    test('should handle app lifecycle state enum values', () {
      expect(CustomAppLifecycleState.values.length, 5);
      expect(CustomAppLifecycleState.values,
          contains(CustomAppLifecycleState.resumed));
      expect(CustomAppLifecycleState.values,
          contains(CustomAppLifecycleState.inactive));
      expect(CustomAppLifecycleState.values,
          contains(CustomAppLifecycleState.paused));
      expect(CustomAppLifecycleState.values,
          contains(CustomAppLifecycleState.detached));
      expect(CustomAppLifecycleState.values,
          contains(CustomAppLifecycleState.hidden));
    });

    test('should handle protocol switching', () async {
      client = AsyncClientConf(config);

      final result = await client.switchProtocols();
      expect(
          result, false); // Should return false when no alternative transport
    });
  });
}
