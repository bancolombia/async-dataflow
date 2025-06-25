// ignore_for_file: avoid-ignoring-return-values
import 'dart:async';

import 'package:logging/logging.dart';

import '../../../channel_sender_client.dart';
import '../../decoder/decoder.dart';
import '../../exceptions/exceptions.dart';
import '../../sse/eventflux.dart';
import '../../utils/capped_list.dart';
import '../../utils/retry_timer.dart';
import '../transport.dart';

class SSETransport implements Transport {
  MessageDecoder msgDecoder = JsonDecoder();
  static const String EVENT_KIND_USER = 'user_event';
  static const String EVENT_KIND_SYSTEM = 'system_event';
  static const String RESPONSE_NEW_TOKEN = ':n_token';

  static const int RETRY_DEFAULT_MAX_RETRIES = 5;
  static const int RETRY_DEFAULT_MAX_TIME = 2000;
  static const int RETRY_DEFAULT_MIN_TIME = 350;

  static const int SSE_OK_CLOSE_CODE = 200;

  late String currentToken;

  final _log = Logger('SSETransport');

  final void Function(int, String) _signalSSEClose;
  final void Function(Object) _signalSSEError;
  final AsyncConfig _config;
  late RetryTimer _connectRetryTimer;

  late StreamController<ChannelMessage> _broadCastStream;
  final CappedList<String> _messageDedup = CappedList<String>(50);

  SSETransport(
    this._signalSSEClose,
    this._signalSSEError,
    this._config,
  ) {
    currentToken = _config.channelSecret;
    _broadCastStream = StreamController<
        ChannelMessage>.broadcast(); // subscribers stream of data
    _connectRetryTimer = RetryTimer(
      () async {
        return await connect();
      },
      () async {
        _signalSSEError(
          MaxRetriesException(
            '[async-client][SSETransport] Max retries reached',
          ),
        );
      },
      initialWait: RETRY_DEFAULT_MIN_TIME,
      maxWait: RETRY_DEFAULT_MAX_TIME,
      maxRetries: _config.maxRetries,
    );
  }

  @override
  TransportType name() {
    return TransportType.sse;
  }

  @override
  Future<bool> connect() async {
    _log.finer('[async-client][SSETransport] connect() started.');

    EventFlux.instance.connect(
      EventFluxConnectionType.get,
      sseUrl(),
      header: {
        'Authorization': 'Bearer $currentToken',
        'Accept': 'text/event-stream',
      },
      multipartRequest: false,
      onSuccessCallback: (EventFluxResponse? response) {
        response?.stream?.listen(
          (data) {
            _onData(data.data);
          },
        );
      },
      onError: (error) {
        _onResponseError(error, StackTrace.current);
      },
      onConnectionClose: () {
        _log.warning('[async-client][SSETransport] onConnectionClose called');
        _signalSSEClose(0, '');
      },
      autoReconnect: true, // Keep the party going, automatically!
      reconnectConfig: ReconnectConfig(
        mode: ReconnectMode.linear, // or exponential,
        interval: const Duration(seconds: 2),
        maxAttempts: _config.maxRetries ??
            RETRY_DEFAULT_MAX_RETRIES, // or -1 for infinite,
        onReconnect: () {
          _log.info('[async-client][SSETransport] onReconnect Called');
        },
        reconnectHeader: () => Future.value({
          'Authorization': 'Bearer $currentToken',
          'Accept': 'text/event-stream',
        }),
      ),
    );

    _log.finest('[async-client][SSETransport] connect() called');

    return true;
  }

  @override
  void send(String message) {
    _log.warning('[async-client][SSETransport] method Send not supported');
  }

  void _handleNewToken(ChannelMessage message) {
    _log.finest('[async-client][SSETransport] new token received');
    currentToken = message.payload;
    _config.channelSecret = currentToken;
  }

  void _onResponseError(error, stackTrace) {
    EventFluxException parsedException;

    parsedException = error is EventFluxException
        ? error
        : EventFluxException(
            message: error?.toString() ?? 'Unknown SSE error',
            statusCode: null,
            reasonPhrase: null,
          );

    // Provide default values for null status codes and reason phrases
    int? statusCode = parsedException.statusCode;
    String? reasonPhrase = parsedException.reasonPhrase ?? 'Unknown error';

    // close code 200 is ok to ignore
    if (statusCode != SSE_OK_CLOSE_CODE) {
      _log.severe(
        '[async-client][SSETransport] Error in SSE connection: ${parsedException.statusCode}, ${parsedException.reasonPhrase}, stackTrace: $stackTrace',
      );
      // ignore: prefer-async-await
      EventFlux.instance.disconnect().then(
        (_) {
          if (!_connectRetryTimer.isActive()) {
            _connectRetryTimer.schedule();
          } else {
            _log.warning(
              '[async-client][SSETransport] Retry timer is already active. Waiting for it to finish.',
            );
          }
        },
        onError: (e) {
          _log.severe(
            '[async-client][SSETransport] Error calling EventFlux.disconnect(): $e, stackTrace: $stackTrace',
          );
        },
      );
    }
  }

  int extractCode(String stringCode) {
    return int.tryParse(stringCode) ?? 0;
  }

  void _onData(String data) {
    _log.finest('[async-client][SSETransport] Received raw from Server: $data');
    var message = msgDecoder.decode(data);

    if (message.event == RESPONSE_NEW_TOKEN) {
      _handleNewToken(message);
    }

    if (_messageDedup.contains(message.messageId ?? '')) {
      _log.warning(
        '[async-client][SSETransport] message deduped: ${message.messageId}',
      );

      return;
    } else {
      _messageDedup.add(message.messageId ?? '');
      _broadCastStream.add(message);
    }
  }

  String sseUrl() {
    String url = '';
    if (_config.sseUrl != null) {
      url = _config.sseUrl ?? '';
      url = '$url?channel=${_config.channelRef}';
      _log.info('[async-client][SSETransport] url is $url');
    } else {
      if (_config.socketUrl.startsWith('ws')) {
        url = _config.socketUrl
            .replaceFirstMapped('ws:', (match) => 'http:')
            .replaceFirstMapped('wss:', (match) => 'https:')
            .replaceFirstMapped('/ws', (match) => '/sse')
            .replaceFirstMapped('/socket', (match) => '/sse');
      }
      url = '$url?channel=${_config.channelRef}';
      _log.info('[async-client][SSETransport] Calculated url will be $url');
    }

    return url;
  }

  @override
  bool isOpen() => false;

  @override
  Stream<ChannelMessage> get stream => _broadCastStream.stream;

  @override
  Future<void> disconnect() async {
    _log.info('[async-client][SSETransport] disconnect() called');
    await EventFlux.instance.disconnect();
    _connectRetryTimer.reset();
    _log.info('[async-client][SSETransport] disconnect() finished');

    return;
  }
}
