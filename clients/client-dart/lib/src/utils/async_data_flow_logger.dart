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
      printTime: true,
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

    switch (record.level.name) {
      case 'SEVERE':
        _logger.e(
          message,
          record.error,
          record.stackTrace,
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
      case 'FINER':
      case 'FINEST':
        _logger.d(message);
        break;
      default:
        _logger.i(message);
    }
  }
}
