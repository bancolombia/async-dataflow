import 'package:app_async_flutter/application/app_config.dart';
import 'package:app_async_flutter/domain/model/channel_credentials.dart';
import 'package:app_async_flutter/domain/model/gateway/async_client_gateway.dart';
import 'package:channel_sender_client/channel_sender_client.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ResponsesNotifier extends ChangeNotifier {
  List<String> responses = [];
  void addResponse(String response) {
    responses.add(response);
    notifyListeners();
  }

  void clean() {
    responses.clear();
    notifyListeners();
  }
}

class AsyncClientService extends InheritedWidget {
  AsyncClientService(
      {Key? key,
      required this.child,
      required this.eventListen,
      required this.asyncClientGateway,
      required this.appConfig})
      : super(key: key, child: child);

  @override
  final Widget child;

  final String eventListen;
  late AsyncClient asyncClient;
  final AsyncClientGateway asyncClientGateway;

  late SharedPreferences prefs;
  ResponsesNotifier responsesNotifier = ResponsesNotifier();
  final AppConfig appConfig;

  void _handleEvent(dynamic result) {
    responsesNotifier.addResponse(
        "Message from async dataflow, payload: ${result.payload} correlationId: ${result.correlationId}");
  }

  static AsyncClientService? of(BuildContext context) {
    return context.findAncestorWidgetOfExactType<AsyncClientService>();
  }

  void closeSession() async {
    await deleteChannelCreated();
    asyncClient.disconnect();
  }

  Future<void> deleteChannelCreated() async {
    await prefs.remove('channelRef');
    await prefs.remove('channelSecret');
  }

  Future<void> initAsyncClient() async {
    prefs = await SharedPreferences.getInstance();
    ChannelCredential? channelCredential = await _requestChannelCredentials();
    if (channelCredential != null) {
      final conf = AsyncConfig(
          socketUrl: appConfig.socketUrl,
          enableBinaryTransport: false,
          channelRef: channelCredential.channelRef,
          channelSecret: channelCredential.channelSecret,
          heartbeatInterval: appConfig.heartbeatInterval,
          maxRetries: appConfig.maxRetries);

      asyncClient = AsyncClient(conf).connect();
      asyncClient.subscribeTo(eventListen, (eventResult) {
        _handleEvent(eventResult);
      }, onError: (err) {
        _handleEvent(err);
      });
    } else {
      throw Exception("AsyncClient could not be initialized");
    }
  }

  Future<ChannelCredential?> _requestChannelCredentials() async {
    ChannelCredential? channelCredential;
    if (hasChannelCreated()) {
      return getChannelCreated();
    }
    channelCredential = await asyncClientGateway.getCredentials();
    print(channelCredential!.channelRef);
    persistCredentials(channelCredential);
    return channelCredential;
  }

  bool hasChannelCreated() {
    return (prefs.getString('channelRef') != null &&
        prefs.getString('channelSecret') != null);
  }

  ChannelCredential getChannelCreated() {
    return ChannelCredential(
        channelRef: prefs.getString('channelRef')!,
        channelSecret: prefs.getString('channelSecret')!);
  }

  void persistCredentials(ChannelCredential? channelCredential) async {
    if (channelCredential != null) {
      await prefs.setString('channelRef', channelCredential.channelRef);
      await prefs.setString('channelSecret', channelCredential.channelSecret);
    }
  }

  @override
  bool updateShouldNotify(AsyncClientService oldWidget) {
    return true;
  }
}
