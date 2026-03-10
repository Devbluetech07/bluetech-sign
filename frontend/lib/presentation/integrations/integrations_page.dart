import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/api_config.dart';
import '../../core/app_theme.dart';
import '../widgets/glass_container.dart';

class IntegrationsPage extends StatefulWidget {
  const IntegrationsPage({super.key});

  @override
  State<IntegrationsPage> createState() => _IntegrationsPageState();
}

class _IntegrationsPageState extends State<IntegrationsPage> {
  List<Map<String, dynamic>> _docs = [];
  bool _loading = true;
  String _status = 'all';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/api/v1/integrations/documents?status=$_status&search=${Uri.encodeQueryComponent(_searchController.text)}',
    );
    final res = await http.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );
    if (res.statusCode == 200) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      setState(() {
        _docs = (body['documents'] as List<dynamic>? ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _loading = false;
      });
      return;
    }
    setState(() => _loading = false);
  }

  Future<void> _showDetails(Map<String, dynamic> doc) async {
    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) {
          final signers = (doc['Signers'] as List<dynamic>? ?? [])
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
          final nameCtrl = TextEditingController();
          final emailCtrl = TextEditingController();
          final roleCtrl = TextEditingController(text: 'Signatario');
          return AlertDialog(
            title: Text('Integração • ${doc['Name'] ?? '-'}'),
            content: SizedBox(
              width: 760,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Ref externa: ${doc['ExternalRef'] ?? '-'}'),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Origem: ${doc['SourceSystem'] ?? 'api'}'),
                  ),
                  const SizedBox(height: 8),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Signatários'),
                  ),
                  ...signers.map(
                    (s) => ListTile(
                      dense: true,
                      title: Text((s['Name'] ?? '-').toString()),
                      subtitle: Text((s['Email'] ?? '-').toString()),
                    ),
                  ),
                  const Divider(),
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nome do signatário',
                    ),
                  ),
                  TextField(
                    controller: emailCtrl,
                    decoration: const InputDecoration(
                      labelText: 'E-mail do signatário',
                    ),
                  ),
                  TextField(
                    controller: roleCtrl,
                    decoration: const InputDecoration(labelText: 'Papel'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Fechar'),
              ),
              OutlinedButton(
                onPressed: () async {
                  final prefs = await SharedPreferences.getInstance();
                  final token = prefs.getString('token') ?? '';
                  await http.post(
                    Uri.parse(
                      '${ApiConfig.baseUrl}/api/v1/integrations/documents/${doc['ID']}/signers',
                    ),
                    headers: {
                      'Authorization': 'Bearer $token',
                      'Content-Type': 'application/json',
                    },
                    body: jsonEncode({
                      'name': nameCtrl.text.trim(),
                      'email': emailCtrl.text.trim(),
                      'role': roleCtrl.text.trim(),
                    }),
                  );
                  if (!mounted) return;
                  Navigator.pop(context);
                  _fetch();
                },
                child: const Text('Adicionar signatário'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final prefs = await SharedPreferences.getInstance();
                  final token = prefs.getString('token') ?? '';
                  await http.post(
                    Uri.parse(
                      '${ApiConfig.baseUrl}/api/v1/integrations/documents/${doc['ID']}/send',
                    ),
                    headers: {'Authorization': 'Bearer $token'},
                  );
                  if (!mounted) return;
                  Navigator.pop(context);
                  _fetch();
                },
                child: const Text('Enviar para assinatura'),
              ),
            ],
          );
        },
      ),
    );
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
                      'Integrações',
                      style: TextStyle(
                        fontSize: 26,
                        fontFamily: 'Orbitron',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    SizedBox(
                      width: 280,
                      child: TextField(
                        controller: _searchController,
                        decoration: const InputDecoration(
                          prefixIcon: Icon(LucideIcons.search),
                          hintText: 'Buscar',
                        ),
                        onSubmitted: (_) => _fetch(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    DropdownButton<String>(
                      value: _status,
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('Todos')),
                        DropdownMenuItem(
                          value: 'draft',
                          child: Text('Aguardando config'),
                        ),
                        DropdownMenuItem(
                          value: 'in_progress',
                          child: Text('Em assinatura'),
                        ),
                        DropdownMenuItem(
                          value: 'completed',
                          child: Text('Concluídos'),
                        ),
                      ],
                      onChanged: (v) {
                        setState(() => _status = v ?? 'all');
                        _fetch();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: GlassContainer(
                    borderColor: Colors.white12,
                    padding: const EdgeInsets.all(10),
                    child: _loading
                        ? const Center(child: CircularProgressIndicator())
                        : ListView.builder(
                            itemCount: _docs.length,
                            itemBuilder: (_, i) {
                              final d = _docs[i];
                              final signers =
                                  (d['Signers'] as List<dynamic>? ?? []).length;
                              return ListTile(
                                leading: const Icon(LucideIcons.unplug),
                                title: Text((d['Name'] ?? '-').toString()),
                                subtitle: Text(
                                  'Ref: ${d['ExternalRef'] ?? '-'} • Origem: ${d['SourceSystem'] ?? 'api'}',
                                ),
                                trailing: Text(
                                  '${d['Status'] ?? '-'} • $signers signatário(s)',
                                ),
                                onTap: () => _showDetails(d),
                              );
                            },
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
