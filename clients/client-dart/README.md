# Async Dataflow Dart Client
[![Pub](https://img.shields.io/pub/v/channel_sender_client.svg)](https://pub.dev/packages/channel_sender_client)

Transport client for Async dataflow channel sender in Dart.

## Installation

With Dart:
```
dart pub add channel_sender_client
```
With Flutter:
```
flutter pub add channel_sender_client
```

### Getting Started

```dart
// Create AsyncConfig
  var conf = AsyncConfig(
    socketUrl: 'ws://localhost:8082/ext/socket',
    enableBinaryTransport: false,
    channelRef:
        'd30774f110683c9db9eece36524d2d04.99621ecb9d3c4f71b69887d2c639fed0',
    channelSecret:
        'SFMyNTY.g2gDaANtAAAAQWQzMDc3NGYxMTA2ODNjOWRiOWVlY2UzNjUyNGQyZDA0Ljk5NjIxZWNiOWQzYzRmNzFiNjk4ODdkMmM2MzlmZWQwbQAAAARhcHAxbQAAAAh1c2VyX3JlZm4GAFfri3p_AWIAAVGA.dgeQR6mBXL30fm-8PuUA9YrThFJ0ieJMl8R-LcM1WOg',
    heartbeatInterval: 5000,
    maxRetries: 10,
    transportsProvider: [TransportType.ws, TransportType.sse]
    
  );

  AsyncClient client = AsyncClient(conf);
    // start connection
  client.connect();
  // listen events
  client.subscribeTo(
    'event.productCreated',
    (event) {
      Logger.root.info('SUB 1 JUST RECEIVED: $event');
    },
    onError: (err) {
      Logger.root.severe('SUB 1 JUST RECEIVED AN ERROR: $err');
    },
  );

  client.subscribeTo(
    'event.productCreated',
    (event) {
      Logger.root.info('SUB 2 JUST RECEIVED: $event');
    },
    onError: (err) {
      Logger.root.severe('SUB 2 JUST RECEIVED AN ERROR: $err');
    },
  );
```

## TODO

See issues page for roadmap. 