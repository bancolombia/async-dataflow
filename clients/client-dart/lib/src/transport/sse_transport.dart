import 'dart:async';

import 'package:flutter_client_sse/constants/sse_request_type_enum.dart';
import 'package:flutter_client_sse/flutter_client_sse.dart';
import 'package:logging/logging.dart';

import '../../channel_sender_client.dart';
import '../decoder/json_decoder.dart';
import '../decoder/message_decoder.dart';
import '../utils/retry_timer.dart';
import 'transport.dart';

class SSETransport implements Transport {
  MessageDecoder msgDecoder = JsonDecoder();
  static const String EVENT_KIND_USER = 'user_event';
  static const String EVENT_KIND_SYSTEM = 'system_event';
  static const String RESPONSE_NEW_TOKEN = ':n_token';

  final _log = Logger('SSETransport');

  final Function(int, String) _signalSSEClose;
  final Function(Object) _signalSSEError;
  final AsyncConfig _config;

  late String currentToken;
  late RetryTimer _connectRetryTimer;
  Stream<SSEModel>? _eventSource;
  late StreamController<ChannelMessage> _localStream;
  StreamSubscription<dynamic>? _streamSub;
  late Stream<ChannelMessage> _broadCastStream; // subscribers stream of data

  final int _errorCount = 0;

  SSETransport(
    this._signalSSEClose,
    this._signalSSEError,
    this._config,
  ) {
    currentToken = _config.channelSecret;
    _connectRetryTimer = RetryTimer(
      () async {
        connect();

        return 1;
      },
      maxRetries: _config.maxRetries,
    );
  }
  @override
  TransportType name() {
    return TransportType.sse;
  }

  set eventSource(Stream<SSEModel> value) {
    _eventSource = value;
  }

  set localStream(StreamController<ChannelMessage> value) {
    _localStream = value;
  }

  @override
  void connect() {
    _eventSource ??= SSEClient.subscribeToSSE(
      method: SSERequestType.GET,
      url: sseUrl(),
      header: {
        'Authorization': 'Bearer $currentToken',
      },
      maxRetry: _config.maxRetries ?? 5,
    );

    _localStream = StreamController(onListen: _onListen);
    _broadCastStream = _localStream.stream
        .map((message) {
          var kind = EVENT_KIND_SYSTEM;
          if (message.event == RESPONSE_NEW_TOKEN) {
            _handleNewToken(message);
          } else {
            kind = EVENT_KIND_USER;
          }

          return [message, kind];
        })
        .where((data) =>
            data.last ==
            EVENT_KIND_USER) // only allows passing user events from this point
        .map((data) {
          return data.first as ChannelMessage;
        });
    _broadCastStream = _broadCastStream.asBroadcastStream();

    _log.finest('async-client. sse connect() called');
  }

  void _handleNewToken(ChannelMessage message) {
    currentToken = message.payload;
  }

  void _onListen() {
    _streamSub = subscribe(cancelOnErrorFlag: true);
  }

  StreamSubscription subscribe({required bool cancelOnErrorFlag}) {
    return _eventSource!.listen(
      (data) {
        _onData(data);
      },
      onError: (error, stacktrace) {
        _onResponseError(error, stacktrace);
      },
      onDone: () {
        _log.info('async-client. sse done');
        _signalSSEClose(0, 'done');
      },
      cancelOnError: cancelOnErrorFlag,
    );
  }

  Future<void> _onResponseError(error, stackTrace) async {
    _log.finest('async-client. [Sse response error] $error, $stackTrace');

    _log.info('async-client. sse stopping retries');
    _signalSSEError({'origin': 'sse', 'code': 1, 'message': error});
  }

  int extractCode(String stringCode) {
    return int.tryParse(stringCode) ?? 0;
  }

  void _onData(SSEModel data) {
    _log.finest('async-client. Received raw from Server: $data');
    var decoded = msgDecoder.decode(data.data);
    _log.finest('async-client. Received Decoded: $decoded');
    _localStream.add(decoded);
  }

  String sseUrl() {
    String url = _config.socketUrl;
    if (url.startsWith('ws')) {
      url = url.replaceFirstMapped('ws', (match) => 'http');
    }
    url = '$url/ext/sse?channel=${_config.channelRef}';

    return url;
  }

  @override
  bool isOpen() => false;

  @override
  // TODO: implement stream
  Stream<ChannelMessage> get stream => _broadCastStream;

  @override
  Future<void> disconnect() {
    _log.info('async-client. sse disconnect() called');

    return Future.value();
  }
}
