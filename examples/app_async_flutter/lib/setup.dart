import 'package:app_async_flutter/application/app_config.dart';
import 'package:app_async_flutter/infrastructure/notifier/log_notifier.dart';
import 'package:app_async_flutter/my_app.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:logging/logging.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Setup {
  static AppConfig getApp(SharedPreferences prefs) {
    var env = dotenv.env;
    LogNotifier logNotifier = configureLogger();
    prefs.getString('apiBusiness');
    return AppConfig(
      businessUrl: getEnvironment(prefs, 'apiBusiness'),
      heartbeatInterval: int.parse(getEnvironment(prefs, 'heartbeatInterval')),
      maxRetries: int.parse(getEnvironment(prefs, 'maxRetries')),
      socketUrl: getEnvironment(prefs, 'socketUrl'),
      logNotifier: logNotifier,
      child: const MyApp(),
    );
  }

  static String getEnvironment(
    SharedPreferences prefs,
    String key,
  ) {
    var businessUrl = prefs.getString(key);
    if (businessUrl == null) {
      businessUrl = dotenv.env[key]!;
      prefs.setString(key, businessUrl);
    }
    print(businessUrl);

    return businessUrl;
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
      // debugPrint(log);
    });
    return logNotifier;
  }
}
