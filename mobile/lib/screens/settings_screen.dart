import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/theme_provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../l10n/app_localizations.dart';
import 'login_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _language = 'tr';
  bool _saving = false;
  String? _avatarUrl;
  bool _uploadingAvatar = false;

  @override
  void initState() {
    super.initState();
    _language = context.read<ThemeProvider>().languageCode;
    _loadAvatar();
  }

  Future<void> _loadAvatar() async {
    try {
      final api = context.read<ApiService>();
      final res = await api.get('/user/profile');
      final img = res.data['user']?['profileImage'];
      if (img != null && mounted) setState(() => _avatarUrl = img);
    } catch (_) {}
  }

  Future<void> _changeAvatar() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 512, imageQuality: 85);
    if (picked == null || !mounted) return;
    setState(() => _uploadingAvatar = true);
    try {
      final api = context.read<ApiService>();
      final url = await api.uploadFile('/upload/avatar', picked.path, 'avatar');
      if (mounted) setState(() { _avatarUrl = url; _uploadingAvatar = false; });
    } catch (_) {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  Future<void> _saveSettings() async {
    setState(() => _saving = true);
    try {
      final tp = context.read<ThemeProvider>();
      final api = context.read<ApiService>();
      // Apply locale change immediately
      await tp.setLocale(_language);
      await api.put('/user/settings', data: {
        'language': _language,
        'theme': tp.isDark ? 'dark' : 'light',
        'fontSize': tp.fontSize,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.settingsSaved, style: const TextStyle(color: Colors.white)), backgroundColor: const Color(0xFF242424), behavior: SnackBarBehavior.floating),
        );
      }
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
    final tp = context.watch<ThemeProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.settings.toUpperCase(), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, letterSpacing: 3)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // Avatar section
          Center(
            child: GestureDetector(
              onTap: _uploadingAvatar ? null : _changeAvatar,
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: const Color(0xFF333333),
                    backgroundImage: _avatarUrl != null
                        ? NetworkImage(context.read<ApiService>().getFullUrl(_avatarUrl!))
                        : null,
                    child: _avatarUrl == null ? Icon(Icons.person, size: 36, color: Colors.grey[600]) : null,
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFC9A96E),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF1A1A1A), width: 2),
                      ),
                      child: _uploadingAvatar
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.black))
                          : const Icon(Icons.camera_alt, size: 14, color: Colors.black),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),
          _sectionTitle(AppLocalizations.of(context)!.theme.toUpperCase()),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _OptionCard(
                  label: AppLocalizations.of(context)!.dark.toUpperCase(),
                  icon: Icons.dark_mode_outlined,
                  selected: tp.isDark,
                  onTap: () => tp.setThemeMode(ThemeMode.dark),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _OptionCard(
                  label: AppLocalizations.of(context)!.light.toUpperCase(),
                  icon: Icons.light_mode_outlined,
                  selected: !tp.isDark,
                  onTap: () => tp.setThemeMode(ThemeMode.light),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          _sectionTitle(AppLocalizations.of(context)!.fontSize.toUpperCase()),
          const SizedBox(height: 12),
          Row(
            children: [
              Text('A', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              Expanded(
                child: Slider(
                  value: tp.fontSize,
                  min: 12,
                  max: 24,
                  divisions: 6,
                  activeColor: const Color(0xFFC9A96E),
                  inactiveColor: Colors.grey[800],
                  onChanged: (v) => tp.setFontSize(v),
                ),
              ),
              Text('A', style: TextStyle(fontSize: 20, color: Colors.grey[500])),
            ],
          ),
          Center(child: Text('${tp.fontSize.toInt()} px', style: TextStyle(fontSize: 12, color: Colors.grey[600]))),
          const SizedBox(height: 28),
          _sectionTitle(AppLocalizations.of(context)!.language.toUpperCase()),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _OptionCard(
                  label: 'TÜRKÇE',
                  icon: Icons.translate,
                  selected: _language == 'tr',
                  onTap: () => setState(() => _language = 'tr'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _OptionCard(
                  label: 'ENGLISH',
                  icon: Icons.translate,
                  selected: _language == 'en',
                  onTap: () => setState(() => _language = 'en'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 36),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _saveSettings,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC9A96E),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _saving
                  ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.black))
                  : Text(AppLocalizations.of(context)!.save.toUpperCase(), style: const TextStyle(fontSize: 12, letterSpacing: 2, fontWeight: FontWeight.w500)),
            ),
          ),
          const SizedBox(height: 40),
          Center(
            child: TextButton(
              onPressed: () {
                context.read<AuthProvider>().logout();
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const _LogoutRedirect()),
                  (route) => false,
                );
              },
              child: Text(AppLocalizations.of(context)!.logout.toUpperCase(), style: TextStyle(fontSize: 11, letterSpacing: 2, color: Colors.grey[600])),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) => Text(text, style: TextStyle(fontSize: 10, letterSpacing: 2, color: Colors.grey[500], fontWeight: FontWeight.w500));
}

class _OptionCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _OptionCard({required this.label, required this.icon, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          border: Border.all(color: selected ? const Color(0xFFC9A96E) : Colors.grey[800]!),
          borderRadius: BorderRadius.circular(2),
          color: selected ? const Color(0xFFC9A96E).withAlpha(15) : null,
        ),
        child: Column(
          children: [
            Icon(icon, size: 22, color: selected ? const Color(0xFFC9A96E) : Colors.grey[600]),
            const SizedBox(height: 6),
            Text(label, style: TextStyle(fontSize: 10, letterSpacing: 1.5, color: selected ? const Color(0xFFC9A96E) : Colors.grey[600], fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

class _LogoutRedirect extends StatelessWidget {
  const _LogoutRedirect();

  @override
  Widget build(BuildContext context) {
    return const LoginScreen();
  }
}
