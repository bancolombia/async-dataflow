import 'package:flutter/material.dart';

class LogNotifier extends ChangeNotifier {
  LogLevel level = LogLevel.all;

  List<String> logs = [];
  void setLog(log) {
    logs.insert(0, log);
    notifyListeners();
  }

  void setLevel(newLevel) {
    level = newLevel;
    notifyListeners();
  }

  void clean() {
    logs.clear();
    notifyListeners();
  }

  List<String> getLogs() {
    return logs;
  }
}

enum LogLevel { info, all }
