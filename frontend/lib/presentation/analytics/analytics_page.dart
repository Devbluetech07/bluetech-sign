import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:lucide_icons/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/api_config.dart';
import '../../core/app_theme.dart';
import '../widgets/glass_container.dart';

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  bool _loading = true;
  List<Map<String, dynamic>> _documents = [];

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
      Uri.parse('${ApiConfig.baseUrl}/api/v1/documents/'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (res.statusCode == 200) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      setState(() {
        _documents = (body['documents'] as List<dynamic>? ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _loading = false;
      });
      return;
    }
    setState(() => _loading = false);
  }

  int _countByStatus(String status) =>
      _documents.where((d) => (d['Status'] ?? '') == status).length;

  int get _totalSigners {
    int total = 0;
    for (final d in _documents) {
      total += (d['Signers'] as List<dynamic>? ?? []).length;
    }
    return total;
  }

  int get _signedSigners {
    int total = 0;
    for (final d in _documents) {
      final signers = (d['Signers'] as List<dynamic>? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      total += signers.where((s) => (s['Status'] ?? '') == 'signed').length;
    }
    return total;
  }

  String get _signatureRate {
    if (_totalSigners == 0) return '0%';
    final pct = (_signedSigners / _totalSigners) * 100;
    return '${pct.toStringAsFixed(1)}%';
  }

  Map<String, int> _signersByEmail() {
    final map = <String, int>{};
    for (final d in _documents) {
      final signers = (d['Signers'] as List<dynamic>? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      for (final s in signers) {
        final email = (s['Email'] ?? '').toString().trim();
        if (email.isEmpty) continue;
        map[email] = (map[email] ?? 0) + 1;
      }
    }
    return map;
  }

  Widget _kpi(
    IconData icon,
    String value,
    String label, {
    Color color = AppTheme.tealNeon,
  }) {
    return Expanded(
      child: GlassContainer(
        borderColor: Colors.white12,
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Orbitron',
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(fontSize: 12, color: Colors.white60),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final signerByEmail = _signersByEmail().entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Relatórios',
                        style: TextStyle(
                          fontSize: 28,
                          fontFamily: 'Orbitron',
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Visão consolidada de documentos e assinaturas',
                        style: TextStyle(color: Colors.white60),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          _kpi(
                            LucideIcons.fileText,
                            _documents.length.toString(),
                            'Total documentos',
                          ),
                          const SizedBox(width: 10),
                          _kpi(
                            LucideIcons.hourglass,
                            _countByStatus('in_progress').toString(),
                            'Em assinatura',
                            color: AppTheme.goldSoft,
                          ),
                          const SizedBox(width: 10),
                          _kpi(
                            LucideIcons.badgeCheck,
                            _countByStatus('completed').toString(),
                            'Concluídos',
                            color: Colors.greenAccent,
                          ),
                          const SizedBox(width: 10),
                          _kpi(
                            LucideIcons.gauge,
                            _signatureRate,
                            'Taxa de assinatura',
                            color: Colors.cyanAccent,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: GlassContainer(
                                borderColor: Colors.white12,
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Documentos recentes',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'Orbitron',
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Expanded(
                                      child: ListView.builder(
                                        itemCount: _documents.length,
                                        itemBuilder: (context, i) {
                                          final d = _documents[i];
                                          final signers =
                                              (d['Signers'] as List<dynamic>? ??
                                                      [])
                                                  .length;
                                          return ListTile(
                                            leading: const Icon(
                                              LucideIcons.fileText,
                                              size: 16,
                                            ),
                                            title: Text(
                                              (d['Name'] ?? '-').toString(),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            subtitle: Text(
                                              'Status: ${d['Status'] ?? '-'} • $signers signatário(s)',
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ),
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
                                    const Text(
                                      'Top contatos',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'Orbitron',
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Expanded(
                                      child: signerByEmail.isEmpty
                                          ? const Center(
                                              child: Text(
                                                'Sem dados',
                                                style: TextStyle(
                                                  color: Colors.white54,
                                                ),
                                              ),
                                            )
                                          : ListView.builder(
                                              itemCount: signerByEmail.length,
                                              itemBuilder: (_, i) {
                                                final e = signerByEmail[i];
                                                return ListTile(
                                                  dense: true,
                                                  leading: CircleAvatar(
                                                    radius: 14,
                                                    backgroundColor: AppTheme
                                                        .tealNeon
                                                        .withOpacity(0.2),
                                                    child: Text(
                                                      e.key
                                                          .substring(0, 1)
                                                          .toUpperCase(),
                                                      style: const TextStyle(
                                                        color:
                                                            AppTheme.tealNeon,
                                                      ),
                                                    ),
                                                  ),
                                                  title: Text(
                                                    e.key,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                  trailing: Text(
                                                    '${e.value} docs',
                                                    style: const TextStyle(
                                                      color: Colors.white70,
                                                    ),
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
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
