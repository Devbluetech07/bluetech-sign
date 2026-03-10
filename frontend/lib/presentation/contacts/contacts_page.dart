import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/api_config.dart';
import '../../core/app_theme.dart';
import '../widgets/glass_container.dart';

class ContactsPage extends StatefulWidget {
  const ContactsPage({super.key});

  @override
  State<ContactsPage> createState() => _ContactsPageState();
}

class _ContactsPageState extends State<ContactsPage> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _contacts = [];
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
      Uri.parse('${ApiConfig.baseUrl}/api/v1/contacts/'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (res.statusCode == 200) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      setState(() {
        _contacts = (body['contacts'] as List<dynamic>? ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _loading = false;
      });
      return;
    }
    setState(() => _loading = false);
  }

  List<Map<String, dynamic>> get _filtered {
    final q = _searchController.text.toLowerCase().trim();
    if (q.isEmpty) return _contacts;
    return _contacts
        .where(
          (c) =>
              (c['name'] ?? '').toString().toLowerCase().contains(q) ||
              (c['email'] ?? '').toString().toLowerCase().contains(q),
        )
        .toList();
  }

  Future<void> _openCreateDialog() async {
    final name = TextEditingController();
    final email = TextEditingController();
    final phone = TextEditingController();
    String role = 'Signatario';
    String auth = 'email_token';
    final vals = <String>{};

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Novo contato'),
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
                      controller: email,
                      decoration: const InputDecoration(labelText: 'E-mail *'),
                    ),
                    TextField(
                      controller: phone,
                      decoration: const InputDecoration(labelText: 'Telefone'),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: role,
                      items: const [
                        DropdownMenuItem(
                          value: 'Signatario',
                          child: Text('Signatário'),
                        ),
                        DropdownMenuItem(
                          value: 'Testemunha',
                          child: Text('Testemunha'),
                        ),
                        DropdownMenuItem(
                          value: 'Aprovador',
                          child: Text('Aprovador'),
                        ),
                      ],
                      onChanged: (v) =>
                          setDialogState(() => role = v ?? 'Signatario'),
                      decoration: const InputDecoration(
                        labelText: 'Papel padrão',
                      ),
                    ),
                    DropdownButtonFormField<String>(
                      value: auth,
                      items: const [
                        DropdownMenuItem(
                          value: 'email_token',
                          child: Text('Token por e-mail'),
                        ),
                        DropdownMenuItem(
                          value: 'biometria_facial',
                          child: Text('Biometria facial'),
                        ),
                      ],
                      onChanged: (v) =>
                          setDialogState(() => auth = v ?? 'email_token'),
                      decoration: const InputDecoration(
                        labelText: 'Autenticação padrão',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        FilterChip(
                          selected: vals.contains('selfie'),
                          onSelected: (v) => setDialogState(
                            () =>
                                v ? vals.add('selfie') : vals.remove('selfie'),
                          ),
                          label: const Text('Selfie'),
                        ),
                        FilterChip(
                          selected: vals.contains('doc_photo'),
                          onSelected: (v) => setDialogState(
                            () => v
                                ? vals.add('doc_photo')
                                : vals.remove('doc_photo'),
                          ),
                          label: const Text('Foto documento'),
                        ),
                        FilterChip(
                          selected: vals.contains('selfie_with_document'),
                          onSelected: (v) => setDialogState(
                            () => v
                                ? vals.add('selfie_with_document')
                                : vals.remove('selfie_with_document'),
                          ),
                          label: const Text('Selfie com documento'),
                        ),
                      ],
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
            );
          },
        );
      },
    );

    if (ok != true) return;
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';
    await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/v1/contacts/'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'name': name.text.trim(),
        'email': email.text.trim(),
        'phone': phone.text.trim(),
        'default_role': role,
        'default_auth_method': auth,
        'default_validations': vals.toList(),
      }),
    );
    _fetch();
  }

  String _initials(String value) {
    if (value.trim().isEmpty) return '?';
    final parts = value.trim().split(' ');
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
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
                      'Contatos',
                      style: TextStyle(
                        fontSize: 26,
                        fontFamily: 'Orbitron',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    SizedBox(
                      width: 320,
                      child: TextField(
                        controller: _searchController,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          prefixIcon: Icon(LucideIcons.search),
                          hintText: 'Buscar nome/email',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      onPressed: _openCreateDialog,
                      icon: const Icon(LucideIcons.plus, size: 16),
                      label: const Text('Novo contato'),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: GlassContainer(
                    borderColor: Colors.white12,
                    padding: const EdgeInsets.all(12),
                    child: _loading
                        ? const Center(child: CircularProgressIndicator())
                        : ListView.separated(
                            itemCount: _filtered.length,
                            separatorBuilder: (_, __) =>
                                const Divider(color: Colors.white10),
                            itemBuilder: (context, index) {
                              final c = _filtered[index];
                              final docs = c['documents_count'] ?? 0;
                              final vals =
                                  (c['default_validations'] as List<dynamic>? ??
                                          [])
                                      .where(
                                        (e) => e.toString().trim().isNotEmpty,
                                      )
                                      .join(', ');
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: AppTheme.tealNeon
                                      .withOpacity(0.2),
                                  child: Text(
                                    _initials((c['name'] ?? '').toString()),
                                    style: const TextStyle(
                                      color: AppTheme.tealNeon,
                                    ),
                                  ),
                                ),
                                title: Text((c['name'] ?? '-').toString()),
                                subtitle: Text(
                                  '${c['email'] ?? '-'} • ${c['phone'] ?? '-'}',
                                ),
                                trailing: SizedBox(
                                  width: 280,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        '$docs documento(s)',
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12,
                                        ),
                                      ),
                                      Text(
                                        'Padrão: ${c['default_role'] ?? '-'} | ${c['default_auth_method'] ?? '-'}',
                                        style: const TextStyle(
                                          color: Colors.white60,
                                          fontSize: 11,
                                        ),
                                      ),
                                      if (vals.isNotEmpty)
                                        Text(
                                          'Validações: $vals',
                                          style: const TextStyle(
                                            color: Colors.white54,
                                            fontSize: 11,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
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
