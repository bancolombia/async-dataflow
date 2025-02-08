import 'package:app_async_flutter/ui/atoms/button.dart';
import 'package:flutter/material.dart';

import '../../application/app_config.dart';
import '../../async_client_service.dart';
import '../../infrastructure/notifier/log_notifier.dart';
import '../atoms/input_field.dart';

class ConfigPage extends StatefulWidget {
  const ConfigPage({super.key});

  @override
  State<ConfigPage> createState() => _ConfigPageState();
}

class _ConfigPageState extends State<ConfigPage> {
  TextEditingController heartbeatController = TextEditingController();
  TextEditingController maxRetriesController = TextEditingController();
  TextEditingController apiBusinessController = TextEditingController();
  TextEditingController socketController = TextEditingController();
  late AsyncClientService asyncClientService;

  @override
  void initState() {
    super.initState();
    heartbeatController.text =
        AppConfig.of(context).heartbeatInterval.toString();
    maxRetriesController.text = AppConfig.of(context).maxRetries.toString();
    apiBusinessController.text = AppConfig.of(context).socketUrl;
    socketController.text = AppConfig.of(context).businessUrl;
  }

  @override
  Widget build(BuildContext context) {
    asyncClientService = AsyncClientService.of(context)!;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          InputField(
              textEditingController: heartbeatController,
              labelText: "Heartbeat delay in ms",
              icon: Icons.lock_clock_outlined),
          const SizedBox(height: 20),
          InputField(
              textEditingController: maxRetriesController,
              labelText: "max retries to connect",
              icon: Icons.plus_one),
          const SizedBox(height: 20),
          InputField(
              textEditingController: apiBusinessController,
              labelText: "Socket url",
              keyboardType: TextInputType.url,
              icon: Icons.connect_without_contact_sharp),
          const SizedBox(height: 20),
          InputField(
              textEditingController: socketController,
              labelText: "api Business url",
              keyboardType: TextInputType.url,
              icon: Icons.api),
          const SizedBox(height: 20),
          const Text('Show all logs'),
          Switch(
            value: AppConfig.of(context).logNotifier.level == LogLevel.all,
            onChanged: (value) {
              AppConfig.of(context)
                  .logNotifier
                  .setLevel(value ? LogLevel.all : LogLevel.info);
              setState(() {});
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('logs level saved'),
                ),
              );
            },
          ),
          const Text(
              'If you disable this option, will set the log level to info'),
          const SizedBox(height: 40),
          Button(
              onTap: () {
                AppConfig.of(context).updateConfig(
                    heartbeatInterval: int.parse(heartbeatController.text),
                    maxRetries: int.parse(maxRetriesController.text),
                    socketUrl: apiBusinessController.text,
                    businessUrl: socketController.text);
                asyncClientService.saveConfig();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                        'Configuration saved, remember that the current connection does not take the changes, disconnect and reconnect.'),
                  ),
                );
              },
              text: 'Save')
        ],
      ),
    );
  }
}
