import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/api_config.dart';
import '../../core/app_theme.dart';
import '../widgets/glass_container.dart';

class TeamPage extends StatefulWidget {
  const TeamPage({super.key});

  @override
  State<TeamPage> createState() => _TeamPageState();
}

class _TeamPageState extends State<TeamPage> {
  List<Map<String, dynamic>> _profiles = [];
  List<Map<String, dynamic>> _departments = [];
  bool _loading = true;

  final List<String> _permissionKeys = const [
    'documents:read',
    'documents:write',
    'contacts:read',
    'contacts:write',
    'templates:read',
    'templates:write',
    'folders:read',
    'folders:write',
    'reports:read',
    'integrations:read',
    'integrations:write',
    'team:read',
    'team:write',
    'departments:read',
    'departments:write',
    'settings:read',
    'settings:write',
    'api:read',
    'api:write',
  ];

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';
    final usersRes = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/api/v1/team/users'),
      headers: {'Authorization': 'Bearer $token'},
    );
    final depsRes = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/api/v1/departments/'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (usersRes.statusCode == 200) {
      final body = jsonDecode(usersRes.body) as Map<String, dynamic>;
      _profiles = (body['users'] as List<dynamic>? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }
    if (depsRes.statusCode == 200) {
      final body = jsonDecode(depsRes.body) as Map<String, dynamic>;
      _departments = (body['departments'] as List<dynamic>? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }
    if (mounted) setState(() => _loading = false);
  }

  String _getHierarchyLabel(String h) {
    if (h == 'owner') return 'Proprietário';
    if (h == 'gestor') return 'Gestor';
    return 'Usuário';
  }

  Color _getHierarchyColor(String h) {
    if (h == 'owner') return const Color(0xFF3B82F6);
    if (h == 'gestor') return const Color(0xFF10B981);
    return Colors.white54;
  }

  IconData _getHierarchyIcon(String h) {
    if (h == 'owner') return LucideIcons.shieldCheck;
    if (h == 'gestor') return LucideIcons.shield;
    return LucideIcons.user;
  }

  @override
  Widget build(BuildContext context) {
    final ownerCount = _profiles
        .where((p) => (p['hierarchy'] ?? 'user') == 'owner')
        .length;
    final gestorCount = _profiles
        .where((p) => (p['hierarchy'] ?? 'user') == 'gestor')
        .length;
    final userCount = _profiles
        .where((p) => (p['hierarchy'] ?? 'user') == 'user')
        .length;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        _buildStatCard(
                          'Proprietário',
                          ownerCount,
                          LucideIcons.shieldCheck,
                        ),
                        const SizedBox(width: 8),
                        _buildStatCard(
                          'Gestor',
                          gestorCount,
                          LucideIcons.shield,
                        ),
                        const SizedBox(width: 8),
                        _buildStatCard('Usuário', userCount, LucideIcons.user),
                      ],
                    ),
                    ElevatedButton.icon(
                      icon: const Icon(LucideIcons.plus, size: 16),
                      label: const Text('Novo usuário'),
                      onPressed: _createUserDialog,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: GlassContainer(
                    borderColor: Colors.white12,
                    child: _loading
                        ? const Center(child: CircularProgressIndicator())
                        : Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                decoration: const BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(color: Colors.white12),
                                  ),
                                ),
                                child: const Row(
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: Text(
                                        'USUÁRIO',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white54,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        'HIERARQUIA',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white54,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        'DEPARTAMENTO',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white54,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        'STATUS',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white54,
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 48),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: ListView.separated(
                                  itemCount: _profiles.length,
                                  separatorBuilder: (_, __) => const Divider(
                                    color: Colors.white12,
                                    height: 1,
                                  ),
                                  itemBuilder: (context, index) {
                                    final profile = _profiles[index];
                                    final hierarchy =
                                        (profile['hierarchy'] ?? 'user')
                                            .toString();
                                    final fullName =
                                        (profile['full_name'] ??
                                                profile['email'] ??
                                                '-')
                                            .toString();
                                    final deptId = profile['department_id']
                                        ?.toString();
                                    final dep = _departments
                                        .where(
                                          (d) => d['ID'].toString() == deptId,
                                        )
                                        .toList();
                                    return Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 12,
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            flex: 3,
                                            child: Row(
                                              children: [
                                                CircleAvatar(
                                                  radius: 18,
                                                  backgroundColor: AppTheme
                                                      .tealNeon
                                                      .withOpacity(0.2),
                                                  child: Text(
                                                    fullName
                                                        .substring(0, 1)
                                                        .toUpperCase(),
                                                    style: const TextStyle(
                                                      color: AppTheme.tealNeon,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      fullName,
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                    Text(
                                                      (profile['email'] ?? '-')
                                                          .toString(),
                                                      style: const TextStyle(
                                                        fontSize: 12,
                                                        color: Colors.white54,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: Align(
                                              alignment: Alignment.centerLeft,
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 4,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: _getHierarchyColor(
                                                    hierarchy,
                                                  ).withOpacity(0.15),
                                                  borderRadius:
                                                      BorderRadius.circular(20),
                                                ),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      _getHierarchyIcon(
                                                        hierarchy,
                                                      ),
                                                      size: 12,
                                                      color: _getHierarchyColor(
                                                        hierarchy,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Text(
                                                      _getHierarchyLabel(
                                                        hierarchy,
                                                      ),
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color:
                                                            _getHierarchyColor(
                                                              hierarchy,
                                                            ),
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: Text(
                                              dep.isNotEmpty
                                                  ? (dep.first['Name'] ?? '—')
                                                        .toString()
                                                  : '—',
                                              style: const TextStyle(
                                                fontSize: 14,
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: Align(
                                              alignment: Alignment.centerLeft,
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 4,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color:
                                                      (profile['active'] ==
                                                          true)
                                                      ? Colors.green
                                                            .withOpacity(0.15)
                                                      : Colors.white12,
                                                  borderRadius:
                                                      BorderRadius.circular(20),
                                                ),
                                                child: Text(
                                                  (profile['active'] == true)
                                                      ? 'Ativo'
                                                      : 'Inativo',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color:
                                                        (profile['active'] ==
                                                            true)
                                                        ? Colors.green
                                                        : Colors.white54,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          PopupMenuButton<String>(
                                            onSelected: (v) {
                                              if (v == 'permissions')
                                                _openPermissions(profile);
                                              if (v == 'toggle')
                                                _toggleActive(profile);
                                            },
                                            itemBuilder: (_) => const [
                                              PopupMenuItem(
                                                value: 'permissions',
                                                child: Text('Permissões'),
                                              ),
                                              PopupMenuItem(
                                                value: 'toggle',
                                                child: Text('Ativar/Desativar'),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _createUserDialog() async {
    final fullName = TextEditingController();
    final email = TextEditingController();
    final pass = TextEditingController(text: '123456');
    String hierarchy = 'user';
    String department = '';
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Novo usuário'),
          content: SizedBox(
            width: 560,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: fullName,
                  decoration: const InputDecoration(labelText: 'Nome'),
                ),
                TextField(
                  controller: email,
                  decoration: const InputDecoration(labelText: 'E-mail'),
                ),
                TextField(
                  controller: pass,
                  decoration: const InputDecoration(labelText: 'Senha inicial'),
                ),
                DropdownButtonFormField<String>(
                  value: hierarchy,
                  items: const [
                    DropdownMenuItem(value: 'gestor', child: Text('Gestor')),
                    DropdownMenuItem(value: 'user', child: Text('Usuário')),
                  ],
                  onChanged: (v) =>
                      setDialogState(() => hierarchy = v ?? 'user'),
                  decoration: const InputDecoration(labelText: 'Hierarquia'),
                ),
                DropdownButtonFormField<String>(
                  value: department.isEmpty ? null : department,
                  items: _departments
                      .map(
                        (d) => DropdownMenuItem(
                          value: d['ID'].toString(),
                          child: Text((d['Name'] ?? '-').toString()),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setDialogState(() => department = v ?? ''),
                  decoration: const InputDecoration(labelText: 'Departamento'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Criar'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';
    await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/v1/team/users'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'full_name': fullName.text.trim(),
        'email': email.text.trim(),
        'password': pass.text,
        'hierarchy': hierarchy,
        'department_id': department,
      }),
    );
    _fetch();
  }

  Future<void> _toggleActive(Map<String, dynamic> profile) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';
    await http.put(
      Uri.parse('${ApiConfig.baseUrl}/api/v1/team/users/${profile['id']}'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'active': !(profile['active'] == true)}),
    );
    _fetch();
  }

  Future<void> _openPermissions(Map<String, dynamic> profile) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';
    final res = await http.get(
      Uri.parse(
        '${ApiConfig.baseUrl}/api/v1/team/users/${profile['id']}/permissions',
      ),
      headers: {'Authorization': 'Bearer $token'},
    );
    final selected = <String>{};
    if (res.statusCode == 200) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      for (final p in (body['permissions'] as List<dynamic>? ?? [])) {
        final m = Map<String, dynamic>.from(p as Map);
        if (m['Granted'] == true || m['granted'] == true) {
          selected.add((m['Permission'] ?? m['permission']).toString());
        }
      }
    }
    final save = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Permissões • ${profile['email']}'),
          content: SizedBox(
            width: 640,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _permissionKeys.map((perm) {
                return FilterChip(
                  selected: selected.contains(perm),
                  onSelected: (v) => setDialogState(
                    () => v ? selected.add(perm) : selected.remove(perm),
                  ),
                  label: Text(perm),
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
    if (save != true) return;
    await http.put(
      Uri.parse(
        '${ApiConfig.baseUrl}/api/v1/team/users/${profile['id']}/permissions',
      ),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'permissions': selected.toList()}),
    );
  }

  Widget _buildStatCard(String title, int count, IconData icon) {
    return Card(
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Colors.white12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Icon(icon, size: 16, color: Colors.white54),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                count.toString(),
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
