import 'package:flutter/material.dart';

import '../../application/app_config.dart';
import '../../infrastructure/notifier/log_notifier.dart';
import '../atoms/button.dart';

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
    logNotifier = AppConfig.of(context).logNotifier;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      logNotifier?.addListener(() {
        if (mounted) {
          setState(() {});
        }
      });
    });
  }

  @override
  void dispose() {
    // TODO: implement dispose
    super.dispose();
    logNotifier?.removeListener(() {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Button(
              text: "Clean Logs",
              onTap: () => AppConfig.of(context).logNotifier.clean()),
          const SizedBox(height: 10),
          Expanded(
            child: ListView.separated(
              itemCount: logNotifier?.logs.length ?? 0,
              separatorBuilder: (context, index) =>
                  const SizedBox(height: 16), // Espacio entre elementos
              itemBuilder: (context, index) {
                return SelectableText(logNotifier?.logs[index] ?? '');
              },
            ),
          ),
        ],
      ),
    );
  }
}
