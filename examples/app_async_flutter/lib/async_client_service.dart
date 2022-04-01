import 'package:app_async_flutter/api_service.dart';
import 'package:app_async_flutter/channel_credentials.dart';
import 'package:channel_sender_client/adf_client.dart';
import 'package:dotenv/dotenv.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AsyncClientService extends InheritedWidget {
  AsyncClientService({Key? key, required this.child, required this.eventListen})
      : super(key: key, child: child);

  final Widget child;
  final String eventListen;

  late AsyncClient asyncClient;
  List<String> responses = [];
  late final prefs;
  late DotEnv env;

  void _handleEvent(String result) {
    print(result);
    responses.add(result);
  }

  static AsyncClientService? of(BuildContext context) {
    return context.findAncestorWidgetOfExactType<AsyncClientService>();
  }

  void closeSession() async {
    await prefs.remove('channelRef');
    await prefs.remove('channelSecret');
    asyncClient.disconnect();
  }

  Future<void> initAsyncClient() async {
    prefs = await SharedPreferences.getInstance();
    env = DotEnv(includePlatformEnvironment: true)..load();

    ChannelCredential? channelCredential = await _requestChannelCredentials();
    if (channelCredential != null) {
      final conf = AsyncConfig(
          socketUrl: env['socketUrl'] ?? 'ws://localhost:8082/ext/socket',
          enableBinaryTransport: false,
          channelRef: channelCredential.channelRef,
          channelSecret: channelCredential.channelSecret,
          heartbeatInterval: int.tryParse(env['heartbeatInterval']!) ?? 2500);

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
    channelCredential = await ApiService.getCredentials(
        env["apiBusiness"] ?? 'http://localhost:8080/api');
    persistCredentials(channelCredential);
    return channelCredential;
  }

  bool hasChannelCreated() {
    return (prefs.getString('channelRef') != null &&
        prefs.getString('channelSecret') != null);
  }

  ChannelCredential getChannelCreated() {
    return ChannelCredential(
        channelRef: prefs.getString('channelRef'),
        channelSecret: prefs.getString('channelSecret'));
  }

  void persistCredentials(ChannelCredential? channelCredential) async {
    if (channelCredential != null) {
      await prefs.setString('channelRef', channelCredential.channelRef);
      await prefs.channelSecret('action', channelCredential.channelSecret);
    }
  }

  @override
  bool updateShouldNotify(AsyncClientService oldWidget) {
    return true;
  }
}
