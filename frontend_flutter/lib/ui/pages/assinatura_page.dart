import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:signature/signature.dart';
import 'package:frontend_flutter/core/api_client.dart';
import 'dart:html' as html;

class AssinaturaPage extends StatefulWidget {
  const AssinaturaPage({super.key});

  @override
  State<AssinaturaPage> createState() => _AssinaturaPageState();
}

class _AssinaturaPageState extends State<AssinaturaPage> {
  bool isDrawMode = true;
  final SignatureController _signatureController = SignatureController(
    penStrokeWidth: 3,
    penColor: Colors.cyanAccent,
    exportBackgroundColor: Colors.black,
  );
  
  final TextEditingController _textController = TextEditingController();
  bool _isSubmitting = false;
  
  @override
  void dispose() {
    _signatureController.dispose();
    _textController.dispose();
    super.dispose();
  }

  Future<void> submitCapture(String base64Image) async {
    setState(() => _isSubmitting = true);
    try {
      // Mock geo and device logic for now
      final metadata = {
        'userAgent': html.window.navigator.userAgent,
        'platform': html.window.navigator.platform,
        'timestamp': DateTime.now().toIso8601String(),
        'latitude': -23.5505,
        'longitude': -46.6333,
        'address': 'São Paulo, SP, Brasil',
      };

      final res = await apiClient.post('/captures', {
        'service_type': 'assinatura',
        'image_data': 'data:image/png;base64,$base64Image',
        'metadata': metadata,
      });

      if (res.statusCode == 201) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Assinatura salva com sucesso!')),
          );
          _signatureController.clear();
          _textController.clear();
        }
      } else {
        throw Exception('Failed to save');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao salvar assinatura.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void onSubmitDraw() async {
    if (_signatureController.isEmpty) return;
    
    final bytes = await _signatureController.toPngBytes();
    if (bytes == null) return;
    
    submitCapture(base64Encode(bytes));
  }

  void onSubmitText() {
    if (_textController.text.length < 3) return;
    // In Flutter Web, creating an image from text purely in memory can be done via ui.PictureRecorder
    // But for a simple fallback, we could draw it on a canvas.
    // For now we will mock the image or draw it properly.
    // Let's create an image using Flutter's Canvas:
    _createImageFromText(_textController.text).then((bytes) {
      submitCapture(base64Encode(bytes));
    });
  }
  
  Future<List<int>> _createImageFromText(String text) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint()..color = Colors.black;
    canvas.drawRect(const Rect.fromLTWH(0, 0, 800, 300), paint);
    
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: Colors.cyanAccent, 
          fontSize: 60,
          fontStyle: FontStyle.italic,
          fontFamily: 'cursive',
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, const Offset(50, 100));
    
    final picture = recorder.endRecording();
    final image = await picture.toImage(800, 300);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Captura de Assinatura', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Row(
            children: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDrawMode ? Theme.of(context).colorScheme.primary : Colors.grey[800],
                ),
                onPressed: () => setState(() => isDrawMode = true),
                child: const Text('Desenho', style: TextStyle(color: Colors.white)),
              ),
              const SizedBox(width: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: !isDrawMode ? Theme.of(context).colorScheme.primary : Colors.grey[800],
                ),
                onPressed: () => setState(() => isDrawMode = false),
                child: const Text('Digitada', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
          const SizedBox(height: 32),
          
          if (isDrawMode)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white24),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Signature(
                      controller: _signatureController,
                      width: MediaQuery.of(context).size.width > 800 ? 800 : MediaQuery.of(context).size.width - 64,
                      height: 300,
                      backgroundColor: Colors.black,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    TextButton(
                      onPressed: () => _signatureController.clear(),
                      child: const Text('Limpar', style: TextStyle(color: Colors.redAccent)),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: _isSubmitting ? null : onSubmitDraw,
                      child: _isSubmitting 
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Confirmar Assinatura'),
                    ),
                  ],
                )
              ],
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: MediaQuery.of(context).size.width > 800 ? 800 : MediaQuery.of(context).size.width - 64,
                  child: TextField(
                    controller: _textController,
                    decoration: const InputDecoration(
                      labelText: 'Nome Completo',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _isSubmitting ? null : onSubmitText,
                  child: _isSubmitting 
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Gerar Assinatura'),
                ),
              ],
            )
        ],
      ),
    );
  }
}
