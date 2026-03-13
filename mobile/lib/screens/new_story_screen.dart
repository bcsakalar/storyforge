import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/story_provider.dart';
import 'story_screen.dart';

class NewStoryScreen extends StatefulWidget {
  const NewStoryScreen({super.key});

  @override
  State<NewStoryScreen> createState() => _NewStoryScreenState();
}

class _NewStoryScreenState extends State<NewStoryScreen> {
  String? _selectedGenre;
  String? _selectedMood;
  String _language = 'tr';
  bool _navigated = false;

  static const _genres = [
    {'value': 'fantastik', 'label': 'Fantastik', 'icon': '🐉', 'desc': 'Büyü, ejderhalar ve destansı maceralar'},
    {'value': 'korku', 'label': 'Korku', 'icon': '👻', 'desc': 'Gerilim, karanlık ve doğaüstü tehditler'},
    {'value': 'bilim_kurgu', 'label': 'Bilim Kurgu', 'icon': '🚀', 'desc': 'Uzay, teknoloji ve gelecek'},
    {'value': 'romantik', 'label': 'Romantik', 'icon': '💕', 'desc': 'Aşk, ilişkiler ve duygusal derinlik'},
    {'value': 'macera', 'label': 'Macera', 'icon': '⚔️', 'desc': 'Aksiyon, keşif ve kahramanlık'},
    {'value': 'gizem', 'label': 'Gizem', 'icon': '🔍', 'desc': 'Sırlar, dedektiflik ve sürprizler'},
  ];

  static const _moods = [
    {'value': 'korku', 'label': 'Karanlık', 'icon': Icons.nights_stay},
    {'value': 'romantik', 'label': 'Romantik', 'icon': Icons.favorite},
    {'value': 'komedi', 'label': 'Komedi', 'icon': Icons.sentiment_very_satisfied},
    {'value': 'gerilim', 'label': 'Gerilimli', 'icon': Icons.bolt},
    {'value': 'epik', 'label': 'Epik', 'icon': Icons.auto_awesome},
    {'value': 'melankolik', 'label': 'Melankolik', 'icon': Icons.water_drop},
  ];

  Future<void> _createStory() async {
    if (_selectedGenre == null) return;

    final provider = context.read<StoryProvider>();
    provider.createStoryStream(_selectedGenre!, mood: _selectedMood, language: _language);
    // Stay on this screen showing streaming content
    // Navigation happens in build() when story completes
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<StoryProvider>();

    // Auto-navigate when streaming story creation completes
    if (!_navigated && !provider.loading && !provider.isStreaming && provider.currentStory != null && _selectedGenre != null) {
      _navigated = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => StoryScreen(storyId: provider.currentStory!.id)),
          );
        }
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(''),
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Color(0xFF888888)), onPressed: () => Navigator.pop(context)),
      ),
      body: provider.loading || provider.isStreaming
          ? Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1, color: const Color(0xFFC9A96E))),
                      const SizedBox(width: 10),
                      Text('Hikaye oluşturuluyor...', style: TextStyle(color: Colors.grey[500], fontSize: 13, fontWeight: FontWeight.w300)),
                    ],
                  ),
                  if (provider.isStreaming && provider.streamingText.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Text(
                          provider.extractStoryText(provider.streamingText),
                          style: const TextStyle(fontSize: 15, height: 1.8, fontWeight: FontWeight.w300),
                        ),
                      ),
                    ),
                  ] else ...[
                    const Spacer(),
                  ],
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  const Text('TÜR SEÇ', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, letterSpacing: 3, color: Color(0xFFC9A96E))),
                  const SizedBox(height: 8),
                  const Text('Yeni Hikaye', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w300)),
                  const SizedBox(height: 8),
                  Text('Gerisini yapay zeka halleder', style: TextStyle(color: Colors.grey[600], fontSize: 14, fontWeight: FontWeight.w300)),
                  const SizedBox(height: 32),

                  ..._genres.map((genre) => _buildGenreRow(genre)),

                  const SizedBox(height: 32),
                  Text('TON / MOOD', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, letterSpacing: 3, color: Colors.grey[500])),
                  const SizedBox(height: 4),
                  Text('Opsiyonel', style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w300)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _moods.map((m) {
                      final selected = _selectedMood == m['value'];
                      return ChoiceChip(
                        avatar: Icon(m['icon'] as IconData, size: 16, color: selected ? Colors.black : Colors.grey[500]),
                        label: Text(m['label'] as String, style: TextStyle(fontSize: 11, color: selected ? Colors.black : Colors.grey[400])),
                        selected: selected,
                        selectedColor: const Color(0xFFC9A96E),
                        backgroundColor: const Color(0xFF1A1A1A),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2), side: BorderSide(color: Colors.grey[700]!)),
                        onSelected: (s) => setState(() => _selectedMood = s ? m['value'] as String : null),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 28),
                  Text('DİL', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, letterSpacing: 3, color: Colors.grey[500])),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildLangChip('Türkçe', 'tr'),
                      const SizedBox(width: 10),
                      _buildLangChip('English', 'en'),
                    ],
                  ),

                  const SizedBox(height: 32),

                  if (provider.error != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(border: Border.all(color: const Color(0xFFAA4444))),
                      child: Text(provider.error!, style: const TextStyle(color: Color(0xFFAA4444), fontSize: 13)),
                    ),

                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton(
                      onPressed: _selectedGenre != null ? _createStory : null,
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: _selectedGenre != null ? Colors.grey[400]! : Colors.grey[800]!),
                        shape: const RoundedRectangleBorder(),
                        foregroundColor: Colors.grey[300],
                        disabledForegroundColor: Colors.grey[700],
                      ),
                      child: const Text('HİKAYEYİ BAŞLAT', style: TextStyle(fontSize: 12, letterSpacing: 2, fontWeight: FontWeight.w400)),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _buildLangChip(String label, String value) {
    final selected = _language == value;
    return GestureDetector(
      onTap: () => setState(() => _language = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: selected ? const Color(0xFFC9A96E) : Colors.grey[700]!),
          borderRadius: BorderRadius.circular(2),
          color: selected ? const Color(0xFFC9A96E).withAlpha(15) : null,
        ),
        child: Text(label, style: TextStyle(fontSize: 12, color: selected ? const Color(0xFFC9A96E) : Colors.grey[500], fontWeight: FontWeight.w400)),
      ),
    );
  }

  Widget _buildGenreRow(Map<String, String> genre) {
    final isSelected = _selectedGenre == genre['value'];
    return InkWell(
      onTap: () => setState(() => _selectedGenre = genre['value'] as String),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey[800]!))),
        child: Row(
          children: [
            Text(genre['icon']!, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(genre['label']!, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: isSelected ? const Color(0xFFC9A96E) : Colors.grey[300])),
                  const SizedBox(height: 2),
                  Text(genre['desc']!, style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w300)),
                ],
              ),
            ),
            if (isSelected)
              Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFFC9A96E), shape: BoxShape.circle)),
          ],
        ),
      ),
    );
  }
}
