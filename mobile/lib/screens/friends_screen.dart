import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/friend_provider.dart';
import '../providers/auth_provider.dart';
import '../services/socket_service.dart';
import 'chat_screen.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    Future.microtask(() {
      if (!mounted) return;
      final fp = context.read<FriendProvider>();
      fp.loadFriends();
      fp.loadPendingRequests();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fp = context.watch<FriendProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('ARKADAŞLAR', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, letterSpacing: 3)),
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFFC9A96E),
          unselectedLabelColor: Colors.grey[600],
          indicatorColor: const Color(0xFFC9A96E),
          labelStyle: const TextStyle(fontSize: 11, letterSpacing: 1.5, fontWeight: FontWeight.w500),
          tabs: [
            Tab(text: 'ARKADAŞLAR (${fp.friends.length})'),
            Tab(text: 'İSTEKLER (${fp.pendingRequests.length})'),
            const Tab(text: 'ARA'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildFriendsList(fp),
          _buildPendingList(fp),
          _buildSearchTab(fp),
        ],
      ),
    );
  }

  Widget _buildFriendsList(FriendProvider fp) {
    if (fp.loading) return Center(child: CircularProgressIndicator(color: Colors.grey[600], strokeWidth: 1.5));
    if (fp.friends.isEmpty) {
      return Center(child: Text('Henüz arkadaşın yok', style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w300)));
    }

    final myId = context.read<AuthProvider>().user?.id;
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: fp.friends.length,
      itemBuilder: (context, index) {
        final f = fp.friends[index];
        final friend = f.getFriend(myId);
        if (friend == null) return const SizedBox.shrink();

        return Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey[800]!))),
          child: Row(
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: const Color(0xFF333333),
                    child: Text(friend.username[0].toUpperCase(), style: const TextStyle(color: Color(0xFFC9A96E), fontWeight: FontWeight.w500)),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: context.watch<SocketService>().isUserOnline(friend.id)
                            ? const Color(0xFF4CAF50)
                            : Colors.grey[700],
                        border: Border.all(color: const Color(0xFF1A1A1A), width: 1.5),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(friend.username, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w400))),
              IconButton(
                icon: Icon(Icons.chat_outlined, size: 18, color: Colors.grey[600]),
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(userId: friend.id, username: friend.username)));
                },
              ),
              IconButton(
                icon: Icon(Icons.person_remove_outlined, size: 18, color: Colors.grey[700]),
                onPressed: () => fp.removeFriend(f.id),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPendingList(FriendProvider fp) {
    if (fp.pendingRequests.isEmpty) {
      return Center(child: Text('Bekleyen istek yok', style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w300)));
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: fp.pendingRequests.length,
      itemBuilder: (context, index) {
        final r = fp.pendingRequests[index];
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey[800]!))),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFF333333),
                child: Text(r.sender?.username[0].toUpperCase() ?? '?', style: const TextStyle(color: Color(0xFFC9A96E))),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(r.sender?.username ?? '', style: const TextStyle(fontSize: 14))),
              TextButton(
                onPressed: () => fp.acceptRequest(r.id),
                child: const Text('KABUL', style: TextStyle(fontSize: 11, letterSpacing: 1, color: Color(0xFFC9A96E))),
              ),
              TextButton(
                onPressed: () => fp.rejectRequest(r.id),
                child: Text('REDDET', style: TextStyle(fontSize: 11, letterSpacing: 1, color: Colors.grey[600])),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSearchTab(FriendProvider fp) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w300),
            decoration: InputDecoration(
              hintText: 'Kullanıcı adı ara...',
              hintStyle: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w300),
              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey[700]!)),
              focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFC9A96E))),
              suffixIcon: IconButton(
                icon: const Icon(Icons.search, size: 20),
                onPressed: () => fp.searchUsers(_searchController.text.trim()),
              ),
            ),
            onSubmitted: (v) => fp.searchUsers(v.trim()),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: fp.searchResults.length,
              itemBuilder: (context, index) {
                final user = fp.searchResults[index];
                return Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey[800]!))),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: const Color(0xFF333333),
                        child: Text(user.username[0].toUpperCase(), style: const TextStyle(fontSize: 12, color: Color(0xFFC9A96E))),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Text(user.username, style: const TextStyle(fontSize: 14))),
                      OutlinedButton(
                        onPressed: () async {
                          final ok = await fp.sendRequest(user.username);
                          if (ok && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('İstek gönderildi', style: TextStyle(color: Colors.white)), backgroundColor: Color(0xFF242424), behavior: SnackBarBehavior.floating),
                            );
                          }
                        },
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.grey[700]!),
                          shape: const RoundedRectangleBorder(),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        ),
                        child: const Text('EKLE', style: TextStyle(fontSize: 10, letterSpacing: 1, color: Color(0xFFC9A96E))),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
