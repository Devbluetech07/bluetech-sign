import 'package:flutter/material.dart';

class ValerisFrame extends StatelessWidget {
  final String serviceUrl;
  final void Function(String serviceType, String captureId)? onCaptureSuccess;

  const ValerisFrame({
    super.key,
    required this.serviceUrl,
    this.onCaptureSuccess,
  });

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Microsserviço Valeris disponível apenas no Flutter Web.',
        style: TextStyle(color: Colors.white70),
        textAlign: TextAlign.center,
      ),
    );
  }
}
