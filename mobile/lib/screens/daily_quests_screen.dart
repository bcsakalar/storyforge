import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import '../services/api_service.dart';
import '../models/quest.dart';

class DailyQuestsScreen extends StatefulWidget {
  const DailyQuestsScreen({super.key});

  @override
  State<DailyQuestsScreen> createState() => _DailyQuestsScreenState();
}

class _DailyQuestsScreenState extends State<DailyQuestsScreen> {
  List<Quest> _quests = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final api = context.read<ApiService>();
      final res = await api.get('/quests/daily');
      final list = (res.data['quests'] as List?)?.map((q) => Quest.fromJson(q)).toList() ?? [];
      if (mounted) setState(() { _quests = list; _loading = false; });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _claim(int questId) async {
    try {
      final api = context.read<ApiService>();
      final res = await api.post('/quests/$questId/claim', data: {});
      if (mounted) {
        final xp = res.data['xpReward'] ?? 0;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('+$xp XP kazandınız!', style: const TextStyle(color: Colors.white)), backgroundColor: const Color(0xFF242424), behavior: SnackBarBehavior.floating),
        );
        _load();
      }
    } catch (e) {
      if (mounted) {
        String msg = 'Görevi tamamlamadan ödül alamazsın!';
        if (e is DioException && e.response?.statusCode == 404) {
          msg = 'Görev bulunamadı';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg, style: const TextStyle(color: Colors.white)), backgroundColor: const Color(0xFF242424), behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('GÜNLÜK GÖREVLER', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, letterSpacing: 2)),
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: Colors.grey[600], strokeWidth: 1.5))
          : _quests.isEmpty
              ? Center(child: Text('Bugün görev yok', style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w300)))
              : ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Text('BUGÜNKÜ GÖREVLER', style: TextStyle(fontSize: 11, letterSpacing: 2, color: Colors.grey[500], fontWeight: FontWeight.w500)),
                    const SizedBox(height: 12),
                    ..._quests.map((q) => _QuestCard(quest: q, onClaim: () => _claim(q.id))),
                  ],
                ),
    );
  }
}

class _QuestCard extends StatelessWidget {
  final Quest quest;
  final VoidCallback onClaim;
  const _QuestCard({required this.quest, required this.onClaim});

  static const _questIcons = {
    'create_story': Icons.add_circle_outline,
    'make_choices': Icons.touch_app,
    'complete_story': Icons.check_circle_outline,
    'share_story': Icons.share_outlined,
    'like_stories': Icons.favorite_outline,
    'comment_stories': Icons.chat_bubble_outline,
    'send_messages': Icons.mail_outline,
  };

  @override
  Widget build(BuildContext context) {
    final progress = (quest.target ?? 0) > 0 ? (quest.progress ?? 0) / (quest.target ?? 1) : 0.0;
    final isComplete = (quest.progress ?? 0) >= (quest.target ?? 0);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: quest.claimed ? Colors.grey[800]! : isComplete ? const Color(0xFFC9A96E).withAlpha(80) : Colors.grey[800]!),
        borderRadius: BorderRadius.circular(2),
        color: quest.claimed ? const Color(0xFF1A1A1A) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _questIcons[quest.type] ?? Icons.task_alt,
                size: 20,
                color: quest.claimed ? Colors.grey[700] : isComplete ? const Color(0xFFC9A96E) : Colors.grey[500],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  quest.description,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: quest.claimed ? Colors.grey[600] : Colors.white,
                    decoration: quest.claimed ? TextDecoration.lineThrough : null,
                  ),
                ),
              ),
              Text(
                '+${quest.xpReward} XP',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: quest.claimed ? Colors.grey[700] : const Color(0xFFC9A96E)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(1),
                  child: LinearProgressIndicator(
                    value: progress.clamp(0.0, 1.0),
                    minHeight: 3,
                    backgroundColor: Colors.grey[800],
                    valueColor: AlwaysStoppedAnimation<Color>(quest.claimed ? Colors.grey[700]! : const Color(0xFFC9A96E)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text('${quest.progress ?? 0}/${quest.target ?? 0}', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
              if (isComplete && !quest.claimed) ...[
                const SizedBox(width: 8),
                InkWell(
                  onTap: onClaim,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFC9A96E),
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: const Text('AL', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.black, letterSpacing: 1)),
                  ),
                ),
              ],
              if (quest.claimed) ...[
                const SizedBox(width: 8),
                Icon(Icons.check, size: 16, color: Colors.grey[700]),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
