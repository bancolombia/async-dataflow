import 'package:flutter/material.dart';

class LogNotifier extends ChangeNotifier {
  List<String> logs = [];
  void setLog(log) {
    logs.add(log);
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
