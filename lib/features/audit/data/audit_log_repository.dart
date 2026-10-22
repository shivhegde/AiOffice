import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/firestore_paths.dart';
import '../domain/audit_entry.dart';

/// Append-only audit trail per REQUIREMENTS.md §10. Client-written (no
/// Cloud Function yet, see Phase 1 plan decision #1) but immutable —
/// `firestore.rules` forbids update/delete on this collection entirely.
class AuditLogRepository {
  /// [appVersion] supplies the running build's version, stamped on every
  /// entry; omitted (as in tests) entries carry none.
  AuditLogRepository(this._firestore, {Future<String> Function()? appVersion}) : _appVersionSource = appVersion;

  final FirebaseFirestore _firestore;
  final Future<String> Function()? _appVersionSource;
  Future<String>? _appVersion;

  /// Looked up once; a failed lookup just leaves entries unstamped.
  Future<String> _version() {
    final source = _appVersionSource;
    if (source == null) return Future.value('');
    return _appVersion ??= _lookup(source);
  }

  static Future<String> _lookup(Future<String> Function() source) async {
    try {
      return await source();
    } catch (_) {
      return '';
    }
  }

  CollectionReference<Map<String, dynamic>> get _collection => _firestore.collection(FirestorePaths.auditLog);

  Future<void> log({
    required String actorUid,
    required String actorName,
    required AuditAction action,
    required String module,
    required String targetId,
    required String targetLabel,
  }) async {
    await _collection.add(
      AuditEntry.toCreateMap(
        actorUid: actorUid,
        actorName: actorName,
        action: action,
        module: module,
        targetId: targetId,
        targetLabel: targetLabel,
        appVersion: await _version(),
      ),
    );
  }

  Stream<List<AuditEntry>> watchRecent({int limit = 100}) {
    return _collection
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map((d) => AuditEntry.fromMap(d.id, d.data())).toList());
  }
}
