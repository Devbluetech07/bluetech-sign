import 'package:flutter/material.dart';

class DownloadsPage extends StatelessWidget {
  const DownloadsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Downloads e SDKs', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
          SizedBox(height: 16),
          Text('NPN Packages:', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
          Text('• vl-assinatura\n• vl-documento\n• vl-selfie\n• vl-selfie-doc', style: TextStyle(fontSize: 16, color: Colors.grey)),
          SizedBox(height: 32),
          Text('\$ npm install @valeris/vl-core', style: TextStyle(fontFamily: 'monospace', backgroundColor: Colors.black26, fontSize: 16)),
        ],
      )
    );
  }
}

class DocsPage extends StatelessWidget {
  const DocsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Documentação da API REST', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
          SizedBox(height: 16),
          Text('Endpoints Fictícios:', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
          Text('POST /api/captures\nGET /api/keys\nPOST /api/chat', style: TextStyle(fontFamily: 'monospace', color: Colors.cyanAccent)),
          SizedBox(height: 32),
          Text('Integração Go + PostgreSQL funcionando no backend local.', style: TextStyle(fontSize: 16, color: Colors.grey)),
        ],
      )
    );
  }
}
