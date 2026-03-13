import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';

class NotificationProvider extends ChangeNotifier {
  final ApiService _api;
  final SocketService _socketService;

  int _unreadCount = 0;
  int get unreadCount => _unreadCount;

  late final void Function(Map<String, dynamic>) _onNewNotification;
  late final void Function(Map<String, dynamic>) _onNotificationRead;

  NotificationProvider(this._api, this._socketService) {
    _onNewNotification = (_) {
      _unreadCount++;
      notifyListeners();
    };
    _onNotificationRead = (data) {
      _unreadCount = data['unreadCount'] ?? 0;
      notifyListeners();
    };
    _socketService.onNotification(_onNewNotification);
    _socketService.onNotificationRead(_onNotificationRead);
  }

  Future<void> loadUnreadCount() async {
    try {
      final res = await _api.get('/notifications', queryParameters: {'limit': '1'});
      _unreadCount = res.data['unreadCount'] ?? 0;
      notifyListeners();
    } catch (_) {}
  }

  void reset() {
    _unreadCount = 0;
    notifyListeners();
  }

  @override
  void dispose() {
    _socketService.removeNotification(_onNewNotification);
    _socketService.removeNotificationRead(_onNotificationRead);
    super.dispose();
  }
}
