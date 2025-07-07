import 'package:logging/logging.dart';

import '../async_config.dart';
import '../exceptions/exceptions.dart';
import '../model/channel_message.dart';
import '../utils/utils.dart';

import 'transport.dart';

import 'types/noop_transport.dart';
import 'types/sse_transport.dart';
import 'types/ws_transport.dart';

/// Default Transport Strategy.
///
/// This strategy is responsible for selecting the transport
/// to be used by the client.
/// It also provides the ability to iterate over the transports
/// in case of failure.
class DefaultTransportStrategy {
  static const int RETRY_DEFAULT_MAX_RETRIES = 5;

  late int retries = 1;

  late Transport _currentTransport;
  late List<TransportType> _transportTypes;
  late Map<TransportType, dynamic> _transportBuilders;

  final _log = Logger('DefaultTransportStrategy');
  final AsyncConfig _config;
  final Function(int, String) _signalClose;
  final Function(Object) _signalError;

  int _currentTransportIndex = 0;

  DefaultTransportStrategy(
    this._config,
    this._signalClose,
    this._signalError,
  ) {
    _transportBuilders = _defaultTransportBuilders();
    _build();
  }

  DefaultTransportStrategy.custom(
    this._config,
    this._signalClose,
    this._signalError,
    this._transportBuilders,
  ) {
    _build();
  }

  void _build() {
    _transportTypes = _config.transports;
    _log.finest(
      '[async-client][DefaultTransportStrategy] selected transports $_transportTypes',
    );
    if (_transportTypes.isEmpty) {
      throw InvalidStrategyException(
        'Invalid or empty transport list for the strategy',
      );
    }
    // ignore: prefer-first-or-null
    _currentTransport = _buildTransport(_transportTypes.first);
  }

  Future<bool> connect() async {
    _log.finest(
      '[async-client][DefaultTransportStrategy] Calling connect on transport ${_currentTransport.name()}',
    );

    var connected = await _currentTransport.connect();

    while (!connected &&
        retries <= (_config.maxRetries ?? RETRY_DEFAULT_MAX_RETRIES)) {
      _log.severe(
        '[async-client][DefaultTransportStrategy] Transport could not get a connection retry #$retries',
      );
      int wait = expBackoff(400, 2000, retries);
      retries++;
      // ignore: avoid-ignoring-return-values
      await Future.delayed(Duration(milliseconds: wait));

      // Only iterate transport if we have multiple transport types
      if (_transportTypes.length > 1) {
        await iterateTransport();
      }

      connected = await _currentTransport.connect();
    }

    //reset
    retries = 1;

    return connected;
  }

  Future<void> disconnect() async {
    await _currentTransport.disconnect();
    _currentTransport = NoopTransport();
  }

  Future<void> sendInfo(String message) async {
    _currentTransport.send('Info::$message');
  }

  Transport getTransport() {
    return _currentTransport;
  }

  Future<TransportType> iterateTransport() async {
    _log.finest('[async-client][DefaultTransportStrategy] iterating transport');

    if (_transportTypes.isEmpty) {
      throw InvalidStrategyException(
        'Invalid or empty transport list for the strategy',
      );
    }

    if (_transportTypes.length == 1) {
      _log.warning(
        '[async-client][DefaultTransportStrategy] one transport strategy can not iterate',
      );
      _currentTransportIndex = 0;

      return _currentTransport.name();
    } else {
      _currentTransportIndex++;
      if (_currentTransportIndex >= _transportTypes.length) {
        _currentTransportIndex = 0;
      }

      await _currentTransport.disconnect();

      _currentTransport =
          _buildTransport(_transportTypes[_currentTransportIndex]);

      _log.finest(
        '[async-client][DefaultTransportStrategy] iterating ended, new transport = ${_currentTransport.name()}',
      );

      return _currentTransport.name();
    }
  }

  Stream<ChannelMessage> get stream => getTransport().stream;

  Map<TransportType, dynamic> _defaultTransportBuilders() {
    return <TransportType, dynamic>{
      TransportType.ws: () => WSTransport(
            _signalClose,
            _signalError,
            _config,
          ),
      TransportType.sse: () => SSETransport(
            _signalClose,
            _signalError,
            _config,
          ),
    };
  }

  Transport _buildTransport(TransportType transportType) {
    _log.finest(
      '[async-client][DefaultTransportStrategy] Building transport of type ${transportType.toString()}',
    );

    if (_transportBuilders.containsKey(transportType)) {
      return _transportBuilders[transportType]!();
    } else {
      throw InvalidStrategyException('Invalid transport type $transportType');
    }
  }
}
