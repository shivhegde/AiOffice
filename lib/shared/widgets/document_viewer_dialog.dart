import 'dart:math' as math;
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

/// In-app preview for a document fetched from Cloud Storage — PDFs render
/// page-by-page via `printing`'s rasterizer, images via [Image.memory].
/// Storage never exposes a public download URL (see
/// `StorageUploadService`), so callers already hold the bytes in memory;
/// this just renders them instead of forcing a save-to-disk round trip.
class DocumentViewerDialog extends StatelessWidget {
  const DocumentViewerDialog({super.key, required this.bytes, required this.fileName, required this.contentType});

  final Uint8List bytes;
  final String fileName;
  final String contentType;

  static Future<void> show(
    BuildContext context, {
    required Uint8List bytes,
    required String fileName,
    required String contentType,
  }) {
    return showDialog(
      context: context,
      builder: (_) => DocumentViewerDialog(bytes: bytes, fileName: fileName, contentType: contentType),
    );
  }

  bool get _isPdf => contentType == 'application/pdf' || fileName.toLowerCase().endsWith('.pdf');

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: SizedBox(
        width: math.min(720, screen.width - 48),
        height: math.min(800, screen.height - 48),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      fileName,
                      style: Theme.of(context).textTheme.titleMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.download_outlined, size: 19),
                    tooltip: 'Save a copy',
                    onPressed: () => FilePicker.saveFile(fileName: fileName, bytes: bytes, mimeType: contentType),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 19),
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _isPdf
                  ? PdfPreview(
                      build: (format) async => bytes,
                      canChangeOrientation: false,
                      canChangePageFormat: false,
                      canDebug: false,
                      allowSharing: false,
                      useActions: false,
                    )
                  : InteractiveViewer(maxScale: 4, child: Center(child: Image.memory(bytes))),
            ),
          ],
        ),
      ),
    );
  }
}
