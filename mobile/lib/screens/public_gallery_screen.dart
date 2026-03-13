import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/social_provider.dart';
import '../models/shared_story.dart';
import 'story_detail_public_screen.dart';

class PublicGalleryScreen extends StatefulWidget {
  const PublicGalleryScreen({super.key});

  @override
  State<PublicGalleryScreen> createState() => _PublicGalleryScreenState();
}

class _PublicGalleryScreenState extends State<PublicGalleryScreen> {
  String _sort = 'newest';
  final _searchController = TextEditingController();
  Timer? _debounce;

  static const _genres = [
    {'value': '', 'label': 'Tümü'},
    {'value': 'fantasy', 'label': 'Fantastik'},
    {'value': 'horror', 'label': 'Korku'},
    {'value': 'sci-fi', 'label': 'Bilim Kurgu'},
    {'value': 'romance', 'label': 'Romantik'},
    {'value': 'adventure', 'label': 'Macera'},
    {'value': 'mystery', 'label': 'Gizem'},
  ];

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      context.read<SocialProvider>().loadPublicStories(sort: _sort);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      final sp = context.read<SocialProvider>();
      sp.setSearchQuery(query.trim());
      sp.loadPublicStories(sort: _sort);
    });
  }

  void _onGenreSelected(String genre) {
    final sp = context.read<SocialProvider>();
    sp.setSelectedGenre(genre);
    sp.loadPublicStories(sort: _sort);
  }

  @override
  Widget build(BuildContext context) {
    final sp = context.watch<SocialProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('KEŞFET', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, letterSpacing: 3)),
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Icons.sort, size: 20, color: Colors.grey[600]),
            color: const Color(0xFF242424),
            onSelected: (v) {
              setState(() => _sort = v);
              sp.loadPublicStories(sort: v);
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'newest', child: Text('En Yeni', style: TextStyle(fontSize: 13))),
              const PopupMenuItem(value: 'popular', child: Text('Popüler', style: TextStyle(fontSize: 13))),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Hikaye ara...',
                hintStyle: TextStyle(fontSize: 13, color: Colors.grey[600]),
                prefixIcon: Icon(Icons.search, size: 20, color: Colors.grey[600]),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear, size: 18, color: Colors.grey[600]),
                        onPressed: () {
                          _searchController.clear();
                          _onSearchChanged('');
                        },
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFF242424),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: Colors.grey[800]!)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: Colors.grey[800]!)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: Color(0xFFC9A96E))),
              ),
            ),
          ),
          // Genre chips
          SizedBox(
            height: 48,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              scrollDirection: Axis.horizontal,
              itemCount: _genres.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final genre = _genres[index];
                final isSelected = sp.selectedGenre == genre['value'];
                return ChoiceChip(
                  label: Text(genre['label']!, style: TextStyle(fontSize: 12, color: isSelected ? Colors.black : Colors.grey[400])),
                  selected: isSelected,
                  selectedColor: const Color(0xFFC9A96E),
                  backgroundColor: const Color(0xFF242424),
                  side: BorderSide(color: isSelected ? const Color(0xFFC9A96E) : Colors.grey[800]!),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  onSelected: (_) => _onGenreSelected(genre['value']!),
                );
              },
            ),
          ),
          // Story list
          Expanded(
            child: sp.loadingPublic
                ? Center(child: CircularProgressIndicator(color: Colors.grey[600], strokeWidth: 1.5))
                : sp.publicStories.isEmpty
                    ? RefreshIndicator(
                        color: const Color(0xFFC9A96E),
                        onRefresh: () => sp.loadPublicStories(sort: _sort),
                        child: ListView(
                          children: [
                            SizedBox(height: MediaQuery.of(context).size.height * 0.25),
                            Center(child: Text('Hikaye bulunamadı', style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w300))),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        color: const Color(0xFFC9A96E),
                        onRefresh: () => sp.loadPublicStories(sort: _sort),
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          itemCount: sp.publicStories.length,
                          itemBuilder: (context, index) {
                            final story = sp.publicStories[index];
                            return _SharedStoryCard(story: story);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _SharedStoryCard extends StatelessWidget {
  final SharedStory story;
  const _SharedStoryCard({required this.story});

  static const _genreIcons = {
    'fantasy': Icons.auto_fix_high,
    'sci-fi': Icons.rocket_launch_outlined,
    'horror': Icons.visibility,
    'romance': Icons.favorite_outline,
    'mystery': Icons.search,
    'adventure': Icons.explore_outlined,
  };

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => StoryDetailPublicScreen(sharedStoryId: story.id)));
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[800]!),
          borderRadius: BorderRadius.circular(2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_genreIcons[story.storyGenre] ?? Icons.book, size: 16, color: const Color(0xFFC9A96E)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(story.storyTitle, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                CircleAvatar(
                  radius: 10,
                  backgroundColor: const Color(0xFF333333),
                  child: Text(story.user?.username[0].toUpperCase() ?? '?', style: const TextStyle(fontSize: 8, color: Color(0xFFC9A96E))),
                ),
                const SizedBox(width: 6),
                Text(story.user?.username ?? '?', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                const Spacer(),
                Icon(Icons.favorite, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text('${story.likeCount}', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                const SizedBox(width: 12),
                Icon(Icons.chat_bubble_outline, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text('${story.commentCount}', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
