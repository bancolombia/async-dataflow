import 'package:app_async_flutter/application/app_config.dart';
import 'package:app_async_flutter/domain/model/channel_credentials.dart';
import 'package:app_async_flutter/domain/model/gateway/async_client_gateway.dart';
import 'package:channel_sender_client/channel_sender_client.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

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
  final _log = Logger('AsyncClientService');

  late SharedPreferences prefs;
  ResponsesNotifier responsesNotifier = ResponsesNotifier();
  final AppConfig appConfig;

  void _handleEvent(dynamic msg) {
    if (msg.event == 'businessEvent') {
      responsesNotifier.addResponse(
          'Message from async dataflow, title: ${msg.payload['title']} detail: ${msg.payload['detail']}');
    }

    if (msg.event == 'ch-ms-async-callback.svp.reply') {
      responsesNotifier.addResponse(
          'Message from async dataflow, title: ${msg.payload['data']['reply']['messageData']['title']} detail: ${msg.payload['data']['reply']['messageData']['detail']}');
    }
  }

  static AsyncClientService? of(BuildContext context) {
    return context.findAncestorWidgetOfExactType<AsyncClientService>();
  }

  Future<void> closeSession() async {
    prefs = await SharedPreferences.getInstance();
    await deleteChannelCreated();
    asyncClient.disconnect();
  }

  Future<void> deleteChannelCreated() async {
    await prefs.remove('channelRef');
    await prefs.remove('channelSecret');
    await prefs.remove('userRef');
  }

  bool hasUserRef() {
    return prefs.getString('userRef') != null;
  }

  Future<String> createUserRef() async {
    if (hasUserRef()) {
      return prefs.getString('userRef')!;
    }
    var uuid = const Uuid();
    String ref = uuid.v4();
    await prefs.setString('userRef', ref);
    return ref;
  }

  Future<void> saveConfig() async {
    prefs = await SharedPreferences.getInstance();

    await prefs.setString('socketUrl', appConfig.socketUrl);
    await prefs.setString('apiBusiness', appConfig.businessUrl);
    await prefs.setString(
        'heartbeatInterval', appConfig.heartbeatInterval.toString());
    await prefs.setString('maxRetries', appConfig.maxRetries.toString());
  }

  Future<void> initAsyncClient() async {
    prefs = await SharedPreferences.getInstance();
    var userRef = await createUserRef();
    _log.info("userRef $userRef");
    ChannelCredential? channelCredential =
        await _requestChannelCredentials(userRef);
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

  Future<ChannelCredential?> _requestChannelCredentials(String userRef) async {
    ChannelCredential? channelCredential;
    if (hasChannelCreated()) {
      return getChannelCreated();
    }
    channelCredential = await asyncClientGateway.getCredentials(userRef);
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
