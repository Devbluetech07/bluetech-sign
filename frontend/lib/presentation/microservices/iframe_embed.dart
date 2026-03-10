import 'package:flutter/material.dart';
import 'dart:html' as html;
import 'dart:ui' as ui;

class ValerisMicroserviceEmbed extends StatefulWidget {
  final String serviceUrl; // ex: http://localhost:3000/?service=assinatura
  
  const ValerisMicroserviceEmbed({super.key, required this.serviceUrl});

  @override
  State<ValerisMicroserviceEmbed> createState() => _ValerisMicroserviceEmbedState();
}

class _ValerisMicroserviceEmbedState extends State<ValerisMicroserviceEmbed> {
  final String _viewType = 'valeris-iframe-\${DateTime.now().microsecondsSinceEpoch}';

  @override
  void initState() {
    super.initState();
    // Register the iframe to the Flutter engine for Web
    // ignoring the web only platform restriction here since we are only supporting web first
    // ignore: undefined_prefixed_name
    ui.platformViewRegistry.registerViewFactory(
      _viewType,
      (int viewId) => html.IFrameElement()
        ..src = widget.serviceUrl
        ..style.border = 'none'
        ..allowFullscreen = true
        ..allow = 'camera;microphone;geolocation', // allow all permissions required by valeris
    );
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _viewType);
  }
}
