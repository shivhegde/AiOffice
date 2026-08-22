import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';

/// Wraps Cloud Storage uploads/downloads. Deliberately never exposes a
/// shareable `getDownloadURL()` token — bytes are always fetched through the
/// authenticated SDK call, gated by `storage.rules`, per REQUIREMENTS.md §11
/// ("no public links"). See Phase 1 plan decision #2.
class StorageUploadService {
  StorageUploadService(this._storage);

  final FirebaseStorage _storage;

  Future<void> uploadBytes({
    required String path,
    required Uint8List bytes,
    required String contentType,
  }) async {
    final ref = _storage.ref(path);
    await ref.putData(bytes, SettableMetadata(contentType: contentType));
  }

  Future<Uint8List?> fetchBytes(String path) {
    return _storage.ref(path).getData(20 * 1024 * 1024);
  }

  Future<void> delete(String path) => _storage.ref(path).delete();
}
