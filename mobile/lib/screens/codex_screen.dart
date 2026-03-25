import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';

/// Story Codex (Encyclopedia) — Hikaye ansiklopedisi
/// Karakter, lokasyon, eşya, lore bilgilerini gösterir.
class CodexScreen extends StatefulWidget {
  final int storyId;
  final String storyTitle;

  const CodexScreen({super.key, required this.storyId, required this.storyTitle});

  @override
  State<CodexScreen> createState() => _CodexScreenState();
}

class _CodexScreenState extends State<CodexScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, dynamic>? _codex;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadCodex();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadCodex() async {
    try {
      final api = context.read<ApiService>();
      final res = await api.get('/stories/${widget.storyId}/codex');
      if (mounted) {
        setState(() {
          _codex = res.data['codex'];
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Ansiklopedi yüklenemedi';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'ANSİKLOPEDİ',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, letterSpacing: 3),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF888888)),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFFC9A96E),
          unselectedLabelColor: Colors.grey[600],
          indicatorColor: const Color(0xFFC9A96E),
          indicatorWeight: 1,
          labelStyle: const TextStyle(fontSize: 10, letterSpacing: 1.5, fontWeight: FontWeight.w600),
          unselectedLabelStyle: const TextStyle(fontSize: 10, letterSpacing: 1.5, fontWeight: FontWeight.w400),
          tabs: const [
            Tab(text: 'KARAKTER'),
            Tab(text: 'MEKAN'),
            Tab(text: 'EŞYA'),
            Tab(text: 'BİLGİ'),
          ],
        ),
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: Colors.grey[600], strokeWidth: 1.5))
          : _error != null
              ? Center(child: Text(_error!, style: TextStyle(color: Colors.grey[600], fontSize: 13)))
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildEntityList(_codex?['characters'] ?? []),
                    _buildEntityList(_codex?['locations'] ?? []),
                    _buildEntityList(_codex?['items'] ?? []),
                    _buildLoreList(_codex?['lore'] ?? []),
                  ],
                ),
    );
  }

  Widget _buildEntityList(List<dynamic> entities) {
    if (entities.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_stories_outlined, size: 40, color: Colors.grey[700]),
            const SizedBox(height: 12),
            Text('Henüz veri yok', style: TextStyle(color: Colors.grey[600], fontSize: 13, fontWeight: FontWeight.w300)),
            const SizedBox(height: 4),
            Text('Hikayede ilerledikçe burada görünecek', style: TextStyle(color: Colors.grey[700], fontSize: 11)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: entities.length,
      itemBuilder: (context, index) {
        final entity = entities[index] as Map<String, dynamic>;
        return _EntityCard(entity: entity);
      },
    );
  }

  Widget _buildLoreList(List<dynamic> lore) {
    if (lore.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.menu_book_outlined, size: 40, color: Colors.grey[700]),
            const SizedBox(height: 12),
            Text('Dünya bilgisi henüz yok', style: TextStyle(color: Colors.grey[600], fontSize: 13, fontWeight: FontWeight.w300)),
          ],
        ),
      );
    }

    // Group by category
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final item in lore) {
      final cat = (item as Map<String, dynamic>)['category']?.toString() ?? 'other';
      groups.putIfAbsent(cat, () => []).add(item);
    }

    final categoryLabels = {
      'rule': 'Kurallar',
      'history': 'Tarih',
      'geography': 'Coğrafya',
      'magic_system': 'Büyü Sistemi',
      'culture': 'Kültür',
      'technology': 'Teknoloji',
    };

    return ListView(
      padding: const EdgeInsets.all(16),
      children: groups.entries.map((entry) {
        final label = categoryLabels[entry.key] ?? entry.key.toUpperCase();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 12),
              child: Text(label.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 2, color: Colors.grey[500])),
            ),
            ...entry.value.map((item) => _LoreCard(item: item)),
            const SizedBox(height: 8),
          ],
        );
      }).toList(),
    );
  }
}

class _EntityCard extends StatefulWidget {
  final Map<String, dynamic> entity;
  const _EntityCard({required this.entity});

  @override
  State<_EntityCard> createState() => _EntityCardState();
}

class _EntityCardState extends State<_EntityCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final e = widget.entity;
    final status = e['status'] ?? 'active';
    final relationships = (e['relationships'] as List<dynamic>?) ?? [];
    final statusHistory = (e['statusHistory'] as List<dynamic>?) ?? [];
    final importance = ((e['importance'] as num?)?.toDouble() ?? 0.5);

    // Status color
    Color statusColor;
    String statusLabel;
    switch (status) {
      case 'dead':
        statusColor = const Color(0xFFCC3333);
        statusLabel = 'ÖLÜM';
        break;
      case 'missing':
        statusColor = const Color(0xFFCC9933);
        statusLabel = 'KAYIP';
        break;
      case 'transformed':
        statusColor = const Color(0xFF8B6FCF);
        statusLabel = 'DÖNÜŞMÜŞ';
        break;
      case 'inactive':
        statusColor = Colors.grey;
        statusLabel = 'PASİF';
        break;
      default:
        statusColor = const Color(0xFF4CAF50);
        statusLabel = 'AKTİF';
    }

    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          border: Border(
            left: BorderSide(
              color: statusColor.withAlpha(180),
              width: 2,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Expanded(
                  child: Text(
                    e['name'] ?? '',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: status == 'dead' ? Colors.grey[500] : Colors.white,
                      decoration: status == 'dead' ? TextDecoration.lineThrough : null,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor.withAlpha(30),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(fontSize: 8, fontWeight: FontWeight.w600, letterSpacing: 1, color: statusColor),
                  ),
                ),
                const SizedBox(width: 8),
                // Importance indicator
                ...List.generate(
                  (importance * 5).round().clamp(1, 5),
                  (_) => Container(
                    width: 4,
                    height: 4,
                    margin: const EdgeInsets.only(left: 2),
                    decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFC9A96E)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Description
            Text(
              e['description'] ?? '',
              style: TextStyle(fontSize: 12, height: 1.6, fontWeight: FontWeight.w300, color: Colors.grey[400]),
              maxLines: _expanded ? null : 2,
              overflow: _expanded ? null : TextOverflow.ellipsis,
            ),

            if (_expanded && relationships.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text('İLİŞKİLER', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, letterSpacing: 1.5, color: Colors.grey[500])),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: relationships.map<Widget>((rel) {
                  final r = rel as Map<String, dynamic>;
                  final relType = r['type'] ?? '';
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[800]!),
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: Text(
                      '${r['targetName']} — ${_relTypeLabel(relType)}',
                      style: TextStyle(fontSize: 10, color: _relTypeColor(relType), fontWeight: FontWeight.w400),
                    ),
                  );
                }).toList(),
              ),
            ],

            if (_expanded && statusHistory.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text('GEÇMİŞ', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, letterSpacing: 1.5, color: Colors.grey[500])),
              const SizedBox(height: 6),
              ...statusHistory.map<Widget>((sh) {
                final h = sh as Map<String, dynamic>;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    'Bölüm ${h['chapter']}: ${h['from']} → ${h['to']} — ${h['reason']}',
                    style: TextStyle(fontSize: 10, color: Colors.grey[500], fontWeight: FontWeight.w300),
                  ),
                );
              }),
            ],

            // Chapter info
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'İlk: Bölüm ${e['firstSeen'] ?? 1} · Son: Bölüm ${e['lastSeen'] ?? 1}',
                style: TextStyle(fontSize: 9, color: Colors.grey[700]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _relTypeLabel(String type) {
    const labels = {
      'ally': 'Müttefik',
      'enemy': 'Düşman',
      'lover': 'Sevgili',
      'family': 'Aile',
      'mentor': 'Akıl Hocası',
      'rival': 'Rakip',
      'stranger': 'Yabancı',
      'servant': 'Hizmetkar',
      'master': 'Efendi',
    };
    return labels[type] ?? type;
  }

  Color _relTypeColor(String type) {
    const colors = {
      'ally': Color(0xFF4CAF50),
      'enemy': Color(0xFFCC3333),
      'lover': Color(0xFFE8A0BF),
      'family': Color(0xFFC9A96E),
      'mentor': Color(0xFF00D4AA),
      'rival': Color(0xFFE8A020),
    };
    return colors[type] ?? Colors.grey;
  }
}

class _LoreCard extends StatelessWidget {
  final Map<String, dynamic> item;
  const _LoreCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        border: Border(left: BorderSide(color: const Color(0xFF8B6FCF).withAlpha(120), width: 2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item['title'] ?? '',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 6),
          Text(
            item['content'] ?? '',
            style: TextStyle(fontSize: 12, height: 1.6, fontWeight: FontWeight.w300, color: Colors.grey[400]),
          ),
        ],
      ),
    );
  }
}
