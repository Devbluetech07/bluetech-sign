import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:go_router/go_router.dart';
import 'dart:convert';
import '../../core/api_config.dart';
import '../../core/app_theme.dart';
import '../widgets/glass_container.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int totalDocs = 0;
  int pendingDocs = 0;
  int signedDocs = 0;
  List<dynamic> recentDocs = [];

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }

  Future<void> _fetchDashboardData() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) {
      if(mounted) context.go('/login');
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/v1/documents/'),
        headers: {'Authorization': 'Bearer \$token'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> docs = jsonDecode(response.body);
        setState(() {
          totalDocs = docs.length;
          pendingDocs = docs.where((doc) => doc['Status'] == 'pending').length;
          signedDocs = docs.where((doc) => doc['Status'] == 'signed').length;
          recentDocs = docs.take(3).toList(); // Pega apenas os 3 mais recentes pro dash
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao carregar dashboard')),
        );
      }
    }
  }

  void _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    if(mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent, // Vai pegar o fundo do MainLayout se tiver, ou aplicamos aqui:
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.backgroundGradient,
        ),
        child: Stack(
          children: [
            // Background texture
            Positioned.fill(
              child: Opacity(
                opacity: 0.05,
                child: Image.network(
                  "https://www.transparenttextures.com/patterns/cubes.png",
                  repeat: ImageRepeat.repeat,
                  color: AppTheme.tealNeon,
                ),
              ),
            ),
            
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // TOP BAR
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Image.asset('assets/images/logo.png', height: 32, fit: BoxFit.contain),
                          ],
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(LucideIcons.bell, color: AppTheme.goldSoft),
                              onPressed: () {},
                            ),
                            IconButton(
                              icon: const Icon(LucideIcons.logOut, color: Colors.white54),
                              onPressed: _logout,
                            ),
                          ],
                        )
                      ],
                    ),
                    const SizedBox(height: 32),

                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // USER LEVEL CARD (Gamified)
                            GlassContainer(
                              padding: const EdgeInsets.all(20),
                              borderColor: AppTheme.goldSoft.withOpacity(0.5),
                              boxShadow: [BoxShadow(color: AppTheme.goldSoft.withOpacity(0.1), blurRadius: 20, spreadRadius: 2)],
                              child: Row(
                                children: [
                                  // Avatar Placeholder com brilho
                                  Container(
                                    width: 60, height: 60,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(color: AppTheme.goldSoft, width: 2),
                                      boxShadow: [BoxShadow(color: AppTheme.goldSoft.withOpacity(0.4), blurRadius: 10)],
                                      image: const DecorationImage(
                                        image: NetworkImage("https://i.pravatar.cc/150?img=11"), // Generico tech avatar
                                        fit: BoxFit.cover,
                                      )
                                    ),
                                  ),
                                  const SizedBox(width: 20),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('User Level', style: TextStyle(color: Colors.white70, fontSize: 12, letterSpacing: 1.5)),
                                        const SizedBox(height: 4),
                                        const Text('Nível 15 - Mestre de Assinaturas', style: TextStyle(color: AppTheme.goldSoft, fontSize: 16, fontWeight: FontWeight.bold)),
                                        const SizedBox(height: 8),
                                        // XP Bar
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Stack(
                                                clipBehavior: Clip.none,
                                                children: [
                                                  Container(
                                                    height: 8,
                                                    decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(4)),
                                                  ),
                                                  FractionallySizedBox(
                                                    widthFactor: 0.85, // 85% XP
                                                    child: Container(
                                                      height: 8,
                                                      decoration: BoxDecoration(
                                                        color: AppTheme.goldSoft, 
                                                        borderRadius: BorderRadius.circular(4),
                                                        boxShadow: [BoxShadow(color: AppTheme.goldSoft.withOpacity(0.5), blurRadius: 5)],
                                                      ),
                                                    ),
                                                  ),
                                                  // VA logo na barra de progresso
                                                  Positioned(
                                                    right: 0,
                                                    top: -6,
                                                    child: Container(
                                                      padding: const EdgeInsets.all(2),
                                                      decoration: BoxDecoration(color: AppTheme.tealDark, shape: BoxShape.circle, border: Border.all(color: AppTheme.goldSoft)),
                                                      child: const Icon(LucideIcons.triangle, size: 10, color: AppTheme.goldSoft),
                                                    ),
                                                  )
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            const Text('85%', style: TextStyle(color: AppTheme.goldSoft, fontSize: 12, fontWeight: FontWeight.bold)),
                                          ],
                                        )
                                      ],
                                    ),
                                  )
                                ],
                              ),
                            ),
                            
                            const SizedBox(height: 32),
                            const Text('Ações Recomendadas', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.5)),
                            const SizedBox(height: 16),
                            
                            // AÇÕES RECOMENDADAS CARDS
                            Row(
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => context.push('/documents/new'),
                                    child: GlassContainer(
                                      padding: const EdgeInsets.all(16),
                                      borderColor: AppTheme.tealNeon.withOpacity(0.3),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Icon(LucideIcons.fileSignature, color: AppTheme.tealNeon, size: 24),
                                          const SizedBox(height: 12),
                                          const Text('Assinar Novo', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                                          const SizedBox(height: 4),
                                          const Text('+ 150 XP', style: TextStyle(color: AppTheme.tealNeon, fontSize: 12, fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => context.push('/documents'),
                                    child: GlassContainer(
                                      padding: const EdgeInsets.all(16),
                                      borderColor: Colors.white24,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Icon(LucideIcons.search, color: Colors.white70, size: 24),
                                          const SizedBox(height: 12),
                                          const Text('Revisar Docs', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                                          const SizedBox(height: 4),
                                          const Text('+ 75 XP', style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 32),
                            const Text('Documentos Recentes', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.5)),
                            const SizedBox(height: 16),

                            // PENDING DOCUMENTS LIST
                            if (recentDocs.isEmpty)
                               GlassContainer(
                                 padding: const EdgeInsets.all(24),
                                 child: Center(
                                   child: Column(
                                     children: [
                                       Icon(LucideIcons.folderX, color: Colors.white24, size: 48),
                                       const SizedBox(height: 16),
                                       const Text('Nenhum documento ativo', style: TextStyle(color: Colors.white54)),
                                     ],
                                   ),
                                 )
                               )
                            else 
                               ListView.builder(
                                 shrinkWrap: true,
                                 physics: const NeverScrollableScrollPhysics(),
                                 itemCount: recentDocs.length,
                                 itemBuilder: (context, index) {
                                   final doc = recentDocs[index];
                                   final isSigned = doc['Status'] == 'signed';
                                   final progressColor = isSigned ? AppTheme.goldSoft : AppTheme.tealNeon;

                                   return Padding(
                                     padding: const EdgeInsets.only(bottom: 12.0),
                                     child: GlassContainer(
                                       padding: const EdgeInsets.all(16),
                                       borderColor: progressColor.withOpacity(0.3),
                                       child: Row(
                                         children: [
                                           // Document Icon
                                           Container(
                                             padding: const EdgeInsets.all(10),
                                             decoration: BoxDecoration(
                                               color: progressColor.withOpacity(0.1),
                                               borderRadius: BorderRadius.circular(8),
                                             ),
                                             child: Icon(LucideIcons.fileText, color: progressColor, size: 24),
                                           ),
                                           const SizedBox(width: 16),
                                           Expanded(
                                             child: Column(
                                               crossAxisAlignment: CrossAxisAlignment.start,
                                               children: [
                                                 Text(doc['Name'] ?? 'Documento', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                                                 const SizedBox(height: 8),
                                                 // Mini progress line
                                                 Stack(
                                                   children: [
                                                     Container(height: 4, decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(2))),
                                                     FractionallySizedBox(
                                                       widthFactor: isSigned ? 1.0 : 0.6,
                                                       child: Container(
                                                         height: 4, 
                                                         decoration: BoxDecoration(
                                                           color: progressColor, 
                                                           borderRadius: BorderRadius.circular(2),
                                                           boxShadow: [BoxShadow(color: progressColor.withOpacity(0.5), blurRadius: 4)]
                                                         )
                                                       ),
                                                     )
                                                   ],
                                                 )
                                               ],
                                             ),
                                           ),
                                           const SizedBox(width: 16),
                                           // Badge Circular de progresso literal
                                           Container(
                                             width: 48, height: 48,
                                             decoration: BoxDecoration(
                                               shape: BoxShape.circle,
                                               border: Border.all(color: progressColor.withOpacity(0.5), width: 2),
                                             ),
                                             child: Center(
                                               child: isSigned 
                                                 ? Icon(LucideIcons.check, color: AppTheme.goldSoft, size: 20)
                                                 : Text('60%', style: TextStyle(color: AppTheme.tealNeon, fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Orbitron')),
                                             ),
                                           ),
                                           if (isSigned)
                                             Padding(
                                               padding: const EdgeInsets.only(left: 8.0),
                                               child: Icon(LucideIcons.award, color: AppTheme.goldSoft, size: 24), // Ribbon badge mock
                                             )
                                         ],
                                       ),
                                     ),
                                   );
                                 },
                               ),
                            
                            const SizedBox(height: 100), // Espaço pro FAB se tiver
                          ],
                        ),
                      ),
                    )
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
