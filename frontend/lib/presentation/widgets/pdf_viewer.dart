import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

class PdfViewer extends StatefulWidget {
  final String? fileUrl;
  final int currentPage;

  const PdfViewer({
    super.key,
    this.fileUrl,
    required this.currentPage,
  });

  @override
  State<PdfViewer> createState() => _PdfViewerState();
}

class _PdfViewerState extends State<PdfViewer> {
  final PdfViewerController _pdfViewerController = PdfViewerController();

  @override
  void initState() {
    super.initState();
  }

  @override
  void didUpdateWidget(covariant PdfViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentPage != widget.currentPage) {
      _pdfViewerController.jumpToPage(widget.currentPage);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.fileUrl == null || widget.fileUrl!.isEmpty) {
      return Container(
        color: Colors.black12,
        child: const Center(
          child: Text(
            'Nenhum documento selecionado',
            style: TextStyle(color: Colors.white54),
          ),
        ),
      );
    }

    return SfPdfViewer.network(
      widget.fileUrl!,
      controller: _pdfViewerController,
      canShowScrollHead: false,
      canShowScrollStatus: false,
      enableDoubleTapZooming: false,
      enableTextSelection: false,
      pageLayoutMode: PdfPageLayoutMode.single,
    );
  }
}
