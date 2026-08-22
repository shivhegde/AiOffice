import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/firestore_paths.dart';
import '../../../core/services/firestore_counter_service.dart';
import '../../audit/data/audit_log_repository.dart';
import '../../audit/domain/audit_entry.dart';
import '../domain/tender.dart';

/// Tender-EMD CRUD (REQUIREMENTS.md §7). Doc numbers generated atomically
/// via [FirestoreCounterService], same pattern as
/// `IoRepository` — see that class for why the final [Tender] is always
/// built directly via its constructor rather than round-tripping through
/// `toMap()`/`fromMap()` (that round-trip crashes on the unresolved
/// `FieldValue.serverTimestamp()` sentinel `toMap()` puts in `createdAt`).
class TenderRepository {
  TenderRepository({required FirebaseFirestore firestore, required AuditLogRepository auditLog})
    : _firestore = firestore,
      _auditLog = auditLog,
      _counter = FirestoreCounterService(firestore);

  final FirebaseFirestore _firestore;
  final AuditLogRepository _auditLog;
  final FirestoreCounterService _counter;

  CollectionReference<Map<String, dynamic>> get _collection => _firestore.collection(FirestorePaths.tenders);

  Stream<List<Tender>> watchAll() {
    return _collection
        .orderBy('submissionDate', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => Tender.fromMap(d.id, d.data())).toList());
  }

  Future<Tender> create({required Tender draft, required String actorUid, required String actorName}) async {
    final year = draft.submissionDate.year;
    final sequence = await _counter.nextSequence(type: 'tender', year: year);
    final tenderNumber = FirestoreCounterService.formatDocNumber(prefix: 'TND', year: year, sequence: sequence);

    final docRef = _collection.doc();
    final toSave = Tender(
      id: docRef.id,
      tenderNumber: tenderNumber,
      year: year,
      tenderName: draft.tenderName,
      departmentName: draft.departmentName,
      category: draft.category,
      publishDate: draft.publishDate,
      submissionDate: draft.submissionDate,
      emdAmount: draft.emdAmount,
      emdType: draft.emdType,
      utrNumber: draft.utrNumber,
      emdValidUntil: draft.emdValidUntil,
      refundStatus: draft.refundStatus,
      refundedAt: draft.refundedAt,
      deptContactPerson: draft.deptContactPerson,
      deptContactMobile: draft.deptContactMobile,
      deptContactEmail: draft.deptContactEmail,
      deptOfficeAddress: draft.deptOfficeAddress,
      remarks: draft.remarks,
      createdBy: actorUid,
      createdByName: actorName,
    );

    await docRef.set(toSave.toMap());
    await _auditLog.log(
      actorUid: actorUid,
      actorName: actorName,
      action: AuditAction.create,
      module: 'tender_emd',
      targetId: docRef.id,
      targetLabel: '$tenderNumber — ${draft.tenderName}',
    );

    return toSave;
  }

  Future<void> update({required Tender tender, required String actorUid, required String actorName}) async {
    await _collection.doc(tender.id).update(tender.toMap());
    await _auditLog.log(
      actorUid: actorUid,
      actorName: actorName,
      action: AuditAction.update,
      module: 'tender_emd',
      targetId: tender.id,
      targetLabel: '${tender.tenderNumber} — ${tender.tenderName}',
    );
  }

  Future<void> delete({required Tender tender, required String actorUid, required String actorName}) async {
    await _collection.doc(tender.id).delete();
    await _auditLog.log(
      actorUid: actorUid,
      actorName: actorName,
      action: AuditAction.delete,
      module: 'tender_emd',
      targetId: tender.id,
      targetLabel: '${tender.tenderNumber} — ${tender.tenderName}',
    );
  }
}
