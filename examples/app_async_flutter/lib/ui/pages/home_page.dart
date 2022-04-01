import 'package:app_async_flutter/async_client_service.dart';
import 'package:app_async_flutter/ui/atoms/button.dart';
import 'package:app_async_flutter/ui/atoms/delay_field.dart';
import 'package:flutter/material.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late AsyncClientService asyncClientService;
  TextEditingController textEditingController = TextEditingController();

  @override
  void initState() {
    super.initState();
    asyncClientService = AsyncClientService.of(context)!;
    setState(() {
      textEditingController.text = "250";
    });
    asyncClientService.initAsyncClient();
  }

  @override
  void dispose() {
    asyncClientService.closeSession();
    super.dispose();
  }

  void _callAsyncBackend() {
    int start = DateTime.now().millisecondsSinceEpoch;

    asyncClientService.asyncClientGateway
        .callBusinessUseCase(
            asyncClientService.prefs.getString("channelRef") ?? "",
            int.tryParse(textEditingController.text) ?? 100)
        .then((value) => asyncClientService.responses.add(
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
            ...List.generate(asyncClientService.responses.length,
                (index) => Text(asyncClientService.responses[index]))
          ],
        ),
      ),
    );
  }
}
