import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:lucide_icons/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  List<Map<String, dynamic>> _externalDepartments = [];
  List<Map<String, dynamic>> _externalCargos = [];
  final Map<int, List<Map<String, dynamic>>> _externalCollaboratorsCache = {};
  List<Map<String, dynamic>> _filteredProfiles = [];
  bool _loading = true;
  bool _saving = false;
  final TextEditingController _searchController = TextEditingController();
  String _hierarchyFilter = 'all';

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
    _searchController.addListener(_applyFilters);
    _fetch();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';
    await _fetchCompanyDirectoryOptions(token);
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
    _applyFilters();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _fetchCompanyDirectoryOptions(String token) async {
    try {
      final res = await http.get(
        Uri.parse(
          '${ApiConfig.baseUrl}/api/v1/company-directory/options?ensure_local=true',
        ),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode != 200) return;
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      _externalDepartments = (body['departments'] as List<dynamic>? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      _externalCargos = (body['cargos'] as List<dynamic>? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } catch (_) {}
  }

  Future<List<Map<String, dynamic>>> _fetchExternalCollaborators(
    int departmentId,
  ) async {
    final cached = _externalCollaboratorsCache[departmentId];
    if (cached != null) return cached;

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';
    final res = await http.get(
      Uri.parse(
        '${ApiConfig.baseUrl}/api/v1/company-directory/departments/$departmentId/collaborators',
      ),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (res.statusCode != 200) return [];
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final collaborators = (body['collaborators'] as List<dynamic>? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    _externalCollaboratorsCache[departmentId] = collaborators;
    return collaborators;
  }

  String? _resolveLocalDepartmentId(Map<String, dynamic> externalDepartment) {
    final fromApi = externalDepartment['local_department_id']?.toString();
    if (fromApi != null && fromApi.isNotEmpty) return fromApi;
    final extName = (externalDepartment['name'] ?? '').toString().trim();
    if (extName.isEmpty) return null;
    for (final dep in _departments) {
      if ((dep['Name'] ?? '').toString().trim().toLowerCase() ==
          extName.toLowerCase()) {
        return dep['ID']?.toString();
      }
    }
    return null;
  }

  void _applyFilters() {
    final query = _searchController.text.toLowerCase().trim();
    final filtered = _profiles.where((p) {
      final hierarchy = (p['hierarchy'] ?? 'user').toString();
      final name = (p['full_name'] ?? '').toString().toLowerCase();
      final email = (p['email'] ?? '').toString().toLowerCase();
      final byHierarchy =
          _hierarchyFilter == 'all' || hierarchy == _hierarchyFilter;
      final byQuery =
          query.isEmpty || name.contains(query) || email.contains(query);
      return byHierarchy && byQuery;
    }).toList();

    if (mounted) {
      setState(() => _filteredProfiles = filtered);
    }
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

  String _inferHierarchyFromCargoName(String cargoName) {
    final c = cargoName.trim().toLowerCase();
    if (c.isEmpty) return 'user';
    if (c.contains('diretor') ||
        c.contains('director') ||
        c.contains('ceo') ||
        c.contains('cto') ||
        c.contains('cfo') ||
        c.contains('presidente')) {
      return 'owner';
    }
    if (c.contains('gerente') ||
        c.contains('coordenador') ||
        c.contains('coordenadora') ||
        c.contains('supervisor') ||
        c.contains('lider') ||
        c.contains('líder')) {
      return 'gestor';
    }
    return 'user';
  }

  Future<void> _createUserDialog() async {
    final fullName = TextEditingController();
    final email = TextEditingController();
    final pass = TextEditingController(text: '123456');
    String hierarchy = 'user';
    String department = '';
    String externalDepartmentId = '';
    String externalDepartmentName = '';
    String externalCollaboratorId = '';
    String externalCargoId = '';
    String externalCargoName = '';
    bool loadingCollaborators = false;
    List<Map<String, dynamic>> externalCollaborators = [];
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
                TextFormField(
                  initialValue: _getHierarchyLabel(hierarchy),
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: 'Hierarquia (automática por cargo)',
                  ),
                ),
                DropdownButtonFormField<String>(
                  initialValue: externalDepartmentId.isEmpty
                      ? null
                      : externalDepartmentId,
                  items: _externalDepartments
                      .map(
                        (d) => DropdownMenuItem(
                          value: d['id'].toString(),
                          child: Text((d['name'] ?? '-').toString()),
                        ),
                      )
                      .toList(),
                  onChanged: (v) async {
                    final selected = _externalDepartments.where(
                      (d) => d['id'].toString() == v,
                    );
                    final selectedDepartment = selected.isEmpty
                        ? null
                        : selected.first;
                    setDialogState(() {
                      externalDepartmentId = v ?? '';
                      externalDepartmentName =
                          (selectedDepartment?['name'] ?? '').toString();
                      externalCollaboratorId = '';
                      externalCollaborators = [];
                      loadingCollaborators = externalDepartmentId.isNotEmpty;
                      department =
                          _resolveLocalDepartmentId(selectedDepartment ?? {}) ??
                          '';
                    });
                    final depInt = int.tryParse(externalDepartmentId);
                    if (depInt == null) {
                      setDialogState(() => loadingCollaborators = false);
                      return;
                    }
                    final fetched = await _fetchExternalCollaborators(depInt);
                    setDialogState(() {
                      externalCollaborators = fetched;
                      loadingCollaborators = false;
                    });
                  },
                  decoration: const InputDecoration(
                    labelText: 'Departamento da empresa',
                  ),
                ),
                DropdownButtonFormField<String>(
                  initialValue: externalCollaboratorId.isEmpty
                      ? null
                      : externalCollaboratorId,
                  items: externalCollaborators
                      .map(
                        (c) => DropdownMenuItem(
                          value: c['id'].toString(),
                          child: Text((c['name'] ?? '-').toString()),
                        ),
                      )
                      .toList(),
                  onChanged: loadingCollaborators
                      ? null
                      : (v) {
                          final selected = externalCollaborators.where(
                            (c) => c['id'].toString() == v,
                          );
                          if (selected.isEmpty) return;
                          final collaborator = selected.first;
                          setDialogState(() {
                            externalCollaboratorId = v ?? '';
                            fullName.text = (collaborator['name'] ?? '')
                                .toString();
                            email.text = (collaborator['email'] ?? '')
                                .toString();
                            if (collaborator['cargo_id'] != null) {
                              externalCargoId = collaborator['cargo_id']
                                  .toString();
                              externalCargoName =
                                  (collaborator['cargo_name'] ?? '').toString();
                              hierarchy = _inferHierarchyFromCargoName(
                                externalCargoName,
                              );
                            }
                          });
                        },
                  decoration: InputDecoration(
                    labelText: loadingCollaborators
                        ? 'Colaborador (carregando...)'
                        : 'Colaborador da empresa',
                  ),
                ),
                DropdownButtonFormField<String>(
                  initialValue: externalCargoId.isEmpty
                      ? null
                      : externalCargoId,
                  items: _externalCargos
                      .map(
                        (c) => DropdownMenuItem(
                          value: c['id'].toString(),
                          child: Text((c['name'] ?? '-').toString()),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    final selected = _externalCargos.where(
                      (c) => c['id'].toString() == v,
                    );
                    setDialogState(() {
                      externalCargoId = v ?? '';
                      externalCargoName = selected.isEmpty
                          ? ''
                          : (selected.first['name'] ?? '').toString();
                      hierarchy = _inferHierarchyFromCargoName(
                        externalCargoName,
                      );
                    });
                  },
                  decoration: const InputDecoration(labelText: 'Cargo'),
                ),
                DropdownButtonFormField<String>(
                  initialValue: department.isEmpty ? null : department,
                  items: _departments
                      .map(
                        (d) => DropdownMenuItem(
                          value: d['ID'].toString(),
                          child: Text((d['Name'] ?? '-').toString()),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setDialogState(() => department = v ?? ''),
                  decoration: const InputDecoration(
                    labelText: 'Departamento interno',
                  ),
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
    setState(() => _saving = true);
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';
    final res = await http.post(
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
        'external_collaborator_id': int.tryParse(externalCollaboratorId),
        'external_department_id': int.tryParse(externalDepartmentId),
        'external_department_name': externalDepartmentName,
        'external_cargo_id': int.tryParse(externalCargoId),
        'external_cargo_name': externalCargoName,
      }),
    );
    setState(() => _saving = false);
    if (res.statusCode == 201) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final tempPassword = (body['password'] ?? '').toString();
      if (mounted && tempPassword.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Usuário criado. Senha temporária: $tempPassword'),
          ),
        );
      }
    }
    _fetch();
  }

  Future<void> _editUserDialog(Map<String, dynamic> profile) async {
    final fullName = TextEditingController(
      text: (profile['full_name'] ?? '').toString(),
    );
    String hierarchy = (profile['hierarchy'] ?? 'user').toString();
    String department = (profile['department_id'] ?? '').toString();
    String externalDepartmentName = (profile['external_department_name'] ?? '')
        .toString();
    String externalCargoName = (profile['external_cargo_name'] ?? '')
        .toString();
    String externalCargoId = (profile['external_cargo_id'] ?? '').toString();
    if (externalDepartmentName == 'null') {
      externalDepartmentName = '';
    }
    if (externalCargoName == 'null') {
      externalCargoName = '';
    }
    if (externalCargoId == 'null') {
      externalCargoId = '';
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Editar usuário'),
          content: SizedBox(
            width: 560,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: fullName,
                  decoration: const InputDecoration(labelText: 'Nome'),
                ),
                DropdownButtonFormField<String>(
                  initialValue: _getHierarchyLabel(hierarchy),
                  items: [
                    DropdownMenuItem(
                      value: _getHierarchyLabel('owner'),
                      child: const Text('Proprietário'),
                    ),
                    DropdownMenuItem(
                      value: _getHierarchyLabel('gestor'),
                      child: const Text('Gestor'),
                    ),
                    DropdownMenuItem(
                      value: _getHierarchyLabel('user'),
                      child: const Text('Usuário'),
                    ),
                  ],
                  onChanged: null,
                  decoration: const InputDecoration(
                    labelText: 'Hierarquia (automática por cargo)',
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'A hierarquia é definida automaticamente pelo cargo selecionado.',
                  style: TextStyle(fontSize: 12, color: Colors.white54),
                ),
                DropdownButtonFormField<String>(
                  initialValue: externalCargoId.isEmpty
                      ? null
                      : externalCargoId,
                  items: _externalCargos
                      .map(
                        (c) => DropdownMenuItem(
                          value: c['id'].toString(),
                          child: Text((c['name'] ?? '-').toString()),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    final selected = _externalCargos.where(
                      (c) => c['id'].toString() == v,
                    );
                    setDialogState(() {
                      externalCargoId = v ?? '';
                      externalCargoName = selected.isEmpty
                          ? ''
                          : (selected.first['name'] ?? '').toString();
                      hierarchy = _inferHierarchyFromCargoName(
                        externalCargoName,
                      );
                    });
                  },
                  decoration: const InputDecoration(labelText: 'Cargo'),
                ),
                TextFormField(
                  initialValue: externalDepartmentName,
                  onChanged: (v) => externalDepartmentName = v,
                  decoration: const InputDecoration(
                    labelText: 'Departamento empresa (nome)',
                  ),
                ),
                DropdownButtonFormField<String>(
                  initialValue: department.isEmpty ? null : department,
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
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';
    await http.put(
      Uri.parse('${ApiConfig.baseUrl}/api/v1/team/users/${profile['id']}'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'full_name': fullName.text.trim(),
        'hierarchy': hierarchy,
        'department_id': department,
        'external_department_name': externalDepartmentName,
        'external_cargo_id': int.tryParse(externalCargoId),
        'external_cargo_name': externalCargoName,
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

  Future<void> _resetPassword(Map<String, dynamic> profile) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';
    final res = await http.post(
      Uri.parse(
        '${ApiConfig.baseUrl}/api/v1/team/users/${profile['id']}/reset-password',
      ),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (res.statusCode == 200) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final tempPassword = (body['temporary_password'] ?? '').toString();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Senha temporária: $tempPassword')),
        );
      }
      return;
    }
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Falha ao resetar senha')));
    }
  }

  Future<void> _removeUser(Map<String, dynamic> profile) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remover usuário'),
        content: Text('Deseja remover ${profile['email']} do time?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';
    final res = await http.delete(
      Uri.parse('${ApiConfig.baseUrl}/api/v1/team/users/${profile['id']}'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            res.statusCode == 200
                ? 'Usuário removido com sucesso'
                : 'Falha ao remover usuário',
          ),
        ),
      );
    }
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
    if (!mounted) return;
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
                      onPressed: _saving ? null : _createUserDialog,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: const InputDecoration(
                          hintText: 'Buscar por nome ou e-mail...',
                          prefixIcon: Icon(LucideIcons.search, size: 16),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 220,
                      child: DropdownButtonFormField<String>(
                        initialValue: _hierarchyFilter,
                        items: const [
                          DropdownMenuItem(value: 'all', child: Text('Todos')),
                          DropdownMenuItem(
                            value: 'owner',
                            child: Text('Proprietário'),
                          ),
                          DropdownMenuItem(
                            value: 'gestor',
                            child: Text('Gestor'),
                          ),
                          DropdownMenuItem(
                            value: 'user',
                            child: Text('Usuário'),
                          ),
                        ],
                        onChanged: (v) {
                          _hierarchyFilter = v ?? 'all';
                          _applyFilters();
                        },
                        decoration: const InputDecoration(
                          labelText: 'Hierarquia',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
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
                                        'CARGO',
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
                                  itemCount: _filteredProfiles.length,
                                  separatorBuilder: (_, separatorIndex) =>
                                      const Divider(
                                        color: Colors.white12,
                                        height: 1,
                                      ),
                                  itemBuilder: (context, index) {
                                    final profile = _filteredProfiles[index];
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
                                                      .withValues(alpha: 0.2),
                                                  child: Text(
                                                    fullName.isEmpty
                                                        ? '?'
                                                        : fullName
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
                                                  ).withValues(alpha: 0.15),
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
                                                  : ((profile['external_department_name'] ??
                                                            '—')
                                                        .toString()),
                                              style: const TextStyle(
                                                fontSize: 14,
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: Text(
                                              (profile['external_cargo_name'] ??
                                                      '—')
                                                  .toString(),
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
                                                      ? Colors.green.withValues(
                                                          alpha: 0.15,
                                                        )
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
                                              if (v == 'permissions') {
                                                _openPermissions(profile);
                                              } else if (v == 'edit') {
                                                _editUserDialog(profile);
                                              } else if (v == 'reset') {
                                                _resetPassword(profile);
                                              } else if (v == 'toggle') {
                                                _toggleActive(profile);
                                              } else if (v == 'remove') {
                                                _removeUser(profile);
                                              }
                                            },
                                            itemBuilder: (_) => const [
                                              PopupMenuItem(
                                                value: 'edit',
                                                child: Text('Editar usuário'),
                                              ),
                                              PopupMenuItem(
                                                value: 'permissions',
                                                child: Text('Permissões'),
                                              ),
                                              PopupMenuItem(
                                                value: 'reset',
                                                child: Text('Resetar senha'),
                                              ),
                                              PopupMenuItem(
                                                value: 'toggle',
                                                child: Text('Ativar/Desativar'),
                                              ),
                                              PopupMenuItem(
                                                value: 'remove',
                                                child: Text('Remover do time'),
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
}
