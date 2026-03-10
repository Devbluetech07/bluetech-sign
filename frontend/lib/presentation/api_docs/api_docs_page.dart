import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import '../../core/api_config.dart';
import '../../core/app_theme.dart';
import '../widgets/glass_container.dart';

class ApiDocsPage extends StatefulWidget {
  const ApiDocsPage({super.key});

  @override
  State<ApiDocsPage> createState() => _ApiDocsPageState();
}

class _ApiDocsPageState extends State<ApiDocsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  List<Map<String, dynamic>> _keys = [];
  List<Map<String, dynamic>> _hooks = [];
  String? _revealed;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _fetch();
  }

  Future<void> _fetch() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';
    final keyRes = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/api/v1/api-keys/'),
      headers: {'Authorization': 'Bearer $token'},
    );
    final hookRes = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/api/v1/webhooks/'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (keyRes.statusCode == 200) {
      final body = jsonDecode(keyRes.body) as Map<String, dynamic>;
      _keys = (body['keys'] as List<dynamic>? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }
    if (hookRes.statusCode == 200) {
      final body = jsonDecode(hookRes.body) as Map<String, dynamic>;
      _hooks = (body['webhooks'] as List<dynamic>? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }
    if (mounted) setState(() {});
  }

  Future<void> _createKey() async {
    final name = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Criar chave API'),
        content: TextField(
          controller: name,
          decoration: const InputDecoration(labelText: 'Nome da chave'),
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
    );
    if (ok != true) return;
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';
    final res = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/v1/api-keys/'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'name': name.text.trim(),
        'scopes': ['documents:read', 'documents:write'],
      }),
    );
    if (res.statusCode == 201) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      setState(() => _revealed = body['plain_key']?.toString());
      _fetch();
    }
  }

  Future<void> _createWebhook() async {
    final url = TextEditingController();
    final events = <String>{'document.signed'};
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Novo webhook'),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: url,
                  decoration: const InputDecoration(labelText: 'URL'),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children:
                      [
                        'document.created',
                        'document.sent',
                        'document.signed',
                        'document.cancelled',
                      ].map((e) {
                        return FilterChip(
                          selected: events.contains(e),
                          onSelected: (v) => setDialogState(
                            () => v ? events.add(e) : events.remove(e),
                          ),
                          label: Text(e),
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
      Uri.parse('${ApiConfig.baseUrl}/api/v1/webhooks/'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'url': url.text.trim(), 'events': events.toList()}),
    );
    _fetch();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
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
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'API & Webhooks',
                    style: TextStyle(
                      fontSize: 26,
                      fontFamily: 'Orbitron',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TabBar(
                  controller: _tab,
                  tabs: const [
                    Tab(text: 'Documentação'),
                    Tab(text: 'Chaves de API'),
                    Tab(text: 'Webhooks'),
                  ],
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: TabBarView(
                    controller: _tab,
                    children: [
                      GlassContainer(
                        borderColor: Colors.white12,
                        padding: const EdgeInsets.all(16),
                        child: ListView(
                          children: [
                            Row(
                              children: [
                                Text('Base URL: ${ApiConfig.baseUrl}/api/v1'),
                                const SizedBox(width: 8),
                                OutlinedButton(
                                  onPressed: () => Clipboard.setData(
                                    ClipboardData(
                                      text: '${ApiConfig.baseUrl}/api/v1',
                                    ),
                                  ),
                                  child: const Text('Copiar'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Endpoints principais',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'POST /documents/upload\nGET /documents/\nGET /documents/:id\nPOST /documents/:id/send\nPOST /documents/:id/cancel\nPOST /documents/:id/resend',
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Exemplo cURL',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            SelectableText(
                              'curl -X GET "${ApiConfig.baseUrl}/api/v1/documents/" -H "Authorization: Bearer <token>"',
                            ),
                          ],
                        ),
                      ),
                      GlassContainer(
                        borderColor: Colors.white12,
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                const Text(
                                  'Chaves de API',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const Spacer(),
                                ElevatedButton(
                                  onPressed: _createKey,
                                  child: const Text('Criar chave'),
                                ),
                              ],
                            ),
                            if (_revealed != null)
                              Container(
                                margin: const EdgeInsets.only(top: 8),
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.orangeAccent,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: SelectableText(
                                        'Revelada uma única vez: $_revealed',
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () => Clipboard.setData(
                                        ClipboardData(text: _revealed!),
                                      ),
                                      child: const Text('Copiar'),
                                    ),
                                  ],
                                ),
                              ),
                            const SizedBox(height: 10),
                            Expanded(
                              child: ListView.builder(
                                itemCount: _keys.length,
                                itemBuilder: (_, i) {
                                  final k = _keys[i];
                                  return ListTile(
                                    title: Text(k['Name']?.toString() ?? '-'),
                                    subtitle: Text(
                                      'Prefixo: ${k['Prefix'] ?? '-'} • Active: ${k['Active']}',
                                    ),
                                    trailing: IconButton(
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        color: Colors.redAccent,
                                      ),
                                      onPressed: () async {
                                        final prefs =
                                            await SharedPreferences.getInstance();
                                        final token =
                                            prefs.getString('token') ?? '';
                                        await http.delete(
                                          Uri.parse(
                                            '${ApiConfig.baseUrl}/api/v1/api-keys/${k['ID']}',
                                          ),
                                          headers: {
                                            'Authorization': 'Bearer $token',
                                          },
                                        );
                                        _fetch();
                                      },
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      GlassContainer(
                        borderColor: Colors.white12,
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                const Text(
                                  'Webhooks',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const Spacer(),
                                ElevatedButton(
                                  onPressed: _createWebhook,
                                  child: const Text('Novo webhook'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Expanded(
                              child: ListView.builder(
                                itemCount: _hooks.length,
                                itemBuilder: (_, i) {
                                  final h = _hooks[i];
                                  return ListTile(
                                    title: Text(h['URL']?.toString() ?? '-'),
                                    subtitle: Text(
                                      'Eventos: ${h['Events'] ?? '-'}',
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Switch(
                                          value: h['Active'] == true,
                                          onChanged: (_) async {
                                            final prefs =
                                                await SharedPreferences.getInstance();
                                            final token =
                                                prefs.getString('token') ?? '';
                                            await http.put(
                                              Uri.parse(
                                                '${ApiConfig.baseUrl}/api/v1/webhooks/${h['ID']}/toggle',
                                              ),
                                              headers: {
                                                'Authorization':
                                                    'Bearer $token',
                                              },
                                            );
                                            _fetch();
                                          },
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.delete_outline,
                                            color: Colors.redAccent,
                                          ),
                                          onPressed: () async {
                                            final prefs =
                                                await SharedPreferences.getInstance();
                                            final token =
                                                prefs.getString('token') ?? '';
                                            await http.delete(
                                              Uri.parse(
                                                '${ApiConfig.baseUrl}/api/v1/webhooks/${h['ID']}',
                                              ),
                                              headers: {
                                                'Authorization':
                                                    'Bearer $token',
                                              },
                                            );
                                            _fetch();
                                          },
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
                    ],
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
