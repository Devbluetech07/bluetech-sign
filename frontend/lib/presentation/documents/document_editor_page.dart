import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:lucide_icons/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import '../../core/api_config.dart';
import '../../core/app_theme.dart';

class _CampoEditor {
  _CampoEditor({
    required this.id,
    required this.fieldType,
    required this.page,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.signerId,
  });

  final String id;
  final String fieldType;
  final int page;
  final String? signerId;
  double x;
  double y;
  double width;
  double height;
}

class DocumentEditorPage extends StatefulWidget {
  const DocumentEditorPage({super.key, required this.documentId});

  final String documentId;

  @override
  State<DocumentEditorPage> createState() => _DocumentEditorPageState();
}

class _DocumentEditorPageState extends State<DocumentEditorPage> {
  final PdfViewerController _pdfController = PdfViewerController();
  final GlobalKey _canvasKey = GlobalKey();

  bool _loading = true;
  bool _saving = false;
  String _fieldTypeSelecionado = 'signature';
  int _paginaAtual = 1;
  int _totalPaginas = 1;
  String? _pdfUrl;
  Map<String, String> _pdfHeaders = const {};
  Uint8List? _pdfBytes;
  List<_CampoEditor> _campos = <_CampoEditor>[];
  int? _campoSelecionado;

  @override
  void initState() {
    super.initState();
    _carregarDocumento();
  }

  Future<void> _carregarDocumento() async {
    setState(() => _loading = true);
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';
    final resDoc = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/api/v1/documents/${widget.documentId}'),
      headers: {'Authorization': 'Bearer $token'},
    );
    final resCampos = await http.get(
      Uri.parse(
        '${ApiConfig.baseUrl}/api/v1/documents/${widget.documentId}/fields',
      ),
      headers: {'Authorization': 'Bearer $token'},
    );
    final resDownload = await http.get(
      Uri.parse(
        '${ApiConfig.baseUrl}/api/v1/documents/${widget.documentId}/download',
      ),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (resDoc.statusCode == 200) {
      final body = jsonDecode(resDoc.body) as Map<String, dynamic>;
      final doc = Map<String, dynamic>.from((body['document'] ?? {}) as Map);
      final fieldsRaw = resCampos.statusCode == 200
          ? ((jsonDecode(resCampos.body) as Map<String, dynamic>)['fields']
                    as List<dynamic>? ??
                <dynamic>[])
          : (doc['Fields'] as List<dynamic>? ?? <dynamic>[]);
      final campos = fieldsRaw.map((raw) {
        final f = Map<String, dynamic>.from(raw as Map);
        return _CampoEditor(
          id: (f['ID'] ?? f['id'] ?? UniqueKey().toString()).toString(),
          fieldType: (f['FieldType'] ?? f['field_type'] ?? 'signature')
              .toString(),
          page: (f['Page'] ?? f['page'] ?? 1) as int,
          x: ((f['X'] ?? f['x'] ?? 0.1) as num).toDouble(),
          y: ((f['Y'] ?? f['y'] ?? 0.1) as num).toDouble(),
          width: ((f['Width'] ?? f['width'] ?? 0.18) as num).toDouble(),
          height: ((f['Height'] ?? f['height'] ?? 0.05) as num).toDouble(),
          signerId: (f['SignerID'] ?? f['signer_id'])?.toString(),
        );
      }).toList();

      var paginas = 1;
      for (final c in campos) {
        if (c.page > paginas) {
          paginas = c.page;
        }
      }
      if (paginas < 1) {
        paginas = 1;
      }

      setState(() {
        _campos = campos;
        _totalPaginas = paginas;
        _pdfUrl =
            '${ApiConfig.baseUrl}/api/v1/documents/${widget.documentId}/download';
        _pdfHeaders = {'Authorization': 'Bearer $token'};
        _pdfBytes = resDownload.statusCode == 200
            ? resDownload.bodyBytes
            : null;
        _loading = false;
      });
      return;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Falha ao carregar documento para edição'),
        ),
      );
    }
    setState(() => _loading = false);
  }

  void _adicionarCampo(Offset localOffset, Size canvasSize) {
    final x = (localOffset.dx / canvasSize.width).clamp(0.0, 0.95);
    final y = (localOffset.dy / canvasSize.height).clamp(0.0, 0.95);
    setState(() {
      _campos.add(
        _CampoEditor(
          id: UniqueKey().toString(),
          fieldType: _fieldTypeSelecionado,
          page: _paginaAtual,
          x: x,
          y: y,
          width: 0.2,
          height: 0.06,
        ),
      );
      _campoSelecionado = _campos.length - 1;
    });
  }

  Future<void> _salvarCampos() async {
    setState(() => _saving = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      final payload = {
        'fields': _campos.map((c) {
          return {
            'signer_id': c.signerId,
            'field_type': c.fieldType,
            'x': c.x,
            'y': c.y,
            'width': c.width,
            'height': c.height,
            'page': c.page,
            'value': '',
          };
        }).toList(),
      };

      final res = await http.put(
        Uri.parse(
          '${ApiConfig.baseUrl}/api/v1/documents/${widget.documentId}/fields',
        ),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      );
      if (!mounted) {
        return;
      }
      if (res.statusCode == 200 || res.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Campos salvos com sucesso')),
        );
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Falha ao salvar campos')));
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppTheme.tealNeon),
        ),
      );
    }

    final camposDaPagina = _campos
        .asMap()
        .entries
        .where((entry) => entry.value.page == _paginaAtual)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Editor de campos'),
        actions: [
          IconButton(
            onPressed: _saving ? null : _salvarCampos,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(LucideIcons.save),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: const Color(0xFF111827),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () =>
                      context.go('/documents/${widget.documentId}'),
                  icon: const Icon(LucideIcons.arrowLeft, size: 14),
                  label: const Text('Voltar'),
                ),
                const SizedBox(width: 12),
                DropdownButton<String>(
                  value: _fieldTypeSelecionado,
                  dropdownColor: const Color(0xFF1F2937),
                  items: const [
                    DropdownMenuItem(
                      value: 'signature',
                      child: Text('Assinatura'),
                    ),
                    DropdownMenuItem(value: 'text', child: Text('Texto')),
                    DropdownMenuItem(value: 'date', child: Text('Data')),
                    DropdownMenuItem(
                      value: 'checkbox',
                      child: Text('Checkbox'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }
                    setState(() => _fieldTypeSelecionado = value);
                  },
                ),
                const Spacer(),
                IconButton(
                  onPressed: _paginaAtual > 1
                      ? () {
                          setState(() => _paginaAtual -= 1);
                          _pdfController.previousPage();
                        }
                      : null,
                  icon: const Icon(LucideIcons.chevronLeft),
                ),
                Text('Página $_paginaAtual/$_totalPaginas'),
                IconButton(
                  onPressed: _paginaAtual < _totalPaginas
                      ? () {
                          setState(() => _paginaAtual += 1);
                          _pdfController.nextPage();
                        }
                      : null,
                  icon: const Icon(LucideIcons.chevronRight),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _saving ? null : _salvarCampos,
                  icon: const Icon(LucideIcons.save, size: 14),
                  label: const Text('Salvar campos'),
                ),
              ],
            ),
          ),
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 800 / 1100,
                child: Container(
                  color: Colors.white,
                  child: Stack(
                    children: [
                      if (_pdfUrl != null)
                        (_pdfBytes != null && _pdfBytes!.isNotEmpty)
                            ? SfPdfViewer.memory(
                                _pdfBytes!,
                                controller: _pdfController,
                                canShowScrollHead: false,
                                canShowScrollStatus: false,
                                enableDoubleTapZooming: false,
                                pageLayoutMode: PdfPageLayoutMode.single,
                                onPageChanged: (details) {
                                  setState(
                                    () => _paginaAtual = details.newPageNumber,
                                  );
                                },
                              )
                            : SfPdfViewer.network(
                                _pdfUrl!,
                                controller: _pdfController,
                                canShowScrollHead: false,
                                canShowScrollStatus: false,
                                enableDoubleTapZooming: false,
                                pageLayoutMode: PdfPageLayoutMode.single,
                                onPageChanged: (details) {
                                  setState(
                                    () => _paginaAtual = details.newPageNumber,
                                  );
                                },
                                headers: _pdfHeaders,
                              ),
                      Positioned.fill(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            return GestureDetector(
                              key: _canvasKey,
                              behavior: HitTestBehavior.opaque,
                              onTapDown: (details) {
                                _adicionarCampo(
                                  details.localPosition,
                                  Size(
                                    constraints.maxWidth,
                                    constraints.maxHeight,
                                  ),
                                );
                              },
                              child: Stack(
                                children: camposDaPagina.map((entry) {
                                  final index = entry.key;
                                  final campo = entry.value;
                                  final selected = _campoSelecionado == index;
                                  final left = campo.x * constraints.maxWidth;
                                  final top = campo.y * constraints.maxHeight;
                                  final width =
                                      campo.width * constraints.maxWidth;
                                  final height =
                                      campo.height * constraints.maxHeight;

                                  return Positioned(
                                    left: left,
                                    top: top,
                                    child: GestureDetector(
                                      onTap: () => setState(
                                        () => _campoSelecionado = index,
                                      ),
                                      onPanUpdate: (details) {
                                        setState(() {
                                          campo.x =
                                              ((left + details.delta.dx) /
                                                      constraints.maxWidth)
                                                  .clamp(0.0, 0.98);
                                          campo.y =
                                              ((top + details.delta.dy) /
                                                      constraints.maxHeight)
                                                  .clamp(0.0, 0.98);
                                        });
                                      },
                                      child: Container(
                                        width: width,
                                        height: height,
                                        decoration: BoxDecoration(
                                          color: Colors.blueAccent.withValues(
                                            alpha: 0.15,
                                          ),
                                          border: Border.all(
                                            color: selected
                                                ? Colors.orangeAccent
                                                : Colors.blueAccent,
                                            width: selected ? 2 : 1.2,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: Stack(
                                          children: [
                                            Center(
                                              child: Text(
                                                campo.fieldType,
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                  color: Colors.blueAccent,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                            Positioned(
                                              top: 1,
                                              right: 1,
                                              child: GestureDetector(
                                                onTap: () {
                                                  setState(() {
                                                    _campos.removeAt(index);
                                                    _campoSelecionado = null;
                                                  });
                                                },
                                                child: const Icon(
                                                  LucideIcons.xCircle,
                                                  size: 14,
                                                  color: Colors.redAccent,
                                                ),
                                              ),
                                            ),
                                            Positioned(
                                              right: 0,
                                              bottom: 0,
                                              child: GestureDetector(
                                                onPanUpdate: (details) {
                                                  setState(() {
                                                    final newWidth =
                                                        (width +
                                                            details.delta.dx) /
                                                        constraints.maxWidth;
                                                    final newHeight =
                                                        (height +
                                                            details.delta.dy) /
                                                        constraints.maxHeight;
                                                    campo.width = newWidth
                                                        .clamp(0.06, 0.8);
                                                    campo.height = newHeight
                                                        .clamp(0.03, 0.4);
                                                  });
                                                },
                                                child: Container(
                                                  width: 10,
                                                  height: 10,
                                                  color: Colors.orangeAccent,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
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
          ),
        ],
      ),
    );
  }
}
