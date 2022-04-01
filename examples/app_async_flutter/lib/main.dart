import 'package:app_async_flutter/api_service.dart';
import 'package:app_async_flutter/async_client_service.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);
  final String title = 'Consumer Async Data Flow';

  Widget build(BuildContext context) {
    return AsyncClientService(
      eventListen: "businessEvent",
      child: MaterialApp(
        title: title,
        theme: ThemeData(
          primarySwatch: Colors.blue,
        ),
        home: MyHomePage(title: title),
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key? key, required this.title}) : super(key: key);
  final String title;

  @override
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  List<String> responses = [];
  TextEditingController textEditingController = new TextEditingController();

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
    ApiService.callBusinessUseCase('http://localhost:8080/api',
        int.tryParse(textEditingController.text) ?? 100);
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
            TextField(
              controller: textEditingController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                border: UnderlineInputBorder(),
                icon: Icon(Icons.lock_clock_outlined),
                labelText: "Delay service",
              ),
            ),
            const SizedBox(
              height: 20,
            ),
            submitButton(context),
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

  Container submitButton(BuildContext context) {
    return Container(
        decoration: BoxDecoration(
            color: Colors.amber, borderRadius: BorderRadius.circular(15)),
        child: TextButton(
          onPressed: () {
            _callAsyncBackend();
          },
          child: Text("Generate Request",
              style: Theme.of(context).textTheme.bodyText1),
        ));
  }
}
