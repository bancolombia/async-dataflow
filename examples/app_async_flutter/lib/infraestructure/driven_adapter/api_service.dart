import 'dart:convert';

import 'package:app_async_flutter/application/app_config.dart';
import 'package:app_async_flutter/domain/model/channel_credentials.dart';
import 'package:app_async_flutter/domain/model/gateway/async_client_gateway.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class ApiService implements AsyncClientGateway {
  late String urlBusinessService;
  ApiService(BuildContext context) {
    urlBusinessService = AppConfig.of(context).businessUrl;
  }
  @override
  Future<ChannelCredential?> getCredentials() async {
    ChannelCredential? channelCredential;
    return http
        .get(Uri.parse("$urlBusinessService/credentials"))
        .then((response) {
      try {
        print("response.body ${response.body}");
        final dynamic body = jsonDecode(response.body);
        channelCredential = ChannelCredential.fromMap(body);
        return channelCredential;
      } catch (_) {
        print("error");
        throw Exception("Could not get Credentials");
      }
    });
  }

  @override
  Future<http.Response> callBusinessUseCase(
      String channelRef, int delay) async {
    return http.get(Uri.parse(
        "$urlBusinessService/business?channel_ref=$channelRef&delay=$delay"));
  }
}
