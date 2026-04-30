import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

class PdfPreviewScreen extends StatelessWidget {
  const PdfPreviewScreen({
    super.key,
    required this.pdfBytes,
    required this.suggestedFileName,
  });

  final Uint8List pdfBytes;
  final String suggestedFileName;

  Future<File> _writeToAppDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$suggestedFileName');
    await file.writeAsBytes(pdfBytes, flush: true);
    return file;
  }

  Future<void> _saveToLocal(BuildContext context) async {
    try {
      final file = await _writeToAppDir();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已保存到：${file.path}')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存失败：$e')),
      );
    }
  }

  Future<void> _share(BuildContext context) async {
    try {
      final file = await _writeToAppDir();
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/pdf')],
        subject: suggestedFileName,
        text: 'Markdown 转换 PDF',
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('分享失败：$e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(suggestedFileName, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: '保存到本地',
            icon: const Icon(Icons.save_alt),
            onPressed: () => _saveToLocal(context),
          ),
          IconButton(
            tooltip: '分享',
            icon: const Icon(Icons.share),
            onPressed: () => _share(context),
          ),
        ],
      ),
      body: PdfPreview(
        build: (format) async => pdfBytes,
        canChangePageFormat: false,
        canChangeOrientation: false,
        canDebug: false,
        allowPrinting: true,
        allowSharing: false,
        pdfFileName: suggestedFileName,
        useActions: true,
      ),
    );
  }
}