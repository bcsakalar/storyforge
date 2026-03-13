import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/social_provider.dart';
import '../models/shared_story.dart';
import '../models/comment.dart';
import '../services/api_service.dart';
import '../services/moderation_service.dart';

class StoryDetailPublicScreen extends StatefulWidget {
  final int sharedStoryId;
  const StoryDetailPublicScreen({super.key, required this.sharedStoryId});

  @override
  State<StoryDetailPublicScreen> createState() => _StoryDetailPublicScreenState();
}

class _StoryDetailPublicScreenState extends State<StoryDetailPublicScreen> {
  SharedStory? _story;
  bool _loading = true;
  bool _bookmarked = false;
  final _commentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final sp = context.read<SocialProvider>();
    final s = await sp.loadDetail(widget.sharedStoryId);
    if (mounted) {
      setState(() {
        _story = s;
        _loading = false;
      });
      sp.loadComments(widget.sharedStoryId);
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _onMenuAction(String action, SharedStory story) async {
    final mod = ModerationService(context.read<ApiService>());
    switch (action) {
      case 'report_story':
        final reason = await _showReportDialog();
        if (reason != null && mounted) {
          try {
            await mod.reportContent(targetType: 'story', targetId: story.storyId, reason: reason);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bildirim gönderildi'), backgroundColor: Color(0xFF242424), behavior: SnackBarBehavior.floating));
            }
          } catch (_) {}
        }
        break;
      case 'block_user':
        final confirm = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: const Color(0xFF242424),
            shape: const RoundedRectangleBorder(),
            title: const Text('Engelle', style: TextStyle(fontSize: 16)),
            content: Text('${story.user?.username ?? 'Bu kullanıcı'} engellensin mi?', style: TextStyle(fontSize: 14, color: Colors.grey[400])),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: Text('İptal', style: TextStyle(color: Colors.grey[500]))),
              TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Engelle', style: TextStyle(color: Color(0xFFAA4444)))),
            ],
          ),
        );
        if (confirm == true && mounted) {
          try {
            await mod.blockUser(story.userId);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kullanıcı engellendi'), backgroundColor: Color(0xFF242424), behavior: SnackBarBehavior.floating));
              Navigator.pop(context);
            }
          } catch (_) {}
        }
        break;
    }
  }

  Future<String?> _showReportDialog() {
    String? selectedReason;
    final reasons = ['Uygunsuz içerik', 'Spam', 'Nefret söylemi', 'Telif hakkı ihlali', 'Diğer'];
    return showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF242424),
          shape: const RoundedRectangleBorder(),
          title: const Text('Bildir', style: TextStyle(fontSize: 16)),
          content: RadioGroup<String>(
            groupValue: selectedReason,
            onChanged: (v) => setDialogState(() => selectedReason = v),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: reasons.map((r) => RadioListTile<String>(
                title: Text(r, style: const TextStyle(fontSize: 13)),
                value: r,
                activeColor: const Color(0xFFC9A96E),
              )).toList(),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text('İptal', style: TextStyle(color: Colors.grey[500]))),
            TextButton(
              onPressed: selectedReason != null ? () => Navigator.pop(ctx, selectedReason) : null,
              child: const Text('Bildir', style: TextStyle(color: Color(0xFFC9A96E))),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sp = context.watch<SocialProvider>();

    if (_loading) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: CircularProgressIndicator(color: Colors.grey[600], strokeWidth: 1.5)),
      );
    }

    if (_story == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('Hikaye bulunamadı', style: TextStyle(color: Colors.grey[600]))),
      );
    }

    final story = _story!;

    return Scaffold(
      appBar: AppBar(
        title: Text(story.storyTitle.toUpperCase(), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, letterSpacing: 2)),
        actions: [
          IconButton(
            icon: Icon(_bookmarked ? Icons.bookmark : Icons.bookmark_border, size: 20, color: _bookmarked ? const Color(0xFFC9A96E) : Colors.grey[600]),
            onPressed: () async {
              final mod = ModerationService(context.read<ApiService>());
              try {
                if (_bookmarked) {
                  await mod.removeBookmark(widget.sharedStoryId);
                } else {
                  await mod.addBookmark(widget.sharedStoryId);
                }
                if (mounted) setState(() => _bookmarked = !_bookmarked);
              } catch (_) {}
            },
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, size: 20, color: Colors.grey[600]),
            color: const Color(0xFF242424),
            onSelected: (v) => _onMenuAction(v, story),
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'report_story', child: Text('Hikayeyi Bildir', style: TextStyle(fontSize: 13))),
              const PopupMenuItem(value: 'block_user', child: Text('Kullanıcıyı Engelle', style: TextStyle(fontSize: 13, color: Color(0xFFAA4444)))),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: const Color(0xFF333333),
                      child: Text(story.user?.username[0].toUpperCase() ?? '?', style: const TextStyle(fontSize: 10, color: Color(0xFFC9A96E))),
                    ),
                    const SizedBox(width: 8),
                    Text(story.user?.username ?? '?', style: const TextStyle(fontSize: 13)),
                    const Spacer(),
                    Text(story.storyGenre.toUpperCase(), style: TextStyle(fontSize: 10, letterSpacing: 1.5, color: Colors.grey[500])),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(border: Border.all(color: Colors.grey[800]!), borderRadius: BorderRadius.circular(2)),
                  child: Text(story.storyContent ?? 'İçerik mevcut değil', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w300, height: 1.7, color: Colors.grey[300])),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    InkWell(
                      onTap: () async {
                        final result = await sp.toggleLike(widget.sharedStoryId);
                        if (mounted && result != null) {
                          setState(() {
                            _story = SharedStory(
                              id: story.id,
                              storyId: story.storyId,
                              userId: story.userId,
                              isPublic: story.isPublic,
                              createdAt: story.createdAt,
                              story: story.story,
                              user: story.user,
                              likeCount: result['likeCount'] ?? story.likeCount,
                              commentCount: story.commentCount,
                              hasLiked: result['liked'] ?? !story.hasLiked,
                            );
                          });
                        }
                      },
                      child: Row(
                        children: [
                          Icon(story.hasLiked ? Icons.favorite : Icons.favorite_border, size: 20, color: story.hasLiked ? const Color(0xFFC9A96E) : Colors.grey[600]),
                          const SizedBox(width: 6),
                          Text('${story.likeCount}', style: TextStyle(fontSize: 13, color: Colors.grey[500])),
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),
                    Icon(Icons.chat_bubble_outline, size: 18, color: Colors.grey[600]),
                    const SizedBox(width: 6),
                    Text('${sp.comments.length}', style: TextStyle(fontSize: 13, color: Colors.grey[500])),
                  ],
                ),
                const SizedBox(height: 24),
                Text('YORUMLAR', style: TextStyle(fontSize: 11, letterSpacing: 2, color: Colors.grey[500], fontWeight: FontWeight.w500)),
                const SizedBox(height: 12),
                ...sp.comments.map((c) => _CommentTile(comment: c, sharedStoryId: widget.sharedStoryId)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.grey[800]!))),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w300),
                    maxLength: 1000,
                    decoration: InputDecoration(
                      counterText: '',
                      hintText: 'Yorum yaz...',
                      hintStyle: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w300),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, size: 20, color: Color(0xFFC9A96E)),
                  onPressed: () async {
                    final text = _commentController.text.trim();
                    if (text.isEmpty) return;
                    _commentController.clear();
                    await sp.addComment(widget.sharedStoryId, text);
                    // Reload detail to update comment count
                    final updated = await sp.loadDetail(widget.sharedStoryId);
                    if (mounted && updated != null) {
                      setState(() => _story = updated);
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  final Comment comment;
  final int sharedStoryId;
  const _CommentTile({required this.comment, required this.sharedStoryId});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey[850] ?? Colors.grey[800]!))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(comment.user?.username ?? '?', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
              const Spacer(),
              Text(_timeAgo(comment.createdAt), style: TextStyle(fontSize: 10, color: Colors.grey[600])),
            ],
          ),
          const SizedBox(height: 4),
          Text(comment.content, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w300, color: Colors.grey[400])),
        ],
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 0) return '${diff.inDays}g önce';
    if (diff.inHours > 0) return '${diff.inHours}s önce';
    if (diff.inMinutes > 0) return '${diff.inMinutes}dk önce';
    return 'şimdi';
  }
}
