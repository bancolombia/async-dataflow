import 'package:app_async_flutter/async_client_service.dart';
import 'package:app_async_flutter/ui/atoms/button.dart';
import 'package:app_async_flutter/ui/atoms/delay_field.dart';
import 'package:flutter/material.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);
  final String title;

  @override
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  List<String> responses = [];
  TextEditingController textEditingController = TextEditingController();

  @override
  void initState() {
    super.initState();
    setState(() {
      textEditingController.text = "250";
    });
    AsyncClientService.of(context)!.initAsyncClient();
  }

  @override
  void dispose() {
    AsyncClientService.of(context)!.closeSession();
    super.dispose();
  }

  void _callAsyncBackend() {
    int start = DateTime.now().millisecondsSinceEpoch;

    AsyncClientService.of(context)!
        .asyncClientGateway
        .callBusinessUseCase(
            AsyncClientService.of(context)!.prefs.getString("channelRef") ?? "",
            int.tryParse(textEditingController.text) ?? 100)
        .then((value) => responses.add(
            "Get empty response after ${DateTime.now().millisecondsSinceEpoch - start} ms"));
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
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            DelayField(textEditingController: textEditingController),
            const SizedBox(
              height: 20,
            ),
            Button(callback: _callAsyncBackend),
            const SizedBox(
              height: 20,
            ),
            ...List.generate(
                responses.length, (index) => Text(responses[index]))
          ],
        ),
      ),
    );
  }
}
