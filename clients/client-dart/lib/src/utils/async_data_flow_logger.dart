import 'package:logger/logger.dart';
import 'package:logging/logging.dart' as dft_logging;

class AsyncDataFlowLogger {
  static final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 2,
      errorMethodCount: 8,
      lineLength: 120,
      colors: true,
      printEmojis: true,
      dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
    ),
  );

  static void setup() {
    dft_logging.Logger.root.level = dft_logging.Level.ALL;

    dft_logging.Logger.root.onRecord.listen((record) {
      _convertAndLog(record);
    });
  }

  static void _convertAndLog(dft_logging.LogRecord record) {
    final message = '${record.loggerName}: ${record.message}';

    // Convertir niveles del logging estándar a logger
    switch (record.level.name) {
      case 'SEVERE':
        _logger.e(
          message,
          error: record.error,
          stackTrace: record.stackTrace,
        );
        break;
      case 'WARNING':
        _logger.w(message);
        break;
      case 'INFO':
        _logger.i(message);
        break;
      case 'CONFIG':
      case 'FINE':
        _logger.d(message);
        break;
      case 'FINER':
      case 'FINEST':
        _logger.t(message);
        break;
      default:
        _logger.i(message);
    }
  }
}
