import 'package:flutter/material.dart';

class AppConfig extends InheritedWidget {
  const AppConfig({
    Key? key,
    required this.businessUrl,
    required this.socketUrl,
    required this.heartbeatInterval,
    required Widget child,
  }) : super(key: key, child: child);

  final String businessUrl;
  final String socketUrl;
  final int heartbeatInterval;

  static AppConfig of(BuildContext context) =>
      context.findAncestorWidgetOfExactType<AppConfig>()!;

  @override
  bool updateShouldNotify(InheritedWidget oldWidget) => false;
}
