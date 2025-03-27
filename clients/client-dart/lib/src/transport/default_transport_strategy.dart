import 'package:logging/logging.dart';
import '../async_config.dart';
import '../model/channel_message.dart';
import '../utils/utils.dart';
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

  static const int RETRY_DEFAULT_MAX_RETRIES = 5;

  final _log = Logger('DefaultTransportStrategy');
  
  final AsyncConfig _config;
  final Function(int, String) _signalClose;
  final Function(Object) _signalError;

  int _currentTransportIndex = 0;
  late Transport _currentTransport;
  late List<TransportType> _transportTypes;
  late int retries = 1;

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
  
  Future<bool> connect() async {
    var connected =  await _currentTransport.connect();
    while (!connected && retries <= (_config.maxRetries ?? RETRY_DEFAULT_MAX_RETRIES)) {
      _log.severe('[async-client][DefaultTransportStrategy] Transport could not get a connection retry #$retries');
      int wait = Utils.expBackoff(400, 2000, retries);
      retries++;
      await Future.delayed(Duration(milliseconds: wait));
      await iterateTransport();
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

  Transport getTransport() {
    return _currentTransport;
  }

  Future<TransportType> iterateTransport() async {
    _log.finest('[async-client][DefaultTransportStrategy] iterating transport');      

    if (_transportTypes.isEmpty) {
      throw InvalidStrategyException('Invalid or empty transport list for the strategy');
    }

    if (_transportTypes.length == 1) {
      _log.warning('[async-client][DefaultTransportStrategy] one transport strategy can not iterate');
      _currentTransportIndex = 0;

      return _currentTransport.name();
    }
    else {

      _currentTransportIndex++;
      if (_currentTransportIndex >= _transportTypes.length) {
        _currentTransportIndex = 0;
      }

      await _currentTransport.disconnect();
      
      _currentTransport = _transportTypes[_currentTransportIndex] == TransportType.ws ? _buildWSTransport() : _buildSSETransport();

      _log.finest('[async-client][DefaultTransportStrategy] iterating ended, new transport = ${_currentTransport.name()}');  

      return _currentTransport.name();
    }

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