import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import '../../core/api_config.dart';
import '../../core/app_theme.dart';
import '../widgets/glass_container.dart';
import '../widgets/pdf_viewer.dart';
import 'dart:typed_data';
import 'package:web/web.dart' as web;
import 'dart:js_interop';
import 'package:pointer_interceptor/pointer_interceptor.dart';

class _SignerDraft {
  _SignerDraft({
    required this.name,
    required this.email,
    required this.cpf,
    required this.phone,
    required this.role,
    required this.authMethod,
    required this.requiredValidations,
  });

  final String name;
  final String email;
  final String cpf;
  final String phone;
  final String role;
  final String authMethod;
  final List<String> requiredValidations;
}

class _FieldDraft {
  _FieldDraft({
    required this.fieldType,
    required this.page,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.signerIndex,
  });

  final String fieldType;
  final int page;
  final double x;
  final double y;
  final double width;
  final double height;
  final int signerIndex;
}

class DocumentFlowPage extends StatefulWidget {
  const DocumentFlowPage({super.key});

  @override
  State<DocumentFlowPage> createState() => _DocumentFlowPageState();
}

class _DocumentFlowPageState extends State<DocumentFlowPage> {
  int _currentStep = 0;

  static const List<String> _stepLabels = <String>[
    'DOCUMENTO',
    'SIGNATARIOS',
    'CAMPOS',
    'CONFIGURAR',
    'ENVIAR',
  ];
  static const List<IconData> _stepIcons = <IconData>[
    LucideIcons.filePlus,
    LucideIcons.users,
    Icons.edit,
    LucideIcons.settings2,
    LucideIcons.send,
  ];

  // Step 1
  final TextEditingController _docNameController = TextEditingController();
  final TextEditingController _templateContentController =
      TextEditingController();
  PlatformFile? _selectedFile;
  List<Map<String, dynamic>> _templates = <Map<String, dynamic>>[];
  String? _selectedTemplateId;
  bool _templateHasFile = false;

  // Step 2
  final List<_SignerDraft> _signers = <_SignerDraft>[];
  final TextEditingController _signerNameController = TextEditingController();
  final TextEditingController _signerEmailController = TextEditingController();
  final TextEditingController _signerCpfController = TextEditingController();
  final TextEditingController _signerPhoneController = TextEditingController();
  List<Map<String, dynamic>> _contacts = <Map<String, dynamic>>[];
  String? _selectedContactEmail;
  String _authMethod = 'email_token';
  String _signerRole = 'Signatario';
  bool _requireSelfie = false;
  bool _requireDocumentPhoto = false;
  bool _requireSelfieWithDocument = false;

  // Step 3
  int _activePage = 1;
  int _totalPages = 1;
  int _activeSignerIndex = 0;
  String _activeFieldType = 'signature';
  final List<_FieldDraft> _fields = <_FieldDraft>[];
  String? _temporaryDocUrl;
  double _zoomLevel = 1.0;
  final GlobalKey _canvasKey = GlobalKey();

  // Step 4
  bool _sequentialFlow = true;
  final TextEditingController _messageController = TextEditingController();
  bool _enableReminders = true;
  int _reminderDays = 3;
  String _emailLanguage = 'pt-BR';
  DateTime? _deadline;

  bool _isSaving = false;

  final List<Color> _signerColors = [
    const Color(0xFF0D9488),
    const Color(0xFFF59E0B),
    const Color(0xFF3B82F6),
    const Color(0xFF8B5CF6),
    const Color(0xFFEF4444),
  ];

  @override
  void initState() {
    super.initState();
    _fetchContacts();
    _fetchTemplates();
  }

  Future<void> _fetchContacts() async {
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
      });
    }
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

  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'png', 'doc', 'docx'],
      withData: true,
    );
    if (result != null) {
      setState(() {
        _selectedFile = result.files.first;
        // Create a blob URL for local preview
        final blob = web.Blob([(_selectedFile!.bytes as Uint8List).toJS].toJS, web.BlobPropertyBag(type: 'application/pdf'));
        _temporaryDocUrl = web.URL.createObjectURL(blob);
      });
    }
  }

  Future<void> _submitDocumentFlow() async {
    final useTemplateOnly =
        _selectedTemplateId != null && _selectedFile == null;
    if (!useTemplateOnly &&
        (_selectedFile == null || _selectedFile!.bytes == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecione arquivo ou modelo para continuar'),
        ),
      );
      return;
    }
    if (_signers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Adicione ao menos um signatário')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      late Map<String, dynamic> uploadJson;
      if (useTemplateOnly) {
        final res = await http.post(
          Uri.parse('${ApiConfig.baseUrl}/api/v1/documents/from-template'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'template_id': _selectedTemplateId,
            'name': _docNameController.text.trim(),
            'custom_content': _templateContentController.text.trim(),
          }),
        );
        if (res.statusCode != 201 && res.statusCode != 200) {
          throw Exception('Falha ao criar documento a partir do modelo');
        }
        uploadJson = jsonDecode(res.body) as Map<String, dynamic>;
      } else {
        final request = http.MultipartRequest(
          'POST',
          Uri.parse('${ApiConfig.baseUrl}/api/v1/documents/upload'),
        );
        request.headers['Authorization'] = 'Bearer $token';
        request.fields['name'] = _docNameController.text.isNotEmpty
            ? _docNameController.text
            : _selectedFile!.name;
        request.files.add(
          http.MultipartFile.fromBytes(
            'file',
            _selectedFile!.bytes!,
            filename: _selectedFile!.name,
          ),
        );

        final resUpload = await request.send();
        final uploadBody = await resUpload.stream.bytesToString();
        if (resUpload.statusCode != 201 && resUpload.statusCode != 200) {
          throw Exception('Falha na transferência do arquivo pro MinIO: \$uploadBody');
        }
        uploadJson = jsonDecode(uploadBody) as Map<String, dynamic>;
      }

      final docId = (uploadJson['ID'] ?? uploadJson['id']) as String?;
      if (docId == null || docId.isEmpty) {
        throw Exception('ID do documento não retornado no upload');
      }

      // 2) Add signers in flow order
      final signerIds = <String>[];
      for (int i = 0; i < _signers.length; i++) {
        final signer = _signers[i];
        final payload = <String, dynamic>{
          'name': signer.name,
          'email': signer.email,
          'cpf': signer.cpf,
          'phone': signer.phone,
          'signature_type': 'assinar',
          'auth_method': signer.authMethod,
          'role': signer.role,
          'sign_order': i + 1,
          'required_validations': signer.requiredValidations,
        };

        final resSigner = await http.post(
          Uri.parse('${ApiConfig.baseUrl}/api/v1/documents/$docId/signers'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(payload),
        );

        if (resSigner.statusCode != 201) {
          throw Exception('Falha ao registrar signatário ${signer.email}');
        }

        final signerBody = jsonDecode(resSigner.body) as Map<String, dynamic>;
        final signerId = (signerBody['ID'] ?? signerBody['id'])?.toString();
        if (signerId != null && signerId.isNotEmpty) {
          signerIds.add(signerId);
        }
      }

      // 3) Save visual fields
      if (_fields.isNotEmpty) {
        final fieldsPayload = {
          'fields': _fields.map((f) {
            String? signerId;
            if (f.signerIndex >= 0 && f.signerIndex < signerIds.length) {
              signerId = signerIds[f.signerIndex];
            }
            return {
              'signer_id': signerId,
              'field_type': f.fieldType,
              'x': f.x,
              'y': f.y,
              'width': f.width,
              'height': f.height,
              'page': f.page,
              'value': '',
            };
          }).toList(),
        };
        final resFields = await http.post(
          Uri.parse('${ApiConfig.baseUrl}/api/v1/documents/$docId/fields'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(fieldsPayload),
        );
        if (resFields.statusCode != 201) {
          throw Exception('Falha ao registrar campos');
        }
      }

      // 4) Save validation steps by signer
      final steps = <Map<String, dynamic>>[];
      for (int i = 0; i < _signers.length && i < signerIds.length; i++) {
        final signer = _signers[i];
        for (
          int order = 0;
          order < signer.requiredValidations.length;
          order++
        ) {
          steps.add({
            'signer_id': signerIds[i],
            'step_type': signer.requiredValidations[order],
            'order': order + 1,
            'required': true,
          });
        }
      }
      if (steps.isNotEmpty) {
        final resSteps = await http.post(
          Uri.parse(
            '${ApiConfig.baseUrl}/api/v1/documents/$docId/validation-steps',
          ),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'steps': steps}),
        );
        if (resSteps.statusCode != 201) {
          throw Exception('Falha ao registrar etapas de validação');
        }
      }

      // 5) Save configs
      final configRes = await http.put(
        Uri.parse('${ApiConfig.baseUrl}/api/v1/documents/$docId/config'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'message': _messageController.text.trim(),
          'deadline': _deadline?.toIso8601String(),
          'sequential_flow': _sequentialFlow,
          'notify_language': _emailLanguage,
          'reminder_days': _enableReminders ? _reminderDays : 0,
        }),
      );
      if (configRes.statusCode != 200) {
        throw Exception('Falha ao salvar configurações');
      }

      // 6) Send document
      final resSend = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/v1/documents/$docId/send'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (resSend.statusCode != 200)
        throw Exception('Falha no disparo do documento');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Missão concluída: Documento disparado!',
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: AppTheme.tealNeon,
          ),
        );
        context.go('/documents');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Erro no fluxo: $e',
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _docNameController.dispose();
    _templateContentController.dispose();
    _signerNameController.dispose();
    _signerEmailController.dispose();
    _signerCpfController.dispose();
    _signerPhoneController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _addSigner() {
    final name = _signerNameController.text.trim();
    final email = _signerEmailController.text.trim();
    if (name.isEmpty || email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nome e email são obrigatórios')),
      );
      return;
    }

    final validations = <String>[
      if (_requireSelfie) 'selfie',
      if (_requireDocumentPhoto) 'doc_photo',
      if (_requireSelfieWithDocument) 'selfie_with_document',
    ];

    setState(() {
      _signers.add(
        _SignerDraft(
          name: name,
          email: email,
          cpf: _signerCpfController.text.trim(),
          phone: _signerPhoneController.text.trim(),
          role: _signerRole,
          authMethod: _authMethod,
          requiredValidations: validations,
        ),
      );
      _signerNameController.clear();
      _signerEmailController.clear();
      _signerCpfController.clear();
      _signerPhoneController.clear();
      _requireSelfie = false;
      _requireDocumentPhoto = false;
      _requireSelfieWithDocument = false;
    });
  }

  void _moveSigner(int index, int delta) {
    final newIndex = index + delta;
    if (newIndex < 0 || newIndex >= _signers.length) return;
    setState(() {
      final signer = _signers.removeAt(index);
      _signers.insert(newIndex, signer);
    });
  }



  bool _validateCurrentStep() {
    if (_currentStep == 0 &&
        _selectedFile == null &&
        _selectedTemplateId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecione arquivo ou modelo para continuar'),
        ),
      );
      return false;
    }
    if (_currentStep == 1 && _signers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Adicione ao menos um signatário')),
      );
      return false;
    }
    return true;
  }

  Widget _buildStepIndicator(int stepIndex, String label, IconData icon) {
    final isActive = _currentStep == stepIndex;
    final isCompleted = _currentStep > stepIndex;

    final color = isCompleted
        ? AppTheme.goldSoft
        : (isActive ? AppTheme.tealNeon : Colors.white24);

    return Expanded(
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withOpacity(0.1),
              border: Border.all(color: color, width: isActive ? 2 : 1),
              boxShadow: isActive || isCompleted
                  ? [BoxShadow(color: color.withOpacity(0.5), blurRadius: 10)]
                  : [],
            ),
            child: Icon(
              isCompleted ? LucideIcons.check : icon,
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              fontFamily: 'Orbitron',
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLineIndicator(int stepIndex) {
    final isCompleted = _currentStep > stepIndex;
    final color = isCompleted ? AppTheme.goldSoft : Colors.white12;
    return Expanded(
      child: Container(
        height: 2,
        decoration: BoxDecoration(
          color: color,
          boxShadow: isCompleted
              ? [BoxShadow(color: color.withOpacity(0.5), blurRadius: 4)]
              : [],
        ),
      ),
    );
  }

  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'DADOS DO ARQUIVO',
          style: TextStyle(
            fontFamily: 'Orbitron',
            fontSize: 12,
            color: AppTheme.tealNeon,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _docNameController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Nome da Missão (Opcional)',
            labelStyle: const TextStyle(
              color: Colors.white54,
              fontFamily: 'Orbitron',
            ),
            filled: true,
            fillColor: Colors.black.withOpacity(0.2),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.white12),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.tealNeon),
            ),
          ),
        ),
        const SizedBox(height: 24),
        DropdownButtonFormField<String>(
          value: _selectedTemplateId,
          dropdownColor: const Color(0xFF172226),
          decoration: InputDecoration(
            labelText: 'Usar modelo (opcional)',
            labelStyle: const TextStyle(color: Colors.white54),
            filled: true,
            fillColor: Colors.black.withOpacity(0.2),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.white12),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.tealNeon),
            ),
          ),
          items: _templates
              .map(
                (t) => DropdownMenuItem<String>(
                  value: t['ID']?.toString(),
                  child: Text((t['Name'] ?? '-').toString()),
                ),
              )
              .toList(),
          onChanged: (value) {
            setState(() => _selectedTemplateId = value);
            if (value == null) return;
            final selected = _templates.firstWhere(
              (e) => e['ID'].toString() == value,
              orElse: () => {},
            );
            if (selected.isEmpty) return;
            _templateHasFile = (selected['FileKey'] ?? '')
                .toString()
                .trim()
                .isNotEmpty;
            _docNameController.text = (selected['Name'] ?? '').toString();
            _templateContentController.text = (selected['Content'] ?? '')
                .toString();
          },
        ),
        const SizedBox(height: 10),
        if (_selectedTemplateId != null) ...[
          Row(
            children: [
              Expanded(
                child: Text(
                  _templateHasFile
                      ? 'Modelo com documento base anexado.'
                      : 'Modelo sem arquivo: use editor de conteúdo.',
                  style: TextStyle(
                    color: _templateHasFile
                        ? AppTheme.goldSoft
                        : Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ),
              OutlinedButton(
                onPressed: () async {
                  await showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('Conteúdo do modelo'),
                      content: SizedBox(
                        width: 820,
                        child: TextField(
                          controller: _templateContentController,
                          maxLines: 18,
                          decoration: const InputDecoration(
                            hintText:
                                'Digite conteúdo markdown do documento...',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Fechar'),
                        ),
                      ],
                    ),
                  );
                  if (mounted) setState(() {});
                },
                child: const Text('Editar conteúdo'),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        InkWell(
          onTap: _pickFile,
          child: Container(
            height: 180,
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border.all(
                color: _selectedFile == null
                    ? AppTheme.tealNeon.withOpacity(0.5)
                    : AppTheme.goldSoft.withOpacity(0.5),
                width: 2,
              ),
              borderRadius: BorderRadius.circular(16),
              color: Colors.black.withOpacity(0.3),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _selectedFile == null
                        ? LucideIcons.uploadCloud
                        : LucideIcons.fileCheck,
                    size: 48,
                    color: _selectedFile == null
                        ? AppTheme.tealNeon
                        : AppTheme.goldSoft,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _selectedFile == null
                        ? 'INSERIR ARQUIVO'
                        : 'MATRIZ CARREGADA',
                    style: TextStyle(
                      fontFamily: 'Orbitron',
                      color: _selectedFile == null
                          ? AppTheme.tealNeon
                          : AppTheme.goldSoft,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                  if (_selectedFile != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        _selectedFile!.name,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStep2() {
    final roleOptions = <String>[
      'Signatario',
      'Testemunha',
      'Aprovador',
      'Fiador',
      'Avalista',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'SIGNATARIOS E VALIDACOES',
          style: TextStyle(
            fontFamily: 'Orbitron',
            fontSize: 12,
            color: AppTheme.tealNeon,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: _selectedContactEmail,
          dropdownColor: const Color(0xFF172226),
          decoration: InputDecoration(
            labelText: 'Selecionar contato salvo (opcional)',
            labelStyle: const TextStyle(color: Colors.white54),
            filled: true,
            fillColor: Colors.black.withOpacity(0.2),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.white12),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.tealNeon),
            ),
          ),
          items: _contacts
              .map(
                (c) => DropdownMenuItem<String>(
                  value: (c['email'] ?? '').toString(),
                  child: Text(
                    '${c['name'] ?? '-'} • ${c['email'] ?? '-'}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          onChanged: (value) {
            setState(() => _selectedContactEmail = value);
            if (value == null) return;
            final selected = _contacts.firstWhere(
              (e) => (e['email'] ?? '').toString() == value,
              orElse: () => {},
            );
            if (selected.isEmpty) return;
            _signerNameController.text = (selected['name'] ?? '').toString();
            _signerEmailController.text = (selected['email'] ?? '').toString();
            _signerPhoneController.text = (selected['phone'] ?? '').toString();
            _signerRole = (selected['default_role'] ?? 'Signatario').toString();
            _authMethod = (selected['default_auth_method'] ?? 'email_token')
                .toString();
            final vals =
                (selected['default_validations'] as List<dynamic>? ?? [])
                    .map((e) => e.toString())
                    .toList();
            _requireSelfie = vals.contains('selfie');
            _requireDocumentPhoto = vals.contains('doc_photo');
            _requireSelfieWithDocument = vals.contains('selfie_with_document');
          },
        ),
        const SizedBox(height: 12),
        GlassContainer(
          borderRadius: 16,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              TextField(
                controller: _signerNameController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Nome Completo',
                  labelStyle: const TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: Colors.black.withOpacity(0.2),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.white12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.tealNeon),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _signerEmailController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Canal (E-mail)',
                        labelStyle: const TextStyle(color: Colors.white54),
                        filled: true,
                        fillColor: Colors.black.withOpacity(0.2),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.white12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: AppTheme.tealNeon,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _signerCpfController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'CPF',
                        labelStyle: const TextStyle(color: Colors.white54),
                        filled: true,
                        fillColor: Colors.black.withOpacity(0.2),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.white12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: AppTheme.tealNeon,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _signerPhoneController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Telefone',
                  labelStyle: const TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: Colors.black.withOpacity(0.2),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.white12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.tealNeon),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _signerRole,
                      dropdownColor: const Color(0xFF172226),
                      decoration: InputDecoration(
                        labelText: 'Papel',
                        labelStyle: const TextStyle(color: Colors.white54),
                        filled: true,
                        fillColor: Colors.black.withOpacity(0.2),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.white12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: AppTheme.tealNeon,
                          ),
                        ),
                      ),
                      items: roleOptions
                          .map(
                            (r) => DropdownMenuItem<String>(
                              value: r,
                              child: Text(r),
                            ),
                          )
                          .toList(),
                      onChanged: (value) =>
                          setState(() => _signerRole = value ?? 'Signatario'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _authMethod,
                      dropdownColor: const Color(0xFF172226),
                      decoration: InputDecoration(
                        labelText: 'Autenticacao',
                        labelStyle: const TextStyle(color: Colors.white54),
                        filled: true,
                        fillColor: Colors.black.withOpacity(0.2),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.white12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: AppTheme.tealNeon,
                          ),
                        ),
                      ),
                      items: const [
                        DropdownMenuItem<String>(
                          value: 'email_token',
                          child: Text('Token via Email'),
                        ),
                        DropdownMenuItem<String>(
                          value: 'biometria_facial',
                          child: Text('Biometria Facial'),
                        ),
                      ],
                      onChanged: (value) =>
                          setState(() => _authMethod = value ?? 'email_token'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 8,
                  children: [
                    FilterChip(
                      selected: _requireSelfie,
                      onSelected: (v) => setState(() => _requireSelfie = v),
                      label: const Text('Selfie'),
                      selectedColor: AppTheme.tealNeon.withOpacity(0.25),
                      checkmarkColor: AppTheme.tealNeon,
                      labelStyle: const TextStyle(color: Colors.white),
                      side: const BorderSide(color: Colors.white24),
                    ),
                    FilterChip(
                      selected: _requireDocumentPhoto,
                      onSelected: (v) =>
                          setState(() => _requireDocumentPhoto = v),
                      label: const Text('Foto Documento'),
                      selectedColor: AppTheme.goldSoft.withOpacity(0.25),
                      checkmarkColor: AppTheme.goldSoft,
                      labelStyle: const TextStyle(color: Colors.white),
                      side: const BorderSide(color: Colors.white24),
                    ),
                    FilterChip(
                      selected: _requireSelfieWithDocument,
                      onSelected: (v) =>
                          setState(() => _requireSelfieWithDocument = v),
                      label: const Text('Selfie com Documento'),
                      selectedColor: AppTheme.tealMedium.withOpacity(0.25),
                      checkmarkColor: AppTheme.tealMedium,
                      labelStyle: const TextStyle(color: Colors.white),
                      side: const BorderSide(color: Colors.white24),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(LucideIcons.userPlus),
                  label: const Text('Adicionar Signatario'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.tealNeon,
                    foregroundColor: Colors.black,
                  ),
                  onPressed: _addSigner,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'ORDEM DO FLUXO',
          style: TextStyle(
            fontFamily: 'Orbitron',
            fontSize: 12,
            color: AppTheme.goldSoft,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 8),
        if (_signers.isEmpty)
          const Text(
            'Nenhum signatário adicionado.',
            style: TextStyle(color: Colors.white60),
          )
        else
          Column(
            children: List<Widget>.generate(_signers.length, (index) {
              final signer = _signers[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(99),
                        color: AppTheme.goldSoft.withOpacity(0.2),
                      ),
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(
                          color: AppTheme.goldSoft,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            signer.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${signer.email} • ${signer.role}',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                          if (signer.requiredValidations.isNotEmpty)
                            Text(
                              'Validações: ${signer.requiredValidations.join(", ")}',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => _moveSigner(index, -1),
                      icon: const Icon(
                        LucideIcons.arrowUp,
                        color: Colors.white70,
                        size: 18,
                      ),
                    ),
                    IconButton(
                      onPressed: () => _moveSigner(index, 1),
                      icon: const Icon(
                        LucideIcons.arrowDown,
                        color: Colors.white70,
                        size: 18,
                      ),
                    ),
                    IconButton(
                      onPressed: () => setState(() => _signers.removeAt(index)),
                      icon: const Icon(
                        LucideIcons.trash2,
                        color: Colors.redAccent,
                        size: 18,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ],
      );
  }
  Widget _buildStep3() {
    return Column(
      children: [
        // Exact Header from Reference
        Container(
          height: 70,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            border: Border(bottom: BorderSide(color: AppTheme.tealNeon.withOpacity(0.3))),
          ),
          child: Row(
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Etapa 3 de 4',
                    style: TextStyle(fontSize: 12, color: AppTheme.tealNeon, fontWeight: FontWeight.normal),
                  ),
                  const Text(
                    'Configurar envio',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ],
              ),
              const Spacer(),
              _buildHeaderPill(
                icon: LucideIcons.users,
                label: '${_signers.isEmpty ? 0 : 1}/${_signers.length} signatários',
              ),
              const SizedBox(width: 12),
              _buildHeaderPill(
                icon: LucideIcons.fileSignature,
                label: '${_fields.length} campo(s)',
              ),
            ],
          ),
        ),
        Expanded(
          child: Row(
            children: [
              _buildLeftSidebar(),
              const VerticalDivider(width: 1, color: Color(0xFFE2E8F0)),
              Expanded(child: _buildCenterCanvas()),
              const VerticalDivider(width: 1, color: Color(0xFFE2E8F0)),
              _buildRightSidebar(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderPill({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.tealMedium.withOpacity(0.2),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: AppTheme.tealNeon.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppTheme.tealNeon),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildLeftSidebar() {
    return Container(
      width: 280,
      color: Colors.transparent,
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle('ATRIBUIR CAMPOS PARA'),
                  const SizedBox(height: 12),
                  _buildSignerDropdown(),
                  const SizedBox(height: 32),
                  _buildSectionTitle('ARRASTE OS CAMPOS'),
                  const SizedBox(height: 16),
                  _buildStep3ToolItem(LucideIcons.penTool, 'Assinatura', 'signature'),
                  _buildStep3ToolItem(LucideIcons.atSign, 'Iniciais', 'initial'),
                  _buildStep3ToolItem(LucideIcons.calendar, 'Data', 'date'),
                  _buildStep3ToolItem(LucideIcons.type, 'Texto', 'text'),
                  _buildStep3ToolItem(LucideIcons.checkSquare, 'Checkbox', 'checkbox'),
                  _buildStep3ToolItem(LucideIcons.hash, 'Número', 'number'),
                  _buildStep3ToolItem(LucideIcons.mail, 'Email', 'email'),
                  _buildStep3ToolItem(LucideIcons.image, 'Imagem', 'image'),
                ],
              ),
            ),
          ),
          const Divider(height: 1, color: Colors.white12),
          Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionTitle('CAMPOS POR SIGNATÁRIO'),
                const SizedBox(height: 16),
                if (_signers.isEmpty)
                  const Text('Nenhum signatário', style: TextStyle(color: Colors.white54, fontSize: 13))
                else
                  ...List.generate(_signers.length, (index) {
                    final count = _fields.where((f) => f.signerIndex == index).length;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _signerColors[index % _signerColors.length],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _signers[index].name,
                              style: const TextStyle(fontSize: 13, color: Colors.white70),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$count',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        color: AppTheme.tealNeon,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildSignerDropdown() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.tealNeon.withOpacity(0.3)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButtonFormField<int>(
          dropdownColor: const Color(0xFF172226),
          value: _activeSignerIndex,
          decoration: const InputDecoration(
            contentPadding: EdgeInsets.symmetric(horizontal: 16),
            border: InputBorder.none,
          ),
          items: List.generate(_signers.length, (i) {
            return DropdownMenuItem(
              value: i,
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: _signerColors[i % _signerColors.length],
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _signers[i].name,
                    style: const TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            );
          }),
          onChanged: (v) => setState(() => _activeSignerIndex = v ?? 0),
        ),
      ),
    );
  }

  Widget _buildStep3ToolItem(IconData icon, String label, String type) {
    final isActive = _activeFieldType == type;
    return Draggable<String>(
      data: type,
      feedback: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.tealDark.withOpacity(0.8),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [BoxShadow(color: AppTheme.tealNeon.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4))],
            border: Border.all(color: AppTheme.tealNeon),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: AppTheme.tealNeon),
              const SizedBox(width: 12),
              Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
            ],
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: InkWell(
          onTap: () => setState(() => _activeFieldType = type),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isActive ? Colors.white.withOpacity(0.1) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isActive ? AppTheme.tealNeon : Colors.white12),
            ),
            child: Row(
              children: [
                Icon(icon, size: 20, color: isActive ? AppTheme.tealNeon : Colors.white70),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                    color: isActive ? AppTheme.tealNeon : Colors.white70,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCenterCanvas() {
    return Container(
      color: Colors.transparent,
      child: Column(
        children: [
          // Center Toolbar
          Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: const BoxDecoration(
              color: Colors.transparent,
              border: Border(bottom: BorderSide(color: Colors.white12)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    _buildPageNavButton(
                      icon: LucideIcons.chevronLeft,
                      onPressed: _activePage > 1 ? () => setState(() => _activePage--) : null,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Página $_activePage de $_totalPages',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(width: 8),
                    _buildPageNavButton(
                      icon: LucideIcons.chevronRight,
                      onPressed: _activePage < _totalPages ? () => setState(() => _activePage++) : null,
                    ),
                  ],
                ),
                Row(
                  children: [
                    _buildPageNavButton(
                      icon: LucideIcons.zoomOut,
                      onPressed: _zoomLevel > 0.5 ? () => setState(() => _zoomLevel -= 0.1) : null,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${(_zoomLevel * 100).toInt()}%',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(width: 8),
                    _buildPageNavButton(
                      icon: LucideIcons.zoomIn,
                      onPressed: _zoomLevel < 3.0 ? () => setState(() => _zoomLevel += 0.1) : null,
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return DragTarget<String>(
                  onAcceptWithDetails: (details) {
                    final box = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
                    if (box == null) return;
                    final localOffset = box.globalToLocal(details.offset);
                    _addFieldAt(
                      localOffset,
                      Size(box.size.width, box.size.height),
                      type: details.data,
                    );
                  },
                  builder: (context, candidateData, _) {
                    final highlight = candidateData.isNotEmpty;
                    return SingleChildScrollView(
                      padding: const EdgeInsets.all(40),
                      child: Center(
                        child: Transform.scale(
                          scale: _zoomLevel,
                          alignment: Alignment.topCenter,
                          child: Container(
                            key: _canvasKey,
                            width: 800,
                            height: 1100,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 20, offset: Offset(0, 10))],
                              border: highlight ? Border.all(color: AppTheme.tealNeon, width: 2) : null,
                            ),
                            child: _temporaryDocUrl != null
                                ? Stack(
                                    children: [
                                      SizedBox.expand(
                                        child: PdfViewer(
                                          fileUrl: _temporaryDocUrl!,
                                          currentPage: _activePage,
                                        ),
                                      ),
                                      Positioned.fill(
                                        child: GestureDetector(
                                          behavior: HitTestBehavior.opaque,
                                          onTapDown: (details) => _addFieldAt(
                                            details.localPosition,
                                            const Size(800, 1100),
                                          ),
                                          child: Container(color: Colors.transparent),
                                        ),
                                      ),
                                      ..._fields
                                          .where((f) => f.page == _activePage)
                                          .map((f) => _buildReplicatedField(f))
                                          .toList(),
                                    ],
                                  )
                                : Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(LucideIcons.fileText, size: 48, color: const Color(0xFFCBD5E1)),
                                        const SizedBox(height: 16),
                                        const Text(
                                          'Selecione um documento na Etapa 1 para visualizá-lo aqui.',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                                        ),
                                      ],
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReplicatedField(_FieldDraft field) {
    // Relative positioning handled by PdfViewer internal stack
    // But since we are passing children to PdfViewer, it should handle them.
    // If PdfViewer uses a Stack, we use Positioned.
    final color = _signerColors[field.signerIndex % _signerColors.length];
    
    return Positioned(
      left: field.x * 800, // Assuming 800 baseline
      top: field.y * 1100, // Assuming 1100 baseline
      child: Container(
        width: field.width * 800,
        height: field.height * 1100,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color, width: 2),
        ),
        child: Stack(
          children: [
            Center(
              child: Text(
                field.fieldType.toUpperCase(),
                style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold),
              ),
            ),
            Positioned(
              right: 2,
              top: 2,
              child: GestureDetector(
                onTap: () => setState(() => _fields.remove(field)),
                child: Icon(LucideIcons.xCircle, size: 14, color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRightSidebar() {
    return Container(
      width: 280,
      color: Colors.white,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: _buildSectionTitle('PROPRIEDADES'),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.mousePointer2, size: 40, color: const Color(0xFFCBD5E1)),
                    const SizedBox(height: 16),
                    const Text(
                      'Selecione um campo para editar suas propriedades',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionTitle('PÁGINAS'),
                const SizedBox(height: 16),
                SizedBox(
                  height: 80,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _totalPages,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      final p = index + 1;
                      final isActive = _activePage == p;
                      return GestureDetector(
                        onTap: () => setState(() => _activePage = p),
                        child: Container(
                          width: 60,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFB),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isActive ? const Color(0xFF0D9488) : const Color(0xFFE2E8F0),
                              width: isActive ? 2 : 1,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              '$p',
                              style: TextStyle(
                                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                                color: isActive ? const Color(0xFF0D9488) : const Color(0xFF64748B),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _addFieldAt(Offset localPosition, Size size, {String? type}) {
    if (_signers.isEmpty) return;
    final fieldType = type ?? _activeFieldType;
    final normalizedX = (localPosition.dx / size.width).clamp(0.0, 0.95);
    final normalizedY = (localPosition.dy / size.height).clamp(0.0, 0.95);

    setState(() {
      _fields.add(
        _FieldDraft(
          fieldType: fieldType,
          page: _activePage,
          x: normalizedX,
          y: normalizedY,
          width: 0.18,
          height: 0.05,
          signerIndex: _activeSignerIndex.clamp(0, _signers.length - 1),
        ),
      );
    });
  }

  Widget _buildPageNavButton({required IconData icon, VoidCallback? onPressed}) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(icon, color: onPressed == null ? Colors.white38 : Colors.white),
      style: IconButton.styleFrom(
        backgroundColor: Colors.white.withOpacity(0.1),
        padding: const EdgeInsets.all(8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }



  Widget _buildStep4() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'CONFIGURACOES DA MISSAO',
          style: TextStyle(
            fontFamily: 'Orbitron',
            fontSize: 12,
            color: AppTheme.tealNeon,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 16),
        SwitchListTile(
          value: _sequentialFlow,
          activeColor: AppTheme.goldSoft,
          title: const Text(
            'Fluxo sequencial',
            style: TextStyle(color: Colors.white),
          ),
          subtitle: const Text(
            'Signatário seguinte recebe após o anterior',
            style: TextStyle(color: Colors.white60),
          ),
          onChanged: (value) => setState(() => _sequentialFlow = value),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _messageController,
          maxLines: 3,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Mensagem opcional',
            labelStyle: const TextStyle(color: Colors.white54),
            filled: true,
            fillColor: Colors.black.withOpacity(0.2),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.white12),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.tealNeon),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SwitchListTile(
          value: _enableReminders,
          activeColor: AppTheme.tealNeon,
          title: const Text(
            'Lembretes automáticos',
            style: TextStyle(color: Colors.white),
          ),
          subtitle: const Text(
            'Enviar lembretes para signatários pendentes',
            style: TextStyle(color: Colors.white60),
          ),
          onChanged: (value) => setState(() => _enableReminders = value),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<int>(
          value: _reminderDays,
          dropdownColor: const Color(0xFF172226),
          decoration: InputDecoration(
            labelText: 'Intervalo dos lembretes',
            labelStyle: const TextStyle(color: Colors.white54),
            filled: true,
            fillColor: Colors.black.withOpacity(0.2),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.white12),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.tealNeon),
            ),
          ),
          items: const [
            DropdownMenuItem(value: 1, child: Text('A cada 1 dia')),
            DropdownMenuItem(value: 2, child: Text('A cada 2 dias')),
            DropdownMenuItem(value: 3, child: Text('A cada 3 dias')),
            DropdownMenuItem(value: 7, child: Text('A cada 7 dias')),
          ],
          onChanged: _enableReminders
              ? (value) => setState(() => _reminderDays = value ?? 3)
              : null,
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _emailLanguage,
          dropdownColor: const Color(0xFF172226),
          decoration: InputDecoration(
            labelText: 'Idioma do e-mail',
            labelStyle: const TextStyle(color: Colors.white54),
            filled: true,
            fillColor: Colors.black.withOpacity(0.2),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.white12),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.tealNeon),
            ),
          ),
          items: const [
            DropdownMenuItem(value: 'pt-BR', child: Text('Português (Brasil)')),
            DropdownMenuItem(value: 'en', child: Text('English')),
            DropdownMenuItem(value: 'es', child: Text('Español')),
          ],
          onChanged: (value) =>
              setState(() => _emailLanguage = value ?? 'pt-BR'),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: DateTime.now().add(const Duration(days: 7)),
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 365)),
            );
            if (picked != null) {
              setState(() => _deadline = picked);
            }
          },
          icon: const Icon(LucideIcons.calendar),
          label: Text(
            _deadline == null
                ? 'Definir prazo'
                : 'Prazo: ${_deadline!.toIso8601String().split("T").first}',
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            side: const BorderSide(color: Colors.white30),
          ),
        ),
      ],
    );
  }

  Widget _buildStep5() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'REVISAO E ENVIO',
          style: TextStyle(
            fontFamily: 'Orbitron',
            fontSize: 12,
            color: AppTheme.goldSoft,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Documento: ${_docNameController.text.isEmpty ? (_selectedFile?.name ?? '-') : _docNameController.text}',
          style: const TextStyle(color: Colors.white70),
        ),
        const SizedBox(height: 6),
        Text(
          'Signatários: ${_signers.length}',
          style: const TextStyle(color: Colors.white70),
        ),
        const SizedBox(height: 6),
        Text(
          'Campos: ${_fields.length}',
          style: const TextStyle(color: Colors.white70),
        ),
        const SizedBox(height: 6),
        Text(
          'Fluxo: ${_sequentialFlow ? "Sequencial" : "Paralelo"}',
          style: const TextStyle(color: Colors.white70),
        ),
        const SizedBox(height: 6),
        Text(
          'Idioma: $_emailLanguage | Lembrete: ${_enableReminders ? "a cada $_reminderDays dia(s)" : "desativado"}',
          style: const TextStyle(color: Colors.white70),
        ),
        if (_deadline != null) ...[
          const SizedBox(height: 6),
          Text(
            'Prazo: ${_deadline!.toIso8601String().split("T").first}',
            style: const TextStyle(color: Colors.white70),
          ),
        ],
        if (_messageController.text.trim().isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            'Mensagem: ${_messageController.text.trim()}',
            style: const TextStyle(color: Colors.white70),
          ),
        ],
        const SizedBox(height: 24),
        if (_isSaving) ...[
          const CircularProgressIndicator(color: AppTheme.goldSoft),
          const SizedBox(height: 8),
          const Text(
            'Processando envio...',
            style: TextStyle(color: AppTheme.goldSoft, fontFamily: 'Orbitron'),
          ),
        ],
      ],
    );
  }

  Widget _currentStepWidget() {
    switch (_currentStep) {
      case 0:
        return _buildStep1();
      case 1:
        return _buildStep2();
      case 2:
        return _buildStep3();
      case 3:
        return _buildStep4();
      default:
        return _buildStep5();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isStep3 = _currentStep == 2;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.backgroundGradient,
        ),
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
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(
                            LucideIcons.arrowLeft,
                            color: Colors.white,
                          ),
                          onPressed: () => context.go('/dashboard'),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'INICIAR MISSÃO',
                          style: TextStyle(
                            fontFamily: 'Orbitron',
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                            color: Colors.white,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Row(
                      children: [
                        for (int i = 0; i < _stepLabels.length; i++) ...[
                          _buildStepIndicator(i, _stepLabels[i], _stepIcons[i]),
                          if (i < _stepLabels.length - 1)
                            _buildLineIndicator(i),
                        ],
                      ],
                    ),
                  ),

                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: isStep3 ? 0 : 32),
                      child: isStep3
                          ? _buildStep3()
                          : SingleChildScrollView(
                              child: GlassContainer(
                                padding: const EdgeInsets.all(32),
                                borderColor: _currentStep == 4
                                    ? AppTheme.goldSoft.withOpacity(0.5)
                                    : AppTheme.tealNeon.withOpacity(0.3),
                                borderRadius: 24,
                                child: _currentStepWidget(),
                              ),
                            ),
                    ),
                  ),

                  Container(
                    decoration: BoxDecoration(
                      color: isStep3 ? Colors.white.withOpacity(0.05) : Colors.transparent,
                      border: isStep3 ? Border(top: BorderSide(color: AppTheme.tealNeon.withOpacity(0.3))) : null,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (_currentStep > 0)
                          OutlinedButton.icon(
                            icon: const Icon(LucideIcons.arrowLeft, size: 16),
                            label: const Text(
                              'Voltar',
                              style: TextStyle(
                                fontFamily: 'Orbitron',
                                letterSpacing: 1,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: BorderSide(color: isStep3 ? AppTheme.tealNeon.withOpacity(0.3) : Colors.white30),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 16,
                              ),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: _isSaving
                                ? null
                                : () => setState(() => _currentStep -= 1),
                          )
                        else
                          const SizedBox(),

                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _currentStep == 4
                                ? AppTheme.goldSoft
                                : AppTheme.tealNeon,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 16,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: isStep3 ? 0 : 10,
                            shadowColor: _currentStep == 4
                                ? AppTheme.goldSoft
                                : AppTheme.tealNeon,
                          ),
                          onPressed: _isSaving
                              ? null
                              : () {
                                  if (!_validateCurrentStep()) return;
                                  if (_currentStep < 4) {
                                    setState(() => _currentStep += 1);
                                  } else {
                                    _submitDocumentFlow();
                                  }
                                },
                          child: Row(
                            children: [
                              Text(
                                _currentStep == 4
                                    ? 'CONFIRMAR DISPARO'
                                    : (isStep3 ? 'Próximo' : 'AVANCAR'),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontFamily: isStep3 ? 'Inter' : 'Orbitron',
                                  letterSpacing: 1,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                _currentStep == 4
                                    ? LucideIcons.rocket
                                    : LucideIcons.arrowRight,
                                size: 18,
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
          ],
        ),
      ),
    );
  }
}
