import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../widgets/glass_container.dart';
import 'package:lucide_icons/lucide_icons.dart';

class FoldersPage extends StatefulWidget {
  const FoldersPage({super.key});

  @override
  State<FoldersPage> createState() => _FoldersPageState();
}

class _FoldersPageState extends State<FoldersPage> {
  final List<Map<String, dynamic>> _folders = [
    {'name': 'Contratos', 'color': const Color(0xFF6366F1), 'count': 12},
    {'name': 'Financeiro', 'color': const Color(0xFF10B981), 'count': 8},
    {'name': 'RH', 'color': const Color(0xFFEC4899), 'count': 5},
  ];
  String? _selectedFolder;

  final List<Map<String, dynamic>> _documents = [
    {'name': 'Contrato A', 'folder': 'Contratos'},
    {'name': 'Contrato B', 'folder': 'Contratos'},
    {'name': 'NF Março', 'folder': 'Financeiro'},
  ];

  void _createFolder() {
    final name = TextEditingController();
    Color selected = const Color(0xFF14b8a6);
    final palette = [
      const Color(0xFF6366F1),
      const Color(0xFFEC4899),
      const Color(0xFFF59E0B),
      const Color(0xFF10B981),
      const Color(0xFF3B82F6),
      const Color(0xFF8B5CF6),
      const Color(0xFFEF4444),
      const Color(0xFF06B6D4),
    ];
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Nova pasta'),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Nome'),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: palette.map((c) {
                    return InkWell(
                      onTap: () => setDialogState(() => selected = c),
                      child: Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: selected == c
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
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(
                  () => _folders.add({
                    'name': name.text.trim(),
                    'color': selected,
                    'count': 0,
                  }),
                );
                Navigator.pop(context);
              },
              child: const Text('Criar'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final docs = _selectedFolder == null
        ? []
        : _documents.where((d) => d['folder'] == _selectedFolder).toList();
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
                      'Pastas',
                      style: TextStyle(
                        fontSize: 26,
                        fontFamily: 'Orbitron',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    ElevatedButton.icon(
                      onPressed: _createFolder,
                      icon: const Icon(LucideIcons.plus, size: 16),
                      label: const Text('Nova pasta'),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: GridView.builder(
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                childAspectRatio: 1.6,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                              ),
                          itemCount: _folders.length,
                          itemBuilder: (_, i) {
                            final f = _folders[i];
                            return InkWell(
                              onTap: () => setState(
                                () => _selectedFolder = f['name'].toString(),
                              ),
                              child: GlassContainer(
                                borderColor: _selectedFolder == f['name']
                                    ? AppTheme.tealNeon
                                    : Colors.white12,
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      LucideIcons.folderOpen,
                                      color: f['color'] as Color,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      (f['name'] ?? '-').toString(),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      '${f['count']} documento(s)',
                                      style: const TextStyle(
                                        color: Colors.white60,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GlassContainer(
                          borderColor: Colors.white12,
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _selectedFolder == null
                                    ? 'Selecione uma pasta'
                                    : 'Documentos em $_selectedFolder',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Expanded(
                                child: ListView.builder(
                                  itemCount: docs.length,
                                  itemBuilder: (_, i) => ListTile(
                                    leading: const Icon(
                                      LucideIcons.fileText,
                                      size: 16,
                                    ),
                                    title: Text(docs[i]['name'].toString()),
                                  ),
                                ),
                              ),
                            ],
                          ),
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
