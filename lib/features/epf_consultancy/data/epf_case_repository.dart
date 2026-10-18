import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/firestore_paths.dart';
import '../../../core/services/firestore_counter_service.dart';
import '../../../core/services/storage_upload_service.dart';
import '../../../core/utils/date_formatting.dart';
import '../../audit/data/audit_log_repository.dart';
import '../../audit/domain/audit_entry.dart';
import '../domain/epf_case.dart';
import '../domain/epf_enums.dart';
import '../domain/epf_followup.dart';

/// EPF Case CRUD (REQUIREMENTS.md §9.5). Same pattern as every other
/// repository in this app: doc numbers via [FirestoreCounterService], and
/// the final [EpfCase] is always built directly via its constructor
/// (never round-tripped through `toMap()`/`fromMap()`).
class EpfCaseRepository {
  EpfCaseRepository({
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

  CollectionReference<Map<String, dynamic>> get _collection => _firestore.collection(FirestorePaths.epfCases);
  CollectionReference<Map<String, dynamic>> get _followups => _firestore.collection(FirestorePaths.epfFollowups);

  Stream<List<EpfCase>> watchAll() {
    return _collection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => EpfCase.fromMap(d.id, d.data())).toList());
  }

  Future<Map<EpfDocumentSlot, String>> _uploadDocuments({
    required String docId,
    required int year,
    required Map<EpfDocumentSlot, ({Uint8List bytes, String name, String contentType})> files,
  }) async {
    final paths = <EpfDocumentSlot, String>{};
    for (final entry in files.entries) {
      final path = 'epf_cases/$year/$docId/${entry.key.wireValue}/${entry.value.name}';
      await _storage.uploadBytes(path: path, bytes: entry.value.bytes, contentType: entry.value.contentType);
      paths[entry.key] = path;
    }
    return paths;
  }

  Future<EpfCase> create({
    required EpfCase draft,
    required String actorUid,
    required String actorName,
    Map<EpfDocumentSlot, ({Uint8List bytes, String name, String contentType})> documentFiles = const {},
  }) async {
    final year = DateTime.now().year;
    final sequence = await _counter.nextSequence(type: 'epf', year: year);
    final clientId = FirestoreCounterService.formatDocNumber(prefix: 'CL', year: year, sequence: sequence);

    final docRef = _collection.doc();
    final uploadedPaths = await _uploadDocuments(docId: docRef.id, year: year, files: documentFiles);
    final uploadedNames = {for (final entry in documentFiles.entries) entry.key: entry.value.name};

    final toSave = EpfCase(
      id: docRef.id,
      clientId: clientId,
      year: year,
      name: draft.name,
      fatherName: draft.fatherName,
      mobile: draft.mobile,
      alternateMobile: draft.alternateMobile,
      email: draft.email,
      address: draft.address,
      aadhaarNumber: draft.aadhaarNumber,
      panNumber: draft.panNumber,
      dateOfBirth: draft.dateOfBirth,
      gender: draft.gender,
      uanNumber: draft.uanNumber,
      password: draft.password,
      currentCompany: draft.currentCompany,
      services: draft.services,
      otherService: draft.otherService,
      stage: draft.stage,
      documentPaths: uploadedPaths,
      documentFileNames: uploadedNames,
      fee: draft.fee,
      amountPaid: draft.amountPaid,
      feePaidAt: draft.feePaidAt,
      followUps: draft.followUps,
      createdBy: actorUid,
      createdByName: actorName,
    );

    await docRef.set(toSave.toMap());
    await _auditLog.log(
      actorUid: actorUid,
      actorName: actorName,
      action: AuditAction.create,
      module: 'epf_consultancy',
      targetId: docRef.id,
      targetLabel: '$clientId — ${draft.name} (${draft.servicesLabel})',
    );

    return toSave;
  }

  Future<void> update({
    required EpfCase epfCase,
    required String actorUid,
    required String actorName,
    Map<EpfDocumentSlot, ({Uint8List bytes, String name, String contentType})> documentFiles = const {},
  }) async {
    final uploadedPaths = await _uploadDocuments(docId: epfCase.id, year: epfCase.year, files: documentFiles);
    final mergedPaths = {...epfCase.documentPaths, ...uploadedPaths};
    final mergedNames = {
      ...epfCase.documentFileNames,
      for (final entry in documentFiles.entries) entry.key: entry.value.name,
    };

    final toSave = EpfCase(
      id: epfCase.id,
      clientId: epfCase.clientId,
      year: epfCase.year,
      name: epfCase.name,
      fatherName: epfCase.fatherName,
      mobile: epfCase.mobile,
      alternateMobile: epfCase.alternateMobile,
      email: epfCase.email,
      address: epfCase.address,
      aadhaarNumber: epfCase.aadhaarNumber,
      panNumber: epfCase.panNumber,
      dateOfBirth: epfCase.dateOfBirth,
      gender: epfCase.gender,
      uanNumber: epfCase.uanNumber,
      password: epfCase.password,
      currentCompany: epfCase.currentCompany,
      services: epfCase.services,
      otherService: epfCase.otherService,
      stage: epfCase.stage,
      documentPaths: mergedPaths,
      documentFileNames: mergedNames,
      fee: epfCase.fee,
      amountPaid: epfCase.amountPaid,
      feePaidAt: epfCase.feePaidAt,
      followUps: epfCase.followUps,
      createdBy: epfCase.createdBy,
      createdByName: epfCase.createdByName,
      createdAt: epfCase.createdAt,
    );

    await _collection.doc(toSave.id).update(toSave.toMap());
    await _auditLog.log(
      actorUid: actorUid,
      actorName: actorName,
      action: AuditAction.update,
      module: 'epf_consultancy',
      targetId: toSave.id,
      targetLabel: '${toSave.clientId} — ${toSave.name} (${toSave.servicesLabel})',
    );
  }

  Future<void> delete({required EpfCase epfCase, required String actorUid, required String actorName}) async {
    for (final path in epfCase.documentPaths.values) {
      await _storage.delete(path);
    }
    final followups = await _followups.where('caseId', isEqualTo: epfCase.id).get();
    if (followups.docs.isNotEmpty) {
      final batch = _firestore.batch();
      for (final f in followups.docs) {
        batch.delete(f.reference);
      }
      await batch.commit();
    }
    await _collection.doc(epfCase.id).delete();
    await _auditLog.log(
      actorUid: actorUid,
      actorName: actorName,
      action: AuditAction.delete,
      module: 'epf_consultancy',
      targetId: epfCase.id,
      targetLabel: '${epfCase.clientId} — ${epfCase.name}',
    );
  }

  // ---- Followups ----

  /// Every EPF followup; callers group by case and sort client-side.
  Stream<List<EpfFollowup>> watchFollowups() {
    return _followups.snapshots().map((snap) => snap.docs.map((d) => EpfFollowup.fromMap(d.id, d.data())).toList());
  }

  Future<void> addFollowup({
    required EpfCase epfCase,
    required DateTime followupDate,
    required String remark,
    required FollowupStatus status,
    required String actorUid,
    required String actorName,
  }) async {
    final ref = _followups.doc();
    final followup = EpfFollowup(
      id: ref.id,
      caseId: epfCase.id,
      clientId: epfCase.clientId,
      followupDate: followupDate,
      remark: remark,
      status: status,
      createdBy: actorUid,
      createdByName: actorName,
    );
    await ref.set(followup.toMap());
    await _auditLog.log(
      actorUid: actorUid,
      actorName: actorName,
      action: AuditAction.create,
      module: 'epf_consultancy',
      targetId: epfCase.id,
      targetLabel: '${epfCase.clientId} followup added (${formatDisplayDate(followupDate)})',
    );
  }

  Future<void> updateFollowup({
    required EpfFollowup followup,
    required DateTime followupDate,
    required String remark,
    required FollowupStatus status,
    required String actorUid,
    required String actorName,
  }) async {
    await _followups.doc(followup.id).update({
      'followupDate': Timestamp.fromDate(followupDate),
      'remark': remark,
      'status': status.wireValue,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await _auditLog.log(
      actorUid: actorUid,
      actorName: actorName,
      action: AuditAction.update,
      module: 'epf_consultancy',
      targetId: followup.caseId,
      targetLabel: '${followup.clientId} followup (${formatDisplayDate(followupDate)}) updated',
    );
  }

  Future<void> setFollowupStatus({
    required EpfFollowup followup,
    required FollowupStatus status,
    required String actorUid,
    required String actorName,
  }) async {
    await _followups.doc(followup.id).update({'status': status.wireValue, 'updatedAt': FieldValue.serverTimestamp()});
    await _auditLog.log(
      actorUid: actorUid,
      actorName: actorName,
      action: AuditAction.update,
      module: 'epf_consultancy',
      targetId: followup.caseId,
      targetLabel:
          '${followup.clientId} followup (${formatDisplayDate(followup.followupDate)}) marked ${status.label}',
    );
  }

  Future<void> deleteFollowup({
    required EpfFollowup followup,
    required String actorUid,
    required String actorName,
  }) async {
    await _followups.doc(followup.id).delete();
    await _auditLog.log(
      actorUid: actorUid,
      actorName: actorName,
      action: AuditAction.delete,
      module: 'epf_consultancy',
      targetId: followup.caseId,
      targetLabel: '${followup.clientId} followup (${formatDisplayDate(followup.followupDate)}) deleted',
    );
  }
}
