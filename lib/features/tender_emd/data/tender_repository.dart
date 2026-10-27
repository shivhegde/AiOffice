import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/firestore_paths.dart';
import '../../../core/services/storage_upload_service.dart';
import '../../audit/data/audit_log_repository.dart';
import '../../audit/domain/audit_entry.dart';
import '../domain/tender.dart';

/// Tender-EMD CRUD (REQUIREMENTS.md §7). The tender number is entered by
/// the user, not generated. Same pattern as `IoRepository` — see that
/// class for why the final [Tender] is always
/// built directly via its constructor rather than round-tripping through
/// `toMap()`/`fromMap()` (that round-trip crashes on the unresolved
/// `FieldValue.serverTimestamp()` sentinel `toMap()` puts in `createdAt`).
class TenderRepository {
  TenderRepository({
    required FirebaseFirestore firestore,
    required StorageUploadService storage,
    required AuditLogRepository auditLog,
  }) : _firestore = firestore,
       _storage = storage,
       _auditLog = auditLog;

  final FirebaseFirestore _firestore;
  final StorageUploadService _storage;
  final AuditLogRepository _auditLog;

  CollectionReference<Map<String, dynamic>> get _collection => _firestore.collection(FirestorePaths.tenders);

  Stream<List<Tender>> watchAll() {
    return _collection
        .orderBy('submissionDate', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => Tender.fromMap(d.id, d.data())).toList());
  }

  Future<String?> _uploadProof({
    required String docId,
    required String slot,
    required int year,
    ({Uint8List bytes, String name, String contentType})? file,
  }) async {
    if (file == null) return null;
    final path = 'tenders/$year/$docId/$slot/${file.name}';
    await _storage.uploadBytes(path: path, bytes: file.bytes, contentType: file.contentType);
    return path;
  }

  Future<Tender> create({
    required Tender draft,
    required String actorUid,
    required String actorName,
    ({Uint8List bytes, String name, String contentType})? paymentProofFile,
    ({Uint8List bytes, String name, String contentType})? refundProofFile,
  }) async {
    final year = draft.submissionDate.year;
    final tenderNumber = draft.tenderNumber.trim();

    final docRef = _collection.doc();
    final proofPath = await _uploadProof(docId: docRef.id, slot: 'payment_proof', year: year, file: paymentProofFile);
    final refundProofPath = await _uploadProof(
      docId: docRef.id,
      slot: 'refund_proof',
      year: year,
      file: refundProofFile,
    );
    final toSave = Tender(
      id: docRef.id,
      tenderNumber: tenderNumber,
      year: year,
      tenderName: draft.tenderName,
      departmentName: draft.departmentName,
      subDepartmentName: draft.subDepartmentName,
      category: draft.category,
      status: draft.status,
      publishDate: draft.publishDate,
      submissionDate: draft.submissionDate,
      bidValidityDays: draft.bidValidityDays,
      emdAmount: draft.emdAmount,
      emdType: draft.emdType,
      emdPaymentDate: draft.emdPaymentDate,
      emdPaymentBank: draft.emdPaymentBank,
      utrNumber: draft.utrNumber,
      paymentProofStoragePath: proofPath,
      paymentProofFileName: proofPath != null ? paymentProofFile!.name : null,
      emdValidUntil: draft.emdValidUntil,
      refundStatus: draft.refundStatus,
      refundedAt: draft.refundedAt,
      refundToAccount: draft.refundToAccount,
      refundUtrNumber: draft.refundUtrNumber,
      refundProofStoragePath: refundProofPath,
      refundProofFileName: refundProofPath != null ? refundProofFile!.name : null,
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

  /// [tender] carries the existing payment/refund proof paths and names;
  /// a new [paymentProofFile] or [refundProofFile] replaces them.
  Future<void> update({
    required Tender tender,
    required String actorUid,
    required String actorName,
    ({Uint8List bytes, String name, String contentType})? paymentProofFile,
    ({Uint8List bytes, String name, String contentType})? refundProofFile,
  }) async {
    final proofPath = await _uploadProof(
      docId: tender.id,
      slot: 'payment_proof',
      year: tender.year,
      file: paymentProofFile,
    );
    final refundProofPath = await _uploadProof(
      docId: tender.id,
      slot: 'refund_proof',
      year: tender.year,
      file: refundProofFile,
    );
    final data = tender.toMap();
    if (proofPath != null) {
      data['paymentProofStoragePath'] = proofPath;
      data['paymentProofFileName'] = paymentProofFile!.name;
    }
    if (refundProofPath != null) {
      data['refundProofStoragePath'] = refundProofPath;
      data['refundProofFileName'] = refundProofFile!.name;
    }
    await _collection.doc(tender.id).update(data);
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
    if (tender.hasPaymentProof) await _storage.delete(tender.paymentProofStoragePath!);
    if (tender.hasRefundProof) await _storage.delete(tender.refundProofStoragePath!);
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
