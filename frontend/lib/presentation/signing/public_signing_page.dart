import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:http/http.dart' as http;
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import '../../core/api_config.dart';
import 'dart:convert';
import '../../core/app_theme.dart';
import '../widgets/glass_container.dart';
import '../microservices/valeris_frame.dart';

class PublicSigningPage extends StatefulWidget {
  final String token;
  const PublicSigningPage({super.key, required this.token});

  @override
  State<PublicSigningPage> createState() => _PublicSigningPageState();
}

class _PublicSigningPageState extends State<PublicSigningPage> {
  String _state =
      'loading'; // loading | document | validation | complete | error
  bool _isSendingCode = false;
  Map<String, dynamic>? _docData;
  String? _error;
  bool _isFinishingStep = false;

  final TextEditingController _typedSignatureController =
      TextEditingController();
  final TextEditingController _tokenController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchDocumentData();
  }

  String get _valerisToken {
    const token = String.fromEnvironment(
      'VALERIS_API_TOKEN',
      defaultValue: 'portal-demo',
    );
    return token.trim().isEmpty ? 'portal-demo' : token.trim();
  }

  String _valerisCaptureApiUrl() {
    return '${ApiConfig.baseUrl}/api/v1/valeris';
  }

  String _buildValerisPageUrl(String folder, String fileName) {
    final uri = Uri(
      path: '/valeris-ui/$folder/$fileName',
      queryParameters: {
        'apiUrl': _valerisCaptureApiUrl(),
        'token': _valerisToken,
      },
    );
    final origin = kIsWeb ? Uri.base.origin : ApiConfig.baseUrl;
    return '$origin${uri.toString()}';
  }

  String _validationServicePath(String rawStepType) {
    final stepType = rawStepType.toLowerCase().trim();
    if (stepType.contains('selfie') && stepType.contains('document')) {
      return _buildValerisPageUrl('selfie_doc', 'selfie_doc.html');
    }
    if (stepType.contains('document')) {
      return _buildValerisPageUrl('documento', 'documento.html');
    }
    return _buildValerisPageUrl('selfie', 'selfie.html');
  }

  Future<void> _fetchDocumentData() async {
    try {
      final res = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/v1/signing/${widget.token}'),
      );
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final fields = (body['fields'] as List<dynamic>? ?? []);
        final validations = (body['validation_steps'] as List<dynamic>? ?? []);
        final pendingFields = fields
            .where(
              (f) => (Map<String, dynamic>.from(f as Map)['Value'] ?? '')
                  .toString()
                  .trim()
                  .isEmpty,
            )
            .length;
        final pendingValidations = validations
            .where(
              (v) =>
                  (Map<String, dynamic>.from(v as Map)['Status'] ?? '') !=
                  'completed',
            )
            .length;
        setState(() {
          _docData = body;
          if (body['already_signed'] == true) {
            _state = 'complete';
          } else if (pendingFields > 0) {
            _state = 'document';
          } else if (pendingValidations > 0) {
            _state = 'validation';
          } else {
            _state = 'document';
          }
        });
      } else {
        setState(() {
          _error = jsonDecode(res.body)['error'] ?? 'Erro desconhecido';
          _state = 'error';
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Erro de conexão: $e';
        _state = 'error';
      });
    }
  }

  Future<void> _requestVerificationToken() async {
    setState(() => _isSendingCode = true);
    try {
      await http.post(
        Uri.parse(
          '${ApiConfig.baseUrl}/api/v1/signing/${widget.token}/request-token',
        ),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Código enviado por e-mail!')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSendingCode = false);
    }
  }

  Future<void> _signField(Map<String, dynamic> field) async {
    if (kIsWeb) {
      final captureId = await showDialog<String>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Assinatura Valeris'),
            content: SizedBox(
              width: 760,
              height: 560,
              child: ValerisFrame(
                serviceUrl: _buildValerisPageUrl(
                  'assinatura',
                  'assinatura.html',
                ),
                onCaptureSuccess: (_, capture) {
                  Navigator.of(context).pop(capture);
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Fechar'),
              ),
            ],
          );
        },
      );
      if (captureId == null || captureId.trim().isEmpty) return;

      final res = await http.post(
        Uri.parse(
          '${ApiConfig.baseUrl}/api/v1/signing/${widget.token}/fields/${field['ID']}/sign',
        ),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'signature_type': 'drawn',
          'typed_text': '',
          'image': 'valeris_capture:$captureId',
        }),
      );
      if (res.statusCode == 200) {
        await _fetchDocumentData();
      } else if (mounted) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(body['error']?.toString() ?? 'Erro ao assinar campo'),
          ),
        );
      }
      return;
    }

    final mode = await showDialog<String>(
      context: context,
      builder: (context) {
        String tab = 'drawn';
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Assinar campo'),
              content: SizedBox(
                width: 520,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        ChoiceChip(
                          label: const Text('Desenhar'),
                          selected: tab == 'drawn',
                          onSelected: (_) =>
                              setDialogState(() => tab = 'drawn'),
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('Digitar'),
                          selected: tab == 'typed',
                          onSelected: (_) =>
                              setDialogState(() => tab = 'typed'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (tab == 'drawn')
                      Container(
                        height: 120,
                        width: double.infinity,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white24),
                          borderRadius: BorderRadius.circular(8),
                          color: Colors.black.withValues(alpha: 0.2),
                        ),
                        child: const Text(
                          'Área de desenho pronta (captura simplificada)',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ),
                    if (tab == 'typed')
                      TextField(
                        controller: _typedSignatureController,
                        decoration: const InputDecoration(
                          labelText: 'Digite sua assinatura',
                        ),
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
                  onPressed: () => Navigator.pop(context, tab),
                  child: const Text('Confirmar assinatura'),
                ),
              ],
            );
          },
        );
      },
    );
    if (mode == null) return;

    final res = await http.post(
      Uri.parse(
        '${ApiConfig.baseUrl}/api/v1/signing/${widget.token}/fields/${field['ID']}/sign',
      ),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'signature_type': mode,
        'typed_text': mode == 'typed'
            ? _typedSignatureController.text.trim()
            : '',
        'image': '',
      }),
    );
    if (res.statusCode == 200) {
      _typedSignatureController.clear();
      await _fetchDocumentData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Campo assinado com sucesso')),
        );
      }
    } else {
      if (mounted) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(body['error']?.toString() ?? 'Erro ao assinar campo'),
          ),
        );
      }
    }
  }

  Future<void> _completeValidation(
    Map<String, dynamic> step, {
    String details = 'Concluído via fluxo público',
  }) async {
    if (_isFinishingStep) return;
    setState(() => _isFinishingStep = true);
    try {
      final res = await http.post(
        Uri.parse(
          '${ApiConfig.baseUrl}/api/v1/signing/${widget.token}/validation-steps/${step['ID']}/complete',
        ),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'details': details}),
      );
      if (res.statusCode == 200) {
        await _fetchDocumentData();
      } else {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(body['error']?.toString() ?? 'Erro na validação'),
            ),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isFinishingStep = false);
    }
  }

  Future<void> _signDocument() async {
    try {
      final payload = {
        'token_code': _tokenController.text,
        'signature_data': {'image': ''},
      };

      final res = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/v1/signing/${widget.token}/sign'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (res.statusCode == 200) {
        if (mounted) {
          setState(() => _state = 'complete');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Documento assinado com sucesso!'),
              backgroundColor: Colors.green,
            ),
          );
          _fetchDocumentData();
        }
      } else {
        if (mounted) {
          final err = jsonDecode(res.body)['error'];
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro: $err'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro interno: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() {});
    }
  }

  Widget _buildPdfView(List<Map<String, dynamic>> fields, Map<String, dynamic> signer) {
    final fileUrl = _docData?['file_url'] as String?;
    final fullUrl = fileUrl != null ? '${ApiConfig.baseUrl}$fileUrl' : null;

    if (fullUrl == null) {
      return const Center(child: Text('Documento indisponível', style: TextStyle(color: Colors.white)));
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10)],
      ),
      child: Stack(
        children: [
          SfPdfViewer.network(
            fullUrl,
            canShowScrollHead: false,
            canShowScrollStatus: false,
            enableDoubleTapZooming: false,
            pageLayoutMode: PdfPageLayoutMode.single,
          ),
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Approximate mapping: SfPdfViewer scales to fit the width/height.
                // Fields came from an 800x1100 baseline. We'll map them proportionally.
                final viewWidth = constraints.maxWidth;
                final viewHeight = constraints.maxHeight;

                return Stack(
                  children: fields.map((field) {
                     final isPending = (field['Value'] ?? '').toString().trim().isEmpty;
                     final color = isPending ? AppTheme.tealNeon : Colors.greenAccent;
                     
                     final xRatio = (field['X'] as num?)?.toDouble() ?? 0.0;
                     final yRatio = (field['Y'] as num?)?.toDouble() ?? 0.0;
                     final wRatio = (field['Width'] as num?)?.toDouble() ?? 0.15;
                     final hRatio = (field['Height'] as num?)?.toDouble() ?? 0.04;

                    return Positioned(
                      left: xRatio * viewWidth,
                      top: yRatio * viewHeight,
                      width: wRatio * viewWidth,
                      height: hRatio * viewHeight,
                      child: InkWell(
                        onTap: isPending ? () => _signField(field) : null,
                        child: Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: color.withOpacity(isPending ? 0.2 : 0.4),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: color, width: 2),
                          ),
                          child: Text(
                            isPending ? 'Assinar Aqui' : 'Assinado',
                            style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
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
    if (_state == 'loading') {
      return const Scaffold(
        backgroundColor: Color(0xFF1E293B),
        body: Center(child: CircularProgressIndicator(color: AppTheme.tealNeon)),
      );
    }
    if (_state == 'error') {
      return Scaffold(
        backgroundColor: const Color(0xFF1E293B),
        body: Center(
          child: Text(
            _error ?? 'Erro ao carregar documento',
            style: const TextStyle(color: Colors.redAccent, fontSize: 18),
          ),
        ),
      );
    }
    final signer = Map<String, dynamic>.from((_docData?['signer'] ?? {}) as Map);
    final doc = Map<String, dynamic>.from((_docData?['document'] ?? {}) as Map);
    final org = Map<String, dynamic>.from((_docData?['organization'] ?? {}) as Map);
    final fields = (_docData?['fields'] as List<dynamic>? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final pendingFields = fields
        .where((f) => (f['Value'] ?? '').toString().trim().isEmpty)
        .toList();
    final validations = (_docData?['validation_steps'] as List<dynamic>? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final pendingValidations = validations
        .where((v) => (v['Status'] ?? '') != 'completed')
        .toList();

    if (_state == 'complete') {
      return Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        body: Center(
          child: GlassContainer(
            padding: const EdgeInsets.all(40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(LucideIcons.checkCircle2, color: Colors.greenAccent, size: 80),
                const SizedBox(height: 24),
                const Text(
                  'Tudo pronto!',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 12),
                Text(
                  'Você concluiu a assinatura do documento "${doc['name']}".',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  'Uma cópia será enviada ao seu e-mail.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white54, fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Column(
        children: [
          // Top Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: const BoxDecoration(
              color: Color(0xFF1E293B),
              border: Border(bottom: BorderSide(color: Colors.white12)),
            ),
            child: Row(
              children: [
                Image.asset('assets/images/logo.png', height: 32, fit: BoxFit.contain),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (doc['name'] ?? 'Documento para Assinatura').toString(),
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Enviado por ${org['name'] ?? 'SignProof'}',
                        style: const TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: pendingFields.isEmpty ? Colors.green.withOpacity(0.2) : AppTheme.tealNeon.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: pendingFields.isEmpty ? Colors.green : AppTheme.tealNeon),
                  ),
                  child: Text(
                    pendingFields.isEmpty ? 'Pronto para Concluir' : '${pendingFields.length} Campo(s) Restante(s)',
                    style: TextStyle(
                      color: pendingFields.isEmpty ? Colors.greenAccent : AppTheme.tealNeon,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Main Content
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // PDF Viewer Area
                Expanded(
                  flex: 3,
                  child: Container(
                    padding: const EdgeInsets.all(32),
                    color: const Color(0xFF0F172A),
                    child: Center(
                      child: AspectRatio(
                        aspectRatio: 800 / 1100, // Standard document ratio
                        child: _buildPdfView(fields, signer),
                      ),
                    ),
                  ),
                ),

                // Action Sidebar
                Container(
                  width: 340,
                  decoration: const BoxDecoration(
                    color: Color(0xFF1E293B),
                    border: Border(left: BorderSide(color: Colors.white12)),
                  ),
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (signer['auth_method'] == 'email_token') ...[
                        const Text(
                          'Verificação de Identidade',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Para garantir a validade jurídica, confirme seu e-mail.',
                          style: TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _tokenController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'Código do E-mail',
                            labelStyle: const TextStyle(color: Colors.white54),
                            filled: true,
                            fillColor: Colors.black26,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                            suffixIcon: TextButton(
                              onPressed: _isSendingCode ? null : _requestVerificationToken,
                              child: Text(_isSendingCode ? '...' : 'Enviar'),
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                      ],

                      if (_state == 'validation' && pendingValidations.isNotEmpty) ...[
                        const Text(
                          'Validação Valeris',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 16),
                        if (kIsWeb)
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: ValerisFrame(
                                serviceUrl: _validationServicePath((pendingValidations.first['StepType'] ?? '').toString()),
                                onCaptureSuccess: (serviceType, captureId) {
                                  _completeValidation(
                                    pendingValidations.first,
                                    details: 'Captura Valeris $captureId',
                                  );
                                },
                              ),
                            ),
                          ),
                      ],

                      if (_state != 'validation')
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                pendingFields.isEmpty ? LucideIcons.checkCircle2 : LucideIcons.pencil,
                                size: 48,
                                color: pendingFields.isEmpty ? Colors.greenAccent : AppTheme.tealNeon,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                pendingFields.isEmpty 
                                    ? 'Todos os campos preenchidos!' 
                                    : 'Por favor, assine todos os campos indicados no documento ao lado.',
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.white70, fontSize: 14),
                              ),
                            ],
                          ),
                        ),

                      const SizedBox(height: 24),
                      if (pendingFields.isEmpty)
                        ElevatedButton(
                          onPressed: pendingValidations.isNotEmpty
                              ? () => setState(() => _state = 'validation')
                              : _signDocument,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: pendingValidations.isNotEmpty ? Colors.blueAccent : Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: Text(
                            pendingValidations.isNotEmpty ? 'Iniciar Validação' : 'Finalizar Assinatura',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
    );
  }
}
