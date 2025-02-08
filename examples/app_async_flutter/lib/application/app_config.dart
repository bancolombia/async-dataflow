import 'package:app_async_flutter/infrastructure/notifier/log_notifier.dart';
import 'package:flutter/material.dart';

class AppConfig extends InheritedWidget {
  AppConfig({
    Key? key,
    required this.businessUrl,
    required this.socketUrl,
    required this.heartbeatInterval,
    required this.maxRetries,
    required this.logNotifier,
    required Widget child,
  }) : super(key: key, child: child);

  String businessUrl;
  String socketUrl;
  int heartbeatInterval;
  int maxRetries;
  LogNotifier logNotifier;

  static AppConfig of(BuildContext context) =>
      context.findAncestorWidgetOfExactType<AppConfig>()!;

  @override
  bool updateShouldNotify(InheritedWidget oldWidget) => false;

  void updateConfig(
      {required int heartbeatInterval,
      required int maxRetries,
      required String socketUrl,
      required String businessUrl}) {
    this.heartbeatInterval = heartbeatInterval;
    this.maxRetries = maxRetries;
    this.socketUrl = socketUrl;
    this.businessUrl = businessUrl;
  }
}
