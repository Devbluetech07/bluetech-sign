// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

class ValerisFrame extends StatefulWidget {
  final String serviceUrl;
  final void Function(String serviceType, String captureId)? onCaptureSuccess;

  const ValerisFrame({
    super.key,
    required this.serviceUrl,
    this.onCaptureSuccess,
  });

  @override
  State<ValerisFrame> createState() => _ValerisFrameState();
}

class _ValerisFrameState extends State<ValerisFrame> {
  late final String _viewType;
  late final html.IFrameElement _iframe;
  StreamSubscription<html.MessageEvent>? _messageSub;

  @override
  void initState() {
    super.initState();
    _viewType = 'valeris-iframe-${DateTime.now().microsecondsSinceEpoch}';
    _iframe = html.IFrameElement()
      ..src = widget.serviceUrl
      ..style.border = 'none'
      ..allow = 'camera; microphone; geolocation'
      ..allowFullscreen = true;

    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      return _iframe;
    });

    _messageSub = html.window.onMessage.listen((event) {
      final data = event.data;
      String? type;
      String? serviceType;
      String? captureId;

      if (data is Map) {
        type = data['type']?.toString();
        serviceType = data['serviceType']?.toString();
        captureId = data['captureId']?.toString();
      } else if (data is String) {
        try {
          final parsed = jsonDecode(data);
          if (parsed is Map) {
            type = parsed['type']?.toString();
            serviceType = parsed['serviceType']?.toString();
            captureId = parsed['captureId']?.toString();
          }
        } catch (_) {}
      }

      if (type == 'VALERIS_CAPTURE_SUCCESS' &&
          captureId != null &&
          captureId.isNotEmpty) {
        widget.onCaptureSuccess?.call(serviceType ?? 'unknown', captureId);
      }
    });
  }

  @override
  void dispose() {
    _messageSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _viewType);
  }
}
