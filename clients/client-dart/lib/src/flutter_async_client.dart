import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:logging/logging.dart';

import 'async_config.dart';
import 'enhanced_async_client.dart' as enhanced_async_client;
import 'model/channel_message.dart';

export 'package:connectivity_plus/connectivity_plus.dart'
    show ConnectivityResult;

/// Re-export types for convenience.
export 'enhanced_async_client.dart' show ConnectionState, MessageWithState;

/// Flutter-specific wrapper for EnhancedAsyncClient
///
/// This class provides:
/// - Automatic Flutter lifecycle integration
/// - Widget-friendly stream management
/// - Proper resource cleanup
///
/// Usage in a Flutter app:
/// ```dart
/// class MyApp extends StatefulWidget {
///   @override
///   _MyAppState createState() => _MyAppState();
/// }
///
/// class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
///   late FlutterAsyncClient _client;
///
///   @override
///   void initState() {
///     super.initState();
///     WidgetsBinding.instance.addObserver(this);
///
///     _client = FlutterAsyncClient(config);
///     _client.connect();
///   }
///
///   @override
///   void dispose() {
///     WidgetsBinding.instance.removeObserver(this);
///     _client.dispose();
///     super.dispose();
///   }
///
///   @override
///   void didChangeAppLifecycleState(AppLifecycleState state) {
///     _client.handleAppLifecycleChange(state);
///   }
/// }
/// ```
class FlutterAsyncClient with WidgetsBindingObserver {
  final _log = Logger('FlutterAsyncClient');
  late enhanced_async_client.EnhancedAsyncClient _client;
  bool _isObserverAdded = false;

  FlutterAsyncClient(AsyncConfig config) {
    _client = enhanced_async_client.EnhancedAsyncClient(config);
    _addLifecycleObserver();
  }

  /// Add lifecycle observer automatically.
  void _addLifecycleObserver() {
    if (!_isObserverAdded) {
      WidgetsBinding.instance.addObserver(this);
      _isObserverAdded = true;
      _log.info('Added lifecycle observer');
    }
  }

  /// Remove lifecycle observer.
  void _removeLifecycleObserver() {
    if (_isObserverAdded && WidgetsBinding.instance != null) {
      WidgetsBinding.instance.removeObserver(this);
      _isObserverAdded = false;
      _log.info('Removed lifecycle observer');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _log.info('App lifecycle changed to: $state');

    // Convert Flutter's AppLifecycleState to our custom enum
    final customState = _convertLifecycleState(state);
    _client.handleAppLifecycleStateChanged(customState);
  }

  /// Convert Flutter's AppLifecycleState to our custom enum.
  enhanced_async_client.AppLifecycleState _convertLifecycleState(
    AppLifecycleState state,
  ) {
    switch (state) {
      case AppLifecycleState.resumed:
        return enhanced_async_client.AppLifecycleState.resumed;
      case AppLifecycleState.inactive:
        return enhanced_async_client.AppLifecycleState.inactive;
      case AppLifecycleState.paused:
        return enhanced_async_client.AppLifecycleState.paused;
      case AppLifecycleState.detached:
        return enhanced_async_client.AppLifecycleState.detached;
      // case AppLifecycleState.hidden:
      //   return enhanced_async_client.AppLifecycleState.hidden;
    }
  }

  // Delegate all methods to the enhanced client

  /// Connect to the server.
  Future<bool> connect() => _client.connect();

  /// Disconnect from the server.
  Future<bool> disconnect() => _client.disconnect();

  /// Stream of all channel messages.
  Stream<ChannelMessage> get messageStream => _client.messageStream;

  /// Stream of connection state changes.
  Stream<enhanced_async_client.ConnectionState> get connectionState =>
      _client.connectionState;

  /// Stream of connectivity changes.
  Stream<ConnectivityResult> get connectivityState => _client.connectivityState;

  /// Stream of messages filtered by event name(s).
  Stream<ChannelMessage> messagesWhere(List<String> eventFilters) =>
      _client.messagesWhere(eventFilters);

  /// Stream of messages for a specific event.
  Stream<ChannelMessage> messagesFor(String eventName) =>
      _client.messagesFor(eventName);

  /// Stream of messages matching a pattern.
  Stream<ChannelMessage> messagesMatching(String pattern) =>
      _client.messagesMatching(pattern);

  /// Combined stream of messages with connection state.
  Stream<enhanced_async_client.MessageWithState>
      get messagesWithConnectionState => _client.messagesWithConnectionState;

  /// Stream that emits when connected and ready.
  Stream<void> get onReady => _client.onReady;

  /// Stream that emits when disconnected.
  Stream<void> get onDisconnected => _client.onDisconnected;

  /// Check if currently connected.
  bool get isConnected => _client.isConnected;

  /// Check if currently connecting.
  bool get isConnecting => _client.isConnecting;

  /// Get current connection state.
  enhanced_async_client.ConnectionState get currentConnectionState =>
      _client.currentConnectionState;

  /// Get current transport type.
  String get currentTransportType => _client.currentTransportType;

  /// Switch to different transport protocol.
  Future<bool> switchTransport() => _client.switchTransport();

  /// Handle app lifecycle change manually (usually not needed).
  void handleAppLifecycleChange(AppLifecycleState state) {
    didChangeAppLifecycleState(state);
  }

  /// Dispose resources.
  Future<void> dispose() async {
    _removeLifecycleObserver();
    await _client.dispose();
  }
}
