import 'package:app_async_flutter/domain/model/channel_credentials.dart';

abstract class AsyncClientGateway {
  Future<ChannelCredential?> getCredentials(String userRef);
  Future<void> callBusinessUseCase(
      String channelRef, String userRef, int delay);
}
