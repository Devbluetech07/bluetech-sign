import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../core/api_config.dart';
import '../../core/app_theme.dart';
import '../widgets/glass_container.dart';

class DocumentsPage extends StatefulWidget {
  const DocumentsPage({super.key});

  @override
  State<DocumentsPage> createState() => _DocumentsPageState();
}

class _DocumentsPageState extends State<DocumentsPage> {
  final TextEditingController _searchController = TextEditingController();
  String _statusFilter = 'all';
  String _sortBy = 'date_desc';
  bool _isGridView = false;
  bool _isLoading = true;
  List<Map<String, dynamic>> _documents = [];
  List<Map<String, dynamic>> _filteredDocs = [];
  List<String> _selectedDocs = [];

  final List<Map<String, String>> _statusFilters = const [
    {'label': 'Todos', 'value': 'all'},
    {'label': 'Rascunho', 'value': 'draft'},
    {'label': 'Aguardando', 'value': 'in_progress'},
    {'label': 'Assinados', 'value': 'completed'},
    {'label': 'Cancelados', 'value': 'cancelled'},
    {'label': 'Expirados', 'value': 'expired'},
  ];

  @override
  void initState() {
    super.initState();
    _fetchDocuments();
    _searchController.addListener(_applyFilters);
  }

  Future<void> _fetchDocuments() async {
    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';

    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/v1/documents/'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final docs = (body['documents'] as List<dynamic>? ?? <dynamic>[])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        setState(() {
          _documents = docs;
          _applyFilters();
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao carregar documentos')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  int _statusCount(String status) {
    if (status == 'all') return _documents.length;
    return _documents.where((d) => (d['Status'] ?? '') == status).length;
  }

  DateTime _parseDate(Map<String, dynamic> doc) {
    final raw = (doc['CreatedAt'] ?? doc['UpdatedAt'] ?? '').toString();
    return DateTime.tryParse(raw) ?? DateTime.fromMillisecondsSinceEpoch(0);
  }

  String _shortDate(Map<String, dynamic> doc) {
    final date = _parseDate(doc);
    if (date.year < 2000) return '-';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  List<dynamic> _signersOf(Map<String, dynamic> doc) =>
      (doc['Signers'] as List<dynamic>? ?? <dynamic>[]);

  void _applyFilters() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredDocs = _documents.where((doc) {
        final name = (doc['Name'] ?? '').toString().toLowerCase();
        final signerMatch = _signersOf(doc).any((s) {
          final signer = Map<String, dynamic>.from(s as Map);
          return (signer['Name'] ?? '').toString().toLowerCase().contains(
                query,
              ) ||
              (signer['Email'] ?? '').toString().toLowerCase().contains(query);
        });
        final matchesSearch = name.contains(query) || signerMatch;
        final matchesStatus =
            _statusFilter == 'all' || doc['Status'] == _statusFilter;
        return matchesSearch && matchesStatus;
      }).toList();

      _filteredDocs.sort((a, b) {
        if (_sortBy == 'name_asc') {
          return (a['Name'] ?? '').toString().compareTo(
            (b['Name'] ?? '').toString(),
          );
        }
        if (_sortBy == 'name_desc') {
          return (b['Name'] ?? '').toString().compareTo(
            (a['Name'] ?? '').toString(),
          );
        }
        if (_sortBy == 'date_asc')
          return _parseDate(a).compareTo(_parseDate(b));
        return _parseDate(b).compareTo(_parseDate(a));
      });
    });
  }

  void _toggleSelectAll(bool? checked) {
    setState(() {
      if (checked == true) {
        _selectedDocs = _filteredDocs.map((d) => d['ID'].toString()).toList();
      } else {
        _selectedDocs.clear();
      }
    });
  }

  Future<void> _runDocAction(String id, String action) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/v1/documents/$id/$action'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Falha ao executar ação');
    }
  }

  Future<void> _batchAction(String action) async {
    try {
      for (final id in _selectedDocs) {
        await _runDocAction(id, action);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Ação "$action" executada em ${_selectedDocs.length} documento(s)',
            ),
          ),
        );
      }
      setState(() => _selectedDocs.clear());
      _fetchDocuments();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao executar ação em lote')),
        );
      }
    }
  }

  List<Widget> _signerAvatars(Map<String, dynamic> doc) {
    final signers = _signersOf(doc);
    if (signers.isEmpty) {
      return [
        const Text('-', style: TextStyle(color: Colors.white54, fontSize: 12)),
      ];
    }
    return List<Widget>.generate(signers.length.clamp(0, 4), (index) {
      final signer = Map<String, dynamic>.from(signers[index] as Map);
      final palette = [
        AppTheme.tealNeon,
        AppTheme.goldSoft,
        Colors.cyanAccent,
        Colors.orangeAccent,
      ];
      final color = palette[index % palette.length];
      final name = (signer['Name'] ?? '?').toString();
      final letter = name.isNotEmpty ? name[0].toUpperCase() : '?';
      return Padding(
        padding: EdgeInsets.only(left: index == 0 ? 0 : 6),
        child: CircleAvatar(
          radius: 11,
          backgroundColor: color.withOpacity(0.2),
          child: Text(
            letter,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    });
  }

  Widget _buildStatusBadge(String status) {
    Color text;
    String label;
    IconData icon;

    switch (status) {
      case 'completed':
        text = AppTheme.goldSoft;
        label = 'ASSINADO';
        icon = LucideIcons.award;
        break;
      case 'in_progress':
        text = AppTheme.tealNeon;
        label = 'Aguardando';
        icon = LucideIcons.hourglass;
        break;
      case 'expired':
        text = Colors.orangeAccent;
        label = 'Expirado';
        icon = LucideIcons.clock3;
        break;
      case 'cancelled':
        text = Colors.redAccent;
        label = 'Cancelado';
        icon = LucideIcons.shieldAlert;
        break;
      default:
        text = Colors.white54;
        label = 'Rascunho';
        icon = LucideIcons.fileEdit;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: text.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: text.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: text),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: text,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              fontFamily: 'Orbitron',
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: Stack(
          children: [
            Positioned.fill(
              child: Opacity(
                opacity: 0.05,
                child: Image.network(
                  "https://www.transparenttextures.com/patterns/cubes.png",
                  repeat: ImageRepeat.repeat,
                  color: AppTheme.tealNeon,
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    // Header Gamified
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppTheme.tealNeon.withOpacity(0.1),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppTheme.tealNeon.withOpacity(0.5),
                                ),
                              ),
                              child: const Icon(
                                LucideIcons.scroll,
                                color: AppTheme.tealNeon,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 16),
                            const Text(
                              'Documentos',
                              style: TextStyle(
                                fontFamily: 'Orbitron',
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                                color: Colors.white,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                        GlassContainer(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          borderRadius: 20,
                          borderColor: AppTheme.goldSoft.withOpacity(0.3),
                          child: Text(
                            '${_documents.length} documentos',
                            style: const TextStyle(
                              color: AppTheme.goldSoft,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Toolbar superior (Glass)
                    GlassContainer(
                      padding: const EdgeInsets.all(12),
                      borderRadius: 16,
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Buscar por nome ou signatário...',
                                hintStyle: const TextStyle(
                                  color: Colors.white30,
                                  fontSize: 14,
                                ),
                                prefixIcon: const Icon(
                                  LucideIcons.search,
                                  size: 18,
                                  color: AppTheme.tealNeon,
                                ),
                                filled: true,
                                fillColor: Colors.black.withOpacity(0.2),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 0,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _sortBy,
                              dropdownColor: const Color(0xFF1D2A30),
                              borderRadius: BorderRadius.circular(12),
                              onChanged: (v) {
                                if (v != null) {
                                  setState(() => _sortBy = v);
                                  _applyFilters();
                                }
                              },
                              items: const [
                                DropdownMenuItem(
                                  value: 'date_desc',
                                  child: Text('Data desc'),
                                ),
                                DropdownMenuItem(
                                  value: 'date_asc',
                                  child: Text('Data asc'),
                                ),
                                DropdownMenuItem(
                                  value: 'name_asc',
                                  child: Text('Nome A-Z'),
                                ),
                                DropdownMenuItem(
                                  value: 'name_desc',
                                  child: Text('Nome Z-A'),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white12),
                            ),
                            child: Row(
                              children: [
                                IconButton(
                                  icon: Icon(
                                    LucideIcons.list,
                                    color: !_isGridView
                                        ? AppTheme.tealNeon
                                        : Colors.white54,
                                  ),
                                  onPressed: () =>
                                      setState(() => _isGridView = false),
                                ),
                                IconButton(
                                  icon: Icon(
                                    LucideIcons.layoutGrid,
                                    color: _isGridView
                                        ? AppTheme.tealNeon
                                        : Colors.white54,
                                  ),
                                  onPressed: () =>
                                      setState(() => _isGridView = true),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          ElevatedButton.icon(
                            icon: const Icon(LucideIcons.plus, size: 18),
                            label: const Text(
                              'Novo documento',
                              style: TextStyle(
                                fontFamily: 'Orbitron',
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.tealMedium,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 18,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: const BorderSide(
                                  color: AppTheme.tealNeon,
                                ),
                              ),
                              elevation: 10,
                              shadowColor: AppTheme.tealNeon,
                            ),
                            onPressed: () => context.push('/documents/new'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Status Filters Row
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _statusFilters.map((filter) {
                          final isSelected = _statusFilter == filter['value'];
                          return Padding(
                            padding: const EdgeInsets.only(right: 12.0),
                            child: InkWell(
                              onTap: () {
                                setState(() {
                                  _statusFilter = filter['value']!;
                                  _applyFilters();
                                });
                              },
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppTheme.tealNeon.withOpacity(0.2)
                                      : Colors.black.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isSelected
                                        ? AppTheme.tealNeon
                                        : Colors.white12,
                                  ),
                                  boxShadow: isSelected
                                      ? [
                                          BoxShadow(
                                            color: AppTheme.tealNeon
                                                .withOpacity(0.3),
                                            blurRadius: 8,
                                          ),
                                        ]
                                      : [],
                                ),
                                child: Text(
                                  '${filter['label']} (${_statusCount(filter['value']!)})',
                                  style: TextStyle(
                                    color: isSelected
                                        ? AppTheme.tealNeon
                                        : Colors.white70,
                                    fontSize: 12,
                                    fontFamily: 'Orbitron',
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.w500,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Bulk Actions Header (if selected)
                    if (_selectedDocs.isNotEmpty)
                      GlassContainer(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        borderColor: AppTheme.goldSoft.withOpacity(0.5),
                        color: AppTheme.goldSoft.withOpacity(0.05),
                        child: Row(
                          children: [
                            Icon(
                              LucideIcons.checkSquare,
                              color: AppTheme.goldSoft,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${_selectedDocs.length} selecionado(s)',
                              style: const TextStyle(
                                color: AppTheme.goldSoft,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Orbitron',
                                letterSpacing: 1,
                              ),
                            ),
                            const Spacer(),
                            OutlinedButton.icon(
                              icon: const Icon(
                                LucideIcons.send,
                                size: 14,
                                color: Colors.white,
                              ),
                              label: const Text(
                                'Reenviar',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontFamily: 'Orbitron',
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.white30),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed: () => _batchAction('resend'),
                            ),
                            const SizedBox(width: 12),
                            OutlinedButton.icon(
                              icon: const Icon(
                                LucideIcons.trash2,
                                size: 14,
                                color: Colors.redAccent,
                              ),
                              label: const Text(
                                'Cancelar',
                                style: TextStyle(
                                  color: Colors.redAccent,
                                  fontFamily: 'Orbitron',
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.redAccent),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed: () => _batchAction('cancel'),
                            ),
                          ],
                        ),
                      ),

                    // Content Area
                    Expanded(
                      child: _isLoading
                          ? const Center(
                              child: CircularProgressIndicator(
                                color: AppTheme.tealNeon,
                              ),
                            )
                          : _filteredDocs.isEmpty
                          ? Center(
                              child: GlassContainer(
                                padding: const EdgeInsets.all(40),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      LucideIcons.ghost,
                                      size: 64,
                                      color: Colors.white24,
                                    ),
                                    const SizedBox(height: 24),
                                    const Text(
                                      'Nenhum documento encontrado',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white70,
                                        fontFamily: 'Orbitron',
                                        letterSpacing: 1,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      'Sua base de registros não possui entradas compatíveis.',
                                      style: TextStyle(
                                        color: Colors.white54,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : _isGridView
                          ? GridView.builder(
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 3,
                                    childAspectRatio: 1.5,
                                    crossAxisSpacing: 16,
                                    mainAxisSpacing: 16,
                                  ),
                              itemCount: _filteredDocs.length,
                              itemBuilder: (context, index) {
                                final doc = _filteredDocs[index];
                                final signers = _signersOf(doc);
                                final signedCount = signers
                                    .where(
                                      (s) =>
                                          (Map<String, dynamic>.from(
                                                s as Map,
                                              )['Status'] ??
                                              '') ==
                                          'signed',
                                    )
                                    .length;
                                final totalCount = signers.length;
                                return GlassContainer(
                                  padding: const EdgeInsets.all(16),
                                  borderColor: Colors.white12,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Container(
                                            width: 40,
                                            height: 40,
                                            decoration: BoxDecoration(
                                              color: Colors.black.withOpacity(
                                                0.3,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              border: Border.all(
                                                color: Colors.white12,
                                              ),
                                            ),
                                            child: const Icon(
                                              LucideIcons.fileCode,
                                              color: AppTheme.tealNeon,
                                            ),
                                          ),
                                          _buildStatusBadge(
                                            doc['Status'] ?? 'draft',
                                          ),
                                        ],
                                      ),
                                      const Spacer(),
                                      Text(
                                        (doc['Name'] ?? 'Sem título')
                                            .toString(),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: Colors.white,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        _shortDate(doc),
                                        style: const TextStyle(
                                          color: Colors.white60,
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '$signedCount/$totalCount assinatura(s)',
                                        style: const TextStyle(
                                          color: AppTheme.tealNeon,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            )
                          : GlassContainer(
                              padding: const EdgeInsets.all(0),
                              child: Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    decoration: const BoxDecoration(
                                      border: Border(
                                        bottom: BorderSide(
                                          color: Colors.white12,
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Checkbox(
                                          value:
                                              _selectedDocs.length ==
                                                  _filteredDocs.length &&
                                              _filteredDocs.isNotEmpty,
                                          onChanged: _toggleSelectAll,
                                          activeColor: AppTheme.tealNeon,
                                          checkColor: Colors.black,
                                        ),
                                        const Expanded(
                                          flex: 3,
                                          child: Text(
                                            'Documento',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white54,
                                              fontFamily: 'Orbitron',
                                              letterSpacing: 1.2,
                                            ),
                                          ),
                                        ),
                                        const Expanded(
                                          flex: 1,
                                          child: Center(
                                            child: Text(
                                              'ESTADO',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white54,
                                                fontFamily: 'Orbitron',
                                                letterSpacing: 1.5,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const Expanded(
                                          flex: 1,
                                          child: Center(
                                            child: Text(
                                              'Signatários',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white54,
                                                fontFamily: 'Orbitron',
                                                letterSpacing: 1.1,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const Expanded(
                                          flex: 1,
                                          child: Center(
                                            child: Text(
                                              'Data',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white54,
                                                fontFamily: 'Orbitron',
                                                letterSpacing: 1.1,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 44),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    child: ListView.separated(
                                      itemCount: _filteredDocs.length,
                                      separatorBuilder: (context, index) =>
                                          const Divider(
                                            color: Colors.white12,
                                            height: 1,
                                          ),
                                      itemBuilder: (context, index) {
                                        final doc = _filteredDocs[index];
                                        final isSelected = _selectedDocs
                                            .contains(doc['ID'].toString());
                                        return Container(
                                          color: isSelected
                                              ? AppTheme.tealNeon.withOpacity(
                                                  0.05,
                                                )
                                              : Colors.transparent,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 12,
                                          ),
                                          child: Row(
                                            children: [
                                              Checkbox(
                                                value: isSelected,
                                                activeColor: AppTheme.tealNeon,
                                                checkColor: Colors.black,
                                                side: const BorderSide(
                                                  color: Colors.white54,
                                                ),
                                                onChanged: (val) {
                                                  setState(() {
                                                    if (val == true)
                                                      _selectedDocs.add(
                                                        doc['ID'].toString(),
                                                      );
                                                    else
                                                      _selectedDocs.remove(
                                                        doc['ID'].toString(),
                                                      );
                                                  });
                                                },
                                              ),
                                              Expanded(
                                                flex: 3,
                                                child: Row(
                                                  children: [
                                                    Container(
                                                      width: 36,
                                                      height: 36,
                                                      decoration: BoxDecoration(
                                                        color: Colors.black
                                                            .withOpacity(0.3),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              8,
                                                            ),
                                                        border: Border.all(
                                                          color: Colors.white12,
                                                        ),
                                                      ),
                                                      child: const Icon(
                                                        LucideIcons.fileCode,
                                                        size: 16,
                                                        color:
                                                            AppTheme.tealNeon,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 16),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Text(
                                                            (doc['Name'] ??
                                                                    'Sem título')
                                                                .toString(),
                                                            style:
                                                                const TextStyle(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  color: Colors
                                                                      .white,
                                                                ),
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                          ),
                                                          const SizedBox(
                                                            height: 4,
                                                          ),
                                                          Text(
                                                            (doc['FileName'] ??
                                                                    doc['ID'])
                                                                .toString(),
                                                            style:
                                                                const TextStyle(
                                                                  color: Colors
                                                                      .white54,
                                                                  fontSize: 10,
                                                                ),
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Expanded(
                                                flex: 1,
                                                child: Center(
                                                  child: _buildStatusBadge(
                                                    doc['Status'] ?? 'draft',
                                                  ),
                                                ),
                                              ),
                                              Expanded(
                                                flex: 1,
                                                child: Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: _signerAvatars(doc),
                                                ),
                                              ),
                                              Expanded(
                                                flex: 1,
                                                child: Center(
                                                  child: Text(
                                                    _shortDate(doc),
                                                    style: const TextStyle(
                                                      color: Colors.white70,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              SizedBox(
                                                width: 44,
                                                child: Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.end,
                                                  children: [
                                                    PopupMenuButton<String>(
                                                      icon: const Icon(
                                                        LucideIcons
                                                            .moreHorizontal,
                                                        size: 16,
                                                        color: Colors.white70,
                                                      ),
                                                      color: const Color(
                                                        0xFF1D2A30,
                                                      ),
                                                      onSelected: (val) async {
                                                        if (val == 'view') {
                                                          if (!mounted) return;
                                                          context.push(
                                                            '/documents/${doc['ID']}',
                                                          );
                                                          return;
                                                        }
                                                        if (val == 'download') {
                                                          return;
                                                        }
                                                        if (val == 'resend')
                                                          await _runDocAction(
                                                            doc['ID']
                                                                .toString(),
                                                            'resend',
                                                          );
                                                        if (val == 'cancel')
                                                          await _runDocAction(
                                                            doc['ID']
                                                                .toString(),
                                                            'cancel',
                                                          );
                                                        _fetchDocuments();
                                                      },
                                                      itemBuilder: (ctx) =>
                                                          const [
                                                            PopupMenuItem(
                                                              value: 'view',
                                                              child: Text(
                                                                'Visualizar',
                                                              ),
                                                            ),
                                                            PopupMenuItem(
                                                              value: 'resend',
                                                              child: Text(
                                                                'Reenviar',
                                                              ),
                                                            ),
                                                            PopupMenuItem(
                                                              value: 'download',
                                                              child: Text(
                                                                'Baixar',
                                                              ),
                                                            ),
                                                            PopupMenuItem(
                                                              value: 'cancel',
                                                              child: Text(
                                                                'Cancelar',
                                                              ),
                                                            ),
                                                          ],
                                                    ),
                                                  ],
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
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
