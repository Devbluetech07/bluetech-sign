import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:go_router/go_router.dart';
import 'dart:convert';
import '../../core/api_config.dart';
import '../../core/app_theme.dart';
import '../widgets/glass_container.dart';

class AdminCompaniesPage extends StatefulWidget {
  const AdminCompaniesPage({super.key});

  @override
  State<AdminCompaniesPage> createState() => _AdminCompaniesPageState();
}

class _AdminCompaniesPageState extends State<AdminCompaniesPage> {
  List<dynamic> _companies = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchCompanies();
  }

  Future<void> _fetchCompanies() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      final res = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/v1/admin/companies'),
        headers: {'Authorization': 'Bearer \$token'},
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          _companies = data['companies'];
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showAddCompanyModal() {
     showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.8), // Darker overlay
      builder: (context) => _AddCompanyDialog(onAdded: _fetchCompanies),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: Stack(
          children: [
            Positioned.fill(
              child: Opacity(
                opacity: 0.05,
                child: Image.network(
                  "https://www.transparenttextures.com/patterns/cubes.png",
                  repeat: ImageRepeat.repeat,
                  color: AppTheme.goldSoft, // Admin uses gold texture logic
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: AppTheme.goldSoft.withOpacity(0.1), shape: BoxShape.circle, border: Border.all(color: AppTheme.goldSoft.withOpacity(0.5))),
                              child: const Icon(LucideIcons.globe, color: AppTheme.goldSoft, size: 24),
                            ),
                            const SizedBox(width: 16),
                            const Text('INSTÂNCIAS GLOBAIS', style: TextStyle(fontFamily: 'Orbitron', fontWeight: FontWeight.bold, fontSize: 20, color: Colors.white, letterSpacing: 1.5)),
                          ],
                        ),
                        ElevatedButton.icon(
                          icon: const Icon(LucideIcons.plus, size: 18),
                          label: const Text('NOVA EMPRESA', style: TextStyle(fontFamily: 'Orbitron', fontWeight: FontWeight.bold, letterSpacing: 1)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.goldDark,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: AppTheme.goldSoft)),
                            elevation: 10,
                            shadowColor: AppTheme.goldSoft
                          ),
                          onPressed: _showAddCompanyModal,
                        )
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Metrics Banner
                    GlassContainer(
                      padding: const EdgeInsets.all(24),
                      borderColor: AppTheme.goldSoft.withOpacity(0.3),
                      borderRadius: 16,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildMetric(LucideIcons.building, '${_companies.length}', 'EMPRESAS ATIVAS'),
                          Container(width: 1, height: 40, color: Colors.white12),
                          _buildMetric(LucideIcons.users, '${_companies.fold(0, (sum, item) => sum + (item['users_count'] as int))}', 'TOTAL DE USUÁRIOS'),
                           Container(width: 1, height: 40, color: Colors.white12),
                          _buildMetric(LucideIcons.server, 'OK', 'STATUS INFRAESTRUTURA', color: AppTheme.tealNeon),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Content
                    Expanded(
                      child: _isLoading
                        ? const Center(child: CircularProgressIndicator(color: AppTheme.goldSoft))
                        : _companies.isEmpty
                          ? Center(
                              child: GlassContainer(
                                padding: const EdgeInsets.all(40),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(LucideIcons.serverOff, size: 64, color: Colors.white24),
                                    const SizedBox(height: 24),
                                    const Text('CLUSTER VAZIO', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white70, fontFamily: 'Orbitron', letterSpacing: 2)),
                                    const SizedBox(height: 8),
                                    const Text('Nenhuma empresa inquilina registrada na SuperAdmin.', style: TextStyle(color: Colors.white54, fontSize: 12)),
                                  ],
                                ),
                              ),
                            )
                          : GridView.builder(
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                childAspectRatio: 1.3,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                              ),
                              itemCount: _companies.length,
                              itemBuilder: (context, index) {
                                final comp = _companies[index];
                                return GlassContainer(
                                  padding: const EdgeInsets.all(20),
                                  borderColor: AppTheme.goldSoft.withOpacity(0.2),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Container(
                                            width: 48, height: 48,
                                            decoration: BoxDecoration(color: Colors.black.withOpacity(0.3), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white12)),
                                            child: const Icon(LucideIcons.building2, color: AppTheme.goldSoft),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: AppTheme.tealNeon.withOpacity(0.1),
                                              border: Border.all(color: AppTheme.tealNeon.withOpacity(0.5)),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: const Text('ATIVA', style: TextStyle(color: AppTheme.tealNeon, fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'Orbitron', letterSpacing: 1)),
                                          )
                                        ],
                                      ),
                                      const Spacer(),
                                      Text(comp['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis),
                                      const SizedBox(height: 4),
                                      Text('CNPJ: ${comp['cnpj']}', style: const TextStyle(color: Colors.white54, fontSize: 12, fontFamily: 'monospace')),
                                      const SizedBox(height: 16),
                                      
                                      // Progress / Stats
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            children: [
                                              const Icon(LucideIcons.users, size: 14, color: Colors.white54),
                                              const SizedBox(width: 4),
                                              Text('${comp['users_count']} Usuários', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                                            ],
                                          ),
                                          Text('PLANO: ${comp['plan'].toString().toUpperCase()}', style: const TextStyle(color: AppTheme.goldSoft, fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'Orbitron')),
                                        ],
                                      ),
                                      const SizedBox(height: 16),
                                      SizedBox(
                                        width: double.infinity,
                                        child: OutlinedButton(
                                          onPressed: () => context.go('/admin/companies/${comp['id']}'),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: Colors.white,
                                            side: const BorderSide(color: Colors.white24),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          ),
                                          child: const Text('VER DETALHES', style: TextStyle(fontFamily: 'Orbitron', fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
                                        ),
                                      )
                                    ],
                                  ),
                                );
                              },
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

  Widget _buildMetric(IconData icon, String value, String label, {Color color = AppTheme.goldSoft}) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 8),
        Text(value, style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, fontFamily: 'Orbitron')),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10, letterSpacing: 1.5)),
      ],
    );
  }
}

class _AddCompanyDialog extends StatefulWidget {
  final VoidCallback onAdded;
  const _AddCompanyDialog({required this.onAdded});

  @override
  State<_AddCompanyDialog> createState() => _AddCompanyDialogState();
}

class _AddCompanyDialogState extends State<_AddCompanyDialog> {
  final _nameController = TextEditingController();
  final _cnpjController = TextEditingController();
  final _emailController = TextEditingController();
  bool _isLoading = false;
  String? _successPassword;

  Future<void> _submit() async {
      setState(() => _isLoading = true);
      try {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('token') ?? '';

        final res = await http.post(
          Uri.parse('${ApiConfig.baseUrl}/api/v1/admin/companies'),
          headers: {'Authorization': 'Bearer \$token', 'Content-Type': 'application/json'},
          body: jsonEncode({
            'name': _nameController.text,
            'cnpj': _cnpjController.text,
            'plan': 'starter',
            'email': _emailController.text,
          }),
        );
        if (res.statusCode == 201) {
           final body = jsonDecode(res.body);
           print("Response: $body");
           
           setState(() {
              _successPassword = '123456'; // Pelo controller sabemos que cria com esta senha padrao
           });
        } else {
           if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Falha ao adicionar empresa'), backgroundColor: Colors.redAccent));
        }
      } catch (e) {
           if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.redAccent));
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
  }

  @override
  Widget build(BuildContext context) {
      if (_successPassword != null) {
         return _buildSuccessView();
      }

      return Dialog(
        backgroundColor: Colors.transparent,
        child: GlassContainer(
           padding: const EdgeInsets.all(32),
           borderRadius: 24,
           borderColor: AppTheme.goldSoft.withOpacity(0.5),
           width: 500,
           child: SingleChildScrollView(
             child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Row(
                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
                     children: [
                       Row(
                         children: [
                           Icon(LucideIcons.building2, color: AppTheme.goldSoft, size: 28),
                           const SizedBox(width: 12),
                           const Text('NOVA EMPRESA', style: TextStyle(fontFamily: 'Orbitron', fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.5)),
                         ],
                       ),
                       IconButton(icon: const Icon(LucideIcons.x, color: Colors.white54), onPressed: () => Navigator.pop(context)),
                     ],
                   ),
                   const SizedBox(height: 32),
                   
                   const Text('RAZÃO SOCIAL', style: TextStyle(fontSize: 10, color: AppTheme.goldSoft, fontWeight: FontWeight.bold, letterSpacing: 2)),
                   const SizedBox(height: 8),
                   TextField(
                     controller: _nameController, 
                     style: const TextStyle(color: Colors.white),
                     decoration: InputDecoration(
                        hintText: 'Ex: TechCorp LTDA',
                        hintStyle: const TextStyle(color: Colors.white30),
                        filled: true, 
                        fillColor: Colors.black.withOpacity(0.3),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white12)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white12)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.goldSoft)),
                     )
                   ),
                   const SizedBox(height: 16),
                   
                   const Text('CNPJ NUMÉRICO', style: TextStyle(fontSize: 10, color: AppTheme.goldSoft, fontWeight: FontWeight.bold, letterSpacing: 2)),
                   const SizedBox(height: 8),
                   TextField(
                     controller: _cnpjController, 
                     style: const TextStyle(color: Colors.white),
                     decoration: InputDecoration(
                        hintText: '00.000.000/0001-00',
                        hintStyle: const TextStyle(color: Colors.white30),
                        filled: true, 
                        fillColor: Colors.black.withOpacity(0.3),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white12)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white12)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.goldSoft)),
                     )
                   ),
                   const SizedBox(height: 16),

                   const Text('E-MAIL ADMIN PRINCIPAL', style: TextStyle(fontSize: 10, color: AppTheme.goldSoft, fontWeight: FontWeight.bold, letterSpacing: 2)),
                   const SizedBox(height: 8),
                   TextField(
                     controller: _emailController, 
                     style: const TextStyle(color: Colors.white),
                     decoration: InputDecoration(
                        hintText: 'admin@novaempresa.com',
                        hintStyle: const TextStyle(color: Colors.white30),
                        filled: true, 
                        fillColor: Colors.black.withOpacity(0.3),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white12)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white12)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.goldSoft)),
                     )
                   ),
                   const SizedBox(height: 32),

                   Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                         TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCELAR', style: TextStyle(color: Colors.white54, fontFamily: 'Orbitron', fontWeight: FontWeight.bold))),
                         const SizedBox(width: 16),
                         ElevatedButton(
                            onPressed: _isLoading ? null : _submit,
                            style: ElevatedButton.styleFrom(
                               backgroundColor: AppTheme.goldDark, 
                               foregroundColor: Colors.white,
                               padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: AppTheme.goldSoft)),
                            ),
                            child: _isLoading 
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) 
                                : const Text('REGISTRAR INQUILINO', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Orbitron', letterSpacing: 1)),
                         )
                      ],
                   )
                ]
             )
           ),
        ),
      );
  }

  Widget _buildSuccessView() {
      return Dialog(
        backgroundColor: Colors.transparent,
        child: GlassContainer(
           padding: const EdgeInsets.all(40),
           borderRadius: 24,
           borderColor: AppTheme.tealNeon.withOpacity(0.5),
           width: 450,
           child: Column(
             mainAxisSize: MainAxisSize.min,
             children: [
                Container(
                   padding: const EdgeInsets.all(20),
                   decoration: BoxDecoration(color: AppTheme.tealNeon.withOpacity(0.1), shape: BoxShape.circle, border: Border.all(color: AppTheme.tealNeon)),
                   child: const Icon(LucideIcons.checkCircle, color: AppTheme.tealNeon, size: 64),
                ),
                const SizedBox(height: 24),
                const Text('EMPRESA REGISTRADA!', style: TextStyle(fontFamily: 'Orbitron', fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.5)),
                const SizedBox(height: 16),
                const Text('A instância foi criada. O administrador precisará utilizar as credenciais provisórias abaixo no Portal de Acesso da Empresa:', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 24),
                Container(
                   padding: const EdgeInsets.all(16),
                   width: double.infinity,
                   decoration: BoxDecoration(color: Colors.black.withOpacity(0.4), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white12)),
                   child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                         const Text('EMAIL:', style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
                         Text(_emailController.text, style: const TextStyle(color: AppTheme.tealNeon, fontSize: 16, fontWeight: FontWeight.bold)),
                         const SizedBox(height: 12),
                         const Text('SENHA PROVISÓRIA:', style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
                         Text(_successPassword!, style: const TextStyle(color: AppTheme.tealNeon, fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                      ],
                   ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                   width: double.infinity,
                   child: ElevatedButton(
                      onPressed: () {
                         widget.onAdded();
                         Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                         backgroundColor: AppTheme.tealMedium, 
                         foregroundColor: Colors.white,
                         padding: const EdgeInsets.symmetric(vertical: 16),
                         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: AppTheme.tealNeon)),
                      ),
                      child: const Text('FECHAR', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Orbitron', letterSpacing: 1)),
                   ),
                )
             ],
           )
        )
      );
  }
}
