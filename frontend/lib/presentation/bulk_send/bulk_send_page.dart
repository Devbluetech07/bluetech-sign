import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/api_config.dart';
import '../../core/app_theme.dart';
import '../widgets/glass_container.dart';

class BulkSendPage extends StatefulWidget {
  const BulkSendPage({super.key});

  @override
  State<BulkSendPage> createState() => _BulkSendPageState();
}

class _BulkSendPageState extends State<BulkSendPage> {
  List<Map<String, dynamic>> _templates = [];
  Map<String, dynamic>? _selectedTemplate;
  List<Map<String, String>> _rows = [];
  final TextEditingController _messageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchTemplates();
  }

  Future<void> _fetchTemplates() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';
    final res = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/api/v1/templates/'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (res.statusCode == 200) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      setState(() {
        _templates = (body['templates'] as List<dynamic>? ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      });
    }
  }

  Future<void> _uploadCsv() async {
    final pick = await FilePicker.platform.pickFiles(
      withData: true,
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );
    if (pick == null || pick.files.isEmpty || pick.files.first.bytes == null)
      return;
    final text = utf8.decode(pick.files.first.bytes!);
    final lines = text
        .split(RegExp(r'\r?\n'))
        .where((e) => e.trim().isNotEmpty)
        .toList();
    if (lines.length <= 1) return;
    final parsed = <Map<String, String>>[];
    for (int i = 1; i < lines.length; i++) {
      final cols = lines[i].split(',');
      if (cols.isEmpty) continue;
      parsed.add({
        'name': cols.isNotEmpty ? cols[0].trim() : '',
        'email': cols.length > 1 ? cols[1].trim() : '',
        'phone': cols.length > 2 ? cols[2].trim() : '',
      });
    }
    setState(() => _rows = parsed);
  }

  Future<void> _sendBulk() async {
    if (_selectedTemplate == null || _rows.isEmpty) return;
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Envio em massa simulado: ${_rows.length} destinatário(s) com modelo "${_selectedTemplate!['Name'] ?? '-'}"',
        ),
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Envio em massa',
                  style: TextStyle(
                    fontSize: 26,
                    fontFamily: 'Orbitron',
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 14),
                GlassContainer(
                  borderColor: Colors.white12,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '1. Selecionar modelo',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: _selectedTemplate?['ID']?.toString(),
                        items: _templates
                            .map(
                              (t) => DropdownMenuItem<String>(
                                value: t['ID'].toString(),
                                child: Text((t['Name'] ?? '-').toString()),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => setState(
                          () => _selectedTemplate = _templates.firstWhere(
                            (e) => e['ID'].toString() == v,
                          ),
                        ),
                        decoration: const InputDecoration(labelText: 'Modelo'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                GlassContainer(
                  borderColor: Colors.white12,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '2. Importar lista de signatários',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: _uploadCsv,
                        child: const Text('Fazer upload CSV'),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${_rows.length} linha(s) carregadas',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: GlassContainer(
                    borderColor: Colors.white12,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '3. Confirmar e enviar',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _messageController,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Mensagem personalizada',
                          ),
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: ListView.builder(
                            itemCount: _rows.length,
                            itemBuilder: (_, i) => ListTile(
                              title: Text(_rows[i]['name'] ?? '-'),
                              subtitle: Text(
                                '${_rows[i]['email'] ?? '-'} • ${_rows[i]['phone'] ?? '-'}',
                              ),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _sendBulk,
                            child: const Text('Enviar documentos'),
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
