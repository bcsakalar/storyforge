import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../models/achievement.dart';
import 'achievements_screen.dart';
import 'daily_quests_screen.dart';
import 'settings_screen.dart';
import 'bookmarks_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _profile;
  Map<String, dynamic>? _levelInfo;
  List<Achievement> _recentAchievements = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final api = context.read<ApiService>();

      // Load independently so one failure doesn't break all
      Map<String, dynamic>? profile;
      Map<String, dynamic>? levelInfo;
      List<Achievement> achievements = [];

      try {
        final res = await api.get('/user/profile');
        profile = res.data['user'];
        // level info also comes from profile response
        if (res.data['stats'] != null) {
          levelInfo = Map<String, dynamic>.from(res.data['stats']);
        }
      } catch (_) {}

      // Fallback: get level info directly if not from profile
      if (levelInfo == null) {
        try {
          final res = await api.get('/level');
          levelInfo = res.data;
        } catch (_) {}
      }

      try {
        final res = await api.get('/achievements');
        achievements = (res.data['achievements'] as List?)
            ?.map((a) => Achievement.fromJson(a))
            .where((a) => a.isUnlocked)
            .take(5)
            .toList() ?? [];
      } catch (_) {}

      if (mounted) {
        setState(() {
          _profile = profile;
          _levelInfo = levelInfo;
          _recentAchievements = achievements;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: CircularProgressIndicator(color: Colors.grey[600], strokeWidth: 1.5)),
      );
    }

    final level = _levelInfo?['level'] ?? 1;
    final xp = _levelInfo?['xp'] ?? 0;
    final nextLevelXp = _levelInfo?['nextLevelXp'] ?? ((level + 1) * (level + 1) * 100);
    final username = _profile?['username'] ?? '';
    final email = _profile?['email'] ?? '';
    final createdAt = _profile?['createdAt'] ?? _profile?['created_at'];
    final storiesCount = _profile?['_count']?['stories'] ?? 0;
    final completedCount = _profile?['stats']?['storiesCompleted'] ?? _profile?['stats']?['stories_completed'] ?? 0;
    final streak = _profile?['stats']?['dailyStreak'] ?? _profile?['stats']?['daily_streak'] ?? _profile?['stats']?['streak'] ?? 0;

    // Format join date
    String joinDate = '';
    if (createdAt != null) {
      try {
        final date = DateTime.parse(createdAt.toString());
        const months = ['Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran', 'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'];
        joinDate = '${date.day} ${months[date.month - 1]} ${date.year}';
      } catch (_) {}
    }

    // XP progress
    final xpProgress = nextLevelXp > 0 ? (xp / nextLevelXp).clamp(0.0, 1.0) : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('PROFİL', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, letterSpacing: 3)),
        actions: [
          IconButton(
            icon: Icon(Icons.bookmark_border, size: 20, color: Colors.grey[600]),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BookmarksScreen())),
          ),
          IconButton(
            icon: Icon(Icons.settings_outlined, size: 20, color: Colors.grey[600]),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: const Color(0xFFC9A96E),
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: const Color(0xFF333333),
                    child: Text(username.isNotEmpty ? username[0].toUpperCase() : '?', style: const TextStyle(fontSize: 24, color: Color(0xFFC9A96E), fontWeight: FontWeight.w500)),
                  ),
                  const SizedBox(height: 12),
                  Text(username, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 6),
                  Text(
                    [email, if (joinDate.isNotEmpty) 'Katılım: $joinDate'].where((s) => s.isNotEmpty).join(' · '),
                    style: TextStyle(fontSize: 12, color: Colors.grey[500], fontWeight: FontWeight.w300),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // 4-stat grid like web
            Row(
              children: [
                Expanded(child: _StatBox(value: '$level', label: 'SEVİYE')),
                const SizedBox(width: 10),
                Expanded(child: _StatBox(value: '$xp', label: 'XP')),
                const SizedBox(width: 10),
                Expanded(child: _StatBox(value: '$storiesCount', label: 'HİKAYE')),
                const SizedBox(width: 10),
                Expanded(child: _StatBox(value: '$completedCount', label: 'TAMAMLANAN')),
              ],
            ),
            const SizedBox(height: 16),
            // XP Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: xpProgress.toDouble(),
                backgroundColor: Colors.grey[800],
                color: const Color(0xFFC9A96E),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '$xp / $nextLevelXp XP · Seviye ${level + 1} için',
              style: TextStyle(fontSize: 11, color: Colors.grey[600], fontWeight: FontWeight.w300),
            ),
            if (streak > 0) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.local_fire_department, size: 16, color: Color(0xFFC9A96E)),
                  const SizedBox(width: 6),
                  Text('$streak günlük seri', style: TextStyle(fontSize: 12, color: Colors.grey[500], fontWeight: FontWeight.w400)),
                ],
              ),
            ],
            const SizedBox(height: 24),
            _menuItem(Icons.emoji_events_outlined, 'Başarımlar', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AchievementsScreen()))),
            _menuItem(Icons.task_alt_outlined, 'Günlük Görevler', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DailyQuestsScreen()))),
            _menuItem(Icons.settings_outlined, 'Ayarlar', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()))),
            if (_recentAchievements.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text('SON BAŞARIMLAR', style: TextStyle(fontSize: 10, letterSpacing: 2, color: Colors.grey[500], fontWeight: FontWeight.w500)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _recentAchievements.map((a) => Chip(
                  avatar: const Icon(Icons.emoji_events, size: 16, color: Color(0xFFC9A96E)),
                  label: Text(a.title, style: const TextStyle(fontSize: 11)),
                  backgroundColor: const Color(0xFF2A2A2A),
                  side: BorderSide(color: Colors.grey[700]!),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
                )).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _menuItem(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey[800]!))),
        child: Row(
          children: [
            Icon(icon, size: 20, color: Colors.grey[500]),
            const SizedBox(width: 14),
            Expanded(child: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w400))),
            Icon(Icons.chevron_right, size: 18, color: Colors.grey[700]),
          ],
        ),
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String value;
  final String label;
  const _StatBox({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[800]!),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Column(
        children: [
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Color(0xFFC9A96E))),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 9, letterSpacing: 1.5, color: Colors.grey[500])),
        ],
      ),
    );
  }
}
