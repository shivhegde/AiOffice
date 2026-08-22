import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/firestore_paths.dart';
import '../domain/version_gate_config.dart';

class VersionGateRepository {
  VersionGateRepository(this._firestore);

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> get _doc =>
      _firestore.collection(FirestorePaths.appConfig).doc(FirestorePaths.versionGateDocId);

  Stream<VersionGateConfig> watch() {
    return _doc.snapshots().map((snap) {
      final data = snap.data();
      return data == null ? VersionGateConfig.unset : VersionGateConfig.fromMap(data);
    });
  }

  Future<void> save({required VersionGateConfig config, required String updatedByName}) {
    return _doc.set(config.toMap(updatedByName: updatedByName));
  }
}
