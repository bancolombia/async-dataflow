import 'package:flutter/material.dart';

import '../../async_client_service.dart';

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
  void dispose() {
    asyncClientService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    asyncClientService = AsyncClientService.of(context)!;
    homeHelper = HomeHelper(asyncClientService);

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Card(
            color: const Color(0xFF1c2430), // color oscuro de fondo
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Delay in ms',
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: textEditingController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 12),
                      filled: true,
                      fillColor:
                          const Color(0xFF2B2F3A), // color oscuro de fondo
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  AnimatedBuilder(
                    animation: asyncClientService.currentTransportNotifier,
                    builder: (context, _) {
                      return Row(
                        children: [
                          const Text(
                            'Current transport: ',
                          ),
                          Chip(
                            label: Text(
                              asyncClientService
                                  .currentTransportNotifier.currentTransport,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      OutlinedButton(
                        child: const Row(
                          children: [
                            Icon(Icons.play_arrow),
                            SizedBox(width: 5),
                            Text(
                              "Request",
                              style: TextStyle(fontSize: 16),
                            ),
                          ],
                        ),
                        onPressed: () =>
                            homeHelper.callAsyncBackend(textEditingController),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton(
                        child: const Row(
                          children: [
                            Icon(Icons.refresh),
                            SizedBox(width: 5),
                            Text(
                              "Reconnect",
                              style: TextStyle(fontSize: 16),
                            ),
                          ],
                        ),
                        onPressed: () => homeHelper.connect(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      OutlinedButton(
                        child: const Row(
                          children: [
                            Icon(
                              Icons.swap_horiz_outlined,
                            ),
                            SizedBox(width: 5),
                            Text(
                              "Switch Prot",
                              style: TextStyle(fontSize: 16),
                            ),
                          ],
                        ),
                        onPressed: () => homeHelper.switchProtocols(),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton(
                          child: const Row(
                            children: [
                              Icon(
                                Icons.stop,
                              ),
                              SizedBox(width: 5),
                              Text(
                                "Disconn",
                                style: TextStyle(fontSize: 16),
                              ),
                            ],
                          ),
                          onPressed: () => homeHelper.disconnect(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.delete_forever_outlined,
                        ),
                        SizedBox(width: 5),
                        Text(
                          "Clean Logs",
                          style: TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                    onPressed: () =>
                        asyncClientService.responsesNotifier.clean(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: AnimatedBuilder(
              animation: asyncClientService.responsesNotifier,
              builder: (context, _) {
                var data = asyncClientService.responsesNotifier.responses;
                return ListView.builder(
                  itemCount: data.length,
                  itemBuilder: (context, index) => ListTile(
                    title: Text(
                      data[index],
                    ),
                    textColor: data[index].contains("empty")
                        ? Colors.white54
                        : Colors.white,
                  ),
                );
              },
            ),
          ),
          const SizedBox(
            width: 10,
          ),
        ],
      ),
    );
  }
}
