import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/api_config.dart';
import '../../core/app_theme.dart';
import '../widgets/glass_container.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with SingleTickerProviderStateMixin {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscureText = true;
  bool _isLoading = false;
  
  // 'login' ou 'admin'
  String _mode = 'login';

  Future<void> _login() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preencha os dados!')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/v1/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': _emailController.text,
          'password': _passwordController.text,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final token = data['token'];
        final role = data['user']['role']; // admin, superadmin, user
        
        if (_mode == 'admin' && role != 'superadmin') {
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Credenciais não autorizadas para o painel Admin.'), backgroundColor: Colors.redAccent));
           setState(() => _isLoading = false);
           return;
        }

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', token);
        await prefs.setString('role', role ?? 'user');

        if (mounted) {
           if (_mode == 'admin' || role == 'superadmin') {
             context.go('/admin/dashboard');
           } else {
             context.go('/dashboard');
           }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Erro: Credenciais inválidas'), backgroundColor: Colors.redAccent),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro de Conexão: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = _mode == 'admin';

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.backgroundGradient,
        ),
        child: Stack(
          children: [
            // Elementos de fundo gamificados (grades finas)
            Positioned.fill(
              child: Opacity(
                opacity: 0.1,
                child: Image.network(
                  "https://www.transparenttextures.com/patterns/cubes.png",
                  repeat: ImageRepeat.repeat,
                  color: AppTheme.tealNeon,
                ),
              ),
            ),

            Center(
              child: SingleChildScrollView(
                child: Container(
                  width: 400,
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // LOGO SignProof VA
                      Image.asset(
                        'assets/images/logo.png',
                        height: 120,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(height: 48),

                      // Mode Toggle (Gamified Tabs)
                      GlassContainer(
                        padding: const EdgeInsets.all(4),
                        borderRadius: 12,
                        child: Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => _mode = 'login'),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    color: !isAdmin ? AppTheme.tealNeon.withOpacity(0.2) : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                    border: !isAdmin ? Border.all(color: AppTheme.tealNeon, width: 1) : null,
                                    boxShadow: !isAdmin ? [BoxShadow(color: AppTheme.tealNeon.withOpacity(0.4), blurRadius: 10)] : [],
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(LucideIcons.user, size: 14, color: !isAdmin ? AppTheme.tealNeon : Colors.white54),
                                      const SizedBox(width: 6),
                                      Text('USUÁRIO', style: TextStyle(color: !isAdmin ? Colors.white : Colors.white54, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => _mode = 'admin'),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    color: isAdmin ? AppTheme.goldSoft.withOpacity(0.2) : Colors.transparent, 
                                    borderRadius: BorderRadius.circular(8),
                                    border: isAdmin ? Border.all(color: AppTheme.goldSoft, width: 1) : null,
                                    boxShadow: isAdmin ? [BoxShadow(color: AppTheme.goldSoft.withOpacity(0.4), blurRadius: 10)] : [],
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(LucideIcons.shield, size: 14, color: isAdmin ? AppTheme.goldSoft : Colors.white54),
                                      const SizedBox(width: 6),
                                      Text('SISTEMA', style: TextStyle(color: isAdmin ? Colors.white : Colors.white54, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Card Main Form
                      GlassContainer(
                        padding: const EdgeInsets.all(32.0),
                        borderRadius: 24,
                        borderColor: isAdmin ? AppTheme.goldSoft.withOpacity(0.3) : AppTheme.tealNeon.withOpacity(0.3),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(isAdmin ? LucideIcons.shieldAlert : LucideIcons.zap, size: 20, color: isAdmin ? AppTheme.goldSoft : AppTheme.tealNeon),
                                const SizedBox(width: 12),
                                Text(isAdmin ? 'ACESSO RESTRITO' : 'PORTAL DE ACESSO', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1.5)),
                              ],
                            ),
                            const SizedBox(height: 32),
                            
                            // Email
                            Text('IDENTIFICAÇÃO', style: TextStyle(fontSize: 10, color: isAdmin ? AppTheme.goldSoft : AppTheme.tealNeon, fontWeight: FontWeight.bold, letterSpacing: 2)),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _emailController,
                              style: const TextStyle(color: Colors.white, fontSize: 14),
                              decoration: InputDecoration(
                                hintText: isAdmin ? 'admin@valeris.com' : 'usuario@empresa.com',
                                hintStyle: const TextStyle(color: Colors.white30),
                                filled: true,
                                fillColor: Colors.black.withOpacity(0.2),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white12)),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white12)),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isAdmin ? AppTheme.goldSoft : AppTheme.tealNeon, width: 2)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                              ),
                            ),
                            const SizedBox(height: 20),
                            
                            // Password
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('CREDENCIAL SECRETA', style: TextStyle(fontSize: 10, color: isAdmin ? AppTheme.goldSoft : AppTheme.tealNeon, fontWeight: FontWeight.bold, letterSpacing: 2)),
                                if (!isAdmin)
                                  const Text('RECUPERAR', style: TextStyle(fontSize: 10, color: Colors.blueAccent, letterSpacing: 1.5, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _passwordController,
                              obscureText: _obscureText,
                              style: const TextStyle(color: Colors.white, fontSize: 14),
                              decoration: InputDecoration(
                                hintText: '••••••••',
                                hintStyle: const TextStyle(color: Colors.white30),
                                filled: true,
                                fillColor: Colors.black.withOpacity(0.2),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white12)),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white12)),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isAdmin ? AppTheme.goldSoft : AppTheme.tealNeon, width: 2)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                                suffixIcon: IconButton(
                                  icon: Icon(_obscureText ? LucideIcons.eyeOff : LucideIcons.eye, color: Colors.white54, size: 18),
                                  onPressed: () => setState(() => _obscureText = !_obscureText),
                                )
                              ),
                            ),
                            const SizedBox(height: 32),
                            
                            // Submit Button
                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isAdmin ? AppTheme.goldDark : AppTheme.tealMedium,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: BorderSide(color: isAdmin ? AppTheme.goldSoft : AppTheme.tealNeon, width: 1.5)
                                  ),
                                  shadowColor: isAdmin ? AppTheme.goldSoft : AppTheme.tealNeon,
                                  elevation: 10,
                                ),
                                onPressed: _isLoading ? null : _login,
                                child: _isLoading
                                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                    : Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: const [
                                          Text('INICIAR SESSÃO', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2, fontSize: 14)),
                                          SizedBox(width: 8),
                                          Icon(LucideIcons.arrowRight, size: 18),
                                        ],
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 32),
                      
                      // Demo Credentials
                      if (isAdmin)
                        GlassContainer(
                          padding: const EdgeInsets.all(16),
                          borderRadius: 16,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(LucideIcons.info, size: 14, color: AppTheme.goldSoft),
                                  const SizedBox(width: 6),
                                  Text('CHAVES DE TESTE DO SISTEMA', style: TextStyle(fontSize: 10, color: AppTheme.goldSoft, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.white12)), child: const Text('admin@valeris.com', style: TextStyle(fontFamily: 'monospace', fontSize: 12, color: Colors.white))),
                                  const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text(' / ', style: TextStyle(color: Colors.white54))),
                                  Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.white12)), child: const Text('admin123', style: TextStyle(fontFamily: 'monospace', fontSize: 12, color: Colors.white))),
                                ],
                              )
                            ],
                          ),
                        )
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
