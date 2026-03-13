import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<dynamic> _notifications = [];
  bool _loading = true;
  String _filter = 'all';
  late final SocketService _socketService;
  late final void Function(Map<String, dynamic>) _onNotification;

  static const _categories = {
    'all': 'Tümü',
    'social': 'Sosyal',
    'achievement': 'Başarım',
    'coop': 'Co-op',
  };

  static const _socialTypes = {'friend_request', 'friend_accepted', 'like', 'comment'};
  static const _achievementTypes = {'achievement', 'quest', 'level_up'};
  static const _coopTypes = {'coop_invite', 'coop_turn'};

  @override
  void initState() {
    super.initState();
    _socketService = context.read<SocketService>();
    _onNotification = (data) {
      if (!mounted) return;
      setState(() {
        _notifications.insert(0, data);
      });
    };
    _socketService.onNotification(_onNotification);
    _load();
  }

  @override
  void dispose() {
    _socketService.removeNotification(_onNotification);
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final api = context.read<ApiService>();
      final res = await api.get('/notifications');
      if (mounted) setState(() { _notifications = res.data['notifications'] ?? []; _loading = false; });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _markAllRead() async {
    try {
      final api = context.read<ApiService>();
      await api.put('/notifications/read-all');
      _load();
    } catch (_) {}
  }

  List<dynamic> get _filteredNotifications {
    if (_filter == 'all') return _notifications;
    return _notifications.where((n) {
      final type = n['type'] as String? ?? '';
      switch (_filter) {
        case 'social': return _socialTypes.contains(type);
        case 'achievement': return _achievementTypes.contains(type);
        case 'coop': return _coopTypes.contains(type);
        default: return true;
      }
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredNotifications;
    // Group by date
    final today = <dynamic>[];
    final earlier = <dynamic>[];
    final now = DateTime.now();
    for (final n in filtered) {
      final dt = DateTime.tryParse(n['createdAt'] ?? '');
      if (dt != null && now.difference(dt).inHours < 24) {
        today.add(n);
      } else {
        earlier.add(n);
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('BİLDİRİMLER', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, letterSpacing: 2)),
        actions: [
          if (_notifications.isNotEmpty)
            TextButton(
              onPressed: _markAllRead,
              child: Text('Tümünü Oku', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
            ),
        ],
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: Colors.grey[600], strokeWidth: 1.5))
          : Column(
              children: [
                // Filter chips
                SizedBox(
                  height: 44,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    children: _categories.entries.map((e) {
                      final selected = _filter == e.key;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(e.value, style: TextStyle(fontSize: 11, color: selected ? Colors.black : Colors.grey[500])),
                          selected: selected,
                          selectedColor: const Color(0xFFC9A96E),
                          backgroundColor: const Color(0xFF242424),
                          side: BorderSide(color: selected ? const Color(0xFFC9A96E) : Colors.grey[800]!),
                          onSelected: (_) => setState(() => _filter = e.key),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                Expanded(
                  child: filtered.isEmpty
                      ? Center(child: Text('Bildirim yok', style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w300)))
                      : RefreshIndicator(
                          color: const Color(0xFFC9A96E),
                          onRefresh: _load,
                          child: ListView(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            children: [
                              if (today.isNotEmpty) ...[
                                _sectionHeader('BUGÜN'),
                                ...today.map(_buildNotificationTile),
                              ],
                              if (earlier.isNotEmpty) ...[
                                _sectionHeader('ÖNCEKİ'),
                                ...earlier.map(_buildNotificationTile),
                              ],
                            ],
                          ),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _sectionHeader(String text) => Padding(
    padding: const EdgeInsets.only(top: 16, bottom: 8),
    child: Text(text, style: TextStyle(fontSize: 10, letterSpacing: 2, color: Colors.grey[600], fontWeight: FontWeight.w500)),
  );

  Widget _buildNotificationTile(dynamic n) {
    final isRead = n['isRead'] == true;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey[800]!))),
      child: Row(
        children: [
          Icon(
            _iconForType(n['type']),
            size: 18,
            color: isRead ? Colors.grey[700] : const Color(0xFFC9A96E),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  n['title'] ?? n['body'] ?? n['message'] ?? '',
                  style: TextStyle(fontSize: 13, fontWeight: isRead ? FontWeight.w300 : FontWeight.w400, color: isRead ? Colors.grey[600] : Colors.white),
                ),
                const SizedBox(height: 2),
                Text(_timeAgo(n['createdAt']), style: TextStyle(fontSize: 10, color: Colors.grey[600])),
              ],
            ),
          ),
          if (!isRead)
            Container(width: 6, height: 6, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFC9A96E))),
        ],
      ),
    );
  }

  IconData _iconForType(String? type) {
    switch (type) {
      case 'friend_request': return Icons.person_add;
      case 'friend_accepted': return Icons.people;
      case 'like': return Icons.favorite;
      case 'comment': return Icons.chat_bubble;
      case 'coop_invite': return Icons.handshake;
      case 'coop_turn': return Icons.swap_horiz;
      case 'achievement': return Icons.emoji_events;
      case 'quest': return Icons.task_alt;
      case 'level_up': return Icons.arrow_upward;
      default: return Icons.notifications;
    }
  }

  String _timeAgo(String? dateStr) {
    if (dateStr == null) return '';
    final dt = DateTime.tryParse(dateStr);
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 0) return '${diff.inDays}g önce';
    if (diff.inHours > 0) return '${diff.inHours}s önce';
    if (diff.inMinutes > 0) return '${diff.inMinutes}dk önce';
    return 'şimdi';
  }
}
