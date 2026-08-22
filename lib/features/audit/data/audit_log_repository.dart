import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/firestore_paths.dart';
import '../domain/audit_entry.dart';

/// Append-only audit trail per REQUIREMENTS.md §10. Client-written (no
/// Cloud Function yet, see Phase 1 plan decision #1) but immutable —
/// `firestore.rules` forbids update/delete on this collection entirely.
class AuditLogRepository {
  AuditLogRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection(FirestorePaths.auditLog);

  Future<void> log({
    required String actorUid,
    required String actorName,
    required AuditAction action,
    required String module,
    required String targetId,
    required String targetLabel,
  }) {
    return _collection.add(
      AuditEntry.toCreateMap(
        actorUid: actorUid,
        actorName: actorName,
        action: action,
        module: module,
        targetId: targetId,
        targetLabel: targetLabel,
      ),
    );
  }

  Stream<List<AuditEntry>> watchRecent({int limit = 100}) {
    return _collection.orderBy('timestamp', descending: true).limit(limit).snapshots().map(
      (snap) => snap.docs.map((d) => AuditEntry.fromMap(d.id, d.data())).toList(),
    );
  }
}
