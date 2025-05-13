import 'package:flutter/material.dart';

import '../../async_client_service.dart';
import '../atoms/button.dart';
import '../atoms/input_field.dart';
import '../helpers/home_helper.dart';

class RequestPage extends StatefulWidget {
  const RequestPage({super.key});

  @override
  State<RequestPage> createState() => _RequestPageState();
}

class _RequestPageState extends State<RequestPage> {
  late HomeHelper homeHelper;
  late AsyncClientService asyncClientService;
  TextEditingController textEditingController = TextEditingController();
  @override
  void initState() {
    super.initState();
    textEditingController.text = "250";
  }

  @override
  Widget build(BuildContext context) {
    asyncClientService = AsyncClientService.of(context)!;
    homeHelper = HomeHelper(context, asyncClientService);

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          InputField(
            textEditingController: textEditingController,
            labelText: "Delay in ms",
            icon: Icons.timelapse,
          ),
          const SizedBox(height: 10),
          AnimatedBuilder(
            animation: asyncClientService.currentTransportNotifier,
            builder: (context, _) {
              return Text('Current transport: ${asyncClientService.currentTransportNotifier.currentTransport}');
            },
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Button(
                  text: "Request",
                  onTap: () =>
                      homeHelper.callAsyncBackend(textEditingController)),
              const SizedBox(width: 10),
              Button(text: "Re-Connect", onTap: () => homeHelper.connect()),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Button(text: "Switch Prot", onTap: () => homeHelper.switchProtocols()),
              const SizedBox(width: 10),
              Button(text: "Disconnect", onTap: () => homeHelper.disconnect()),
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
        ],
      ),
    );
  }
}
