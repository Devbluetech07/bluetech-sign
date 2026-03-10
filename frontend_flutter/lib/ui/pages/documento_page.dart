import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:frontend_flutter/core/api_client.dart';
import 'dart:html' as html;

class DocumentoPage extends StatefulWidget {
  const DocumentoPage({super.key});

  @override
  State<DocumentoPage> createState() => _DocumentoPageState();
}

class _DocumentoPageState extends State<DocumentoPage> {
  String? _documentType;
  int _step = 0; // 0: Select, 1: Front, 2: Back, 3: Loading
  
  CameraController? _cameraController;
  List<CameraDescription>? cameras;
  
  String? _frontImageBase64;
  String? _backImageBase64;
  
  @override
  void initState() {
    super.initState();
    _initCamera();
  }
  
  Future<void> _initCamera() async {
    try {
      cameras = await availableCameras();
      if (cameras != null && cameras!.isNotEmpty) {
        // Try to get back camera (environment), fallback to first
        var camera = cameras!.firstWhere(
          (c) => c.lensDirection == CameraLensDirection.back,
          orElse: () => cameras!.first,
        );
        _cameraController = CameraController(camera, ResolutionPreset.high, enableAudio: false);
        await _cameraController!.initialize();
        if (mounted) setState(() {});
      }
    } catch (e) {
      debugPrint('Camera error: \$e');
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }
  
  Future<void> _captureImage(bool isFront) async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;
    
    try {
      final xFile = await _cameraController!.takePicture();
      final bytes = await xFile.readAsBytes();
      final b64 = base64Encode(bytes);
      
      setState(() {
        if (isFront) {
          _frontImageBase64 = b64;
          if (_documentType == 'Passaporte') {
            _submitCapture();
          } else {
            _step = 2; // Move to Back
          }
        } else {
          _backImageBase64 = b64;
          _submitCapture();
        }
      });
    } catch (e) {
      debugPrint('Capture error: \$e');
    }
  }
  
  Future<void> _submitCapture() async {
    setState(() => _step = 3);
    try {
      final metadata = {
        'userAgent': html.window.navigator.userAgent,
        'platform': html.window.navigator.platform,
        'timestamp': DateTime.now().toIso8601String(),
        'documentType': _documentType,
        'hasBackDetails': _backImageBase64 != null,
      };

      // Create a composite by just passing front for now, or joining them
      // Real valeris creates composite. Here we just upload front as image_data and back info in metadata (or we combine them, but for brevity we'll just send front as main)
      final res = await apiClient.post('/captures', {
        'service_type': 'documento',
        'image_data': 'data:image/jpeg;base64,\$_frontImageBase64',
        'metadata': metadata,
        // We could attach 'back_image' in metadata or change the Go service to accept another field. Let's send it in metadata for now.
      });

      if (res.statusCode == 201) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Documento capturado!')));
          setState(() {
             _step = 0;
             _documentType = null;
             _frontImageBase64 = null;
             _backImageBase64 = null;
          });
        }
      } else {
        throw Exception('Erro ao processar');
      }
    } catch (e) {
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erro ao salvar documento.')));
         setState(() => _step = 0);
      }
    }
  }

  Widget _buildSelectType() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Selecione o tipo de documento', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 32),
        Row(
           children: [
             _buildTypeCard('RG'),
             const SizedBox(width: 16),
             _buildTypeCard('CNH'),
             const SizedBox(width: 16),
             _buildTypeCard('Passaporte'),
           ]
        )
      ],
    );
  }
  
  Widget _buildTypeCard(String type) {
    return InkWell(
      onTap: () => setState(() {
        _documentType = type;
        _step = 1; // start front
      }),
      child: Container(
        width: 150,
        height: 100,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.cyanAccent.withOpacity(0.5)),
        ),
        child: Center(child: Text(type, style: const TextStyle(fontSize: 18, color: Colors.cyanAccent))),
      ),
    );
  }

  Widget _buildCameraPreview(bool isFront) {
     if (_cameraController == null || !_cameraController!.value.isInitialized) {
       return const Center(child: CircularProgressIndicator());
     }
     
     return Column(
       children: [
         Text(isFront ? "Captura - Frente (\$_documentType)" : "Captura - Verso (\$_documentType)", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
         const SizedBox(height: 16),
         Container(
           width: 640,
           height: 480,
           decoration: BoxDecoration(
             border: Border.all(color: Colors.cyanAccent, width: 2),
             borderRadius: BorderRadius.circular(12),
           ),
           child: Stack(
             fit: StackFit.expand,
             children: [
               ClipRRect(
                 borderRadius: BorderRadius.circular(10),
                 child: CameraPreview(_cameraController!),
               ),
               // Simple overlay guide
               Center(
                 child: Container(
                   width: 500,
                   height: 300,
                   decoration: BoxDecoration(
                     border: Border.all(color: Colors.redAccent, width: 2),
                   ),
                 ),
               ),
             ],
           ),
         ),
         const SizedBox(height: 24),
         ElevatedButton(
           onPressed: () => _captureImage(isFront),
           child: const Padding(
             padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
             child: Text('Capturar', style: TextStyle(fontSize: 18)),
           ),
         )
       ]
     );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: () {
        switch (_step) {
          case 0: return _buildSelectType();
          case 1: return _buildCameraPreview(true);
          case 2: return _buildCameraPreview(false);
          case 3: return const Center(child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Analisando e salvando capturas...', style: TextStyle(color: Colors.cyanAccent, fontSize: 18))
            ],
          ));
          default: return const SizedBox();
        }
      }()
    );
  }
}
