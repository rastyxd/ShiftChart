import 'dart:io';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

class PdfViewerScreen extends StatelessWidget {
  final String filePath;
  final String title;

  const PdfViewerScreen({
    super.key,
    required this.filePath,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: () async {
              final bytes = await File(filePath).readAsBytes();
              await Printing.sharePdf(bytes: bytes, filename: filePath.split('/').last);
            },
          ),
        ],
      ),
      body: InteractiveViewer(
        minScale: 1.0,
        maxScale: 4.0,

        child: PdfPreview(
          build: (format) => File(filePath).readAsBytes(),
          dynamicLayout: true,
          useActions: false,
          canChangePageFormat: false,
          canChangeOrientation: false,
          canDebug: false,
          allowPrinting: true,
          allowSharing: true,
        ),
      ),
    );
  }
}
