import 'package:flutter/material.dart';

import '../../application/app_config.dart';
import '../../infraestructure/notifier/log_notifier.dart';

class LogViewer extends StatefulWidget {
  const LogViewer({super.key});

  @override
  State<LogViewer> createState() => _LogViewerState();
}

class _LogViewerState extends State<LogViewer> {
  LogNotifier? logNotifier;
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
    logNotifier?.dispose();
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      logNotifier?.addListener(() {
        setState(() {});
      });
    });
    logNotifier = AppConfig.of(context).logNotifier;

    return ListView.separated(
      itemCount: logNotifier?.logs.length ?? 0,
      separatorBuilder: (context, index) =>
          const SizedBox(height: 16), // Espacio entre elementos
      itemBuilder: (context, index) {
        return Text(logNotifier?.logs[index] ?? '');
      },
    );
  }
}
