import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/firestore_paths.dart';
import '../../../core/services/firestore_counter_service.dart';
import '../../../core/services/storage_upload_service.dart';
import '../../audit/data/audit_log_repository.dart';
import '../../audit/domain/audit_entry.dart';
import '../domain/io_document.dart';
import '../domain/io_enums.dart';

/// Inward/Outward CRUD (REQUIREMENTS.md §6). Document numbers are
/// generated atomically via [FirestoreCounterService] (Phase 1 plan
/// decision #4); every write is mirrored into [AuditLogRepository].
class IoRepository {
  IoRepository({
    required FirebaseFirestore firestore,
    required StorageUploadService storage,
    required AuditLogRepository auditLog,
  }) : _firestore = firestore,
       _storage = storage,
       _auditLog = auditLog,
       _counter = FirestoreCounterService(firestore);

  final FirebaseFirestore _firestore;
  final StorageUploadService _storage;
  final AuditLogRepository _auditLog;
  final FirestoreCounterService _counter;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection(FirestorePaths.inwardOutwardDocuments);

  Stream<List<IoDocument>> watchByType(IoType type) {
    return _collection
        .where('type', isEqualTo: type.wireValue)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => IoDocument.fromMap(d.id, d.data())).toList());
  }

  /// Creates a new entry: allocates the doc number, writes the Firestore
  /// document, optionally uploads the attached file, then logs the audit
  /// entry. [draft] carries user-entered field values with a placeholder
  /// id/docNumber that get replaced here.
  Future<IoDocument> create({
    required IoDocument draft,
    required String actorUid,
    required String actorName,
    Uint8List? fileBytes,
    String? fileName,
    String? fileContentType,
  }) async {
    final year = draft.date.year;
    final sequence = await _counter.nextSequence(type: draft.type.wireValue, year: year);
    final docNumber = FirestoreCounterService.formatDocNumber(
      prefix: draft.type.docPrefix,
      year: year,
      sequence: sequence,
    );

    final docRef = _collection.doc();

    // Upload first (if any) so the final IoDocument can be built once,
    // directly via its constructor — round-tripping through
    // toMap()/fromMap() here would break, since toMap() sets createdAt to
    // FieldValue.serverTimestamp() (a write-time sentinel), which
    // fromMap()'s `as Timestamp?` cast can't parse back.
    String? storagePath;
    if (fileBytes != null && fileName != null) {
      storagePath = 'inward_outward/${draft.type.wireValue}/$year/${docRef.id}/$fileName';
      await _storage.uploadBytes(
        path: storagePath,
        bytes: fileBytes,
        contentType: fileContentType ?? 'application/octet-stream',
      );
    }

    final toSave = IoDocument(
      id: docRef.id,
      type: draft.type,
      docNumber: docNumber,
      year: year,
      date: draft.date,
      docType: draft.docType,
      department: draft.department,
      subject: draft.subject,
      remarks: draft.remarks,
      receivedFrom: draft.receivedFrom,
      senderCompany: draft.senderCompany,
      priority: draft.priority,
      receiverName: draft.receiverName,
      sentTo: draft.sentTo,
      addressOrEmail: draft.addressOrEmail,
      dispatchMode: draft.dispatchMode,
      trackingNumber: draft.trackingNumber,
      sentBy: draft.sentBy,
      storagePath: storagePath,
      fileName: storagePath != null ? fileName : null,
      fileContentType: storagePath != null ? fileContentType : null,
      fileSizeBytes: storagePath != null ? fileBytes!.length : null,
      createdBy: actorUid,
      createdByName: actorName,
    );

    await docRef.set(toSave.toMap());

    await _auditLog.log(
      actorUid: actorUid,
      actorName: actorName,
      action: AuditAction.create,
      module: 'inward_outward',
      targetId: docRef.id,
      targetLabel: '$docNumber — ${draft.subject}',
    );

    return toSave;
  }

  Future<void> update({
    required IoDocument document,
    required String actorUid,
    required String actorName,
  }) async {
    await _collection.doc(document.id).update(document.toMap());
    await _auditLog.log(
      actorUid: actorUid,
      actorName: actorName,
      action: AuditAction.update,
      module: 'inward_outward',
      targetId: document.id,
      targetLabel: '${document.docNumber} — ${document.subject}',
    );
  }

  /// Toggles the "Seen" acknowledgement flag — used from the checkbox
  /// shown to `power_user`/`manager`/`admin` (see `_SeenCell`). Writes only
  /// `{seen, updatedAt}` rather than the full [IoDocument.toMap] to keep
  /// the payload minimal; [update] would also work since those roles have
  /// full document-write rights (`canManageDocuments()` in
  /// firestore.rules), but this avoids re-sending every other field for a
  /// single-checkbox interaction.
  Future<void> setSeen({
    required IoDocument document,
    required bool seen,
    required String actorUid,
    required String actorName,
  }) async {
    await _collection.doc(document.id).update({'seen': seen, 'updatedAt': FieldValue.serverTimestamp()});
    await _auditLog.log(
      actorUid: actorUid,
      actorName: actorName,
      action: AuditAction.update,
      module: 'inward_outward',
      targetId: document.id,
      targetLabel: '${document.docNumber} marked ${seen ? 'seen' : 'unseen'}',
    );
  }

  Future<void> delete({
    required IoDocument document,
    required String actorUid,
    required String actorName,
  }) async {
    if (document.hasFile) {
      await _storage.delete(document.storagePath!);
    }
    await _collection.doc(document.id).delete();
    await _auditLog.log(
      actorUid: actorUid,
      actorName: actorName,
      action: AuditAction.delete,
      module: 'inward_outward',
      targetId: document.id,
      targetLabel: '${document.docNumber} — ${document.subject}',
    );
  }
}
