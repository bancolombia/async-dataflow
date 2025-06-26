import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:logging/logging.dart';

import '../channel_sender_client.dart';

export 'package:connectivity_plus/connectivity_plus.dart'
    show ConnectivityResult;

/// Re-export types for convenience.
export 'enhanced_async_client.dart'
    show CustomConnectionState, MessageWithState;

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
  late EnhancedAsyncClient _client;
  bool _isObserverAdded = false;

  FlutterAsyncClient(AsyncConfig config) {
    _client = EnhancedAsyncClient(config);
    _addLifecycleObserver();
  }

  /// Add lifecycle observer automatically.
  void _addLifecycleObserver() {
    if (!_isObserverAdded) {
      WidgetsBinding.instance.addObserver(this);
      _isObserverAdded = true;
      _log.info('[flutter-async-client][LifeCycle] Added lifecycle observer');
    }
  }

  /// Remove lifecycle observer.
  void _removeLifecycleObserver() {
    if (_isObserverAdded && WidgetsBinding.instance != null) {
      WidgetsBinding.instance.removeObserver(this);
      _isObserverAdded = false;
      _log.info('[flutter-async-client][LifeCycle] Removed lifecycle observer');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _log.info(
      '[flutter-async-client][LifeCycle] App lifecycle changed to: $state',
    );

    // Convert Flutter's AppLifecycleState to custom enum
    final customState = _convertLifecycleState(state);
    _client.handleAppLifecycleStateChanged(customState);
  }

  /// Convert Flutter's AppLifecycleState to custom enum.
  CustomAppLifecycleState _convertLifecycleState(
    AppLifecycleState state,
  ) {
    switch (state) {
      case AppLifecycleState.resumed:
        return CustomAppLifecycleState.resumed;
      case AppLifecycleState.inactive:
        return CustomAppLifecycleState.inactive;
      case AppLifecycleState.paused:
        return CustomAppLifecycleState.paused;
      case AppLifecycleState.detached:
        return CustomAppLifecycleState.detached;
    }
  }

  /// Connect to the server.
  Future<bool> connect() => _client.connect();

  /// Disconnect from the server.
  Future<bool> disconnect() => _client.disconnect();

  /// Stream of all channel messages.
  Stream<ChannelMessage> get messageStream => _client.messageStream;

  /// Stream of connection state changes.
  Stream<CustomConnectionState> get connectionState => _client.connectionState;

  /// Stream of connectivity changes.
  Stream<ConnectivityResult> get connectivityState => _client.connectivityState;

  /// Stream of messages filtered by event name(s).
  StreamSubscription<ChannelMessage> subscribeToMany(
    List<String> eventFilters,
    Function? onData, {
    Function? onError,
  }) =>
      _client.subscribeToMany(
        eventFilters,
        onData,
        onError: onError,
      );

  /// Stream of messages for a specific event.
  StreamSubscription<ChannelMessage> subscribeTo(
    String eventName,
    Function? onData, {
    Function? onError,
  }) =>
      _client.subscribeTo(
        eventName,
        onData,
        onError: onError,
      );

  /// Stream of messages matching a pattern.
  Stream<ChannelMessage> messagesMatching(String pattern) =>
      _client.messagesMatching(pattern);

  /// Combined stream of messages with connection state.
  Stream<MessageWithState> get messagesWithConnectionState =>
      _client.messagesWithConnectionState;

  /// Stream that emits when disconnected.
  Stream<void> get onDisconnected => _client.onDisconnected;

  /// Check if currently connected.
  bool get isConnected => _client.isConnected;

  /// Check if currently connecting.
  bool get isConnecting => _client.isConnecting;

  /// Get current connection state.
  CustomConnectionState get currentConnectionState =>
      _client.currentConnectionState;

  /// Get current transport type.
  String get currentTransportType => _client.currentTransportType;

  /// Switch to different transport protocol.
  Future<bool> switchProtocols() => _client.switchProtocols();

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
