import 'package:app_async_flutter/infraestructure/notifier/log_notifier.dart';
import 'package:flutter/material.dart';

class AppConfig extends InheritedWidget {
  const AppConfig({
    Key? key,
    required this.businessUrl,
    required this.socketUrl,
    required this.heartbeatInterval,
    required this.maxRetries,
    required this.logNotifier,
    required Widget child,
  }) : super(key: key, child: child);

  final String businessUrl;
  final String socketUrl;
  final int heartbeatInterval;
  final int maxRetries;
  final LogNotifier logNotifier;

  static AppConfig of(BuildContext context) =>
      context.findAncestorWidgetOfExactType<AppConfig>()!;

  @override
  bool updateShouldNotify(InheritedWidget oldWidget) => false;
}
