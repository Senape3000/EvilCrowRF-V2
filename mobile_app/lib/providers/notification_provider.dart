import 'package:flutter/material.dart';

enum NotificationLevel {
  info,
  success,
  warning,
  error,
}

class AppNotification {
  final String message;
  final NotificationLevel level;
  final DateTime timestamp;
  final Duration duration;

  AppNotification({
    required this.message,
    required this.level,
    this.duration = const Duration(seconds: 3),
  }) : timestamp = DateTime.now();

  Color get color {
    switch (level) {
      case NotificationLevel.info:
        return Colors.blue;
      case NotificationLevel.success:
        return Colors.green;
      case NotificationLevel.warning:
        return Colors.orange;
      case NotificationLevel.error:
        return Colors.red;
    }
  }

  IconData get icon {
    switch (level) {
      case NotificationLevel.info:
        return Icons.info_outline;
      case NotificationLevel.success:
        return Icons.check_circle_outline;
      case NotificationLevel.warning:
        return Icons.warning_amber;
      case NotificationLevel.error:
        return Icons.error_outline;
    }
  }
}

class NotificationProvider extends ChangeNotifier {
  AppNotification? _currentNotification;
  AppNotification? get currentNotification => _currentNotification;
  
  final List<AppNotification> _notificationHistory = [];
  List<AppNotification> get notificationHistory => List.unmodifiable(_notificationHistory);
  
  static const int maxHistorySize = 50;

  void showInfo(String message, {Duration? duration}) {
    _showNotification(AppNotification(
      message: message,
      level: NotificationLevel.info,
      duration: duration ?? const Duration(seconds: 3),
    ));
  }

  void showSuccess(String message, {Duration? duration}) {
    _showNotification(AppNotification(
      message: message,
      level: NotificationLevel.success,
      duration: duration ?? const Duration(seconds: 2),
    ));
  }

  void showWarning(String message, {Duration? duration}) {
    _showNotification(AppNotification(
      message: message,
      level: NotificationLevel.warning,
      duration: duration ?? const Duration(seconds: 3),
    ));
  }

  void showError(String message, {Duration? duration}) {
    _showNotification(AppNotification(
      message: message,
      level: NotificationLevel.error,
      duration: duration ?? const Duration(seconds: 4),
    ));
  }

  void _showNotification(AppNotification notification) {
    _currentNotification = notification;
    
    // Add to history
    _notificationHistory.insert(0, notification);
    if (_notificationHistory.length > maxHistorySize) {
      _notificationHistory.removeLast();
    }
    
    notifyListeners();

    // Auto-dismiss after duration
    Future.delayed(notification.duration, () {
      if (_currentNotification == notification) {
        clearNotification();
      }
    });
  }

  void clearNotification() {
    _currentNotification = null;
    notifyListeners();
  }
  
  void clearHistory() {
    _notificationHistory.clear();
    notifyListeners();
  }
}



