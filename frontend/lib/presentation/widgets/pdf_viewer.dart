import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

class PdfViewer extends StatefulWidget {
  final String? fileUrl;
  final Uint8List? fileBytes;
  final int currentPage;
  final ValueChanged<int>? onPageChanged;
  final ValueChanged<int>? onDocumentLoaded;

  const PdfViewer({
    super.key,
    this.fileUrl,
    this.fileBytes,
    required this.currentPage,
    this.onPageChanged,
    this.onDocumentLoaded,
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
    if ((widget.fileBytes == null || widget.fileBytes!.isEmpty) &&
        (widget.fileUrl == null || widget.fileUrl!.isEmpty)) {
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

    final viewer = widget.fileBytes != null && widget.fileBytes!.isNotEmpty
        ? SfPdfViewer.memory(
            widget.fileBytes!,
            controller: _pdfViewerController,
            canShowScrollHead: false,
            canShowScrollStatus: false,
            enableDoubleTapZooming: false,
            enableTextSelection: false,
            pageLayoutMode: PdfPageLayoutMode.single,
            onDocumentLoaded: (details) {
              widget.onDocumentLoaded?.call(details.document.pages.count);
            },
            onPageChanged: (details) {
              widget.onPageChanged?.call(details.newPageNumber);
            },
          )
        : SfPdfViewer.network(
            widget.fileUrl!,
            controller: _pdfViewerController,
            canShowScrollHead: false,
            canShowScrollStatus: false,
            enableDoubleTapZooming: false,
            enableTextSelection: false,
            pageLayoutMode: PdfPageLayoutMode.single,
            onDocumentLoaded: (details) {
              widget.onDocumentLoaded?.call(details.document.pages.count);
            },
            onPageChanged: (details) {
              widget.onPageChanged?.call(details.newPageNumber);
            },
          );

    return viewer;
  }
}
