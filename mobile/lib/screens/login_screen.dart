import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import 'register_screen.dart';
import 'dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  void _showServerSettings() {
    final api = context.read<ApiService>();
    final urlController = TextEditingController(text: api.baseUrl);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF242424),
        shape: const RoundedRectangleBorder(),
        title: Text('SUNUCU', style: TextStyle(fontSize: 12, letterSpacing: 2, fontWeight: FontWeight.w500, color: Colors.grey[400])),
        content: TextField(
          controller: urlController,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w300),
          decoration: const InputDecoration(
            hintText: 'https://domain.com/api',
            hintStyle: TextStyle(color: Color(0xFF666666), fontWeight: FontWeight.w300),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF333333))),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFC9A96E))),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('İPTAL', style: TextStyle(fontSize: 11, letterSpacing: 1, color: Colors.grey[600])),
          ),
          TextButton(
            onPressed: () {
              final url = urlController.text.trim();
              if (url.isNotEmpty) {
                api.setBaseUrl(url);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Sunucu: $url', style: const TextStyle(fontSize: 12)),
                    backgroundColor: const Color(0xFF242424),
                    behavior: SnackBarBehavior.floating,
                    shape: const RoundedRectangleBorder(),
                  ),
                );
              }
            },
            child: const Text('KAYDET', style: TextStyle(fontSize: 11, letterSpacing: 1, color: Color(0xFFC9A96E))),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();
    final success = await auth.login(
      _emailController.text.trim(),
      _passwordController.text,
    );

    if (success && mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const DashboardScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: Icon(Icons.settings_outlined, size: 18, color: Colors.grey[700]),
                onPressed: _showServerSettings,
              ),
            ),
            Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'STORYFORGE',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: 3, color: Colors.grey[300]),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'INTERACTIVE STORIES',
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.w300, letterSpacing: 4, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 48),
                  const Text('Giriş Yap', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w300)),
                  const SizedBox(height: 8),
                  Text('Hikayelerine devam et', style: TextStyle(color: Colors.grey[600], fontSize: 14, fontWeight: FontWeight.w300)),
                  const SizedBox(height: 40),

                  if (auth.error != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 24),
                      decoration: BoxDecoration(border: Border.all(color: const Color(0xFFAA4444))),
                      child: Text(auth.error!, style: const TextStyle(color: Color(0xFFAA4444), fontSize: 13)),
                    ),

                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(fontWeight: FontWeight.w300),
                    decoration: const InputDecoration(
                      hintText: 'E-posta',
                      hintStyle: TextStyle(color: Color(0xFF888888), fontWeight: FontWeight.w300),
                      border: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF333333))),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF333333))),
                      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFC9A96E))),
                      contentPadding: EdgeInsets.symmetric(vertical: 12),
                    ),
                    validator: (v) => v == null || v.isEmpty ? 'E-posta gerekli' : null,
                  ),
                  const SizedBox(height: 24),

                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    style: const TextStyle(fontWeight: FontWeight.w300),
                    decoration: const InputDecoration(
                      hintText: 'Şifre',
                      hintStyle: TextStyle(color: Color(0xFF888888), fontWeight: FontWeight.w300),
                      border: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF333333))),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF333333))),
                      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFC9A96E))),
                      contentPadding: EdgeInsets.symmetric(vertical: 12),
                    ),
                    validator: (v) => v == null || v.isEmpty ? 'Şifre gerekli' : null,
                    onFieldSubmitted: (_) => _login(),
                  ),
                  const SizedBox(height: 40),

                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton(
                      onPressed: auth.loading ? null : _login,
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.grey[400]!),
                        shape: const RoundedRectangleBorder(),
                        foregroundColor: Colors.grey[300],
                      ),
                      child: auth.loading
                          ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.grey[400]))
                          : Text('GİRİŞ YAP', style: TextStyle(fontSize: 12, letterSpacing: 2, fontWeight: FontWeight.w400, color: Colors.grey[300])),
                    ),
                  ),
                  const SizedBox(height: 24),

                  Center(
                    child: GestureDetector(
                      onTap: () {
                        auth.clearError();
                        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RegisterScreen()));
                      },
                      child: Text.rich(
                        TextSpan(
                          text: 'Hesabın yok mu? ',
                          style: TextStyle(color: Colors.grey[600], fontSize: 13),
                          children: const [TextSpan(text: 'Kayıt Ol', style: TextStyle(color: Color(0xFFC9A96E)))],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
          ],
        ),
      ),
    );
  }
}
