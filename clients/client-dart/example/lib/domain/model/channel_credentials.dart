class ChannelCredential {
  final String channelRef;
  final String channelSecret;

  const ChannelCredential(
      {required this.channelRef, required this.channelSecret});

  ChannelCredential.fromMap(dynamic map)
      : assert(map["channelRef"] != null, "'channelRef' cannot be null"),
        assert(map["channelSecret"] != null, "'channelSecret' cannot be null"),
        channelRef = map["channelRef"],
        channelSecret = map["channelSecret"];
}
