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

class CurrentTransportNotifier extends ChangeNotifier {
  String currentTransport = '';
  void setTransport(String name) {
    currentTransport = name.split('.').last;
    print('updating transport $currentTransport');
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

  final List<String> eventListen;
  late FlutterAsyncClient asyncClient;
  final AsyncClientGateway asyncClientGateway;
  final _log = Logger('AsyncClientService');

  late SharedPreferences prefs;
  ResponsesNotifier responsesNotifier = ResponsesNotifier();
  CurrentTransportNotifier currentTransportNotifier =
      CurrentTransportNotifier();
  final AppConfig appConfig;

  void _handleEvent(dynamic msg) {
    // The client app can subscrtibe to bussines events with different names
    if (msg.event == 'businessEvent') {
      responsesNotifier.addResponse(
          'Message from async dataflow, title: ${msg.payload['title']} detail: ${msg.payload['detail']}');
    }

    // Another bussines event
    if (msg.event == 'ch-ms-async-callback.svp.reply') {
      responsesNotifier.addResponse(
          'Message from async dataflow, title: ${msg.payload['data']['reply']['messageData']['title']} detail: ${msg.payload['data']['reply']['messageData']['detail']}');
    }

    if (msg.event == ':n_token') {
      // The client app can also subscrtibe to this ADF internal event to listen
      // when connector receives a new token from the backend.
      // This is useful if client gets disconnected and needs to reconnect
      // wont use an expired token, but always use the active token.
      prefs.setString('channelSecret', msg.payload).then((onValue) {
        _log.info("Channel secret updated");
      });
    }
  }

  static AsyncClientService? of(BuildContext context) {
    return context.findAncestorWidgetOfExactType<AsyncClientService>();
  }

  Future<void> closeSession() async {
    prefs = await SharedPreferences.getInstance();
    await deleteChannelCreated();
    await asyncClient.disconnect();
    currentTransportNotifier
        .setTransport(asyncClient.getCurrentTransportType());
  }

  Future<void> switchProtocols() async {
    await asyncClient.switchProtocols();
    currentTransportNotifier
        .setTransport(asyncClient.getCurrentTransportType());
  }

  Future<void> deleteChannelCreated() async {
    await prefs.remove('channelRef');
    await prefs.remove('channelSecret');
    await prefs.remove('userRef');
  }

  void dispose() {
    _log.info("Disposing AsyncClientService");
    // asyncClient.dispose();
  }

  Future<void> refreshCredentials() async {
    _log.info("Refreshing credentials due to authentication failure");
    await deleteChannelCreated();
    await initAsyncClient();
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
    print(appConfig.transports.join(","));

    await prefs.setString('socketUrl', appConfig.socketUrl);
    await prefs.setString('sseUrl', appConfig.sseUrl ?? '');
    await prefs.setString('apiBusiness', appConfig.businessUrl);
    await prefs.setString(
        'heartbeatInterval', appConfig.heartbeatInterval.toString());
    await prefs.setString('maxRetries', appConfig.maxRetries.toString());
    await prefs.setStringList('transports', appConfig.transports);
  }

  Future<void> initAsyncClient() async {
    prefs = await SharedPreferences.getInstance();
    var userRef = await createUserRef();
    _log.info("userRef $userRef");
    ChannelCredential? channelCredential =
        await _requestChannelCredentials(userRef);
    if (channelCredential != null) {
      _log.info(
          "Channel credentials - Ref: ${channelCredential.channelRef}, Secret: ${channelCredential.channelSecret.substring(0, 10)}...");
      final conf = AsyncConfig(
        socketUrl: appConfig.socketUrl,
        sseUrl: appConfig.sseUrl,
        enableBinaryTransport: false,
        channelRef: channelCredential.channelRef,
        channelSecret: channelCredential.channelSecret,
        heartbeatInterval: appConfig.heartbeatInterval,
        maxRetries: appConfig.maxRetries,
        transportsProvider: appConfig.transports.map(
          (e) {
            return transportFromString(e);
          },
        ).toList(),
      );

      asyncClient = FlutterAsyncClient(conf); //Breaking change

      // Listen to connection state changes
      // asyncClient.connectionState.listen(
      //   (state) {
      //     _log.info("Connection state changed to: $state");
      //     if (state == CustomConnectionState.connected) {
      //       currentTransportNotifier
      //           .setTransport(asyncClient.getCurrentTransportType());
      //     }
      //   },
      // );

      bool connected = await asyncClient.connect();
      if (connected) {
        _log.info("Connected to ADF");

        asyncClient.subscribeToMany(
          eventListen,
          (eventResult) {
            _handleEvent(eventResult);
          },
          onError: (err) {
            _log.severe("Error in message stream: $err");
          },
        );
      } else {
        _log.severe("Not connected");
      }
    } else {
      throw Exception("AsyncClient could not be initialized");
    }
  }

  Future<ChannelCredential?> _requestChannelCredentials(String userRef) async {
    ChannelCredential? channelCredential;

    // First try cached credentials
    if (hasChannelCreated()) {
      channelCredential = getChannelCreated();
      _log.info(
          "Using cached credentials for channel: ${channelCredential.channelRef}");
    } else {
      // Request new credentials
      _log.info("Requesting new credentials for user: $userRef");
      channelCredential = await asyncClientGateway.getCredentials(userRef);
      if (channelCredential != null) {
        _log.info(
            "Received new credentials for channel: ${channelCredential.channelRef}");
        persistCredentials(channelCredential);
      }
    }
    return channelCredential;
  }

  bool hasChannelCreated() {
    return (prefs.getString('channelRef') != null &&
        prefs.getString('channelSecret') != null);
  }

  ChannelCredential getChannelCreated() {
    return ChannelCredential(
      channelRef: prefs.getString('channelRef')!,
      channelSecret: prefs.getString('channelSecret')!,
    );
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
