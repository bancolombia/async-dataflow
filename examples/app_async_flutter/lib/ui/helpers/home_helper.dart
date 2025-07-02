import 'package:app_async_flutter/async_client_service.dart';
import 'package:flutter/material.dart';

class HomeHelper {
  final AsyncClientService asyncClientService;

  HomeHelper(this.asyncClientService);

  void callAsyncBackend(TextEditingController textEditingController) {
    int start = DateTime.now().millisecondsSinceEpoch;

    asyncClientService.asyncClientGateway
        .callBusinessUseCase(
            asyncClientService.prefs.getString("channelRef") ?? "",
            asyncClientService.prefs.getString("userRef") ?? "",
            int.tryParse(textEditingController.text) ?? 100)
        .then((value) => asyncClientService.responsesNotifier.addResponse(
            "Get empty response after ${DateTime.now().millisecondsSinceEpoch - start} ms"));
  }

  Future<void> disconnect() async {
    await asyncClientService.closeSession();
  }

  Future<void> connect() async {
    await asyncClientService.initAsyncClient();
  }

  Future<void> switchProtocols() async {
    await asyncClientService.switchProtocols();
  }
}
