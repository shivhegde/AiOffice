import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/roles.dart';
import '../../../../shared/widgets/role_gate.dart';
import '../../domain/io_enums.dart';
import '../io_form_slideover.dart';

/// REQUIREMENTS.md §6.6 "Friendly Features": camera scan and gallery
/// upload open a pre-filled New Entry form with the captured image already
/// attached, so capturing a document doesn't require a separate file-picker
/// round trip.
class FriendlyFeaturesBar extends StatelessWidget {
  const FriendlyFeaturesBar({super.key, required this.type});

  final IoType type;

  Future<void> _capture(BuildContext context, ImageSource source) async {
    final picker = ImagePicker();
    final XFile? file = await picker.pickImage(source: source, imageQuality: 85);
    if (file == null || !context.mounted) return;
    final Uint8List bytes = await file.readAsBytes();
    if (!context.mounted) return;
    IoFormSlideover.show(
      context,
      type: type,
      prefilledFile: (bytes: bytes, name: file.name, contentType: 'image/jpeg'),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RoleGate(
      minRole: AppRole.powerUser,
      child: Wrap(
        spacing: 8,
        children: [
          OutlinedButton.icon(
            onPressed: () => _capture(context, ImageSource.camera),
            icon: const Icon(Icons.camera_alt_outlined, size: 16),
            label: const Text('Scan'),
          ),
          OutlinedButton.icon(
            onPressed: () => _capture(context, ImageSource.gallery),
            icon: const Icon(Icons.photo_library_outlined, size: 16),
            label: const Text('Gallery'),
          ),
        ],
      ),
    );
  }
}
