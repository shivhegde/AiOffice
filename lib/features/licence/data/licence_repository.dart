import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/firestore_paths.dart';
import '../domain/licence_config.dart';

class LicenceRepository {
  LicenceRepository(this._firestore);

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> get _doc =>
      _firestore.collection(FirestorePaths.appConfig).doc(FirestorePaths.licenceDocId);

  Stream<LicenceConfig> watch() {
    return _doc.snapshots().map((snap) {
      final data = snap.data();
      return data == null ? LicenceConfig.unset : LicenceConfig.fromMap(data);
    });
  }

  Future<void> save({required LicenceConfig config, required String updatedByName}) {
    return _doc.set(config.toMap(updatedByName: updatedByName));
  }
}
