import 'package:app_async_flutter/application/app_config.dart';
import 'package:app_async_flutter/async_client_service.dart';
import 'package:app_async_flutter/infrastructure/driven_adapter/api_service.dart';
import 'package:app_async_flutter/ui/pages/home_page.dart';
import 'package:flutter/material.dart';

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);
  final String title = 'Consumer Async Data Flow';

  @override
  Widget build(BuildContext context) {
    return AsyncClientService(
      eventListen: const [
        'ch-ms-async-callback.svp.reply',
        'businessEvent',
        ':n_token'
      ],
      asyncClientGateway: ApiService(context),
      appConfig: AppConfig.of(context),
      child: MaterialApp(
        title: title,
        theme: ThemeData(
          primarySwatch: Colors.deepPurple,
          scaffoldBackgroundColor: const Color(0xFF121722),
          textTheme: const TextTheme(
            bodySmall: TextStyle(color: Colors.white),
            bodyMedium: TextStyle(color: Colors.white),
            bodyLarge: TextStyle(color: Colors.white),
          ),
          inputDecorationTheme: const InputDecorationTheme(
            labelStyle: TextStyle(color: Colors.white),
            hintStyle: TextStyle(color: Colors.white54),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.white54),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.grey),
            ),
            iconColor: Colors.white,
          ),
          textSelectionTheme: const TextSelectionThemeData(
            cursorColor: Colors.white,
            selectionColor: Colors.white24,
            selectionHandleColor: Colors.white,
          ),
          outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
            ),
          ),
        ),
        home: MyHomePage(title: title),
      ),
    );
  }
}
