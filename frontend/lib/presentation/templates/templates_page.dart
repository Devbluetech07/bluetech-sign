import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/api_config.dart';
import '../../core/app_theme.dart';
import '../widgets/glass_container.dart';

class TemplatesPage extends StatefulWidget {
  const TemplatesPage({super.key});

  @override
  State<TemplatesPage> createState() => _TemplatesPageState();
}

class _TemplatesPageState extends State<TemplatesPage> {
  List<Map<String, dynamic>> _items = [];
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
      Uri.parse('${ApiConfig.baseUrl}/api/v1/templates/'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (res.statusCode == 200) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      setState(() {
        _items = (body['templates'] as List<dynamic>? ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _loading = false;
      });
      return;
    }
    setState(() => _loading = false);
  }

  Future<void> _createTemplate() async {
    final name = TextEditingController();
    final desc = TextEditingController();
    final category = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Novo Modelo'),
        content: SizedBox(
          width: 520,
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
              TextField(
                controller: category,
                decoration: const InputDecoration(labelText: 'Categoria'),
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
    );
    if (ok != true) return;
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';
    await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/v1/templates/'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'name': name.text.trim(),
        'description': desc.text.trim(),
        'category': category.text.trim(),
        'content': '',
      }),
    );
    _fetch();
  }

  Future<void> _editContent(Map<String, dynamic> item) async {
    final content = TextEditingController(
      text: (item['Content'] ?? '').toString(),
    );
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(item['Name']?.toString() ?? 'Modelo'),
        content: SizedBox(
          width: 900,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: const [
                  Chip(label: Text('Título')),
                  SizedBox(width: 6),
                  Chip(label: Text('Subtítulo')),
                  SizedBox(width: 6),
                  Chip(label: Text('Lista')),
                  SizedBox(width: 6),
                  Chip(label: Text('{{Campo}}')),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 360,
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white24),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Center(
                          child: Text('Preview PDF (lado esquerdo)'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: content,
                        maxLines: null,
                        expands: true,
                        decoration: const InputDecoration(
                          hintText: 'Escreva o conteúdo markdown do modelo...',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
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
            child: const Text('Salvar conteúdo'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';
    await http.put(
      Uri.parse('${ApiConfig.baseUrl}/api/v1/templates/${item['ID']}'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'content': content.text}),
    );
    _fetch();
  }

  Future<void> _uploadBaseFile(Map<String, dynamic> item) async {
    final pick = await FilePicker.platform.pickFiles(withData: true);
    if (pick == null || pick.files.isEmpty || pick.files.first.bytes == null)
      return;
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';
    final file = pick.files.first;
    final req = http.MultipartRequest(
      'POST',
      Uri.parse('${ApiConfig.baseUrl}/api/v1/templates/${item['ID']}/upload'),
    );
    req.headers['Authorization'] = 'Bearer $token';
    req.files.add(
      http.MultipartFile.fromBytes('file', file.bytes!, filename: file.name),
    );
    await req.send();
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
                      'Modelos',
                      style: TextStyle(
                        fontSize: 26,
                        fontFamily: 'Orbitron',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    ElevatedButton.icon(
                      onPressed: _createTemplate,
                      icon: const Icon(LucideIcons.plus, size: 16),
                      label: const Text('Novo modelo'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : GridView.builder(
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                childAspectRatio: 1.65,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                              ),
                          itemCount: _items.length,
                          itemBuilder: (context, i) {
                            final item = _items[i];
                            return GlassContainer(
                              padding: const EdgeInsets.all(12),
                              borderColor: Colors.white12,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(
                                        LucideIcons.folderOpen,
                                        color: AppTheme.tealNeon,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          (item['Name'] ?? '-').toString(),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      PopupMenuButton<String>(
                                        onSelected: (v) async {
                                          if (v == 'edit') _editContent(item);
                                          if (v == 'upload')
                                            _uploadBaseFile(item);
                                          if (v == 'duplicate') {
                                            final prefs =
                                                await SharedPreferences.getInstance();
                                            final token =
                                                prefs.getString('token') ?? '';
                                            await http.post(
                                              Uri.parse(
                                                '${ApiConfig.baseUrl}/api/v1/templates/${item['ID']}/duplicate',
                                              ),
                                              headers: {
                                                'Authorization':
                                                    'Bearer $token',
                                              },
                                            );
                                            _fetch();
                                          }
                                          if (v == 'delete') {
                                            final prefs =
                                                await SharedPreferences.getInstance();
                                            final token =
                                                prefs.getString('token') ?? '';
                                            await http.delete(
                                              Uri.parse(
                                                '${ApiConfig.baseUrl}/api/v1/templates/${item['ID']}',
                                              ),
                                              headers: {
                                                'Authorization':
                                                    'Bearer $token',
                                              },
                                            );
                                            _fetch();
                                          }
                                        },
                                        itemBuilder: (_) => const [
                                          PopupMenuItem(
                                            value: 'edit',
                                            child: Text('Editar conteúdo'),
                                          ),
                                          PopupMenuItem(
                                            value: 'upload',
                                            child: Text(
                                              'Anexar/Trocar documento',
                                            ),
                                          ),
                                          PopupMenuItem(
                                            value: 'duplicate',
                                            child: Text('Duplicar'),
                                          ),
                                          PopupMenuItem(
                                            value: 'delete',
                                            child: Text('Excluir'),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    (item['Description'] ?? '').toString(),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    (item['Category'] ?? 'Sem categoria')
                                        .toString(),
                                    style: const TextStyle(
                                      color: Colors.white60,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    (item['FileName'] ??
                                            'Documento não anexado')
                                        .toString(),
                                    style: const TextStyle(
                                      color: AppTheme.goldSoft,
                                      fontSize: 11,
                                    ),
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
