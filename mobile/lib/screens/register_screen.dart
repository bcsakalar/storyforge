import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'dashboard_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();
    final success = await auth.register(
      _emailController.text.trim(),
      _usernameController.text.trim(),
      _passwordController.text,
    );

    if (success && mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const DashboardScreen()),
        (route) => false,
      );
    }
  }

  Widget _buildInput(TextEditingController controller, String label, {
    bool obscure = false,
    TextInputType inputType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: inputType,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w300),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey[600], fontSize: 13, fontWeight: FontWeight.w300, letterSpacing: 0.5),
        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey[700]!)),
        focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFC9A96E))),
        errorBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFAA4444))),
        focusedErrorBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFAA4444))),
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
      ),
      validator: validator,
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text(''),
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Color(0xFF888888)), onPressed: () => Navigator.pop(context)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                const Text('BAŞLA', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, letterSpacing: 3, color: Color(0xFFC9A96E))),
                const SizedBox(height: 8),
                const Text('Kayıt Ol', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w300)),
                const SizedBox(height: 8),
                Text('Yeni hesap oluştur', style: TextStyle(color: Colors.grey[600], fontSize: 14, fontWeight: FontWeight.w300)),
                const SizedBox(height: 40),

                if (auth.error != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 24),
                    decoration: BoxDecoration(border: Border.all(color: const Color(0xFFAA4444))),
                    child: Text(auth.error!, style: const TextStyle(color: Color(0xFFAA4444), fontSize: 13)),
                  ),

                _buildInput(_usernameController, 'Kullanıcı Adı', validator: (v) {
                  if (v == null || v.isEmpty) return 'Kullanıcı adı gerekli';
                  if (v.length < 3) return 'En az 3 karakter';
                  return null;
                }),
                const SizedBox(height: 24),
                _buildInput(_emailController, 'E-posta', inputType: TextInputType.emailAddress, validator: (v) => v == null || v.isEmpty ? 'E-posta gerekli' : null),
                const SizedBox(height: 24),
                _buildInput(_passwordController, 'Şifre (en az 6 karakter)', obscure: true, validator: (v) {
                  if (v == null || v.isEmpty) return 'Şifre gerekli';
                  if (v.length < 6) return 'En az 6 karakter';
                  return null;
                }),
                const SizedBox(height: 24),
                _buildInput(_confirmController, 'Şifre Tekrar', obscure: true, validator: (v) {
                  if (v != _passwordController.text) return 'Şifreler eşleşmiyor';
                  return null;
                }),
                const SizedBox(height: 40),

                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton(
                    onPressed: auth.loading ? null : _register,
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.grey[400]!),
                      shape: const RoundedRectangleBorder(),
                      foregroundColor: Colors.grey[300],
                    ),
                    child: auth.loading
                        ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.grey[400]))
                        : Text('KAYIT OL', style: TextStyle(fontSize: 12, letterSpacing: 2, fontWeight: FontWeight.w400, color: Colors.grey[300])),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
