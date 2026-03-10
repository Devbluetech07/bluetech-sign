import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:frontend_flutter/core/api_client.dart';
import 'dart:html' as html;

class SelfiePage extends StatefulWidget {
  const SelfiePage({super.key});

  @override
  State<SelfiePage> createState() => _SelfiePageState();
}

class _SelfiePageState extends State<SelfiePage> {
  int _step = 0; // 0: Instructions, 1: Capture, 2: Uploading
  CameraController? _cameraController;
  List<CameraDescription>? cameras;
  
  @override
  void initState() {
    super.initState();
    _initCamera();
  }
  
  Future<void> _initCamera() async {
    try {
      cameras = await availableCameras();
      if (cameras != null && cameras!.isNotEmpty) {
        var camera = cameras!.firstWhere(
          (c) => c.lensDirection == CameraLensDirection.front,
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

  Future<void> _captureSelfie() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;
    
    setState(() => _step = 2);
    try {
      final xFile = await _cameraController!.takePicture();
      final bytes = await xFile.readAsBytes();
      final b64 = base64Encode(bytes);
      
      final metadata = {
        'userAgent': html.window.navigator.userAgent,
        'platform': html.window.navigator.platform,
        'timestamp': DateTime.now().toIso8601String(),
      };

      final res = await apiClient.post('/captures', {
        'service_type': 'selfie',
        'image_data': 'data:image/jpeg;base64,\$b64',
        'metadata': metadata,
      });

      if (res.statusCode == 201) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selfie capturada com sucesso!')));
          setState(() => _step = 0);
        }
      } else {
        throw Exception('Erro ao processar');
      }
    } catch (e) {
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erro ao salvar selfie.')));
         setState(() => _step = 1);
      }
    }
  }

  Widget _buildInstructions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Instruções de Captura', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 32),
        const Text('- Remova óculos e acessórios\n- Esteja em local bem iluminado\n- Centralize seu rosto\n- Olhe diretamente para a câmera', style: TextStyle(fontSize: 18, height: 1.5)),
        const SizedBox(height: 32),
        ElevatedButton(
          onPressed: () => setState(() => _step = 1),
          child: const Padding(
             padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
             child: Text('Iniciar Captura', style: TextStyle(fontSize: 18)),
          ),
        )
      ],
    );
  }

  Widget _buildCapture() {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
       return const Center(child: CircularProgressIndicator());
    }
    
    return Column(
      children: [
         const Text("Capture sua Selfie", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
         const SizedBox(height: 16),
         Container(
           width: 480,
           height: 640,
           decoration: BoxDecoration(
             border: Border.all(color: Colors.cyanAccent, width: 2),
             borderRadius: BorderRadius.circular(20),
           ),
           child: Stack(
             fit: StackFit.expand,
             children: [
               ClipRRect(
                 borderRadius: BorderRadius.circular(18),
                 child: CameraPreview(_cameraController!),
               ),
               Center(
                 child: Container(
                   width: 300,
                   height: 400,
                   decoration: BoxDecoration(
                     border: Border.all(color: Colors.redAccent, width: 2, style: BorderStyle.solid),
                     shape: BoxShape.rectangle,
                     borderRadius: BorderRadius.circular(150),
                   ),
                 ),
               ),
             ],
           ),
         ),
         const SizedBox(height: 24),
         ElevatedButton(
           onPressed: _captureSelfie,
           style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary),
           child: const Padding(
             padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
             child: Text('Capturar', style: TextStyle(color: Colors.white, fontSize: 18)),
           ),
         )
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Center(
        child: () {
          switch (_step) {
            case 0: return _buildInstructions();
            case 1: return _buildCapture();
            case 2: return const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Analisando biometria facial...', style: TextStyle(color: Colors.cyanAccent, fontSize: 18))
              ],
            );
            default: return const SizedBox();
          }
        }()
      )
    );
  }
}
