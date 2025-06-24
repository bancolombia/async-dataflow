import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:logging/logging.dart';
import 'package:rxdart/rxdart.dart';

import 'async_config.dart';
import 'model/channel_message.dart';
import 'transport/default_transport_strategy.dart';

/// Enhanced Async Data Flow Client with reactive patterns,
/// connectivity awareness, and background handling
///
/// This client provides:
/// - Stream-based API for reactive programming
/// - Automatic connectivity monitoring
/// - Background/foreground handling
/// - Advanced error recovery.
class EnhancedAsyncClient {
  final _log = Logger('EnhancedAsyncClient');
  final AsyncConfig _config;

  // Core components
  late DefaultTransportStrategy _transportStrategy;
  late StreamController<ChannelMessage> _eventStreamController;
  late StreamController<ConnectionState> _connectionStateController;

  // Connectivity monitoring
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  // Background handling
  StreamSubscription<AppLifecycleState>? _lifecycleSubscription;
  AppLifecycleState _currentLifecycleState = AppLifecycleState.resumed;

  // State management
  ConnectionState _connectionState = ConnectionState.disconnected;
  bool _isManualDisconnect = false;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;

  // Stream management
  final BehaviorSubject<ConnectionState> _connectionStateSubject =
      BehaviorSubject<ConnectionState>.seeded(ConnectionState.disconnected);
  final BehaviorSubject<List<ConnectivityResult>> _connectivitySubject =
      BehaviorSubject<List<ConnectivityResult>>.seeded(
    [ConnectivityResult.none],
  );

  EnhancedAsyncClient(this._config) {
    _transportStrategy = DefaultTransportStrategy(
      _config,
      _onTransportClose,
      _onTransportError,
    );
    _eventStreamController = StreamController<ChannelMessage>.broadcast();
    _connectionStateController = StreamController<ConnectionState>.broadcast();

    _initializeConnectivityMonitoring();
    _initializeLifecycleHandling();
  }

  /// Initialize connectivity monitoring.
  void _initializeConnectivityMonitoring() {
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      (List<ConnectivityResult> results) {
        _connectivitySubject.add(results);
        _handleConnectivityChange(results);
      },
      onError: (error) {
        _log.warning('Connectivity monitoring error: $error');
      },
    );
  }

  /// Initialize app lifecycle handling.
  void _initializeLifecycleHandling() {
    // Note: In a real Flutter app, you would bind this to WidgetsBindingObserver
    // This is a simplified version for demonstration
  }

  /// Handle connectivity changes.
  void _handleConnectivityChange(List<ConnectivityResult> results) {
    final hasConnection =
        results.any((result) => result != ConnectivityResult.none);

    _log.info('Connectivity changed: $results');

    if (hasConnection &&
        _connectionState == ConnectionState.disconnected &&
        !_isManualDisconnect) {
      _log.info('Network available, attempting to reconnect');
      _attemptReconnect();
    } else if (!hasConnection &&
        _connectionState == ConnectionState.connected) {
      _log.info('Network unavailable, connection lost');
      _updateConnectionState(ConnectionState.disconnected);
    }
  }

  /// Handle app lifecycle changes.
  void handleAppLifecycleStateChanged(AppLifecycleState state) {
    _currentLifecycleState = state;

    switch (state) {
      case AppLifecycleState.resumed:
        if (_connectionState == ConnectionState.disconnected &&
            !_isManualDisconnect) {
          _log.info('App resumed, checking connection');
          _attemptReconnect();
        }
        break;
      case AppLifecycleState.paused:
        _log.info('App paused, maintaining connection');
        break;
      case AppLifecycleState.detached:
        _log.info('App detached, disconnecting');
        _gracefulDisconnect();
        break;
      case AppLifecycleState.inactive:
        break;
      case AppLifecycleState.hidden:
        break;
    }
  }

  /// Connect to the server.
  Future<bool> connect() async {
    _isManualDisconnect = false;
    _updateConnectionState(ConnectionState.connecting);

    try {
      final hasConnection = await _checkConnectivity();
      if (!hasConnection) {
        _log.warning('No network connectivity, cannot connect');
        _updateConnectionState(ConnectionState.disconnected);

        return false;
      }

      final connected = await _transportStrategy.connect();
      if (connected) {
        _log.info('Connected to server');
        _updateConnectionState(ConnectionState.connected);
        _reconnectAttempts = 0;
        _listenToTransportStream();

        return true;
      } else {
        _log.severe('Failed to connect to server');
        _updateConnectionState(ConnectionState.disconnected);

        return false;
      }
    } catch (error) {
      _log.severe('Connection error: $error');
      _updateConnectionState(ConnectionState.disconnected);

      return false;
    }
  }

  /// Disconnect from the server.
  Future<bool> disconnect() async {
    _isManualDisconnect = true;
    _reconnectTimer?.cancel();
    _updateConnectionState(ConnectionState.disconnecting);

    try {
      await _transportStrategy.disconnect();
      _updateConnectionState(ConnectionState.disconnected);

      return true;
    } catch (error) {
      _log.severe('Disconnect error: $error');

      return false;
    }
  }

  /// Check network connectivity.
  Future<bool> _checkConnectivity() async {
    try {
      final results = await _connectivity.checkConnectivity();

      return results.any((result) => result != ConnectivityResult.none);
    } catch (error) {
      _log.warning('Failed to check connectivity: $error');

      return true; // Assume connected if check fails
    }
  }

  /// Attempt to reconnect with exponential backoff
  void _attemptReconnect() {
    if (_isManualDisconnect || _connectionState == ConnectionState.connecting) {
      return;
    }

    final maxRetries = _config.maxRetries ?? 5;
    if (_reconnectAttempts >= maxRetries) {
      _log.warning('Max reconnection attempts reached');
      return;
    }

    final delay = Duration(seconds: (2 * _reconnectAttempts + 1).clamp(1, 30));
    _reconnectAttempts++;

    _log.info(
        'Reconnecting in ${delay.inSeconds}s (attempt $_reconnectAttempts/$maxRetries)');

    _reconnectTimer = Timer(delay, () async {
      if (!_isManualDisconnect) {
        await connect();
      }
    });
  }

  /// Graceful disconnect (for background handling)
  void _gracefulDisconnect() {
    // Don't set _isManualDisconnect to true, so we can reconnect when app resumes
    _transportStrategy.disconnect();
  }

  /// Update connection state and notify listeners
  void _updateConnectionState(ConnectionState newState) {
    if (_connectionState != newState) {
      _connectionState = newState;
      _connectionStateSubject.add(newState);
      _connectionStateController.add(newState);
    }
  }

  /// Listen to transport stream.
  void _listenToTransportStream() {
    try {
      _transportStrategy.stream.listen(
        (message) {
          _eventStreamController.add(message);
        },
        onError: (error, stackTrace) {
          _log.severe('Transport stream error: $error');
        },
        onDone: () {
          _log.info('Transport stream closed');
          if (!_isManualDisconnect) {
            _updateConnectionState(ConnectionState.disconnected);
            _attemptReconnect();
          }
        },
      );
    } catch (error) {
      _log.severe('Failed to listen to transport stream: $error');
    }
  }

  /// Transport close handler.
  void _onTransportClose(int code, String reason) {
    _log.info('Transport closed: $code - $reason');
    if (!_isManualDisconnect) {
      _updateConnectionState(ConnectionState.disconnected);
      _attemptReconnect();
    }
  }

  /// Transport error handler.
  void _onTransportError(Object error) {
    _log.severe('Transport error: $error');
    if (!_isManualDisconnect) {
      _updateConnectionState(ConnectionState.disconnected);
      _attemptReconnect();
    }
  }

  // REACTIVE STREAMS API

  /// Stream of all channel messages.
  Stream<ChannelMessage> get messageStream => _eventStreamController.stream;

  /// Stream of connection state changes.
  Stream<ConnectionState> get connectionState => _connectionStateSubject.stream;

  /// Stream of connectivity changes.
  Stream<List<ConnectivityResult>> get connectivityState =>
      _connectivitySubject.stream;

  /// Stream of messages filtered by event name(s).
  Stream<ChannelMessage> messagesWhere(List<String> eventFilters) {
    return messageStream
        .where((message) => eventFilters.contains(message.event));
  }

  /// Stream of messages for a specific event.
  Stream<ChannelMessage> messagesFor(String eventName) {
    return messageStream.where((message) => message.event == eventName);
  }

  /// Stream of messages matching a pattern.
  Stream<ChannelMessage> messagesMatching(String pattern) {
    final regex =
        RegExp(pattern.replaceAll('*', r'[^.]+').replaceAll('#', r'[^.]+\.?'));

    return messageStream
        .where((message) => regex.hasMatch(message.event.toString()));
  }

  /// Combined stream of messages with connection state.
  Stream<MessageWithState> get messagesWithConnectionState {
    return Rx.combineLatest2(
      messageStream,
      connectionState,
      (ChannelMessage message, ConnectionState state) =>
          MessageWithState(message, state),
    );
  }

  /// Stream that emits when connected and ready to receive messages.
  Stream<void> get onReady {
    return connectionState
        .where((state) => state == ConnectionState.connected)
        .map((_) => null);
  }

  /// Stream that emits when disconnected
  Stream<void> get onDisconnected {
    return connectionState
        .where((state) => state == ConnectionState.disconnected)
        .map((_) => null);
  }

  // UTILITY METHODS

  /// Check if currently connected.
  bool get isConnected => _connectionState == ConnectionState.connected;

  /// Check if currently connecting.
  bool get isConnecting => _connectionState == ConnectionState.connecting;

  /// Get current connection state.
  ConnectionState get currentConnectionState => _connectionState;

  /// Get current transport type.
  String get currentTransportType =>
      _transportStrategy.getTransport().name().toString();

  /// Switch to different transport protocol.
  Future<bool> switchTransport() async {
    final currentType = _transportStrategy.getTransport().name();
    final newType = await _transportStrategy.iterateTransport();

    if (newType == currentType) {
      _log.warning('No alternative transport available');

      return false;
    }

    return await connect();
  }

  /// Dispose resources.
  Future<void> dispose() async {
    _isManualDisconnect = true;
    _reconnectTimer?.cancel();

    await _connectivitySubscription?.cancel();
    await _lifecycleSubscription?.cancel();

    await _transportStrategy.disconnect();

    await _eventStreamController.close();
    await _connectionStateController.close();
    await _connectionStateSubject.close();
    await _connectivitySubject.close();
  }
}

/// Connection state enumeration.
enum ConnectionState {
  disconnected,
  connecting,
  connected,
  disconnecting,
}

/// App lifecycle state (simplified for non-Flutter usage).
enum AppLifecycleState {
  resumed,
  inactive,
  paused,
  detached,
  hidden,
}

/// Combined message and connection state.
class MessageWithState {
  final ChannelMessage message;
  final ConnectionState connectionState;

  MessageWithState(this.message, this.connectionState);
}
