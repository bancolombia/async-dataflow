//ignore_for_file: avoid_ignoring_returns
import 'dart:async';

import 'package:logging/logging.dart';
import 'async_config.dart';
import 'model/channel_message.dart';
import 'transport/default_transport_strategy.dart';
import 'transport/transport.dart';

/// Async Data Flow Low Level Client
///
/// This library allows you to connect to Async Dataflow Channel
/// Sender.
///
class AsyncClient {
  bool closeWasClean = false;
  final _log = Logger('AsyncClient');
  final AsyncConfig _config;

  late DefaultTransportStrategy _transportStrategy;

  // this stream is used to expose the events to the user
  // and abstract the stream from the transport layers.
  late StreamController<ChannelMessage> _eventStreamController;

  AsyncClient(this._config) {
    _transportStrategy = DefaultTransportStrategy(
      _config,
      _onTransportClose,
      _onTransportError,
    );
    _eventStreamController = StreamController<ChannelMessage>.broadcast();
  }

  // Opens up the connection and performs auth flow.
  Future<bool> connect() async {
    closeWasClean = false;
    bool connected = await _transportStrategy.connect();
    if (connected) {
      _log.info('[async-client][Main] Connected to the server');
      _listenToTransportStream();

      return true;
    } else {
      _log.severe('[async-client][Main] Could not connect to the server');

      return false;
    }
  }

  // Listens to the transport stream and pipes the messages
  // to the event stream.
  void _listenToTransportStream() {
    try {
      _transportStrategy.stream.listen(
        (message) {
          _eventStreamController.add(message);
        },
        onError: (error, stacktrace) {
          _log.severe('[async-client][Main] Error in transport stream: $error');
        },
        onDone: () {
          _log.info('[async-client][Main] Transport stream closed');
        },
      );
    } catch (e) {
      _log.severe('[async-client][Main] Error in transport stream: $e');
    }
  }

  Stream<ChannelMessage> get eventStream => _eventStreamController.stream;

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

    return eventStream.listen(
      (message) {
        if (eventFilters.contains(message.event)) {
          onData(message);
        } else {
          _log.warning(
            '[async-client][Main] received event name "${message.event}" does not match event filters: "$eventFilters"  ',
          );
          _transportStrategy.sendInfo('not-subscribed-to[${message.event}]');
        }
      },
      onError: (error, stacktrace) {
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

  bool isOpen() {
    return _transportStrategy.getTransport().isOpen();
  }

  Future<bool> switchProtocols() async {
    TransportType currentTransportType =
        _transportStrategy.getTransport().name();

    // reconnect using (potentially) a different transport. It depends on the strategy.
    TransportType newTransportType =
        await _transportStrategy.iterateTransport();

    if (newTransportType == currentTransportType) {
      _log.severe(
        '[async-client][Main] Not switching protocols. Transport is the same',
      );

      return false;
    }

    return await connect();
  }

  String getCurrentTransportType() {
    return _transportStrategy.getTransport().name().toString();
  }

  Future<bool> disconnect() async {
    closeWasClean = true;
    _log.finer('[async-client][Main] disconnect() called');

    await _transportStrategy.disconnect();
    _log.finer('[async-client][Main] async-client. disconnect() called end');

    return true;
  }

  void _onTransportClose(int code, String reason) {
    _log.severe(
      '[async-client][Main] Transport signaled close: ${_transportStrategy.getTransport().name()} code: $code reason: $reason',
    );

    /// if the close was clean, we don't need to switch protocols.
  }

  void _onTransportError(Object error) async {
    _log.severe(
      '[async-client][Main] Transport signaled error: ${_transportStrategy.getTransport().name()} $error',
    );

    await switchProtocols();
  }
}
