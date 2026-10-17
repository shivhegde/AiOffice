import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';

/// Wraps Cloud Storage uploads/downloads. Deliberately never exposes a
/// shareable `getDownloadURL()` token — bytes are always fetched through the
/// authenticated SDK call, gated by `storage.rules`, per REQUIREMENTS.md §11
/// ("no public links"). See Phase 1 plan decision #2.
///
/// [pathPrefix] is the active environment's Storage prefix (empty for
/// production, `env/<name>/` for a test environment — see
/// `AppEnvironment.storagePrefix`). It's applied here on every call, so
/// the paths callers store in Firestore stay environment-agnostic.
class StorageUploadService {
  StorageUploadService(this._storage, {this.pathPrefix = ''});

  final FirebaseStorage _storage;
  final String pathPrefix;

  Reference _ref(String path) => _storage.ref('$pathPrefix$path');

  Future<void> uploadBytes({
    required String path,
    required Uint8List bytes,
    required String contentType,
  }) async {
    final ref = _ref(path);
    await ref.putData(bytes, SettableMetadata(contentType: contentType));
  }

  Future<Uint8List?> fetchBytes(String path) {
    return _ref(path).getData(20 * 1024 * 1024);
  }

  Future<void> delete(String path) => _ref(path).delete();
}
