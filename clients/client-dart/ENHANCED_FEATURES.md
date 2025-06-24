# Enhanced Dart Client Features

This document describes the enhanced features added to the Dart client for better Flutter integration and reactive programming patterns.

## 🚀 New Features

### 1. Stream-based Reactive API
The enhanced client provides a comprehensive reactive API using Dart Streams and RxDart for better integration with Flutter's reactive patterns.

#### Key Benefits:
- **Reactive Programming**: Use Dart Streams for reactive data flow
- **Event Filtering**: Filter messages by event names or patterns
- **Stream Composition**: Combine multiple streams for complex logic
- **Better Flutter Integration**: Works seamlessly with StreamBuilder and other Flutter widgets

#### Examples:

```dart
// Basic message listening
client.messageStream.listen((message) {
  print('Received: ${message.event}');
});

// Listen to specific events
client.messagesFor('user.login').listen((message) {
  handleUserLogin(message.payload);
});

// Pattern matching for event groups
client.messagesMatching('notification.*').listen((message) {
  showNotification(message.payload);
});

// Combine with connection state
client.messagesWithConnectionState.listen((messageWithState) {
  if (messageWithState.connectionState == ConnectionState.connected) {
    processMessage(messageWithState.message);
  }
});
```

### 2. Connectivity Awareness
Automatic network connectivity monitoring with intelligent reconnection strategies.

#### Key Benefits:
- **Automatic Reconnection**: Reconnects when network becomes available
- **Network State Monitoring**: Real-time connectivity status
- **Smart Retry Logic**: Exponential backoff with jitter
- **Offline Handling**: Graceful degradation when offline

#### Features:
- Uses `connectivity_plus` package for network monitoring
- Automatic reconnection when network is restored
- Exponential backoff retry strategy
- Network state streams for UI updates

```dart
// Monitor connectivity changes
client.connectivityState.listen((results) {
  final hasConnection = results.any((r) => r != ConnectivityResult.none);
  updateNetworkStatus(hasConnection);
});

// React to connection events
client.onReady.listen((_) {
  print('Ready to receive messages');
});

client.onDisconnected.listen((_) {
  print('Disconnected - will auto-reconnect');
});
```

### 3. Background/Foreground Handling
Proper handling of Flutter app lifecycle events for optimal resource management.

#### Key Benefits:
- **Battery Optimization**: Manages connections based on app state
- **Resource Management**: Proper cleanup when app is backgrounded
- **Seamless Recovery**: Automatic reconnection when app returns to foreground
- **Flutter Integration**: Works with Flutter's lifecycle system

#### Features:
- Automatic integration with Flutter's `WidgetsBindingObserver`
- Graceful handling of app pause/resume
- Connection management during app lifecycle changes
- Proper resource cleanup

```dart
// The FlutterAsyncClient automatically handles lifecycle events
// Just add it to your StatefulWidget:

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late FlutterAsyncClient _client;
  
  @override
  void initState() {
    super.initState();
    _client = FlutterAsyncClient(config);
    _client.connect();
  }
  
  @override
  void dispose() {
    _client.dispose(); // Automatically handles cleanup
    super.dispose();
  }
}
```

## 📚 API Reference

### EnhancedAsyncClient

The core enhanced client with reactive features.

#### Streams:
- `messageStream`: Stream of all messages
- `connectionState`: Stream of connection state changes
- `connectivityState`: Stream of network connectivity changes
- `messagesFor(String event)`: Stream of messages for specific event
- `messagesWhere(List<String> events)`: Stream of messages matching event list
- `messagesMatching(String pattern)`: Stream of messages matching pattern
- `messagesWithConnectionState`: Combined stream of messages with connection state
- `onReady`: Stream that emits when connected and ready
- `onDisconnected`: Stream that emits when disconnected

#### Properties:
- `isConnected`: Current connection status
- `isConnecting`: Whether currently attempting to connect
- `currentConnectionState`: Current connection state enum
- `currentTransportType`: Current transport protocol

#### Methods:
- `connect()`: Connect to server
- `disconnect()`: Disconnect from server
- `switchTransport()`: Switch to different transport protocol
- `dispose()`: Clean up resources

### FlutterAsyncClient

Flutter-specific wrapper with automatic lifecycle management.

Extends `EnhancedAsyncClient` with:
- Automatic `WidgetsBindingObserver` integration
- Flutter lifecycle event handling
- Automatic resource management

### Connection States

```dart
enum ConnectionState {
  disconnected,
  connecting,
  connected,
  disconnecting,
}
```

### App Lifecycle States

```dart
enum AppLifecycleState {
  resumed,
  inactive,
  paused,
  detached,
  hidden,
}
```

## 🔧 Installation

Add the required dependencies to your `pubspec.yaml`:

```yaml
dependencies:
  channel_sender_client: ^3.0.1
  connectivity_plus: ^6.0.5
  rxdart: ^0.27.7
```

## 📖 Usage Examples

### Basic Usage

```dart
import 'package:channel_sender_client/channel_sender_client.dart';

// Create config
final config = AsyncConfig(
  socketUrl: 'ws://localhost:8080/ext/socket',
  channelRef: 'my-channel',
  channelSecret: 'my-secret',
  maxRetries: 5,
);

// Create client
final client = FlutterAsyncClient(config);

// Connect
await client.connect();

// Listen to messages
client.messagesFor('notification').listen((message) {
  print('Notification: ${message.payload}');
});
```

### Advanced Stream Usage

```dart
// Multiple event types
client.messagesWhere(['user.login', 'user.logout']).listen((message) {
  handleUserEvent(message);
});

// Pattern matching
client.messagesMatching('order.*').listen((message) {
  handleOrderEvent(message);
});

// Combined streams
StreamZip([
  client.messagesFor('status'),
  client.connectionState,
]).listen((combined) {
  final message = combined[0] as ChannelMessage;
  final state = combined[1] as ConnectionState;
  handleStatusUpdate(message, state);
});
```

### Service Pattern

```dart
class NotificationService {
  final FlutterAsyncClient _client;
  final StreamController<String> _notifications = StreamController.broadcast();

  NotificationService(AsyncConfig config) : _client = FlutterAsyncClient(config) {
    _client.messagesFor('notification').listen((message) {
      _notifications.add(message.payload.toString());
    });
  }

  Stream<String> get notifications => _notifications.stream;
  
  Future<void> connect() => _client.connect();
  Future<void> disconnect() => _client.disconnect();
  
  void dispose() {
    _notifications.close();
    _client.dispose();
  }
}
```

### Widget Integration

```dart
class MessageList extends StatelessWidget {
  final FlutterAsyncClient client;
  
  MessageList({required this.client});
  
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ChannelMessage>(
      stream: client.messageStream,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return ListTile(
            title: Text(snapshot.data!.event),
            subtitle: Text(snapshot.data!.payload.toString()),
          );
        }
        return CircularProgressIndicator();
      },
    );
  }
}
```

## 🔄 Migration Guide

### From Original AsyncClient

The enhanced client is backwards compatible, but here's how to migrate:

#### Old Way:
```dart
final client = AsyncClient(config);
await client.connect();

client.subscribeToMany(['event1', 'event2'], (message) {
  handleMessage(message);
});
```

#### New Way:
```dart
final client = FlutterAsyncClient(config);
await client.connect();

client.messagesWhere(['event1', 'event2']).listen((message) {
  handleMessage(message);
});
```

### Benefits of Migration:
- Better error handling with stream error handling
- Automatic lifecycle management
- Network awareness
- More composable and testable code
- Better Flutter integration

## 🧪 Testing

The enhanced client is designed to be easily testable:

```dart
// Mock the client for testing
class MockAsyncClient implements FlutterAsyncClient {
  final StreamController<ChannelMessage> _messageController = StreamController();
  
  @override
  Stream<ChannelMessage> get messageStream => _messageController.stream;
  
  void simulateMessage(ChannelMessage message) {
    _messageController.add(message);
  }
}
```

## 🎯 Best Practices

1. **Use FlutterAsyncClient** for Flutter apps - it handles lifecycle automatically
2. **Dispose properly** - Always call `dispose()` in your widget's dispose method
3. **Handle connection states** - React to connection state changes in your UI
4. **Use stream transformations** - Leverage RxDart operators for complex stream logic
5. **Implement retry logic** - The client handles basic retries, but implement app-specific retry logic
6. **Monitor connectivity** - Use the connectivity stream to inform users about network status

## 🐛 Troubleshooting

### Common Issues:

1. **Memory leaks**: Make sure to call `dispose()` on the client
2. **Multiple listeners**: Use `broadcast()` streams or multiple subscriptions carefully
3. **Lifecycle issues**: Ensure proper integration with Flutter's lifecycle
4. **Network permissions**: Make sure your app has network permissions

### Debug Logging:

Enable logging to see what's happening:

```dart
import 'package:logging/logging.dart';

Logger.root.level = Level.ALL;
Logger.root.onRecord.listen((record) {
  print('${record.level.name}: ${record.time}: ${record.message}');
});
```

## 🤝 Contributing

To contribute to the enhanced features:

1. Follow the existing code style
2. Add tests for new features
3. Update documentation
4. Ensure backward compatibility
5. Test on multiple Flutter versions

## 📄 License

Same license as the main project.