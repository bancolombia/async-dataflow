import 'dart:convert';

import 'package:app_async_flutter/channel_credentials.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static Future<ChannelCredential?> getCredentials(String url) async {
    ChannelCredential? channelCredential;
    http.get(Uri.parse("$url/credentials")).then((response) {
      try {
        final dynamic body = jsonDecode(response.body);
        channelCredential = ChannelCredential.fromMap(body);
      } catch (_) {
        throw Exception("Could not get Credentials");
      }
    });

    return channelCredential;
  }

  static Future<http.Response> callBusinessUseCase(
      String url, int delay) async {
    final prefs = await SharedPreferences.getInstance();
    String? channelRef = prefs.getString("channelRef");
    return http
        .get(Uri.parse("$url/business?channel_ref=$channelRef&delay=$delay"));
  }
}
