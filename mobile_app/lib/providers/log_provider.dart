import 'package:flutter/foundation.dart';
import '../models/log_entry.dart';

class LogProvider extends ChangeNotifier {
  final List<LogEntry> _logs = [];
  static const int maxLogs = 1000; // Maximum number of logs

  List<LogEntry> get logs => List.unmodifiable(_logs);

  void addLog(LogLevel level, String message, {String? details}) {
    final logEntry = LogEntry(
      timestamp: DateTime.now(),
      level: level,
      message: message,
      details: details,
    );

    _logs.insert(0, logEntry); // Add to beginning of list

    // Limit log count
    if (_logs.length > maxLogs) {
      _logs.removeRange(maxLogs, _logs.length);
    }

    notifyListeners();
  }

  void addCommandLog(String command) {
    addLog(LogLevel.command, 'Sent command: $command');
  }

  void addResponseLog(String response) {
    addLog(LogLevel.response, 'Received: $response');
  }

  void addErrorLog(String error, {String? details}) {
    addLog(LogLevel.error, error, details: details);
  }

  void addInfoLog(String message) {
    addLog(LogLevel.info, message);
  }

  void addWarningLog(String message) {
    addLog(LogLevel.warning, message);
  }

  void clearLogs() {
    _logs.clear();
    notifyListeners();
  }

  List<LogEntry> getLogsByLevel(LogLevel level) {
    return _logs.where((log) => log.level == level).toList();
  }

  List<LogEntry> getRecentLogs(int count) {
    return _logs.take(count).toList();
  }
}
