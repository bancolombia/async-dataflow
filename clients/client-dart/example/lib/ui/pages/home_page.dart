import 'package:app_async_flutter/ui/pages/config_page.dart';
import 'package:app_async_flutter/ui/pages/request_page.dart';
import 'package:flutter/material.dart';

import '../../async_client_service.dart';
import 'log_viewer_page.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _currentIndex = 0;
  final List<Widget> _children = [
    const RequestPage(),
    const LogViewer(),
    const ConfigPage(),
  ];

  void onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  void initState() {
    super.initState();
    AsyncClientService.of(context)!.initAsyncClient();
  }

  @override
  Widget build(BuildContext context) {
    const items = [
      BottomNavigationBarItem(
        icon: Icon(Icons.remove_from_queue_sharp),
        label: 'Requests',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.list),
        label: 'Logs',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.settings),
        label: 'Config',
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: _children[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        items: items,
        selectedItemColor: Colors.amber[800],
        unselectedItemColor: Colors.white,
        backgroundColor: const Color(0xFF1c2430),
        onTap: onTabTapped,
        currentIndex: _currentIndex,
      ),
    );
  }
}
