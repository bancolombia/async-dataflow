import 'package:logging/logging.dart';
import '../async_config.dart';
import '../model/channel_message.dart';
import 'invalid_strategy_exception.dart';
import 'noop_transport.dart';
import 'sse_transport.dart';
import 'transport.dart';
import 'ws_transport.dart';

/// Default Transport Strategy.
/// 
/// This strategy is responsible for selecting the transport
/// to be used by the client.
/// It also provides the ability to iterate over the transports
/// in case of failure.
class DefaultTransportStrategy {

  final _log = Logger('DefaultTransportStrategy');
  
  final AsyncConfig _config;
  final Function(int, String) _signalClose;
  final Function(Object) _signalError;

  int _currentTransportIndex = 0;
  late Transport _currentTransport;
  late List<TransportType> _transportTypes;

  DefaultTransportStrategy(this._config,
    this._signalClose,
    this._signalError,) {
      _transportTypes = _config.transports;
      _log.finest('[async-client][DefaultTransportStrategy] selected transports $_transportTypes');      
      if (_transportTypes.isEmpty) {
        throw InvalidStrategyException('Invalid or empty transport list for the strategy');
      }
      _currentTransport = _transportTypes.first == TransportType.ws ? _buildWSTransport() : _buildSSETransport();
    }

  Transport getTransport() {
    return _currentTransport;
  }

  Future<void> iterateTransport() async {
    _log.finest('[async-client][DefaultTransportStrategy] iterating transport');      

    if (_transportTypes.length == 1) {
      _log.warning('[async-client][DefaultTransportStrategy] one transport strategy can not iterate');
      _currentTransportIndex = 0;

      return;
    }

    _currentTransportIndex = _currentTransportIndex + 1;
    if (_currentTransportIndex >= _transportTypes.length) {
      _currentTransportIndex = 0;
    }
    _log.finest('[async-client][DefaultTransportStrategy] transport index iterated: $_currentTransportIndex');

    await _currentTransport.disconnect();
    _currentTransport = _transportTypes[_currentTransportIndex] == TransportType.ws ? _buildWSTransport() : _buildSSETransport();

    _log.finest('[async-client][DefaultTransportStrategy] iterating ended: = ${_currentTransport.name()}');      
  }
  
  Future<bool> connect() async {
    return await _currentTransport.connect();
  }

  Future<void> disconnect() async {
    await _currentTransport.disconnect();
    _currentTransport = NoopTransport();
  }

  Stream<ChannelMessage> get stream => getTransport().stream;

  Transport _buildWSTransport() {
    _log.finest('[async-client][DefaultTransportStrategy] Building transport of type $TransportType.ws');

    return WSTransport(
      _signalClose,
      _signalError,
      _config,
    );
  }

  Transport _buildSSETransport() {
    _log.finest('[async-client][DefaultTransportStrategy] Building transport of type $TransportType.sse');

    return SSETransport(
      _signalClose,
      _signalError,
      _config,
    );
  }
}