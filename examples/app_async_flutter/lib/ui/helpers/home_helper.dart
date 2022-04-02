import 'package:app_async_flutter/async_client_service.dart';
import 'package:flutter/material.dart';

class HomeHelper {
  late final AsyncClientService asyncClientService;
  HomeHelper(BuildContext context) {
    asyncClientService = AsyncClientService.of(context)!;
  }
  void callAsyncBackend(textEditingController) {
    int start = DateTime.now().millisecondsSinceEpoch;

    asyncClientService.asyncClientGateway
        .callBusinessUseCase(
            asyncClientService.prefs.getString("channelRef") ?? "",
            int.tryParse(textEditingController.text) ?? 100)
        .then((value) => asyncClientService.responsesNotifier.addResponse(
            "Get empty response after ${DateTime.now().millisecondsSinceEpoch - start} ms"));
  }
}
