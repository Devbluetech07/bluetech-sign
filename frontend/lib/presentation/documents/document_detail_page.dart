import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:lucide_icons/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/api_config.dart';
import '../../core/app_theme.dart';
import '../widgets/glass_container.dart';

class DocumentDetailPage extends StatefulWidget {
  const DocumentDetailPage({super.key, required this.documentId});

  final String documentId;

  @override
  State<DocumentDetailPage> createState() => _DocumentDetailPageState();
}

class _DocumentDetailPageState extends State<DocumentDetailPage> {
  bool _loading = true;
  Map<String, dynamic>? _data;
  int _page = 1;
  int _totalPages = 1;

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
      Uri.parse('${ApiConfig.baseUrl}/api/v1/documents/${widget.documentId}'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (res.statusCode == 200) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final fields = (body['document']['Fields'] as List<dynamic>? ?? []);
      int pages = 1;
      for (final f in fields) {
        final p = (Map<String, dynamic>.from(f as Map))['Page'] as int? ?? 1;
        if (p > pages) pages = p;
      }
      setState(() {
        _data = body;
        _totalPages = pages;
        _loading = false;
      });
      return;
    }
    setState(() => _loading = false);
  }

  Future<void> _docAction(String action) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';
    final res = await http.post(
      Uri.parse(
        '${ApiConfig.baseUrl}/api/v1/documents/${widget.documentId}/$action',
      ),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (!mounted) return;
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final sent = (body['emails_sent'] as num?)?.toInt();
      final failedRaw = body['emails_failed'] as List<dynamic>? ?? [];
      final fallbackLinksRaw =
          body['signing_links_fallback'] as List<dynamic>? ?? [];
      final fallbackLinks = fallbackLinksRaw
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      String feedback = 'Ação "$action" executada';
      Color feedbackColor = AppTheme.tealNeon;
      if (sent != null || failedRaw.isNotEmpty) {
        feedback =
            'Envio: ${sent ?? 0} enviado(s), ${failedRaw.length} falha(s)';
      }
      if (failedRaw.isNotEmpty) {
        feedbackColor = Colors.orangeAccent;
        final firstLink = fallbackLinks.isNotEmpty
            ? (fallbackLinks.first['link'] ?? '').toString()
            : '';
        if (firstLink.isNotEmpty) {
          Clipboard.setData(ClipboardData(text: firstLink));
          feedback = '$feedback. Link de assinatura copiado.';
        }
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(feedback), backgroundColor: feedbackColor),
      );
      _fetch();
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Falha ao executar ação')));
    }
  }

  Widget _statusBadge(String status) {
    Color color = Colors.white54;
    String label = 'Rascunho';
    if (status == 'in_progress') {
      color = AppTheme.goldSoft;
      label = 'Aguardando';
    } else if (status == 'completed') {
      color = AppTheme.tealNeon;
      label = 'Concluído';
    } else if (status == 'cancelled') {
      color = Colors.redAccent;
      label = 'Cancelado';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildPreview() {
    final doc = Map<String, dynamic>.from((_data?['document'] ?? {}) as Map);
    final fields = (doc['Fields'] as List<dynamic>? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .where((f) => (f['Page'] ?? 1) == _page)
        .toList();

    return GlassContainer(
      padding: const EdgeInsets.all(16),
      borderColor: Colors.white12,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: _page > 1 ? () => setState(() => _page -= 1) : null,
                icon: const Icon(LucideIcons.chevronLeft, size: 16),
              ),
              Text(
                'Página $_page de $_totalPages',
                style: const TextStyle(color: Colors.white70),
              ),
              IconButton(
                onPressed: _page < _totalPages
                    ? () => setState(() => _page += 1)
                    : null,
                icon: const Icon(LucideIcons.chevronRight, size: 16),
              ),
              const Spacer(),
              Text(
                '${fields.length} campo(s)',
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 360,
            child: LayoutBuilder(
              builder: (context, c) {
                return Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Stack(
                    children: [
                      const Center(
                        child: Text(
                          'Pré-visualização do documento',
                          style: TextStyle(color: Colors.white54),
                        ),
                      ),
                      ...fields.map((field) {
                        final isFilled = (field['Value'] ?? '')
                            .toString()
                            .trim()
                            .isNotEmpty;
                        final color = isFilled
                            ? Colors.greenAccent
                            : Colors.blueAccent;
                        final left =
                            ((field['X'] as num?)?.toDouble() ?? 0.1) *
                            c.maxWidth;
                        final top =
                            ((field['Y'] as num?)?.toDouble() ?? 0.1) *
                            c.maxHeight;
                        final width =
                            ((field['Width'] as num?)?.toDouble() ?? 0.2) *
                            c.maxWidth;
                        final height =
                            ((field['Height'] as num?)?.toDouble() ?? 0.08) *
                            c.maxHeight;
                        return Positioned(
                          left: left,
                          top: top,
                          child: Container(
                            width: width,
                            height: height,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              color: color.withOpacity(isFilled ? 0.22 : 0.08),
                              border: Border.all(
                                color: color,
                                width: isFilled ? 2 : 1.5,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                isFilled
                                    ? '✓'
                                    : (field['FieldType'] ?? 'campo')
                                          .toString(),
                                style: TextStyle(
                                  color: color,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_data == null) {
      return const Scaffold(
        body: Center(child: Text('Documento não encontrado')),
      );
    }
    final doc = Map<String, dynamic>.from((_data?['document'] ?? {}) as Map);
    final signers = (doc['Signers'] as List<dynamic>? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    String firstPendingSignerToken = '';
    for (final signer in signers) {
      final status = (signer['Status'] ?? '').toString();
      final token = (signer['AccessToken'] ?? '').toString();
      if (status != 'signed' && token.isNotEmpty) {
        firstPendingSignerToken = token;
        break;
      }
    }
    final audits = (_data?['audit_entries'] as List<dynamic>? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final status = (doc['Status'] ?? 'draft').toString();
    final canPendingActions = status == 'draft' || status == 'in_progress';

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
                    TextButton.icon(
                      onPressed: () => context.go('/documents'),
                      icon: const Icon(LucideIcons.arrowLeft, size: 16),
                      label: const Text('Voltar para documentos'),
                    ),
                    const Spacer(),
                    OutlinedButton.icon(
                      onPressed: () {
                        final token = firstPendingSignerToken;
                        if (token.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Nenhum link disponível para cópia',
                              ),
                            ),
                          );
                          return;
                        }
                        Clipboard.setData(
                          ClipboardData(
                            text: '${ApiConfig.baseUrl}/sign/$token',
                          ),
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Link copiado')),
                        );
                      },
                      icon: const Icon(LucideIcons.copy, size: 14),
                      label: const Text('Copiar link'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () => context.push(
                        '/documents/${widget.documentId}/editor',
                      ),
                      icon: const Icon(LucideIcons.edit3, size: 14),
                      label: const Text('Editar campos'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final prefs = await SharedPreferences.getInstance();
                        final token = prefs.getString('token') ?? '';
                        await http.get(
                          Uri.parse(
                            '${ApiConfig.baseUrl}/api/v1/documents/${widget.documentId}/download',
                          ),
                          headers: {'Authorization': 'Bearer $token'},
                        );
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Download solicitado'),
                            ),
                          );
                        }
                      },
                      icon: const Icon(LucideIcons.download, size: 14),
                      label: const Text('Baixar'),
                    ),
                    if (canPendingActions) ...[
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () => _docAction('resend'),
                        icon: const Icon(LucideIcons.send, size: 14),
                        label: const Text('Reenviar'),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: () => _docAction('cancel'),
                        icon: const Icon(
                          LucideIcons.x,
                          size: 14,
                          color: Colors.redAccent,
                        ),
                        label: const Text(
                          'Cancelar',
                          style: TextStyle(color: Colors.redAccent),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Column(
                          children: [
                            GlassContainer(
                              borderColor: Colors.white12,
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Text(
                                        'Informações do documento',
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          fontFamily: 'Orbitron',
                                        ),
                                      ),
                                      const Spacer(),
                                      _statusBadge(status),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 18,
                                    runSpacing: 8,
                                    children: [
                                      Text(
                                        'Criado: ${(doc['CreatedAt'] ?? '-').toString()}',
                                        style: const TextStyle(
                                          color: Colors.white70,
                                        ),
                                      ),
                                      Text(
                                        'Atualizado: ${(doc['UpdatedAt'] ?? '-').toString()}',
                                        style: const TextStyle(
                                          color: Colors.white70,
                                        ),
                                      ),
                                      Text(
                                        'Prazo: ${(doc['Deadline'] ?? '-').toString()}',
                                        style: const TextStyle(
                                          color: Colors.white70,
                                        ),
                                      ),
                                      Text(
                                        'Tipo: ${(doc['SignatureType'] ?? '-').toString()}',
                                        style: const TextStyle(
                                          color: Colors.white70,
                                        ),
                                      ),
                                      Text(
                                        'Assinaturas: ${_data?['signed_signers_count'] ?? 0}/${_data?['total_signers_count'] ?? 0}',
                                        style: const TextStyle(
                                          color: Colors.white70,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            Expanded(child: _buildPreview()),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          children: [
                            GlassContainer(
                              borderColor: Colors.white12,
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        'Signatários (${signers.length})',
                                        style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          fontFamily: 'Orbitron',
                                        ),
                                      ),
                                      const Spacer(),
                                      if (canPendingActions)
                                        TextButton.icon(
                                          onPressed: () => _docAction('resend'),
                                          icon: const Icon(
                                            LucideIcons.send,
                                            size: 14,
                                          ),
                                          label: const Text('Reenviar'),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  ...signers.map((s) {
                                    final st = (s['Status'] ?? '').toString();
                                    final icon = st == 'signed'
                                        ? LucideIcons.checkCircle2
                                        : st == 'rejected'
                                        ? LucideIcons.xCircle
                                        : LucideIcons.clock3;
                                    final color = st == 'signed'
                                        ? Colors.greenAccent
                                        : st == 'rejected'
                                        ? Colors.redAccent
                                        : AppTheme.goldSoft;
                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 10),
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: Colors.white10,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 14,
                                            backgroundColor: AppTheme.tealNeon
                                                .withOpacity(0.2),
                                            child: Text(
                                              '${s['SignOrder'] ?? 1}',
                                              style: const TextStyle(
                                                color: AppTheme.tealNeon,
                                                fontSize: 11,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  (s['Name'] ?? '-').toString(),
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                Text(
                                                  (s['Email'] ?? '-')
                                                      .toString(),
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.white70,
                                                  ),
                                                ),
                                                Text(
                                                  (s['Phone'] ?? '-')
                                                      .toString(),
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.white54,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.end,
                                            children: [
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 2,
                                                    ),
                                                decoration: BoxDecoration(
                                                  border: Border.all(
                                                    color: Colors.white30,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(99),
                                                ),
                                                child: Text(
                                                  (s['Role'] ?? 'Signatário')
                                                      .toString(),
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                  ),
                                                ),
                                              ),
                                              if (st != 'signed' &&
                                                  s['AccessToken'] != null) ...[
                                                const SizedBox(height: 4),
                                                InkWell(
                                                  onTap: () {
                                                    final token =
                                                        s['AccessToken']
                                                            .toString();
                                                    Clipboard.setData(
                                                      ClipboardData(
                                                        text:
                                                            '${ApiConfig.baseUrl}/sign/$token',
                                                      ),
                                                    );
                                                    ScaffoldMessenger.of(
                                                      context,
                                                    ).showSnackBar(
                                                      const SnackBar(
                                                        content: Text(
                                                          'Link de assinatura copiado!',
                                                        ),
                                                      ),
                                                    );
                                                  },
                                                  child: const Row(
                                                    children: [
                                                      Icon(
                                                        LucideIcons.link,
                                                        size: 12,
                                                        color:
                                                            AppTheme.tealNeon,
                                                      ),
                                                      SizedBox(width: 4),
                                                      Text(
                                                        'Copiar link',
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          color:
                                                              AppTheme.tealNeon,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                              const SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  Icon(
                                                    icon,
                                                    color: color,
                                                    size: 14,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    st,
                                                    style: TextStyle(
                                                      color: color,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
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
                                      'Trilha de auditoria',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'Orbitron',
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    if (audits.isEmpty)
                                      const Center(
                                        child: Padding(
                                          padding: EdgeInsets.only(top: 24),
                                          child: Text(
                                            'Sem registros de atividade',
                                            style: TextStyle(
                                              color: Colors.white54,
                                            ),
                                          ),
                                        ),
                                      )
                                    else
                                      Expanded(
                                        child: ListView.builder(
                                          itemCount: audits.length,
                                          itemBuilder: (context, i) {
                                            final a = audits[i];
                                            return ListTile(
                                              contentPadding: EdgeInsets.zero,
                                              leading: Container(
                                                width: 30,
                                                height: 30,
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  color: AppTheme.tealNeon
                                                      .withOpacity(0.15),
                                                ),
                                                child: const Icon(
                                                  LucideIcons.activity,
                                                  size: 14,
                                                  color: AppTheme.tealNeon,
                                                ),
                                              ),
                                              title: Text(
                                                (a['Action'] ?? '-').toString(),
                                              ),
                                              subtitle: Text(
                                                (a['Details'] ?? '-')
                                                    .toString(),
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.white70,
                                                ),
                                              ),
                                              trailing: Text(
                                                (a['Timestamp'] ?? '')
                                                    .toString()
                                                    .split('.')
                                                    .first,
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.white54,
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
