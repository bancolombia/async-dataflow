import 'dart:async';

import 'package:flutter_client_sse/constants/sse_request_type_enum.dart';
import 'package:flutter_client_sse/flutter_client_sse.dart';
import 'package:flutter_client_sse/retry_options.dart';
import 'package:logging/logging.dart';

import '../../channel_sender_client.dart';
import '../decoder/json_decoder.dart';
import '../decoder/message_decoder.dart';
import 'capped_list.dart';
import 'max_retries_exception.dart';
import 'transport.dart';

class SSETransport implements Transport {
  MessageDecoder msgDecoder = JsonDecoder();
  static const String EVENT_KIND_USER = 'user_event';
  static const String EVENT_KIND_SYSTEM = 'system_event';
  static const String RESPONSE_NEW_TOKEN = ':n_token';

  static const int RETRY_DEFAULT_MAX_RETRIES = 5;
  static const int RETRY_DEFAULT_MAX_TIME = 2000;
  static const int RETRY_DEFAULT_MIN_TIME = 200;

  final _log = Logger('SSETransport');

  final Function(int, String) _signalSSEClose;
  final Function(Object) _signalSSEError;
  final AsyncConfig _config;

  late String currentToken;
  Stream<SSEModel>? _eventSource;
  StreamSubscription<SSEModel>? _eventStreamSub;
  late StreamController<ChannelMessage> _broadCastStream;
  final CappedList<String> _messageDedup = CappedList<String>(50);

  SSETransport(
    this._signalSSEClose,
    this._signalSSEError,
    this._config,
  ) {
    currentToken = _config.channelSecret;
    _broadCastStream = StreamController<ChannelMessage>.broadcast(); // subscribers stream of data
  }

  @override
  TransportType name() {
    return TransportType.sse;
  }

  set eventSource(Stream<SSEModel> value) {
    _eventSource = value;
  }

  // set localStream(StreamController<ChannelMessage> value) {
  //   _localStream = value;
  // }

  @override
  Future<bool> connect() async {
    _log.finer('[async-client][SSETransport] connect() started.');

    _eventSource ??= SSEClient.subscribeToSSE(
      method: SSERequestType.GET,
      url: sseUrl(),
      header: {
        'Authorization': 'Bearer $currentToken',
      },
      retryOptions: RetryOptions(
        maxRetryTime: RETRY_DEFAULT_MAX_TIME,
        minRetryTime: RETRY_DEFAULT_MIN_TIME,
        maxRetry: _config.maxRetries ?? RETRY_DEFAULT_MAX_RETRIES,
        limitReachedCallback: () async {
          _onResponseError(
              MaxRetriesException('[async-client][SSETransport] Max retries reached'), StackTrace.current,);
        },
      ),
    );

    _eventStreamSub = _eventSource!.listen(
      (data) {
        _onData(data);
      },
      onError: (error, stacktrace) {
        _onResponseError(error, stacktrace);
      },
      onDone: () {
        _log.warning('[async-client][SSETransport] done');
        _signalSSEClose(0, 'done');
      },
      cancelOnError: true,
    );

    _log.finest('[async-client][SSETransport] connect() called');

    return true;
  }

  void _handleNewToken(ChannelMessage message) {
    _log.finest('[async-client][SSETransport] new token received');
    currentToken = message.payload;
    _config.channelSecret = currentToken;
  }

  void _onResponseError(error, stackTrace) {
    _log.severe('[async-client][SSETransport] response error $error');

    _signalSSEError({'origin': 'sse', 'code': 1, 'message': error});
  }

  int extractCode(String stringCode) {
    return int.tryParse(stringCode) ?? 0;
  }

  void _onData(SSEModel data) {
    _log.finest('[async-client][SSETransport] Received raw from Server: $data');
    var message = msgDecoder.decode(data.data);
    _log.finest('[async-client][SSETransport] Received Decoded: $message');

    if (message.event == RESPONSE_NEW_TOKEN) {
      _handleNewToken(message);
    } 

    if (_messageDedup.contains(message.messageId??'')) {
      _log.warning('[async-client][SSETransport] message deduped: ${message.messageId}');

      return;
    } else {
      _messageDedup.add(message.messageId??'');
      _broadCastStream.add(message);
    }

  }

  String sseUrl() {
    String url = '';
    if (_config.sseUrl != null) {
      url = _config.sseUrl ?? '';
      url = '$url?channel=${_config.channelRef}';
      _log.info('[async-client][SSETransport] url is $url');
    }
    else {
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
    await _eventStreamSub?.cancel();
    _eventStreamSub = null;
    _eventSource = null;
    SSEClient.unsubscribeFromSSE();
    _log.info('[async-client][SSETransport] disconnect() finished');    
    
    return;
  }
}
