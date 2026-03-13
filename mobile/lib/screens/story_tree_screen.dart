import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';

class StoryTreeScreen extends StatefulWidget {
  final int storyId;
  final String storyTitle;
  const StoryTreeScreen({super.key, required this.storyId, required this.storyTitle});

  @override
  State<StoryTreeScreen> createState() => _StoryTreeScreenState();
}

class _StoryTreeScreenState extends State<StoryTreeScreen> {
  List<dynamic> _chapters = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final api = context.read<ApiService>();
      final res = await api.get('/stories/${widget.storyId}/tree');
      if (mounted) {
        setState(() {
          final tree = res.data['tree'];
          if (tree is Map) {
            _chapters = (tree['chapters'] as List?) ?? [];
          } else if (tree is List) {
            _chapters = tree;
          } else {
            _chapters = [];
          }
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _branchFrom(int chapterId) async {
    try {
      final api = context.read<ApiService>();
      final res = await api.post('/stories/${widget.storyId}/branch', data: {'chapterId': chapterId});
      if (mounted) {
        final newStoryId = res.data['story']?['id'];
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Dal oluşturuldu! Yeni hikaye #$newStoryId', style: const TextStyle(color: Colors.white)),
            backgroundColor: const Color(0xFF242424),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e', style: const TextStyle(color: Colors.white)), backgroundColor: Colors.red[900], behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('HİKAYE AĞACI', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, letterSpacing: 2)),
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: Colors.grey[600], strokeWidth: 1.5))
          : _chapters.isEmpty
              ? Center(child: Text('Bölüm bulunamadı', style: TextStyle(color: Colors.grey[600])))
              : ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: _chapters.length,
                  itemBuilder: (context, index) {
                    final ch = _chapters[index];
                    return _ChapterNode(
                      chapter: ch,
                      isLast: index == _chapters.length - 1,
                      onBranch: () => _branchFrom(ch['id']),
                    );
                  },
                ),
    );
  }
}

class _ChapterNode extends StatelessWidget {
  final Map<String, dynamic> chapter;
  final bool isLast;
  final VoidCallback onBranch;
  const _ChapterNode({required this.chapter, required this.isLast, required this.onBranch});

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 30,
            child: Column(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFC9A96E), width: 1.5),
                    color: isLast ? const Color(0xFFC9A96E) : Colors.transparent,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(width: 1, color: Colors.grey[700]),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[800]!),
                borderRadius: BorderRadius.circular(2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'BÖLÜM ${chapter['chapterNumber'] ?? '?'}',
                        style: TextStyle(fontSize: 10, letterSpacing: 2, color: Colors.grey[500], fontWeight: FontWeight.w500),
                      ),
                      const Spacer(),
                      InkWell(
                        onTap: onBranch,
                        child: Row(
                          children: [
                            Icon(Icons.call_split, size: 14, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Text('DALLAN', style: TextStyle(fontSize: 9, letterSpacing: 1, color: Colors.grey[600])),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (chapter['summary'] != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      chapter['summary'],
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w300, color: Colors.grey[400]),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (chapter['selectedChoice'] != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      '→ ${chapter['selectedChoice']}',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w300, color: Color(0xFFC9A96E)),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
