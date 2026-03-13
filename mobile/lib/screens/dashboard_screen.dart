import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/story_provider.dart';
import '../providers/notification_provider.dart';
import '../services/offline_service.dart';
import '../models/story.dart';
import '../l10n/app_localizations.dart';
import 'new_story_screen.dart';
import 'story_screen.dart';
import 'public_gallery_screen.dart';
import 'friends_screen.dart';
import 'conversations_screen.dart';
import 'profile_screen.dart';
import 'coop_lobby_screen.dart';
import 'notifications_screen.dart';
import '../widgets/connection_banner.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      context.read<StoryProvider>().loadStories();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const ConnectionBanner(),
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: const [
                _HomeTab(),
                PublicGalleryScreen(),
                FriendsScreen(),
                ConversationsScreen(),
                ProfileScreen(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        type: BottomNavigationBarType.fixed,
        backgroundColor: const Color(0xFF1A1A1A),
        selectedItemColor: const Color(0xFFC9A96E),
        unselectedItemColor: Colors.grey[700],
        selectedFontSize: 10,
        unselectedFontSize: 10,
        selectedLabelStyle: const TextStyle(letterSpacing: 1),
        items: [
          BottomNavigationBarItem(icon: const Icon(Icons.auto_stories, size: 22), label: AppLocalizations.of(context)!.stories.toUpperCase()),
          BottomNavigationBarItem(icon: const Icon(Icons.explore_outlined, size: 22), label: AppLocalizations.of(context)!.explore.toUpperCase()),
          BottomNavigationBarItem(icon: const Icon(Icons.people_outline, size: 22), label: AppLocalizations.of(context)!.friends.toUpperCase()),
          BottomNavigationBarItem(icon: const Icon(Icons.chat_outlined, size: 22), label: AppLocalizations.of(context)!.messages.toUpperCase()),
          BottomNavigationBarItem(icon: const Icon(Icons.person_outline, size: 22), label: AppLocalizations.of(context)!.profile.toUpperCase()),
        ],
      ),
    );
  }
}

class _HomeTab extends StatefulWidget {
  const _HomeTab();

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      context.read<NotificationProvider>().loadUnreadCount();
    });
  }

  @override
  Widget build(BuildContext context) {
    final storyProvider = context.watch<StoryProvider>();
    final notifProvider = context.watch<NotificationProvider>();
    final notifCount = notifProvider.unreadCount;

    return Scaffold(
      appBar: AppBar(
        title: const Text('STORYFORGE', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, letterSpacing: 3)),
        actions: [
          IconButton(
            icon: Icon(Icons.group_work_outlined, size: 20, color: Colors.grey[600]),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CoopLobbyScreen())),
            tooltip: 'Co-op',
          ),
          IconButton(
            icon: Badge(
              isLabelVisible: notifCount > 0,
              label: Text('$notifCount', style: const TextStyle(fontSize: 9)),
              backgroundColor: const Color(0xFFC9A96E),
              child: Icon(Icons.notifications_outlined, size: 20, color: Colors.grey[600]),
            ),
            onPressed: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()));
              if (mounted) notifProvider.loadUnreadCount();
            },
            tooltip: 'Bildirimler',
          ),
        ],
      ),
      body: storyProvider.loading
          ? Center(child: CircularProgressIndicator(color: Colors.grey[600], strokeWidth: 1.5))
          : storyProvider.stories.isEmpty
              ? _buildEmptyState(context)
              : _buildStoryList(context, storyProvider.stories),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(AppLocalizations.of(context)!.noStories, style: TextStyle(fontSize: 14, color: Colors.grey[600], fontWeight: FontWeight.w300)),
          const SizedBox(height: 24),
          OutlinedButton(
            onPressed: () => _newStory(context),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: Colors.grey[600]!),
              shape: const RoundedRectangleBorder(),
              foregroundColor: Colors.grey[300],
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            ),
            child: Text(AppLocalizations.of(context)!.newStory.toUpperCase(), style: const TextStyle(fontSize: 11, letterSpacing: 2, fontWeight: FontWeight.w400)),
          ),
        ],
      ),
    );
  }

  void _newStory(BuildContext context) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const NewStoryScreen()),
    );
    if (result == true && context.mounted) {
      context.read<StoryProvider>().loadStories();
    }
  }

  Widget _buildStoryList(BuildContext context, List<Story> stories) {
    return RefreshIndicator(
      color: const Color(0xFFC9A96E),
      onRefresh: () => context.read<StoryProvider>().loadStories(),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Row(
              children: [
                Text('HİKAYELER', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, letterSpacing: 3, color: Colors.grey[500])),
                const Spacer(),
                GestureDetector(
                  onTap: () => _newStory(context),
                  child: Text('+ ${AppLocalizations.of(context)!.newStory.toUpperCase()}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500, letterSpacing: 2, color: Color(0xFFC9A96E))),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: stories.length,
              itemBuilder: (context, index) {
                final story = stories[index];
                return _StoryRow(story: story);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _StoryRow extends StatelessWidget {
  final Story story;
  const _StoryRow({required this.story});

  @override
  Widget build(BuildContext context) {
    final isDownloaded = context.watch<OfflineService>().isStoryDownloaded(story.id);

    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => StoryScreen(storyId: story.id))),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey[800]!))),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          story.title.length > 60 ? '${story.title.substring(0, 60)}...' : story.title,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w400),
                        ),
                      ),
                      if (isDownloaded)
                        Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: Icon(Icons.download_done, size: 14, color: const Color(0xFFC9A96E)),
                        ),
                      if (story.isCompleted)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(border: Border.all(color: Colors.grey[700]!), borderRadius: BorderRadius.circular(2)),
                          child: Text('BİTTİ', style: TextStyle(fontSize: 8, letterSpacing: 1, color: Colors.grey[600])),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(story.genre.toUpperCase(), style: const TextStyle(fontSize: 10, letterSpacing: 1.5, color: Color(0xFFC9A96E), fontWeight: FontWeight.w500)),
                      const SizedBox(width: 12),
                      Text('${story.chapterCount} bölüm', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                      if (story.mood != null) ...[
                        const SizedBox(width: 12),
                        Text(story.mood!.toUpperCase(), style: TextStyle(fontSize: 9, letterSpacing: 1, color: Colors.grey[600])),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.close, size: 16, color: Colors.grey[700]),
              onPressed: () async {
                final storyProvider = context.read<StoryProvider>();
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: const Color(0xFF242424),
                    shape: const RoundedRectangleBorder(),
                    title: const Text('Sil', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w400)),
                    content: const Text('Bu hikayeyi silmek istediğine emin misin?', style: TextStyle(fontWeight: FontWeight.w300)),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('İptal', style: TextStyle(color: Colors.grey[500]))),
                      TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sil', style: TextStyle(color: Color(0xFFAA4444)))),
                    ],
                  ),
                );
                if (confirm == true) {
                  storyProvider.deleteStory(story.id);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
