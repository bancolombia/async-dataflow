import 'package:app_async_flutter/async_client_service.dart';
import 'package:app_async_flutter/ui/atoms/button.dart';
import 'package:app_async_flutter/ui/atoms/delay_field.dart';
import 'package:app_async_flutter/ui/helpers/home_helper.dart';
import 'package:app_async_flutter/ui/pages/log_viewer.dart';
import 'package:flutter/material.dart';

import '../../application/app_config.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late AsyncClientService asyncClientService;
  late HomeHelper homeHelper;
  TextEditingController textEditingController = TextEditingController();

  @override
  void initState() {
    super.initState();
    asyncClientService = AsyncClientService.of(context)!;
    homeHelper = HomeHelper(context);
    textEditingController.text = "250";

    asyncClientService.initAsyncClient();
  }

  @override
  void dispose() {
    asyncClientService.closeSession();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            DelayField(textEditingController: textEditingController),
            const SizedBox(height: 10),
            Row(
              children: [
                Button(
                    text: "Generate Request",
                    onTap: () =>
                        homeHelper.callAsyncBackend(textEditingController)),
                const SizedBox(width: 10),
                Button(text: "Re-Connect", onTap: () => homeHelper.connect()),
                const SizedBox(width: 10),
                Button(
                    text: "Disconnect", onTap: () => homeHelper.disconnect()),
              ],
            ),
            const SizedBox(height: 10),
            const Text("Response"),
            const SizedBox(height: 10),
            Button(
                text: "Clean Logs",
                onTap: () => asyncClientService.responsesNotifier.clean()),
            const SizedBox(height: 10),
            Expanded(
              child: AnimatedBuilder(
                  animation: asyncClientService.responsesNotifier,
                  builder: (context, _) {
                    var data = asyncClientService.responsesNotifier.responses;
                    return ListView.builder(
                        itemCount: data.length,
                        itemBuilder: (context, index) => ListTile(
                              title: Text(data[index]),
                              textColor: data[index].contains("empty")
                                  ? Colors.black45
                                  : Colors.black,
                            ));
                  }),
            ),
            const SizedBox(width: 10),
            const Text("Captured Console Logs"),
            Button(
                text: "Clean Logs",
                onTap: () => AppConfig.of(context).logNotifier.clean()),
            const SizedBox(height: 10),
            const Expanded(child: LogViewer()),
          ],
        ),
      ),
    );
  }
}
