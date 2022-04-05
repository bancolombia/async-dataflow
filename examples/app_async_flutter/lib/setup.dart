import 'package:app_async_flutter/application/app_config.dart';
import 'package:app_async_flutter/my_app.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class Setup {
  static AppConfig getApp() {
    String businessUrl =
        dotenv.env['apiBusiness'] ?? 'http://localhost:8080/api';
    int heartbeatInterval = int.parse(dotenv.env['version'] ?? '2500');
    String socketUrl =
        dotenv.env['socketUrl'] ?? 'ws://localhost:8082/ext/socket';

    return AppConfig(
      businessUrl: businessUrl,
      heartbeatInterval: heartbeatInterval,
      socketUrl: socketUrl,
      child: const MyApp(),
    );
  }
}
