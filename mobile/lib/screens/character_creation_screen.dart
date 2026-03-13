import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../models/character.dart';

class CharacterCreationScreen extends StatefulWidget {
  final int storyId;
  final Character? existingCharacter;
  const CharacterCreationScreen({super.key, required this.storyId, this.existingCharacter});

  @override
  State<CharacterCreationScreen> createState() => _CharacterCreationScreenState();
}

class _CharacterCreationScreenState extends State<CharacterCreationScreen> {
  final _nameController = TextEditingController();
  final _roleController = TextEditingController();
  final _traitController = TextEditingController();
  final _backstoryController = TextEditingController();
  final _traits = <String>[];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.existingCharacter != null) {
      final c = widget.existingCharacter!;
      _nameController.text = c.name;
      _roleController.text = c.role ?? '';
      _backstoryController.text = c.backstory ?? '';
      _traits.addAll(c.traits);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _roleController.dispose();
    _traitController.dispose();
    _backstoryController.dispose();
    super.dispose();
  }

  void _addTrait() {
    final t = _traitController.text.trim();
    if (t.isEmpty || _traits.length >= 10) return;
    setState(() => _traits.add(t));
    _traitController.clear();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    setState(() => _saving = true);
    try {
      final api = context.read<ApiService>();
      final data = {
        'name': name,
        'role': _roleController.text.trim().isEmpty ? null : _roleController.text.trim(),
        'traits': _traits,
        'backstory': _backstoryController.text.trim().isEmpty ? null : _backstoryController.text.trim(),
      };

      if (widget.existingCharacter != null) {
        await api.put('/stories/${widget.storyId}/characters/${widget.existingCharacter!.id}', data: data);
      } else {
        await api.post('/stories/${widget.storyId}/characters', data: data);
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e', style: const TextStyle(color: Colors.white)), backgroundColor: Colors.red[900], behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingCharacter != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'KARAKTERİ DÜZENLE' : 'KARAKTER OLUŞTUR', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, letterSpacing: 2)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label('İSİM'),
            const SizedBox(height: 8),
            _field(_nameController, 'Karakter adı'),
            const SizedBox(height: 24),
            _label('ROL'),
            const SizedBox(height: 8),
            _field(_roleController, 'Kahraman, düşman, mentor...'),
            const SizedBox(height: 24),
            _label('ÖZELLİKLER'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _field(_traitController, 'Cesur, zeki, gizemli...')),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _addTrait,
                  icon: const Icon(Icons.add, size: 20, color: Color(0xFFC9A96E)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _traits.asMap().entries.map((e) => Chip(
                label: Text(e.value, style: const TextStyle(fontSize: 11)),
                deleteIcon: const Icon(Icons.close, size: 14),
                onDeleted: () => setState(() => _traits.removeAt(e.key)),
                backgroundColor: const Color(0xFF2A2A2A),
                side: BorderSide(color: Colors.grey[700]!),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
              )).toList(),
            ),
            const SizedBox(height: 24),
            _label('GEÇMİŞ HİKAYESİ'),
            const SizedBox(height: 8),
            TextField(
              controller: _backstoryController,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w300),
              maxLines: 5,
              maxLength: 500,
              decoration: InputDecoration(
                hintText: 'Karakterin arka planı...',
                hintStyle: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w300),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey[700]!), borderRadius: BorderRadius.circular(2)),
                focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: Color(0xFFC9A96E)), borderRadius: BorderRadius.circular(2)),
                counterStyle: TextStyle(color: Colors.grey[600], fontSize: 10),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFC9A96E),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: _saving
                    ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.black))
                    : Text(isEditing ? 'GÜNCELLE' : 'OLUŞTUR', style: const TextStyle(fontSize: 12, letterSpacing: 2, fontWeight: FontWeight.w500)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Text(text, style: TextStyle(fontSize: 10, letterSpacing: 2, color: Colors.grey[500], fontWeight: FontWeight.w500));

  Widget _field(TextEditingController c, String hint) => TextField(
    controller: c,
    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w300),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w300),
      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey[700]!)),
      focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFC9A96E))),
    ),
  );
}
