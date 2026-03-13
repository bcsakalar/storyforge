import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:async';
import '../providers/message_provider.dart';
import '../providers/auth_provider.dart';
import '../models/message.dart';
import '../services/socket_service.dart';
import '../services/api_service.dart';
import '../services/moderation_service.dart';
import '../widgets/typing_indicator.dart';

class ChatScreen extends StatefulWidget {
  final int userId;
  final String username;
  const ChatScreen({super.key, required this.userId, required this.username});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  bool _loadingMore = false;
  bool _partnerTyping = false;
  Timer? _typingTimer;
  bool _iAmTyping = false;
  late final SocketService _socketService;
  late final void Function(Map<String, dynamic>) _onMessageNew;
  late final void Function(Map<String, dynamic>) _onTypingStart;
  late final void Function(Map<String, dynamic>) _onTypingStop;

  @override
  void initState() {
    super.initState();
    _socketService = context.read<SocketService>();
    _onMessageNew = (data) {
      if (!mounted) return;
      final msg = Message.fromJson(data);
      final myId = context.read<AuthProvider>().user?.id;
      // Only add if it's from our chat partner and addressed to us
      if (msg.senderId == widget.userId && msg.receiverId == myId) {
        final mp = context.read<MessageProvider>();
        if (!mp.getMessagesFor(widget.userId).any((m) => m.id == msg.id)) {
          mp.addIncomingMessage(msg);
        }
      }
    };
    _onTypingStart = (data) {
      if (!mounted) return;
      final uid = data['userId'] as int?;
      if (uid == widget.userId) {
        setState(() => _partnerTyping = true);
      }
    };
    _onTypingStop = (data) {
      if (!mounted) return;
      final uid = data['userId'] as int?;
      if (uid == widget.userId) {
        setState(() => _partnerTyping = false);
      }
    };
    Future.microtask(() {
      if (!mounted) return;
      context.read<MessageProvider>().loadMessages(widget.userId);
      context.read<MessageProvider>().markAsRead(widget.userId);
      _socketService.joinChatRoom(widget.userId);
      _socketService.onMessageNew(_onMessageNew);
      _socketService.onTypingStart(_onTypingStart);
      _socketService.onTypingStop(_onTypingStop);
    });
    _scrollController.addListener(_onScroll);
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _stopTyping();
    _socketService.leaveChatRoom(widget.userId);
    _socketService.removeMessageNew(_onMessageNew);
    _socketService.removeTypingStart(_onTypingStart);
    _socketService.removeTypingStop(_onTypingStop);
    _typingTimer?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onChatMenuAction(String action) async {
    final mod = ModerationService(context.read<ApiService>());
    if (action == 'block') {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: const Color(0xFF242424),
          title: const Text('Engelle', style: TextStyle(fontSize: 16)),
          content: Text('${widget.username} engellensin mi? Arkadaşlık da kaldırılacaktır.', style: TextStyle(fontSize: 14, color: Colors.grey[400])),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text('İptal', style: TextStyle(color: Colors.grey[500]))),
            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Engelle', style: TextStyle(color: Color(0xFFAA4444)))),
          ],
        ),
      );
      if (confirm == true && mounted) {
        try {
          await mod.blockUser(widget.userId);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kullanıcı engellendi'), backgroundColor: Color(0xFF242424), behavior: SnackBarBehavior.floating));
            Navigator.pop(context);
          }
        } catch (_) {}
      }
    } else if (action == 'report') {
      final reason = await _showReportDialog();
      if (reason != null && mounted) {
        try {
          await mod.reportContent(targetType: 'user', targetId: widget.userId, reason: reason);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bildirim gönderildi'), backgroundColor: Color(0xFF242424), behavior: SnackBarBehavior.floating));
          }
        } catch (_) {}
      }
    }
  }

  Future<String?> _showReportDialog() {
    String? selectedReason;
    final reasons = ['Uygunsuz içerik', 'Spam', 'Taciz', 'Nefret söylemi', 'Diğer'];
    return showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF242424),
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

  void _onTextChanged() {
    if (_controller.text.trim().isNotEmpty && !_iAmTyping) {
      _iAmTyping = true;
      _socketService.emitTypingStart(widget.userId);
    }
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 3), _stopTyping);
  }

  void _stopTyping() {
    if (_iAmTyping) {
      _iAmTyping = false;
      _socketService.emitTypingStop(widget.userId);
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 100 &&
        !_loadingMore &&
        context.read<MessageProvider>().hasMoreMessages(widget.userId)) {
      setState(() => _loadingMore = true);
      context.read<MessageProvider>().loadMessages(widget.userId, loadMore: true).then((_) {
        if (mounted) setState(() => _loadingMore = false);
      });
    }
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _stopTyping();
    _typingTimer?.cancel();
    _controller.clear();
    context.read<MessageProvider>().sendMessage(widget.userId, text);
    if (_scrollController.hasClients) {
      _scrollController.animateTo(0, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
    }
  }

  Future<void> _sendImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1200, imageQuality: 80);
    if (picked == null || !mounted) return;
    try {
      final api = context.read<ApiService>();
      final imageUrl = await api.uploadFile('/upload/message-image', picked.path, 'image');
      if (mounted) {
        context.read<MessageProvider>().sendMessage(widget.userId, '📷 Fotoğraf', messageType: 'image', imageUrl: imageUrl);
        if (_scrollController.hasClients) {
          _scrollController.animateTo(0, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fotoğraf gönderilemedi'), backgroundColor: Color(0xFF242424), behavior: SnackBarBehavior.floating));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final mp = context.watch<MessageProvider>();
    final myId = context.read<AuthProvider>().user?.id;
    final chatMessages = mp.getMessagesFor(widget.userId);

    return Scaffold(
      appBar: AppBar(
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, size: 18, color: Colors.grey[600]),
            color: const Color(0xFF242424),
            onSelected: _onChatMenuAction,
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'block', child: Text('Engelle', style: TextStyle(fontSize: 13))),
              const PopupMenuItem(value: 'report', child: Text('Bildir', style: TextStyle(fontSize: 13, color: Color(0xFFAA4444)))),
            ],
          ),
        ],
        title: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: const Color(0xFF333333),
                  child: Text(widget.username[0].toUpperCase(), style: const TextStyle(fontSize: 11, color: Color(0xFFC9A96E))),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: context.watch<SocketService>().isUserOnline(widget.userId)
                          ? const Color(0xFF4CAF50)
                          : Colors.grey[700],
                      border: Border.all(color: const Color(0xFF1A1A1A), width: 1.5),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.username.toUpperCase(), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, letterSpacing: 3)),
                if (_partnerTyping)
                  const Text('yazıyor...', style: TextStyle(fontSize: 10, color: Color(0xFFC9A96E), fontWeight: FontWeight.w300))
                else if (context.watch<SocketService>().isUserOnline(widget.userId))
                  Text('çevrimiçi', style: TextStyle(fontSize: 10, color: Colors.grey[500], fontWeight: FontWeight.w300)),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: mp.loading && chatMessages.isEmpty
                ? Center(child: CircularProgressIndicator(color: Colors.grey[600], strokeWidth: 1.5))
                : ListView.builder(
                    controller: _scrollController,
                    reverse: true,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: chatMessages.length + (_partnerTyping ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (_partnerTyping && index == 0) {
                        return const TypingIndicator();
                      }
                      final msgIndex = _partnerTyping ? index - 1 : index;
                      final msg = chatMessages[msgIndex];
                      final isMe = msg.senderId == myId;
                      return _MessageBubble(message: msg, isMe: isMe);
                    },
                  ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Colors.grey[800]!)),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.image_outlined, size: 20, color: Colors.grey[500]),
                  onPressed: _sendImage,
                ),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w300),
                    maxLength: 2000,
                    maxLines: 3,
                    minLines: 1,
                    decoration: InputDecoration(
                      counterText: '',
                      hintText: 'Mesaj yaz...',
                      hintStyle: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w300),
                      border: InputBorder.none,
                    ),
                    onSubmitted: (_) => _send(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, size: 20, color: Color(0xFFC9A96E)),
                  onPressed: _send,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final Message message;
  final bool isMe;
  const _MessageBubble({required this.message, required this.isMe});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: message.isImage ? const EdgeInsets.all(4) : const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
        decoration: BoxDecoration(
          color: isMe ? const Color(0xFF2A2A2A) : const Color(0xFF1F1F1F),
          border: isMe ? null : Border.all(color: Colors.grey[800]!),
          borderRadius: BorderRadius.circular(2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (message.isImage && message.imageUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: Image.network(
                  context.read<ApiService>().getFullUrl(message.imageUrl!),
                  width: 220,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    width: 220,
                    height: 150,
                    color: Colors.grey[900],
                    child: Icon(Icons.broken_image, color: Colors.grey[700]),
                  ),
                ),
              )
            else
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  message.content,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w300, color: isMe ? Colors.white : Colors.grey[300]),
                ),
              ),
            if (isMe)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Icon(
                  message.isRead ? Icons.done_all : Icons.done,
                  size: 14,
                  color: message.isRead ? const Color(0xFF64B5F6) : Colors.grey[600],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
