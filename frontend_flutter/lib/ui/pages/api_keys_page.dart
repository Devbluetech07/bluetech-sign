import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:frontend_flutter/core/api_client.dart';

class ApiKeysPage extends StatefulWidget {
  const ApiKeysPage({super.key});

  @override
  State<ApiKeysPage> createState() => _ApiKeysPageState();
}

class _ApiKeysPageState extends State<ApiKeysPage> {
  List<dynamic> _keys = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchKeys();
  }

  Future<void> _fetchKeys() async {
    setState(() => _isLoading = true);
    try {
      final res = await apiClient.get('/keys');
      if (res.statusCode == 200) {
        setState(() => _keys = jsonDecode(res.body));
      }
    } catch (e) {
      // error
    }
    setState(() => _isLoading = false);
  }

  Future<void> _createKey(String name) async {
    try {
      final res = await apiClient.post('/keys', {'name': name});
      if (res.statusCode == 201) {
        final newKey = jsonDecode(res.body);
        
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (c) => AlertDialog(
              title: const Text('Chave Criada com Sucesso'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   const Text('Esta é sua nova chave secreta (salve-a agora):', style: TextStyle(fontWeight: FontWeight.bold)),
                   const SizedBox(height: 16),
                   SelectableText(newKey['key'], style: TextStyle(color: Theme.of(context).colorScheme.secondary, fontSize: 18)),
                ]
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(c);
                    _fetchKeys();
                  },
                  child: const Text('Entendi, Salvei a Chave'),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      // error
    }
  }

  Future<void> _toggleKey(String id, bool val) async {
    try {
      final res = await apiClient.patch('/keys/$id', {'is_active': val});
      if (res.statusCode == 200) {
        _fetchKeys();
      }
    } catch (e) {
      // error
    }
  }

  Future<void> _deleteKey(String id) async {
    try {
      final res = await apiClient.delete('/keys/$id');
      if (res.statusCode == 204) {
        _fetchKeys();
      }
    } catch (e) {
      // error
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Chaves de API', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                  Text('Gerencie as chaves de acesso para integração via API REST.', style: TextStyle(color: Colors.grey)),
                ],
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Nova Chave'),
                onPressed: () {
                   String name = '';
                   showDialog(
                     context: context,
                     builder: (c) => AlertDialog(
                       title: const Text('Nome da Chave'),
                       content: TextField(
                         autofocus: true,
                         onChanged: (v) => name = v,
                         decoration: const InputDecoration(hintText: 'ex: Produção, Homologação'),
                       ),
                       actions: [
                         TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancelar')),
                         ElevatedButton(
                           onPressed: () {
                             if (name.isNotEmpty) {
                               Navigator.pop(c);
                               _createKey(name);
                             }
                           },
                           child: const Text('Criar'),
                         )
                       ],
                     ),
                   );
                },
              ),
            ],
          ),
          const SizedBox(height: 32),
          Expanded(
            child: ListView.builder(
              itemCount: _keys.length,
              itemBuilder: (context, i) {
                final key = _keys[i];
                return Card(
                  color: Theme.of(context).colorScheme.surface,
                  margin: const EdgeInsets.only(bottom: 16),
                  shape: RoundedRectangleBorder(
                    side: BorderSide(color: Colors.white12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Row(
                      children: [
                        Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(key['name'] ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            Text('${key['key_prefix']}****************', style: const TextStyle(fontFamily: 'monospace', color: Colors.grey)),
                            const SizedBox(height: 8),
                            Text('Criado em: ${key['created_at']}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        )),
                        Switch(
                          value: key['is_active'] ?? false,
                          onChanged: (val) => _toggleKey(key['id'], val),
                          activeColor: Theme.of(context).colorScheme.primary,
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _deleteKey(key['id']),
                        )
                      ],
                    ),
                  ),
                );
              },
            ),
          )
        ],
      ),
    );
  }
}
