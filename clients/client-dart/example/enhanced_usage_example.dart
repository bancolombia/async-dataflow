import 'dart:async';

import 'package:channel_sender_client/channel_sender_client.dart';
import 'package:channel_sender_client/src/flutter_async_client.dart';
import 'package:flutter/material.dart';

/// Example demonstrating the enhanced Dart client features:
/// 1. Stream-based reactive API
/// 2. Connectivity awareness
/// 3. Background handling.
class EnhancedClientExample extends StatefulWidget {
  @override
  _EnhancedClientExampleState createState() => _EnhancedClientExampleState();
}

class _EnhancedClientExampleState extends State<EnhancedClientExample> {
  late FlutterAsyncClient _client;
  final List<String> _messages = [];
  final List<String> _connectionEvents = [];

  StreamSubscription? _messageSubscription;
  StreamSubscription? _connectionSubscription;
  StreamSubscription? _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    _initializeClient();
  }

  void _initializeClient() {
    // Configure the client
    final config = AsyncConfig(
      socketUrl: 'ws://localhost:8080/ext/socket',
      channelRef: 'demo-channel',
      channelSecret: 'demo-secret',
      maxRetries: 5,
      heartbeatInterval: 30000,
    );

    // Create Flutter-integrated client
    _client = FlutterAsyncClient(config);

    _setupStreamListeners();
    _client.connect();
  }

  void _setupStreamListeners() {
    // 1. STREAM-BASED API EXAMPLES

    // Listen to all messages with reactive streams
    _messageSubscription = _client.messageStream.listen(
      (message) {
        setState(() {
          _messages.add('${message.event}: ${message.payload}');
        });
      },
    );

    // Listen to specific events
    _client.messagesFor('user.login').listen((message) {
      print('User logged in: ${message.payload}');
    });

    // Listen to multiple events with pattern matching
    _client.messagesMatching('notification.*').listen((message) {
      _showNotification(message.payload.toString());
    });

    // Advanced: Combine streams for complex logic
    _client.messagesWithConnectionState.listen((messageWithState) {
      if (messageWithState.connectionState == ConnectionState.connected) {
        print(
            'Received message while connected: ${messageWithState.message.event}');
      }
    });

    // React to connection state changes
    _connectionSubscription = _client.connectionState.listen((state) {
      setState(() {
        _connectionEvents.add('Connection: ${state.toString()}');
      });

      switch (state) {
        case ConnectionState.connected:
          _showSnackBar('Connected to server', Colors.green);
          break;
        case ConnectionState.disconnected:
          _showSnackBar('Disconnected from server', Colors.red);
          break;
        case ConnectionState.connecting:
          _showSnackBar('Connecting...', Colors.orange);
          break;
        case ConnectionState.disconnecting:
          _showSnackBar('Disconnecting...', Colors.orange);
          break;
      }
    });

    // 2. CONNECTIVITY AWARENESS

    // Monitor network connectivity
    _connectivitySubscription = _client.connectivityState.listen((results) {
      final hasConnection = results.any((r) => r != ConnectivityResult.none);
      setState(() {
        _connectionEvents
            .add('Network: ${hasConnection ? 'Available' : 'Unavailable'}');
      });
    });

    // React when client is ready to receive messages
    _client.onReady.listen((_) {
      print('Client is ready - can now send requests');
      _sendTestMessage();
    });

    // React when disconnected
    _client.onDisconnected.listen((_) {
      print('Client disconnected - will auto-reconnect when network available');
    });
  }

  void _showNotification(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Notification: $message')),
    );
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _sendTestMessage() {
    // In a real app, you would send a message to your backend
    // which would then push a response through the channel
    print('Sending test request to backend...');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Enhanced Async Client Demo'),
        actions: [
          IconButton(
            icon: Icon(_client.isConnected ? Icons.wifi : Icons.wifi_off),
            onPressed: () {
              if (_client.isConnected) {
                _client.disconnect();
              } else {
                _client.connect();
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Connection Status
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(16),
            color: _getConnectionColor(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Status: ${_client.currentConnectionState.toString()}',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Transport: ${_client.currentTransportType}',
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),

          // Connection Events
          Expanded(
            flex: 1,
            child: Container(
              padding: EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Connection Events:',
                      style: Theme.of(context).textTheme.titleMedium),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _connectionEvents.length,
                      itemBuilder: (context, index) {
                        return Text(
                          _connectionEvents[index],
                          style:
                              TextStyle(fontSize: 12, color: Colors.grey[600]),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

          Divider(),

          // Messages
          Expanded(
            flex: 2,
            child: Container(
              padding: EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Messages:',
                      style: Theme.of(context).textTheme.titleMedium),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        return Card(
                          child: ListTile(
                            title: Text(_messages[index]),
                            dense: true,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _client.isConnected ? _sendTestMessage : null,
        child: Icon(Icons.send),
        tooltip: 'Send Test Message',
      ),
    );
  }

  Color _getConnectionColor() {
    switch (_client.currentConnectionState) {
      case ConnectionState.connected:
        return Colors.green;
      case ConnectionState.connecting:
        return Colors.orange;
      case ConnectionState.disconnecting:
        return Colors.orange;
      case ConnectionState.disconnected:
        return Colors.red;
    }
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    _connectionSubscription?.cancel();
    _connectivitySubscription?.cancel();
    _client.dispose();
    super.dispose();
  }
}

/// Example of using the enhanced client in a service/repository pattern
class MessageService {
  final FlutterAsyncClient _client;
  final StreamController<String> _notificationController =
      StreamController.broadcast();

  MessageService(AsyncConfig config) : _client = FlutterAsyncClient(config) {
    _setupMessageHandling();
  }

  void _setupMessageHandling() {
    // Handle different types of messages
    _client.messagesFor('notification.push').listen(_handlePushNotification);
    _client.messagesFor('user.status').listen(_handleUserStatus);
    _client.messagesMatching('order.*').listen(_handleOrderEvents);

    // Handle connection state for UI updates
    _client.connectionState.listen(_handleConnectionStateChange);
  }

  void _handlePushNotification(ChannelMessage message) {
    _notificationController.add(message.payload.toString());
  }

  void _handleUserStatus(ChannelMessage message) {
    // Update user status in your state management solution
    print('User status changed: ${message.payload}');
  }

  void _handleOrderEvents(ChannelMessage message) {
    // Handle order-related events
    print('Order event: ${message.event} - ${message.payload}');
  }

  void _handleConnectionStateChange(ConnectionState state) {
    // Update UI or perform actions based on connection state
    print('Connection state changed: $state');
  }

  // Public API
  Stream<String> get notifications => _notificationController.stream;
  Stream<ChannelMessage> get allMessages => _client.messageStream;
  Stream<ConnectionState> get connectionState => _client.connectionState;

  bool get isConnected => _client.isConnected;

  Future<bool> connect() => _client.connect();
  Future<bool> disconnect() => _client.disconnect();

  void dispose() {
    _notificationController.close();
    _client.dispose();
  }
}

/// Example main function
void main() {
  runApp(MaterialApp(
    home: EnhancedClientExample(),
    title: 'Enhanced Async Client Demo',
  ));
}
