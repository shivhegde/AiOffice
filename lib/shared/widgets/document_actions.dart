import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/inward_outward/application/io_providers.dart' show storageUploadServiceProvider;
import 'document_viewer_dialog.dart';

/// Best-effort MIME type from a stored file's name, re-derived from the
/// extension rather than persisted — matches the content types each
/// module's own upload picker already sets when writing the file.
String mimeTypeForFileName(String fileName) {
  final extension = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : '';
  return switch (extension) {
    'pdf' => 'application/pdf',
    'doc' => 'application/msword',
    'docx' => 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'png' || 'jpg' || 'jpeg' => 'image/$extension',
    _ => 'application/octet-stream',
  };
}

Future<Uint8List> _fetchDocumentBytes(WidgetRef ref, String storagePath) async {
  final bytes = await ref.read(storageUploadServiceProvider).fetchBytes(storagePath);
  if (bytes == null) throw Exception('File not found in storage.');
  return bytes;
}

/// Fetches [storagePath] and opens it in the in-app [DocumentViewerDialog].
Future<void> viewStoredDocument(
  BuildContext context,
  WidgetRef ref, {
  required String storagePath,
  required String fileName,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    final bytes = await _fetchDocumentBytes(ref, storagePath);
    if (!context.mounted) return;
    await DocumentViewerDialog.show(
      context,
      bytes: bytes,
      fileName: fileName,
      contentType: mimeTypeForFileName(fileName),
    );
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('Could not open $fileName: $e')));
  }
}

/// Fetches [storagePath] and saves it to disk via the platform save dialog.
Future<void> downloadStoredDocument(
  BuildContext context,
  WidgetRef ref, {
  required String storagePath,
  required String fileName,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    final bytes = await _fetchDocumentBytes(ref, storagePath);
    await FilePicker.saveFile(fileName: fileName, bytes: bytes, mimeType: mimeTypeForFileName(fileName));
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('Could not download $fileName: $e')));
  }
}

/// The "view" / "download" icon pair shown next to an already-uploaded
/// document across every module's edit form — side by side so download
/// doesn't require opening the viewer first.
class DocumentActionIcons extends ConsumerWidget {
  const DocumentActionIcons({super.key, required this.storagePath, required this.fileName, this.label = 'document'});

  final String storagePath;
  final String fileName;
  final String label;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.visibility_outlined),
          tooltip: 'View $label',
          onPressed: () => viewStoredDocument(context, ref, storagePath: storagePath, fileName: fileName),
        ),
        IconButton(
          icon: const Icon(Icons.download_outlined),
          tooltip: 'Download $label',
          onPressed: () => downloadStoredDocument(context, ref, storagePath: storagePath, fileName: fileName),
        ),
      ],
    );
  }
}
