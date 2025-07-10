//ignore_for_file: avoid-ignoring-return-values
import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:logging/logging.dart';
import 'package:rxdart/rxdart.dart';

import 'async_config.dart';
import 'model/channel_message.dart';
import 'transport/default_transport_strategy.dart';
import 'transport/transport.dart';

/// Enhanced Async Data Flow Client with reactive patterns,
/// connectivity awareness, and background handling
///
/// This client provides:
/// - Stream-based API for reactive programming
/// - Automatic connectivity monitoring
/// - Background/foreground handling
/// - Advanced error recovery.
class AsyncClientConf {
  final _log = Logger('AsyncClient');
  final AsyncConfig _config;

  // Core components
  late DefaultTransportStrategy _transportStrategy;
  late StreamController<ChannelMessage> _eventStreamController;
  late StreamController<CustomConnectionState> _connectionStateController;

  // Connectivity monitoring
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;

  // Background handling
  CustomAppLifecycleState _currentLifecycleState =
      CustomAppLifecycleState.resumed;

  // State management
  CustomConnectionState _connectionState = CustomConnectionState.disconnected;
  bool _isManualDisconnect = false;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;

  // Stream management
  final BehaviorSubject<CustomConnectionState> _connectionStateSubject =
      BehaviorSubject<CustomConnectionState>.seeded(
    CustomConnectionState.disconnected,
  );
  final BehaviorSubject<ConnectivityResult> _connectivitySubject =
      BehaviorSubject<ConnectivityResult>.seeded(
    ConnectivityResult.none,
  );
  StreamSubscription<ChannelMessage>? _transportStreamSubscription;

  AsyncClientConf(this._config) {
    _transportStrategy = DefaultTransportStrategy(
      _config,
      _onTransportClose,
      _onTransportError,
    );
    _eventStreamController = StreamController<ChannelMessage>.broadcast();
    _connectionStateController =
        StreamController<CustomConnectionState>.broadcast();

    _initializeConnectivityMonitoring();
  }

  /// Initialize connectivity monitoring.
  void _initializeConnectivityMonitoring() {
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      (ConnectivityResult results) {
        _connectivitySubject.add(results);
        _handleConnectivityChange(results);
      },
      onError: (error) {
        _log.warning(
          '[async-client][Main] Connectivity monitoring error: $error',
        );
      },
    );
  }

  /// Handle connectivity changes.
  void _handleConnectivityChange(ConnectivityResult results) {
    final hasConnection = results != ConnectivityResult.none;

    _log.info(
      '[async-client][Main] Connectivity changed: $results (hasConnection: $hasConnection)',
    );

    if (hasConnection &&
        _connectionState == CustomConnectionState.disconnected &&
        !_isManualDisconnect) {
      _log.info(
        '[async-client][Main] Network available, attempting to reconnect (channelRef: ${_config.channelRef})',
      );
      _attemptReconnect();
    } else if (!hasConnection &&
        _connectionState == CustomConnectionState.connected) {
      _log.info(
        '[async-client][Main] Network unavailable, connection lost (channelRef: ${_config.channelRef})',
      );
      _updateConnectionState(CustomConnectionState.disconnected);
    }
  }

  /// Handle app lifecycle changes.
  void handleAppLifecycleStateChanged(CustomAppLifecycleState state) {
    _currentLifecycleState = state;

    switch (state) {
      case CustomAppLifecycleState.resumed:
        if (_connectionState == CustomConnectionState.disconnected &&
            !_isManualDisconnect) {
          _log.info(
            '[async-client][LifeCycle] App resumed, checking connection, (channelRef: ${_config.channelRef})',
          );
          _attemptReconnect();
        }
        break;
      case CustomAppLifecycleState.paused:
        _log.info(
          '[async-client][LifeCycle] App paused, maintaining connection, (channelRef: ${_config.channelRef})',
        );
        break;
      case CustomAppLifecycleState.detached:
        _log.info(
          '[async-client][LifeCycle] App detached, disconnecting, (channelRef: ${_config.channelRef})',
        );
        _gracefulDisconnect();
        break;
      case CustomAppLifecycleState.inactive:
        break;
      case CustomAppLifecycleState.hidden:
        break;
    }
  }

  /// Connect to the server.
  Future<bool> connect() async {
    _isManualDisconnect = false;
    _updateConnectionState(CustomConnectionState.connecting);

    try {
      final hasConnection = await _checkConnectivity();
      if (!hasConnection) {
        _log.warning(
          '[async-client][Main] No network connectivity, cannot connect (channelRef: ${_config.channelRef})',
        );
        _updateConnectionState(CustomConnectionState.disconnected);

        return false;
      }

      final connected = await _transportStrategy.connect();
      if (connected) {
        _log.info(
          '[async-client][Main] Connected to server (channelRef: ${_config.channelRef})',
        );
        _updateConnectionState(CustomConnectionState.connected);
        _reconnectAttempts = 0;
        _listenToTransportStream();

        return true;
      } else {
        _log.severe(
          '[async-client][Main] Failed to connect to server (channelRef: ${_config.channelRef})',
        );
        _updateConnectionState(CustomConnectionState.disconnected);

        return false;
      }
    } catch (error) {
      _log.severe(
        '[async-client][Main] Connection error: $error (channelRef: ${_config.channelRef})',
      );
      _updateConnectionState(CustomConnectionState.disconnected);

      return false;
    }
  }

  /// Disconnect from the server.
  Future<bool> disconnect() async {
    _isManualDisconnect = true;
    _reconnectTimer?.cancel();
    _updateConnectionState(CustomConnectionState.disconnecting);

    try {
      await _transportStrategy.disconnect();
      _updateConnectionState(CustomConnectionState.disconnected);

      return true;
    } catch (error) {
      _log.severe(
        '[async-client][Main] Disconnect error: $error (channelRef: ${_config.channelRef})',
      );

      return false;
    }
  }

  /// Check network connectivity.
  Future<bool> _checkConnectivity() async {
    try {
      final results = await _connectivity.checkConnectivity();

      return results != ConnectivityResult.none;
    } catch (error) {
      _log.warning('[async-client][Main] Failed to check connectivity: $error');

      return true; // Assume connected if check fails
    }
  }

  /// Attempt to reconnect with exponential backoff.
  void _attemptReconnect() {
    if (_isManualDisconnect ||
        _connectionState == CustomConnectionState.connecting) {
      return;
    }

    _reconnectTimer?.cancel();

    final maxRetries = _config.maxRetries ?? 5;
    if (_reconnectAttempts >= maxRetries) {
      _log.warning(
        '[async-client][Main] Max reconnection attempts reached (channelRef: ${_config.channelRef})',
      );

      return;
    }

    final delay = Duration(seconds: (2 * _reconnectAttempts + 1).clamp(1, 30));
    _reconnectAttempts++;

    _log.info(
      '[async-client][Main] Reconnecting in ${delay.inSeconds}s (attempt $_reconnectAttempts/$maxRetries) (channelRef: ${_config.channelRef})',
    );

    _reconnectTimer = Timer(delay, () {
      if (!_isManualDisconnect &&
          _connectionState != CustomConnectionState.connecting) {
        connect(); // Removed the await to allow multiple attempts
      }
    });
  }

  /// Graceful disconnect (for background handling).
  void _gracefulDisconnect() {
    // Don't set _isManualDisconnect to true, so we can reconnect when app resumes
    _transportStrategy.disconnect();
  }

  /// Update connection state and notify listeners.
  void _updateConnectionState(CustomConnectionState newState) {
    if (_connectionState != newState) {
      _connectionState = newState;
      _connectionStateSubject.add(newState);
      _connectionStateController.add(newState);
    }
  }

  /// Listen to transport stream.
  void _listenToTransportStream() {
    try {
      // Cancel existing subscription to prevent duplicate listeners
      _transportStreamSubscription?.cancel();

      _transportStreamSubscription = _transportStrategy.stream.listen(
        (message) {
          _eventStreamController.add(message);
        },
        onError: (error, stackTrace) {
          _log.severe('Transport stream error: $error');
        },
        onDone: () {
          _log.info('Transport stream closed');
          if (!_isManualDisconnect) {
            _updateConnectionState(CustomConnectionState.disconnected);
            _attemptReconnect();
          }
        },
      );
    } catch (error) {
      _log.severe(
        '[async-client][Main] Failed to listen to transport stream: $error',
      );
    }
  }

  /// Transport close handler.
  void _onTransportClose(int code, String reason) {
    _log.info('[async-client][Main] Transport closed: $code - $reason');
    if (!_isManualDisconnect) {
      _updateConnectionState(CustomConnectionState.disconnected);
      _attemptReconnect();
    }
  }

  /// Transport error handler.
  void _onTransportError(Object error) {
    _log.severe('[async-client][Main] Transport error: $error');
    if (!_isManualDisconnect) {
      _updateConnectionState(CustomConnectionState.disconnected);
      _attemptReconnect();
    }
  }

  /// Stream of all channel messages.
  Stream<ChannelMessage> get messageStream => _eventStreamController.stream;

  /// Stream of connection state changes.
  Stream<CustomConnectionState> get connectionState =>
      _connectionStateSubject.stream;

  /// Stream of connectivity changes.
  Stream<ConnectivityResult> get connectivityState =>
      _connectivitySubject.stream;

  /// Stream of messages filtered by event name(s).
  StreamSubscription<ChannelMessage> subscribeToMany(
    List<String>? eventFilters,
    Function? onData, {
    Function? onError,
  }) {
    if (eventFilters == null || eventFilters.isEmpty) {
      throw ArgumentError('Invalid event filter(s)');
    } else {
      for (var element in eventFilters) {
        if (element.trim().isEmpty) {
          throw ArgumentError('Invalid event filter');
        }
      }
    }

    return messageStream.listen(
      (message) {
        if (eventFilters.contains(message.event)) {
          onData?.call(message);
        } else {
          _log.warning(
            '[async-client][Main] received event name "${message.event}" does not match event filters: "$eventFilters"',
          );
          _transportStrategy.sendInfo('not-subscribed-to[${message.event}]');
        }
      },
      onError: (error, stackTrace) {
        _log.warning(
          '[async-client][Main] Event stream signaled an error',
        );
        if (onError != null) {
          onError(error);
        }
      },
      onDone: () {
        _log.warning(
          '[async-client][Main] Subscription for "$eventFilters" terminated.',
        );
      },
    );
  }

  /// Stream of messages for a specific event.
  StreamSubscription<ChannelMessage> subscribeTo(
    String eventName,
    Function? onData, {
    Function? onError,
  }) {
    if (eventName.trim().isEmpty) {
      throw ArgumentError('Invalid event name');
    }

    return messageStream.listen(
      (message) {
        if (message.event == eventName) {
          onData?.call(message);
        } else {
          _log.warning(
            '[async-client][Main] received event name "${message.event}" does not match requested event: "$eventName"',
          );
          _transportStrategy.sendInfo('not-subscribed-to[$eventName]');
        }
      },
      onError: (error, stackTrace) {
        _log.warning(
          '[async-client][Main] Event stream signaled an error',
        );
        if (onError != null) {
          onError(error);
        }
      },
      onDone: () {
        _log.warning(
          '[async-client][Main] Subscription for "$eventName" terminated.',
        );
      },
    );
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
      (ChannelMessage message, CustomConnectionState state) =>
          MessageWithState(message, state),
    );
  }

  /// Stream that emits when disconnected.
  Stream<void> get onDisconnected {
    return connectionState
        .where((state) => state == CustomConnectionState.disconnected)
        .map((_) => {});
  }

  /// Check if currently connected.
  bool get isConnected => _connectionState == CustomConnectionState.connected;

  /// Check if currently connecting.
  bool get isConnecting => _connectionState == CustomConnectionState.connecting;

  /// Get current connection state.
  CustomConnectionState get currentConnectionState => _connectionState;

  /// Get current transport type.
  String get currentTransportType =>
      _transportStrategy.getTransport().name().toString();

  Transport get currentTransport {
    return _transportStrategy.getTransport();
  }

  /// Switch to different transport protocol.
  Future<bool> switchProtocols() async {
    final currentType = _transportStrategy.getTransport().name();
    final newType = await _transportStrategy.iterateTransport();

    if (newType == currentType) {
      _log.warning(
        '[async-client][Main] No alternative transport available (channelRef: ${_config.channelRef})',
      );

      return false;
    }

    return await connect();
  }

  /// Dispose resources.
  Future<void> dispose() async {
    _isManualDisconnect = true;
    _reconnectTimer?.cancel();

    await _connectivitySubscription?.cancel();
    await _transportStreamSubscription?.cancel();

    await _transportStrategy.disconnect();

    await _eventStreamController.close();
    await _connectionStateController.close();
    await _connectionStateSubject.close();
    await _connectivitySubject.close();
  }
}

/// Connection state enumeration.
enum CustomConnectionState {
  disconnected,
  connecting,
  connected,
  disconnecting,
}

/// App lifecycle state (simplified for non-Flutter usage).
enum CustomAppLifecycleState {
  resumed,
  inactive,
  paused,
  detached,
  hidden,
}

/// Combined message and connection state.
class MessageWithState {
  final ChannelMessage message;
  final CustomConnectionState connectionState;

  MessageWithState(this.message, this.connectionState);
}
