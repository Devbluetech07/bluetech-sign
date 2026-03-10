import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:go_router/go_router.dart';
import 'dart:convert';
import '../../core/api_config.dart';
import '../../core/app_theme.dart';
import '../widgets/glass_container.dart';

class AdminCompanyDetailsPage extends StatefulWidget {
  final String companyId;
  const AdminCompanyDetailsPage({super.key, required this.companyId});

  @override
  State<AdminCompanyDetailsPage> createState() =>
      _AdminCompanyDetailsPageState();
}

class _AdminCompanyDetailsPageState extends State<AdminCompanyDetailsPage>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  Map<String, dynamic>? _company;
  List<dynamic> _users = [];
  int _documentCount = 0;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchCompanyDetails();
  }

  Future<void> _fetchCompanyDetails() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      final res = await http.get(
        Uri.parse(
          '${ApiConfig.baseUrl}/api/v1/admin/companies/\${widget.companyId}',
        ),
        headers: {'Authorization': 'Bearer \$token'},
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          _company = data['company'];
          _users = data['users'] ?? [];
          _documentCount = data['documents_count'] ?? 0;
        });
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro: \$e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showAddUserModal() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.8),
      builder: (context) => _AddUserDialog(
        companyId: widget.companyId,
        onAdded: _fetchCompanyDetails,
      ),
    );
  }

  Future<void> _resetUserPassword(String userId, String userEmail) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      final res = await http.post(
        Uri.parse(
          '${ApiConfig.baseUrl}/api/v1/admin/users/\$userId/reset_password',
        ),
        headers: {'Authorization': 'Bearer \$token'},
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final newPass = data['new_temporary_password'];
        if (mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: const Color(0xFF1E293B),
              title: const Text(
                'Senha Resetada!',
                style: TextStyle(
                  color: AppTheme.tealNeon,
                  fontFamily: 'Orbitron',
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'A nova senha temporária para \$userEmail é:',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    color: Colors.black38,
                    child: Text(
                      newPass,
                      style: const TextStyle(
                        color: AppTheme.goldSoft,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '(Em produção um email seria enviado com um link real de reset)',
                    style: TextStyle(color: Colors.white30, fontSize: 10),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text(
                    'FECHAR',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          );
        }
      } else {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Falha ao resetar senha')),
          );
      }
    } catch (_) {}
  }

  Future<void> _deactivateUser(String userId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text(
          'Desativar Usuário',
          style: TextStyle(color: Colors.redAccent),
        ),
        content: const Text(
          'Tem certeza que deseja desativar este usuário? Ele perderá acesso ao portal da Empresa.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('CANCELAR'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'DESATIVAR',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('token') ?? '';
        final res = await http.delete(
          Uri.parse('${ApiConfig.baseUrl}/api/v1/admin/users/\$userId'),
          headers: {'Authorization': 'Bearer \$token'},
        );
        if (res.statusCode == 200) {
          _fetchCompanyDetails();
        }
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F172A),
        body: Center(
          child: CircularProgressIndicator(color: AppTheme.goldSoft),
        ),
      );
    }

    if (_company == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F172A),
        body: Center(
          child: Text(
            "Empresa não encontrada",
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    // Default max values just for visual display based on plano
    final int maxUsers = _company!['plan'] == 'enterprise' ? 100 : 50;
    final int maxDocs = _company!['plan'] == 'enterprise' ? 5000 : 1000;

    // Calculate fractional percentages for the progress bars
    double usersProgress = (_users.length / maxUsers).clamp(0.0, 1.0);
    double docsProgress = (_documentCount / maxDocs).clamp(0.0, 1.0);

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
                  color: AppTheme.goldSoft,
                ),
              ),
            ),
            SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Back button
                  Padding(
                    padding: const EdgeInsets.only(left: 16, top: 16),
                    child: TextButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(
                        LucideIcons.arrowLeft,
                        color: Colors.white70,
                        size: 16,
                      ),
                      label: const Text(
                        'Voltar para empresas',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
                  ),

                  // Header Info
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32.0,
                      vertical: 16.0,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: AppTheme.tealNeon.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            LucideIcons.building2,
                            color: AppTheme.tealNeon,
                            size: 32,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _company!['name'] ?? '',
                                style: const TextStyle(
                                  fontFamily: 'Orbitron',
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 1.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _company!['cnpj'] ?? '',
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.tealNeon.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: AppTheme.tealNeon.withOpacity(0.5),
                            ),
                          ),
                          child: const Text(
                            'Ativa',
                            style: TextStyle(
                              color: AppTheme.tealNeon,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white10,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: Text(
                            (_company!['plan'] ?? '').toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Stats Row
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: GlassContainer(
                            padding: const EdgeInsets.all(20),
                            borderColor: Colors.white12,
                            child: Column(
                              children: [
                                Text(
                                  '\${_users.length}',
                                  style: const TextStyle(
                                    fontFamily: 'Orbitron',
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Usuários',
                                  style: TextStyle(
                                    color: Colors.white54,
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  'máx. \$maxUsers',
                                  style: const TextStyle(
                                    color: Colors.white30,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 2,
                          child: GlassContainer(
                            padding: const EdgeInsets.all(20),
                            borderColor: Colors.white12,
                            child: Column(
                              children: [
                                Text(
                                  '\$_documentCount',
                                  style: const TextStyle(
                                    fontFamily: 'Orbitron',
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Documentos (mês)',
                                  style: TextStyle(
                                    color: Colors.white54,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                LinearProgressIndicator(
                                  value: docsProgress,
                                  backgroundColor: Colors.white10,
                                  valueColor: const AlwaysStoppedAnimation(
                                    AppTheme.tealNeon,
                                  ),
                                  minHeight: 4,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: GlassContainer(
                            padding: const EdgeInsets.all(20),
                            borderColor: Colors.white12,
                            child: Column(
                              children: [
                                Text(
                                  '\$maxDocs',
                                  style: const TextStyle(
                                    fontFamily: 'Orbitron',
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Limite mensal',
                                  style: TextStyle(
                                    color: Colors.white54,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 16), // align with PB
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: GlassContainer(
                            padding: const EdgeInsets.all(20),
                            borderColor: Colors.white12,
                            child: Column(
                              children: [
                                Text(
                                  '${_company!['plan']}'.replaceFirst(
                                    RegExp(r'^[a-z]'),
                                    '${_company!['plan']}'
                                        .substring(0, 1)
                                        .toUpperCase(),
                                  ),
                                  style: const TextStyle(
                                    fontFamily: 'Orbitron',
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.tealNeon,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Plano ativo',
                                  style: TextStyle(
                                    color: Colors.white54,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 16),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Tabs
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32.0),
                    child: TabBar(
                      controller: _tabController,
                      isScrollable: true,
                      indicatorColor: AppTheme.tealNeon,
                      labelColor: AppTheme.tealNeon,
                      unselectedLabelColor: Colors.white54,
                      dividerColor: Colors.transparent,
                      tabs: const [
                        Tab(text: 'Usuários'),
                        Tab(text: 'Configurações'),
                        Tab(text: 'Integrações API'),
                      ],
                    ),
                  ),

                  // Tab Views
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        // Tab 1: Users
                        _buildUsersTab(),

                        // Tab 2: Settings
                        const Center(
                          child: Text(
                            'Configurações da Instância',
                            style: TextStyle(color: Colors.white54),
                          ),
                        ),

                        // Tab 3: API integration
                        const Center(
                          child: Text(
                            'Webhooks e Chaves da API',
                            style: TextStyle(color: Colors.white54),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUsersTab() {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '\${_users.length} usuário(s) cadastrado(s)',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              ElevatedButton.icon(
                onPressed: _showAddUserModal,
                icon: const Icon(LucideIcons.plus, size: 16),
                label: const Text(
                  'Novo usuário',
                  style: TextStyle(
                    fontFamily: 'Orbitron',
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.tealDark,
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: AppTheme.tealNeon),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: GlassContainer(
              borderColor: Colors.white12,
              child: ListView.separated(
                itemCount: _users.length,
                separatorBuilder: (context, index) =>
                    const Divider(color: Colors.white12, height: 1),
                itemBuilder: (context, index) {
                  final user = _users[index];
                  final isAdmin = user['Role'] == 'company_admin';
                  final createdAtRaw = user['CreatedAt'];
                  final createdAtText =
                      createdAtRaw is String && createdAtRaw.length >= 10
                      ? createdAtRaw.substring(0, 10)
                      : '-';

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 8,
                    ),
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isAdmin ? LucideIcons.shield : LucideIcons.user,
                        color: isAdmin ? AppTheme.tealNeon : Colors.white54,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      user['Email'],
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: Text(
                      'Cadastrado em: $createdAtText',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: isAdmin
                                ? AppTheme.tealNeon.withOpacity(0.2)
                                : Colors.white10,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            isAdmin ? 'Admin' : 'Usuário',
                            style: TextStyle(
                              color: isAdmin
                                  ? AppTheme.tealNeon
                                  : Colors.white70,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                            border: Border.all(color: Colors.white24),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'Ativo',
                            style: TextStyle(color: Colors.white, fontSize: 10),
                          ),
                        ),
                        const SizedBox(width: 16),
                        PopupMenuButton<String>(
                          icon: const Icon(
                            LucideIcons.moreHorizontal,
                            color: Colors.white70,
                          ),
                          color: const Color(0xFF1E293B),
                          onSelected: (val) {
                            if (val == 'reset') {
                              _resetUserPassword(user['ID'], user['Email']);
                            } else if (val == 'deactivate') {
                              _deactivateUser(user['ID']);
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'edit',
                              child: Row(
                                children: [
                                  Icon(
                                    LucideIcons.edit,
                                    color: AppTheme.goldSoft,
                                    size: 16,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Editar',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'reset',
                              child: Row(
                                children: [
                                  Icon(
                                    LucideIcons.key,
                                    color: Colors.white70,
                                    size: 16,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Resetar senha',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'deactivate',
                              child: Row(
                                children: [
                                  Icon(
                                    LucideIcons.trash2,
                                    color: Colors.redAccent,
                                    size: 16,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Desativar',
                                    style: TextStyle(color: Colors.redAccent),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddUserDialog extends StatefulWidget {
  final String companyId;
  final VoidCallback onAdded;
  const _AddUserDialog({required this.companyId, required this.onAdded});

  @override
  State<_AddUserDialog> createState() => _AddUserDialogState();
}

class _AddUserDialogState extends State<_AddUserDialog> {
  final _emailController = TextEditingController();
  final _passController = TextEditingController();
  String _role = 'user';
  bool _isLoading = false;

  Future<void> _submit() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      final res = await http.post(
        Uri.parse(
          '${ApiConfig.baseUrl}/api/v1/admin/companies/\${widget.companyId}/users',
        ),
        headers: {
          'Authorization': 'Bearer \$token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'email': _emailController.text,
          'password': _passController.text, // Pode ser vazio = 123456
          'role': _role,
          'name': '',
        }),
      );
      if (res.statusCode == 201) {
        widget.onAdded();
        if (mounted) Navigator.pop(context);
      } else {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Falha ao adicionar usuário: \${res.body}')),
          );
      }
    } catch (e) {
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: GlassContainer(
        padding: const EdgeInsets.all(32),
        borderRadius: 24,
        borderColor: AppTheme.tealNeon.withOpacity(0.5),
        width: 400,
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
                      Icon(
                        LucideIcons.userPlus,
                        color: AppTheme.tealNeon,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'NOVO USUÁRIO',
                        style: TextStyle(
                          fontFamily: 'Orbitron',
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(LucideIcons.x, color: Colors.white54),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              const Text(
                'E-MAIL DE ACESSO',
                style: TextStyle(
                  fontSize: 10,
                  color: AppTheme.tealNeon,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _emailController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'usuario@empresa.com',
                  hintStyle: const TextStyle(color: Colors.white30),
                  filled: true,
                  fillColor: Colors.black.withOpacity(0.3),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.white12),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.white12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.tealNeon),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              const Text(
                'SENHA (Vazio = 123456)',
                style: TextStyle(
                  fontSize: 10,
                  color: AppTheme.tealNeon,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _passController,
                style: const TextStyle(color: Colors.white),
                obscureText: true,
                decoration: InputDecoration(
                  hintText: '********',
                  hintStyle: const TextStyle(color: Colors.white30),
                  filled: true,
                  fillColor: Colors.black.withOpacity(0.3),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.white12),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.white12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.tealNeon),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              const Text(
                'NÍVEL DE PERMISSÃO',
                style: TextStyle(
                  fontSize: 10,
                  color: AppTheme.tealNeon,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _role,
                dropdownColor: const Color(0xFF1E293B),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.black.withOpacity(0.3),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.white12),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.white12),
                  ),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'user',
                    child: Text('Operacional (Usuário)'),
                  ),
                  DropdownMenuItem(
                    value: 'company_admin',
                    child: Text('Administrador da Instância'),
                  ),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _role = val);
                },
              ),
              const SizedBox(height: 32),

              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'CANCELAR',
                      style: TextStyle(
                        color: Colors.white54,
                        fontFamily: 'Orbitron',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.tealDark,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: AppTheme.tealNeon),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'REGISTRAR ALVO',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Orbitron',
                              letterSpacing: 1,
                            ),
                          ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
