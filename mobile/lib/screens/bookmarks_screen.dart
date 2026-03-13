import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/moderation_service.dart';
import '../models/shared_story.dart';
import 'story_detail_public_screen.dart';

class BookmarksScreen extends StatefulWidget {
  const BookmarksScreen({super.key});

  @override
  State<BookmarksScreen> createState() => _BookmarksScreenState();
}

class _BookmarksScreenState extends State<BookmarksScreen> {
  List<SharedStory> _bookmarks = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final mod = ModerationService(context.read<ApiService>());
      final data = await mod.getBookmarks();
      if (mounted) {
        setState(() {
          _bookmarks = data.map((b) {
            final ss = b['sharedStory'] as Map<String, dynamic>?;
            if (ss != null) {
              // Merge _count into top-level for fromJson compatibility
              final count = ss['_count'] as Map<String, dynamic>?;
              ss['likeCount'] = count?['likes'] ?? 0;
              ss['commentCount'] = count?['comments'] ?? 0;
              return SharedStory.fromJson(ss);
            }
            return null;
          }).whereType<SharedStory>().toList();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('KAYDEDİLENLER', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, letterSpacing: 3)),
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: Colors.grey[600], strokeWidth: 1.5))
          : _bookmarks.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.bookmark_border, size: 48, color: Colors.grey[700]),
                      const SizedBox(height: 12),
                      Text('Kaydedilen hikaye yok', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  color: const Color(0xFFC9A96E),
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(20),
                    itemCount: _bookmarks.length,
                    separatorBuilder: (_, _) => Divider(color: Colors.grey[800], height: 1),
                    itemBuilder: (context, index) {
                      final story = _bookmarks[index];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                        title: Text(
                          story.storyTitle,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${story.storyGenre}  •  ${story.user?.username ?? ''}',
                          style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                        ),
                        trailing: Icon(Icons.chevron_right, size: 18, color: Colors.grey[600]),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => StoryDetailPublicScreen(sharedStoryId: story.id)),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
