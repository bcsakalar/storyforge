import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/message_provider.dart';
import '../models/message.dart';
import '../services/socket_service.dart';
import 'chat_screen.dart';

class ConversationsScreen extends StatefulWidget {
  const ConversationsScreen({super.key});

  @override
  State<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends State<ConversationsScreen> {
  late final SocketService _socketService;
  late final void Function(Map<String, dynamic>) _onMessageNotif;

  @override
  void initState() {
    super.initState();
    _socketService = context.read<SocketService>();
    _onMessageNotif = (data) {
      if (!mounted) return;
      // Reload conversations to show new message
      context.read<MessageProvider>().loadConversations();
    };
    _socketService.onMessageNotification(_onMessageNotif);
    Future.microtask(() {
      if (!mounted) return;
      context.read<MessageProvider>().loadConversations();
    });
  }

  @override
  void dispose() {
    _socketService.removeMessageNotification(_onMessageNotif);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mp = context.watch<MessageProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('MESAJLAR', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, letterSpacing: 3)),
      ),
      body: mp.loading
          ? Center(child: CircularProgressIndicator(color: Colors.grey[600], strokeWidth: 1.5))
          : mp.conversations.isEmpty
              ? RefreshIndicator(
                  color: const Color(0xFFC9A96E),
                  onRefresh: () => context.read<MessageProvider>().loadConversations(),
                  child: ListView(
                    children: [
                      SizedBox(height: MediaQuery.of(context).size.height * 0.35),
                      Center(child: Text('Henüz mesajınız yok', style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w300))),
                    ],
                  ),
                )
              : RefreshIndicator(
                  color: const Color(0xFFC9A96E),
                  onRefresh: () => context.read<MessageProvider>().loadConversations(),
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: mp.conversations.length,
                    itemBuilder: (context, index) {
                      final c = mp.conversations[index];
                      return _ConversationTile(conversation: c);
                    },
                  ),
                ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  final Conversation conversation;
  const _ConversationTile({required this.conversation});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatScreen(userId: conversation.userId, username: conversation.username),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey[800]!))),
        child: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: const Color(0xFF333333),
                  child: Text(conversation.username[0].toUpperCase(), style: const TextStyle(color: Color(0xFFC9A96E), fontWeight: FontWeight.w500)),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 11,
                    height: 11,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: context.watch<SocketService>().isUserOnline(conversation.userId)
                          ? const Color(0xFF4CAF50)
                          : Colors.grey[700],
                      border: Border.all(color: const Color(0xFF1A1A1A), width: 1.5),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(conversation.username, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  Text(
                    conversation.lastMessage,
                    style: TextStyle(fontSize: 12, color: Colors.grey[500], fontWeight: FontWeight.w300),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (conversation.unreadCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFC9A96E),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('${conversation.unreadCount}', style: const TextStyle(fontSize: 10, color: Colors.black, fontWeight: FontWeight.w600)),
              ),
          ],
        ),
      ),
    );
  }
}
