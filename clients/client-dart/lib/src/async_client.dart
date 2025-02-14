import 'dart:async';

import 'package:logging/logging.dart';

import 'async_config.dart';
import 'model/channel_message.dart';
import 'transport/sse_transport.dart';
import 'transport/transport.dart';
import 'transport/ws_transport.dart';

/// Async Data Flow Low Level Client
///
/// This library allows you to connect do Async Dataflow Channel
/// Sender.
///
class AsyncClient {
  bool closeWasClean = false;
  final _log = Logger('AsyncClient');
  final AsyncConfig _config;

  Transport? _currentTransport;
  int _currentTransportIndex = 0;
  int _retriesByTransport = 0;

  AsyncClient(this._config) {
    _currentTransport = getTransport();
  }

  Transport getTransport() {
    TransportType transport = _config.transports[_currentTransportIndex];
    _log.info(
      'async-client. transports defined:  ${_config.transports.join(', ')}',
    );
    _log.info(
      'async-client. will instantiate transport: $transport',
    );
    if (transport == TransportType.ws) {
      return _buildWSTransport();
    } else if (transport == TransportType.sse) {
      return _buildSSETransport();
    }
    throw Exception('async-client. No transport available:  $transport');
  }

  // Opens up the connection and performs auth flow.

  void connect() {
    closeWasClean = false;
    _currentTransport?.connect();
  }

  StreamSubscription<ChannelMessage>? subscribeTo(
    String eventFilter,
    Function(ChannelMessage) onData, {
    Function? onError,
  }) {
    return onError != null
        ? subscribeToMany([eventFilter], onData, onError: onError)
        : subscribeToMany([eventFilter], onData);
  }

  StreamSubscription<ChannelMessage>? subscribeToMany(
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
    if (onData == null) {
      throw ArgumentError('Invalid onData function');
    }

    return _currentTransport?.stream.listen(
      (message) {
        if (eventFilters.contains(message.event)) {
          onData(message);
        }
      },
      onError: (error, stacktrace) {
        if (onError != null) {
          onError(error);
        }
      },
      onDone: () {
        _log.warning(
          'async-client. Subscription for "$eventFilters" terminated.',
        );
      },
    );
  }

  Transport _buildWSTransport() {
    return WSTransport(
      _onTransportClose,
      _onTransportError,
      _config,
    );
  }

  Transport _buildSSETransport() {
    return SSETransport(
      _onTransportClose,
      _onTransportError,
      _config,
    );
  }

  bool isOpen() {
    return _currentTransport?.isOpen() ?? false;
  }

  Future<bool> disconnect() async {
    closeWasClean = true;
    _log.finer('async-client. disconnect() called');

    await _currentTransport?.disconnect();
    _log.finer('async-client. async-client. disconnect() called end');

    return true;
  }

  void _onTransportClose(int code, String reason) {}

  void _onTransportError(Object error) async {
    _log.severe(
      'async-client. Transport error: ${_currentTransport?.name()} $error',
    );
    _retriesByTransport++;
    await _currentTransport?.disconnect();
    _currentTransportIndex =
        (_currentTransportIndex + 1) % _config.transports.length;

    if (!isOpen()) {
      _log.severe(
        'async-client. Transport error and channel is not open, Scheduling reconnect $_retriesByTransport of ${_config.maxRetries}...',
      );
      if (_retriesByTransport <= (_config.maxRetries ?? 10)) {
        _currentTransport = getTransport();
        connect();
      } else {
        _log.severe('async-client. stopping transport retries for ',
            _config.transports.join(', '));
      }
    }
  }
}
