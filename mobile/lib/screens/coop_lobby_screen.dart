import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/coop_provider.dart';
import '../providers/friend_provider.dart';
import 'coop_story_screen.dart';

class CoopLobbyScreen extends StatefulWidget {
  const CoopLobbyScreen({super.key});

  @override
  State<CoopLobbyScreen> createState() => _CoopLobbyScreenState();
}

class _CoopLobbyScreenState extends State<CoopLobbyScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    Future.microtask(() {
      if (!mounted) return;
      final cp = context.read<CoopProvider>();
      cp.loadSessions();
      cp.loadInvites();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showCreateDialog() {
    final fp = context.read<FriendProvider>();
    if (fp.friends.isEmpty) fp.loadFriends();

    String selectedGenre = 'fantasy';
    int? selectedFriendId;

    final genres = ['fantasy', 'sci-fi', 'horror', 'romance', 'mystery', 'adventure'];
    final genreLabels = {'fantasy': 'Fantastik', 'sci-fi': 'Bilim Kurgu', 'horror': 'Korku', 'romance': 'Romantik', 'mystery': 'Gizem', 'adventure': 'Macera'};

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final friends = context.read<FriendProvider>().friends;

          return AlertDialog(
            backgroundColor: const Color(0xFF242424),
            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
            title: const Text('CO-OP HİKAYE', style: TextStyle(fontSize: 14, letterSpacing: 2, fontWeight: FontWeight.w500)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('TÜR', style: TextStyle(fontSize: 10, letterSpacing: 1.5, color: Colors.grey[500])),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: genres.map((g) => ChoiceChip(
                      label: Text(genreLabels[g]!, style: TextStyle(fontSize: 11, color: selectedGenre == g ? Colors.black : Colors.grey[400])),
                      selected: selectedGenre == g,
                      selectedColor: const Color(0xFFC9A96E),
                      backgroundColor: const Color(0xFF1A1A1A),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2), side: BorderSide(color: Colors.grey[700]!)),
                      onSelected: (s) => setDialogState(() => selectedGenre = g),
                    )).toList(),
                  ),
                  const SizedBox(height: 20),
                  Text('ARKADAŞ', style: TextStyle(fontSize: 10, letterSpacing: 1.5, color: Colors.grey[500])),
                  const SizedBox(height: 8),
                  if (friends.isEmpty)
                    Text('Arkadaş listeniz boş', style: TextStyle(fontSize: 12, color: Colors.grey[600]))
                  else
                    ...friends.map((f) {
                      final friend = f.getFriend(null);
                      if (friend == null) return const SizedBox.shrink();
                      final isSelected = selectedFriendId == friend.id;
                      return ListTile(
                        leading: Icon(
                          isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                          color: isSelected ? const Color(0xFFC9A96E) : Colors.grey[600],
                          size: 20,
                        ),
                        title: Text(friend.username, style: const TextStyle(fontSize: 13)),
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        onTap: () => setDialogState(() => selectedFriendId = friend.id),
                      );
                    }),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('İPTAL', style: TextStyle(fontSize: 11, letterSpacing: 1, color: Colors.grey[500])),
              ),
              TextButton(
                onPressed: selectedFriendId == null
                    ? null
                    : () async {
                        Navigator.pop(ctx);
                        final cp = context.read<CoopProvider>();
                        await cp.createSession(selectedGenre, selectedFriendId!);
                      },
                child: const Text('BAŞLAT', style: TextStyle(fontSize: 11, letterSpacing: 1, color: Color(0xFFC9A96E))),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cp = context.watch<CoopProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('CO-OP', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, letterSpacing: 3)),
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFFC9A96E),
          unselectedLabelColor: Colors.grey[600],
          indicatorColor: const Color(0xFFC9A96E),
          labelStyle: const TextStyle(fontSize: 11, letterSpacing: 1.5, fontWeight: FontWeight.w500),
          tabs: [
            Tab(text: 'HİKAYELER (${cp.sessions.length})'),
            Tab(text: 'DAVETLER (${cp.invites.length})'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateDialog,
        backgroundColor: const Color(0xFFC9A96E),
        shape: const CircleBorder(),
        child: const Icon(Icons.add, color: Colors.black),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSessionsList(cp),
          _buildInvitesList(cp),
        ],
      ),
    );
  }

  Widget _buildSessionsList(CoopProvider cp) {
    if (cp.loading) return Center(child: CircularProgressIndicator(color: Colors.grey[600], strokeWidth: 1.5));
    if (cp.sessions.isEmpty) {
      return Center(child: Text('Henüz co-op hikayeniz yok', style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w300)));
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      itemCount: cp.sessions.length,
      itemBuilder: (context, index) {
        final s = cp.sessions[index];
        return InkWell(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CoopStoryScreen(sessionId: s.id))),
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(border: Border.all(color: Colors.grey[800]!), borderRadius: BorderRadius.circular(2)),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.story?.title ?? 'Co-op Hikaye', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 4),
                      Text('${s.host?.username ?? '?'} & ${s.guest?.username ?? '?'}', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    border: Border.all(color: s.status == 'ACTIVE' ? const Color(0xFFC9A96E) : s.status == 'COMPLETED' ? Colors.grey[600]! : Colors.grey[700]!),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: Text(
                    s.status == 'ACTIVE' ? 'AKTİF' : s.status == 'WAITING' ? 'BEKLENİYOR' : s.status == 'COMPLETED' ? 'BİTTİ' : s.status,
                    style: TextStyle(fontSize: 9, letterSpacing: 1, color: s.status == 'ACTIVE' ? const Color(0xFFC9A96E) : Colors.grey[600]),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInvitesList(CoopProvider cp) {
    if (cp.invites.isEmpty) {
      return Center(child: Text('Davet yok', style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w300)));
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      itemCount: cp.invites.length,
      itemBuilder: (context, index) {
        final inv = cp.invites[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(border: Border.all(color: Colors.grey[800]!), borderRadius: BorderRadius.circular(2)),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${inv.host?.username ?? '?'} seni davet etti', style: const TextStyle(fontSize: 13)),
                    const SizedBox(height: 4),
                    Text(inv.genre.toUpperCase(), style: TextStyle(fontSize: 10, letterSpacing: 1.5, color: Colors.grey[500])),
                  ],
                ),
              ),
              TextButton(
                onPressed: () async {
                  final nav = Navigator.of(context);
                  final ok = await cp.joinSession(inv.id);
                  if (ok && mounted) {
                    nav.push(MaterialPageRoute(builder: (_) => CoopStoryScreen(sessionId: inv.id)));
                  }
                },
                child: const Text('KATIL', style: TextStyle(fontSize: 11, letterSpacing: 1, color: Color(0xFFC9A96E))),
              ),
              const SizedBox(width: 4),
              TextButton(
                onPressed: () => cp.rejectSession(inv.id),
                child: Text('REDDET', style: TextStyle(fontSize: 11, letterSpacing: 1, color: Colors.red[400])),
              ),
            ],
          ),
        );
      },
    );
  }
}
