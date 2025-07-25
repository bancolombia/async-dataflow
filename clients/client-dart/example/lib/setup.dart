import 'package:app_async_flutter/application/app_config.dart';
import 'package:app_async_flutter/infrastructure/notifier/log_notifier.dart';
import 'package:app_async_flutter/my_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:logging/logging.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Setup {
  static AppConfig getApp(SharedPreferences prefs) {
    LogNotifier logNotifier = configureLogger();
    prefs.getString('apiBusiness');
    return AppConfig(
      businessUrl: getEnvironment(prefs, 'apiBusiness'),
      heartbeatInterval: int.parse(getEnvironment(prefs, 'heartbeatInterval')),
      maxRetries: int.parse(getEnvironment(prefs, 'maxRetries')),
      socketUrl: getEnvironment(prefs, 'socketUrl'),
      sseUrl: getEnvironment(prefs, 'sseUrl'),
      transports: getEnvironments(prefs, 'transports'),
      logNotifier: logNotifier,
      child: const MyApp(),
    );
  }

  static String getEnvironment(
    SharedPreferences prefs,
    String key,
  ) {
    var value = prefs.getString(key);
    if (value == null) {
      value = dotenv.env[key]!;
      prefs.setString(key, value);
    }
    debugPrint(value);

    return value;
  }

  static List<String> getEnvironments(
    SharedPreferences prefs,
    String key,
  ) {
    var value = prefs.getStringList(key);
    if (value == null) {
      value = dotenv.env[key]!.split(',');
      prefs.setStringList(key, value);
    }
    debugPrint(value.join(','));

    return value;
  }

  static LogNotifier configureLogger() {
    LogNotifier logNotifier = LogNotifier();
    logNotifier.addListener(() {
      Logger.root.level =
          logNotifier.level == LogLevel.all ? Level.FINEST : Level.INFO;
    });

    Logger.root.onRecord.listen((record) {
      var log = '${record.level.name}: ${record.time}: ${record.message}';
      logNotifier.setLog(log);
      debugPrint(log);
    });
    return logNotifier;
  }
}
