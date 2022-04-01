import 'package:app_async_flutter/domain/model/channel_credentials.dart';

abstract class AsyncClientGateway {
  Future<ChannelCredential?> getCredentials();
  Future<void> callBusinessUseCase(String channelRef, int delay);
}
