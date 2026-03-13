import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/coop_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../services/socket_service.dart' hide ConnectionState;
import '../services/export_service.dart';
import '../services/api_service.dart';
import '../services/pdf_downloader_stub.dart'
    if (dart.library.io) '../services/pdf_downloader_native.dart'
    if (dart.library.js_interop) '../services/pdf_downloader_web.dart';

class CoopStoryScreen extends StatefulWidget {
  final int sessionId;
  const CoopStoryScreen({super.key, required this.sessionId});

  @override
  State<CoopStoryScreen> createState() => _CoopStoryScreenState();
}

class _CoopStoryScreenState extends State<CoopStoryScreen> {
  late final SocketService _socketService;
  late final void Function(Map<String, dynamic>) _onNewChapter;
  late final void Function(Map<String, dynamic>) _onStatusChange;
  bool _actionLoading = false;

  @override
  void initState() {
    super.initState();
    _socketService = context.read<SocketService>();
    _onNewChapter = (data) {
      if (data['sessionId'] == widget.sessionId && mounted) {
        context.read<CoopProvider>().loadSession(widget.sessionId);
      }
    };
    _onStatusChange = (data) {
      if (data['sessionId'] == widget.sessionId && mounted) {
        context.read<CoopProvider>().loadSession(widget.sessionId);
      }
    };
    Future.microtask(() {
      if (!mounted) return;
      final cp = context.read<CoopProvider>();
      cp.loadSession(widget.sessionId);
      cp.loadCharacters(widget.sessionId);
      _socketService.joinCoopRoom(widget.sessionId);
      _socketService.onCoopNewChapter(_onNewChapter);
      _socketService.onCoopStatusChange(_onStatusChange);
    });
  }

  @override
  void dispose() {
    _socketService.leaveCoopRoom(widget.sessionId);
    _socketService.removeCoopNewChapter(_onNewChapter);
    _socketService.removeCoopStatusChange(_onStatusChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cp = context.watch<CoopProvider>();
    final session = cp.currentSession;
    final myId = context.read<AuthProvider>().user?.id;
    final userFontSize = context.watch<ThemeProvider>().fontSize;

    if (cp.loading || session == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: CircularProgressIndicator(color: Colors.grey[600], strokeWidth: 1.5)),
      );
    }

    final isMyTurn = session.isMyTurn(myId ?? 0);
    final isCompleted = session.status == 'COMPLETED';
    final story = session.story;
    final chapters = story?.chapters ?? [];

    return Scaffold(
      appBar: AppBar(
        title: Text('CO-OP HİKAYE', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, letterSpacing: 3)),
        actions: [
          if (!isCompleted)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    border: Border.all(color: isMyTurn ? const Color(0xFFC9A96E) : Colors.grey[700]!),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: Text(
                    isMyTurn ? 'SENİN SIRAN' : 'BEKLENİYOR',
                    style: TextStyle(fontSize: 9, letterSpacing: 1, color: isMyTurn ? const Color(0xFFC9A96E) : Colors.grey[600]),
                  ),
                ),
              ),
            ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: Colors.grey[400], size: 20),
            onSelected: (v) => _handleAction(v, cp),
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'pdf', child: Text('PDF İndir')),
              const PopupMenuItem(value: 'share', child: Text('Paylaş')),
              const PopupMenuItem(value: 'recap', child: Text('Özet')),
              const PopupMenuItem(value: 'tree', child: Text('Hikaye Ağacı')),
              const PopupMenuItem(value: 'characters', child: Text('Karakterler')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey[800]!))),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _PlayerChip(name: session.host?.username ?? '?', isActive: session.currentTurn == 1),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text('vs', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                ),
                _PlayerChip(name: session.guest?.username ?? '?', isActive: session.currentTurn == 2),
              ],
            ),
          ),
          if (isCompleted)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              color: const Color(0xFFC9A96E).withAlpha(30),
              child: const Text('HİKAYE TAMAMLANDI', textAlign: TextAlign.center, style: TextStyle(fontSize: 10, letterSpacing: 2, color: Color(0xFFC9A96E))),
            ),
          Expanded(
            child: chapters.isEmpty
                ? Center(child: Text('Hikaye henüz başlamadı', style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w300)))
                : ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: chapters.length,
                    itemBuilder: (context, index) {
                      final ch = chapters[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('BÖLÜM ${ch['chapterNumber'] ?? index + 1}', style: TextStyle(fontSize: 10, letterSpacing: 2, color: Colors.grey[500])),
                            const SizedBox(height: 8),
                            Text(ch['content'] ?? '', style: TextStyle(fontSize: userFontSize, fontWeight: FontWeight.w300, height: 1.7, color: Colors.grey[300])),
                            if (ch['selectedChoice'] != null) ...[
                              const SizedBox(height: 12),
                              _buildSelectedChoice(ch),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
          ),
          if (!isCompleted && session.status == 'ACTIVE' && chapters.isNotEmpty)
            cp.choosing
                ? Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.grey[800]!))),
                    child: Column(
                      children: [
                        CircularProgressIndicator(color: const Color(0xFFC9A96E), strokeWidth: 1.5),
                        const SizedBox(height: 12),
                        Text('Hikaye devam ediyor...', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                      ],
                    ),
                  )
                : isMyTurn
                    ? _buildChoices(cp, chapters.last)
                    : Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.grey[800]!))),
                    child: Text('Diğer oyuncunun seçim yapması bekleniyor...', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  ),
        ],
      ),
    );
  }

  Widget _buildSelectedChoice(Map<String, dynamic> ch) {
    final selectedId = ch['selectedChoice'];
    final choices = ch['choices'] as List<dynamic>? ?? [];
    String label = selectedId.toString();
    for (final c in choices) {
      if (c is Map && c['id'].toString() == selectedId.toString()) {
        label = c['text']?.toString() ?? label;
        break;
      }
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(border: Border.all(color: const Color(0xFFC9A96E).withAlpha(80)), borderRadius: BorderRadius.circular(2)),
      child: Text('→ $label', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w300, color: Color(0xFFC9A96E))),
    );
  }

  Widget _buildChoices(CoopProvider cp, Map<String, dynamic> lastChapter) {
    final choices = lastChapter['choices'] as List<dynamic>? ?? [];
    if (choices.isEmpty || lastChapter['selectedChoice'] != null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.grey[800]!))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: choices.map((c) {
          final choiceId = c is Map ? c['id'] : c;
          final choiceText = c is Map ? (c['text'] ?? c.toString()) : c.toString();
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: OutlinedButton(
              onPressed: cp.loading ? null : () => cp.makeChoice(widget.sessionId, choiceId),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.grey[700]!),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              ),
              child: Text(
                choiceText.toString(),
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w300, color: Colors.grey[300]),
                textAlign: TextAlign.left,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Future<void> _handleAction(String action, CoopProvider cp) async {
    if (_actionLoading) return;
    setState(() => _actionLoading = true);
    try {
      switch (action) {
        case 'pdf':
          final api = context.read<ApiService>();
          final exportService = ExportService(api);
          final bytes = await exportService.exportCoopPdf(widget.sessionId);
          if (mounted) {
            await savePdf(bytes, 'coop_story_${widget.sessionId}.pdf');
          }
          break;
        case 'share':
          final alreadyShared = await cp.shareStory(widget.sessionId);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(alreadyShared ? 'Bu hikaye zaten paylaşılmış.' : 'Hikaye paylaşıldı!')),
            );
          }
          break;
        case 'recap':
          if (mounted) _showRecapDialog(cp);
          break;
        case 'tree':
          if (mounted) _showTreeDialog(cp);
          break;
        case 'characters':
          if (mounted) _showCharactersSheet(cp);
          break;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
      }
    }
    if (mounted) setState(() => _actionLoading = false);
  }

  void _showRecapDialog(CoopProvider cp) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: const Color(0xFFC9A96E), strokeWidth: 1.5),
                const SizedBox(height: 16),
                const Text('Özet oluşturuluyor...'),
              ],
            ),
          ),
        ),
      ),
    );
    final recap = await cp.getRecap(widget.sessionId);
    if (!mounted) return;
    Navigator.pop(context);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Hikaye Özeti'),
        content: SingleChildScrollView(child: Text(recap ?? 'Özet oluşturulamadı.', style: const TextStyle(height: 1.6))),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Kapat'))],
      ),
    );
  }

  void _showTreeDialog(CoopProvider cp) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Hikaye Ağacı'),
        content: FutureBuilder<Map<String, dynamic>?>(
          future: cp.getStoryTree(widget.sessionId),
          builder: (ctx, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const SizedBox(height: 80, child: Center(child: CircularProgressIndicator(strokeWidth: 1.5)));
            }
            final tree = snap.data;
            if (tree == null) return const Text('Ağaç oluşturulamadı.');
            final nodes = tree['nodes'] as List<dynamic>? ?? [];
            return SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: nodes.length,
                itemBuilder: (_, i) {
                  final n = nodes[i];
                  return ListTile(
                    dense: true,
                    leading: CircleAvatar(radius: 12, child: Text('${n['chapterNumber'] ?? i + 1}', style: const TextStyle(fontSize: 11))),
                    title: Text(n['summary']?.toString() ?? '', style: const TextStyle(fontSize: 13)),
                    subtitle: n['choice'] != null ? Text('→ ${n['choice']}', style: const TextStyle(fontSize: 11, color: Color(0xFFC9A96E))) : null,
                  );
                },
              ),
            );
          },
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Kapat'))],
      ),
    );
  }

  void _showCharactersSheet(CoopProvider cp) {
    final myId = context.read<AuthProvider>().user?.id;
    final nameCtrl = TextEditingController();
    final personalityCtrl = TextEditingController();
    final appearanceCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final chars = cp.characters;
          return Padding(
            padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Karakterler', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                ...chars.map((c) {
                  final isOwn = c['userId'] == myId;
                  return ListTile(
                    dense: true,
                    title: Text(c['name'] ?? '', style: const TextStyle(fontSize: 14)),
                    subtitle: Text(c['personality'] ?? '', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                    trailing: isOwn
                        ? IconButton(icon: const Icon(Icons.delete_outline, size: 18), onPressed: () async {
                            await cp.deleteCharacter(widget.sessionId, c['id']);
                            setSheetState(() {});
                          })
                        : null,
                  );
                }),
                const Divider(),
                const Text('Yeni Karakter', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                TextField(controller: nameCtrl, decoration: _inputDecor('Ad')),
                const SizedBox(height: 8),
                TextField(controller: personalityCtrl, decoration: _inputDecor('Kişilik')),
                const SizedBox(height: 8),
                TextField(controller: appearanceCtrl, decoration: _inputDecor('Görünüm')),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () async {
                      if (nameCtrl.text.trim().isEmpty) return;
                      final ok = await cp.addCharacter(widget.sessionId, name: nameCtrl.text.trim(), personality: personalityCtrl.text.trim(), appearance: appearanceCtrl.text.trim());
                      if (ok) {
                        nameCtrl.clear();
                        personalityCtrl.clear();
                        appearanceCtrl.clear();
                        setSheetState(() {});
                      } else if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Her kullanıcı en fazla 5 karakter ekleyebilir.')));
                      }
                    },
                    child: const Text('Ekle'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  InputDecoration _inputDecor(String label) => InputDecoration(
        labelText: label,
        isDense: true,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      );
}

class _PlayerChip extends StatelessWidget {
  final String name;
  final bool isActive;
  const _PlayerChip({required this.name, required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFFC9A96E).withAlpha(25) : Colors.transparent,
        border: Border.all(color: isActive ? const Color(0xFFC9A96E) : Colors.grey[700]!),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Text(name, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: isActive ? const Color(0xFFC9A96E) : Colors.grey[500])),
    );
  }
}
