import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../models/achievement.dart';

class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  List<Achievement> _achievements = [];
  bool _loading = true;
  Map<String, dynamic>? _levelInfo;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final api = context.read<ApiService>();
      final results = await Future.wait([
        api.get('/achievements'),
        api.get('/level'),
      ]);

      final achList = (results[0].data['achievements'] as List?)?.map((a) => Achievement.fromJson(a)).toList() ?? [];
      final level = results[1].data;

      if (mounted) {
        setState(() {
          _achievements = achList;
          _levelInfo = level;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BAŞARIMLAR', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, letterSpacing: 3)),
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: Colors.grey[600], strokeWidth: 1.5))
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (_levelInfo != null) _buildLevelCard(),
                const SizedBox(height: 24),
                Text(
                  'BAŞARIMLAR (${_achievements.where((a) => a.isUnlocked).length}/${_achievements.length})',
                  style: TextStyle(fontSize: 11, letterSpacing: 2, color: Colors.grey[500], fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 12),
                ..._achievements.map((a) => _AchievementTile(achievement: a)),
              ],
            ),
    );
  }

  Widget _buildLevelCard() {
    final level = _levelInfo!['level'] ?? 1;
    final xp = _levelInfo!['xp'] ?? 0;
    final xpForNext = _levelInfo!['xpForNextLevel'] ?? 100;
    final xpForCurrent = _levelInfo!['xpForCurrentLevel'] ?? 0;
    final progress = xpForNext > xpForCurrent ? (xp - xpForCurrent) / (xpForNext - xpForCurrent) : 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFC9A96E).withAlpha(100)),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFC9A96E), width: 2),
                ),
                child: Center(
                  child: Text('$level', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Color(0xFFC9A96E))),
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('SEVİYE', style: TextStyle(fontSize: 10, letterSpacing: 2, color: Color(0xFFC9A96E))),
                  const SizedBox(height: 4),
                  Text('$xp XP', style: TextStyle(fontSize: 13, color: Colors.grey[400])),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(1),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0).toDouble(),
              minHeight: 4,
              backgroundColor: Colors.grey[800],
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFC9A96E)),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$xp / $xpForNext XP',
            style: TextStyle(fontSize: 10, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }
}

class _AchievementTile extends StatelessWidget {
  final Achievement achievement;
  const _AchievementTile({required this.achievement});

  static const _icons = {
    'first_story': Icons.auto_stories,
    'story_5': Icons.library_books,
    'story_10': Icons.local_library,
    'first_share': Icons.share,
    'popular': Icons.trending_up,
    'social_butterfly': Icons.people,
    'first_coop': Icons.handshake,
    'all_genres': Icons.category,
    'streak_7': Icons.local_fire_department,
    'streak_30': Icons.whatshot,
    'level_5': Icons.star_outline,
    'level_10': Icons.star,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: achievement.isUnlocked ? const Color(0xFF1F1F1F) : Colors.transparent,
        border: Border.all(color: achievement.isUnlocked ? const Color(0xFFC9A96E).withAlpha(60) : Colors.grey[800]!),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Row(
        children: [
          Icon(
            _icons[achievement.key] ?? Icons.emoji_events,
            size: 24,
            color: achievement.isUnlocked ? const Color(0xFFC9A96E) : Colors.grey[700],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  achievement.title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: achievement.isUnlocked ? Colors.white : Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  achievement.description,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w300, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
          if (achievement.isUnlocked)
            const Icon(Icons.check_circle, size: 18, color: Color(0xFFC9A96E))
          else
            Icon(Icons.lock_outline, size: 18, color: Colors.grey[700]),
        ],
      ),
    );
  }
}
