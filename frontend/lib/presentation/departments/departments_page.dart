import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/api_config.dart';
import '../../core/app_theme.dart';
import '../widgets/glass_container.dart';

class DepartmentsPage extends StatefulWidget {
  const DepartmentsPage({super.key});

  @override
  State<DepartmentsPage> createState() => _DepartmentsPageState();
}

class _DepartmentsPageState extends State<DepartmentsPage> {
  List<Map<String, dynamic>> _deps = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';
    final res = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/api/v1/departments/'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (res.statusCode == 200) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      setState(() {
        _deps = (body['departments'] as List<dynamic>? ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _loading = false;
      });
      return;
    }
    setState(() => _loading = false);
  }

  Future<void> _openDialog({Map<String, dynamic>? dep}) async {
    final name = TextEditingController(text: dep?['Name']?.toString() ?? '');
    final desc = TextEditingController(
      text: dep?['Description']?.toString() ?? '',
    );
    String color = dep?['Color']?.toString() ?? '#14b8a6';
    final palette = [
      '#6366f1',
      '#ec4899',
      '#f59e0b',
      '#10b981',
      '#3b82f6',
      '#8b5cf6',
      '#ef4444',
      '#06b6d4',
    ];

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            dep == null ? 'Novo Departamento' : 'Editar Departamento',
          ),
          content: SizedBox(
            width: 540,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Nome *'),
                ),
                TextField(
                  controller: desc,
                  decoration: const InputDecoration(labelText: 'Descrição'),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: palette.map((c) {
                    return InkWell(
                      onTap: () => setDialogState(() => color = c),
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: Color(
                            int.parse(c.substring(1), radix: 16) + 0xFF000000,
                          ),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: color == c
                                ? Colors.white
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
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
    if (dep == null) {
      await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/v1/departments/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'name': name.text.trim(),
          'description': desc.text.trim(),
          'color': color,
        }),
      );
    } else {
      await http.put(
        Uri.parse('${ApiConfig.baseUrl}/api/v1/departments/${dep['ID']}'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'name': name.text.trim(),
          'description': desc.text.trim(),
          'color': color,
        }),
      );
    }
    _fetch();
  }

  Future<void> _delete(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';
    await http.delete(
      Uri.parse('${ApiConfig.baseUrl}/api/v1/departments/$id'),
      headers: {'Authorization': 'Bearer $token'},
    );
    _fetch();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  children: [
                    const Text(
                      'Departamentos',
                      style: TextStyle(
                        fontSize: 26,
                        fontFamily: 'Orbitron',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    ElevatedButton.icon(
                      onPressed: () => _openDialog(),
                      icon: const Icon(LucideIcons.plus, size: 16),
                      label: const Text('Novo departamento'),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : GridView.builder(
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                childAspectRatio: 1.6,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                              ),
                          itemCount: _deps.length,
                          itemBuilder: (context, i) {
                            final d = _deps[i];
                            final colorHex = (d['Color'] ?? '#14b8a6')
                                .toString();
                            final color = Color(
                              int.parse(colorHex.substring(1), radix: 16) +
                                  0xFF000000,
                            );
                            return GlassContainer(
                              borderColor: Colors.white12,
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(LucideIcons.building2, color: color),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          (d['Name'] ?? '-').toString(),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      PopupMenuButton<String>(
                                        onSelected: (v) {
                                          if (v == 'edit') _openDialog(dep: d);
                                          if (v == 'delete')
                                            _delete(d['ID'].toString());
                                        },
                                        itemBuilder: (_) => const [
                                          PopupMenuItem(
                                            value: 'edit',
                                            child: Text('Editar'),
                                          ),
                                          PopupMenuItem(
                                            value: 'delete',
                                            child: Text('Excluir'),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    (d['Description'] ?? 'Sem descrição')
                                        .toString(),
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
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
      ),
    );
  }
}
