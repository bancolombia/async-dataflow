import 'package:app_async_flutter/application/app_config.dart';
import 'package:app_async_flutter/infraestructure/notifier/log_notifier.dart';
import 'package:app_async_flutter/my_app.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:logging/logging.dart';

class Setup {
  static AppConfig getApp() {
    var env = dotenv.env;
    Logger.root.level = Level.INFO;
    LogNotifier logNotifier = LogNotifier();
    Logger.root.onRecord.listen((record) {
      var log = '${record.level.name}: ${record.time}: ${record.message}';
      logNotifier.setLog(log);
      print(log);
    });
    return AppConfig(
      businessUrl: env['apiBusiness'] ?? 'http://localhost:8080/api',
      heartbeatInterval: int.parse(env['version'] ?? '2500'),
      socketUrl: dotenv.env['socketUrl'] ?? 'ws://localhost:8082/ext/socket',
      logNotifier: logNotifier,
      child: const MyApp(),
    );
  }
}
