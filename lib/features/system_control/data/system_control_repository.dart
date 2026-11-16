import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/firestore_paths.dart';
import '../domain/system_control_config.dart';

class SystemControlRepository {
  SystemControlRepository(this._firestore);

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> get _doc =>
      _firestore.collection(FirestorePaths.appConfig).doc(FirestorePaths.systemControlDocId);

  Stream<SystemControlConfig> watch() {
    return _doc.snapshots().map((snap) {
      final data = snap.data();
      return data == null ? SystemControlConfig.unset : SystemControlConfig.fromMap(data);
    });
  }

  /// Turns maintenance mode on/off. Merged so it never touches the force
  /// refresh fields.
  Future<void> saveMaintenance({required bool enabled, required String message, required String updatedByName}) {
    return _doc.set({
      'maintenanceMode': enabled,
      'maintenanceMessage': message.trim(),
      'maintenanceSince': enabled ? FieldValue.serverTimestamp() : null,
      'updatedByName': updatedByName,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Schedules (or with a null [at], clears) the forced refresh. Merged so
  /// it never touches the maintenance fields.
  Future<void> saveForceRefresh({required DateTime? at, required String message, required String updatedByName}) {
    return _doc.set({
      'forceRefreshAt': at == null ? null : Timestamp.fromDate(at),
      'forceRefreshMessage': message.trim(),
      'updatedByName': updatedByName,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
