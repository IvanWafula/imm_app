import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

class DocumentViewerScreen extends StatelessWidget {
  final String title;
  final String filePath;
  final String fileType;

  const DocumentViewerScreen({
    super.key,
    required this.title,
    required this.filePath,
    required this.fileType,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: filePath.isNotEmpty
          ? SfPdfViewer.network(filePath)
          : const Center(child: Text('Document not available')),
    );
  }
}
