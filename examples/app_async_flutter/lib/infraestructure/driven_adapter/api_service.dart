import 'dart:convert';

import 'package:app_async_flutter/domain/model/channel_credentials.dart';
import 'package:app_async_flutter/domain/model/gateway/async_client_gateway.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class ApiService implements AsyncClientGateway {
  late String urlBusinessService;
  ApiService() {
    urlBusinessService =
        dotenv.env['apiBusiness'] ?? 'http://localhost:8080/api';
  }
  @override
  Future<ChannelCredential?> getCredentials() async {
    ChannelCredential? channelCredential;
    http.get(Uri.parse("$urlBusinessService/credentials")).then((response) {
      try {
        final dynamic body = jsonDecode(response.body);
        channelCredential = ChannelCredential.fromMap(body);
      } catch (_) {
        throw Exception("Could not get Credentials");
      }
    });

    return channelCredential;
  }

  @override
  Future<http.Response> callBusinessUseCase(
      String channelRef, int delay) async {
    return http.get(Uri.parse(
        "$urlBusinessService/business?channel_ref=$channelRef&delay=$delay"));
  }
}
