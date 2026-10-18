import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/firestore_paths.dart';
import '../../../core/services/storage_upload_service.dart';
import '../../../core/utils/date_formatting.dart';
import '../../audit/data/audit_log_repository.dart';
import '../../audit/domain/audit_entry.dart';
import '../domain/vehicle_followup.dart';
import '../domain/vehicle_insurance_enums.dart';
import '../domain/vehicle_policy.dart';

/// Vehicle Policy CRUD (REQUIREMENTS.md §9.4). No document-number
/// generation — the natural key here is the insurer's own Policy Number
/// (user-entered), unlike Work Orders/Tenders which mint their own
/// internal reference. Same "always build the final record directly via
/// its constructor" convention as every other repository in this app.
class VehiclePolicyRepository {
  VehiclePolicyRepository({
    required FirebaseFirestore firestore,
    required StorageUploadService storage,
    required AuditLogRepository auditLog,
  }) : _firestore = firestore,
       _storage = storage,
       _auditLog = auditLog;

  final FirebaseFirestore _firestore;
  final StorageUploadService _storage;
  final AuditLogRepository _auditLog;

  CollectionReference<Map<String, dynamic>> get _collection => _firestore.collection(FirestorePaths.vehiclePolicies);
  CollectionReference<Map<String, dynamic>> get _followups => _firestore.collection(FirestorePaths.vehicleFollowups);

  Stream<List<VehiclePolicy>> watchAll() {
    return _collection
        .orderBy('expiryDate')
        .snapshots()
        .map((snap) => snap.docs.map((d) => VehiclePolicy.fromMap(d.id, d.data())).toList());
  }

  /// Supporting documents go beside the policy PDF, with the slot as a
  /// file-name prefix (the Storage rule allows one level under the policy).
  Future<Map<VehicleDocumentSlot, String>> _uploadDocuments({
    required String docId,
    required Map<VehicleDocumentSlot, ({Uint8List bytes, String name, String contentType})> files,
  }) async {
    final paths = <VehicleDocumentSlot, String>{};
    for (final entry in files.entries) {
      final path = 'vehicle_policies/$docId/${entry.key.wireValue}__${entry.value.name}';
      await _storage.uploadBytes(path: path, bytes: entry.value.bytes, contentType: entry.value.contentType);
      paths[entry.key] = path;
    }
    return paths;
  }

  Future<VehiclePolicy> create({
    required VehiclePolicy draft,
    required String actorUid,
    required String actorName,
    ({Uint8List bytes, String name, String contentType})? policyFile,
    Map<VehicleDocumentSlot, ({Uint8List bytes, String name, String contentType})> documentFiles = const {},
  }) async {
    final docRef = _collection.doc();
    final documentPaths = await _uploadDocuments(docId: docRef.id, files: documentFiles);

    String? policyStoragePath;
    if (policyFile != null) {
      policyStoragePath = 'vehicle_policies/${docRef.id}/${policyFile.name}';
      await _storage.uploadBytes(path: policyStoragePath, bytes: policyFile.bytes, contentType: policyFile.contentType);
    }

    final toSave = VehiclePolicy(
      id: docRef.id,
      customerName: draft.customerName,
      customerMobile: draft.customerMobile,
      customerEmail: draft.customerEmail,
      customerAddress: draft.customerAddress,
      customerIdNumber: draft.customerIdNumber,
      customerNotes: draft.customerNotes,
      vehicleNumber: draft.vehicleNumber,
      vehicleType: draft.vehicleType,
      vehicleTypeOther: draft.vehicleTypeOther,
      makeModel: draft.makeModel,
      manufacturingYear: draft.manufacturingYear,
      engineNumber: draft.engineNumber,
      chassisNumber: draft.chassisNumber,
      financerDetails: draft.financerDetails,
      insuranceCompany: draft.insuranceCompany,
      policyNumber: draft.policyNumber,
      policyTypes: draft.policyTypes,
      policyTypeOther: draft.policyTypeOther,
      idv: draft.idv,
      ncb: draft.ncb,
      premium: draft.premium,
      commission: draft.commission,
      startDate: draft.startDate,
      expiryDate: draft.expiryDate,
      policyStoragePath: policyStoragePath,
      policyFileName: policyStoragePath != null ? policyFile!.name : null,
      documentPaths: documentPaths,
      documentFileNames: {for (final e in documentFiles.entries) e.key: e.value.name},
      status: draft.status,
      renewedAt: draft.renewedAt,
      createdBy: actorUid,
      createdByName: actorName,
    );

    await docRef.set(toSave.toMap());
    await _auditLog.log(
      actorUid: actorUid,
      actorName: actorName,
      action: AuditAction.create,
      module: 'vehicle_insurance',
      targetId: docRef.id,
      targetLabel: '${draft.vehicleNumber} — ${draft.customerName}',
    );

    return toSave;
  }

  Future<void> update({
    required VehiclePolicy policy,
    required String actorUid,
    required String actorName,
    ({Uint8List bytes, String name, String contentType})? policyFile,
    Map<VehicleDocumentSlot, ({Uint8List bytes, String name, String contentType})> documentFiles = const {},
  }) async {
    final uploadedPaths = await _uploadDocuments(docId: policy.id, files: documentFiles);
    var policyStoragePath = policy.policyStoragePath;
    var policyFileName = policy.policyFileName;
    if (policyFile != null) {
      policyStoragePath = 'vehicle_policies/${policy.id}/${policyFile.name}';
      await _storage.uploadBytes(path: policyStoragePath, bytes: policyFile.bytes, contentType: policyFile.contentType);
      policyFileName = policyFile.name;
    }

    final toSave = VehiclePolicy(
      id: policy.id,
      customerName: policy.customerName,
      customerMobile: policy.customerMobile,
      customerEmail: policy.customerEmail,
      customerAddress: policy.customerAddress,
      customerIdNumber: policy.customerIdNumber,
      customerNotes: policy.customerNotes,
      vehicleNumber: policy.vehicleNumber,
      vehicleType: policy.vehicleType,
      vehicleTypeOther: policy.vehicleTypeOther,
      makeModel: policy.makeModel,
      manufacturingYear: policy.manufacturingYear,
      engineNumber: policy.engineNumber,
      chassisNumber: policy.chassisNumber,
      financerDetails: policy.financerDetails,
      insuranceCompany: policy.insuranceCompany,
      policyNumber: policy.policyNumber,
      policyTypes: policy.policyTypes,
      policyTypeOther: policy.policyTypeOther,
      idv: policy.idv,
      ncb: policy.ncb,
      premium: policy.premium,
      commission: policy.commission,
      startDate: policy.startDate,
      expiryDate: policy.expiryDate,
      policyStoragePath: policyStoragePath,
      policyFileName: policyFileName,
      documentPaths: {...policy.documentPaths, ...uploadedPaths},
      documentFileNames: {
        ...policy.documentFileNames,
        for (final e in documentFiles.entries) e.key: e.value.name,
      },
      status: policy.status,
      renewedAt: policy.renewedAt,
      createdBy: policy.createdBy,
      createdByName: policy.createdByName,
      createdAt: policy.createdAt,
    );

    await _collection.doc(toSave.id).update(toSave.toMap());
    await _auditLog.log(
      actorUid: actorUid,
      actorName: actorName,
      action: AuditAction.update,
      module: 'vehicle_insurance',
      targetId: toSave.id,
      targetLabel: '${toSave.vehicleNumber} — ${toSave.customerName}',
    );
  }

  Future<void> delete({required VehiclePolicy policy, required String actorUid, required String actorName}) async {
    if (policy.hasPolicyFile) {
      await _storage.delete(policy.policyStoragePath!);
    }
    for (final path in policy.documentPaths.values) {
      await _storage.delete(path);
    }
    final followups = await _followups.where('policyId', isEqualTo: policy.id).get();
    if (followups.docs.isNotEmpty) {
      final batch = _firestore.batch();
      for (final f in followups.docs) {
        batch.delete(f.reference);
      }
      await batch.commit();
    }
    await _collection.doc(policy.id).delete();
    await _auditLog.log(
      actorUid: actorUid,
      actorName: actorName,
      action: AuditAction.delete,
      module: 'vehicle_insurance',
      targetId: policy.id,
      targetLabel: '${policy.vehicleNumber} — ${policy.customerName}',
    );
  }

  // ---- Followups ----

  /// Every vehicle followup; callers group by policy and sort client-side.
  Stream<List<VehicleFollowup>> watchFollowups() {
    return _followups.snapshots().map((snap) => snap.docs.map((d) => VehicleFollowup.fromMap(d.id, d.data())).toList());
  }

  Future<void> addFollowup({
    required VehiclePolicy policy,
    required DateTime followupDate,
    required String remark,
    required FollowupStatus status,
    required String actorUid,
    required String actorName,
  }) async {
    final ref = _followups.doc();
    final followup = VehicleFollowup(
      id: ref.id,
      policyId: policy.id,
      vehicleNumber: policy.vehicleNumber,
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
      module: 'vehicle_insurance',
      targetId: policy.id,
      targetLabel: '${policy.vehicleNumber} followup added (${formatDisplayDate(followupDate)})',
    );
  }

  Future<void> updateFollowup({
    required VehicleFollowup followup,
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
      module: 'vehicle_insurance',
      targetId: followup.policyId,
      targetLabel: '${followup.vehicleNumber} followup (${formatDisplayDate(followupDate)}) updated',
    );
  }

  Future<void> setFollowupStatus({
    required VehicleFollowup followup,
    required FollowupStatus status,
    required String actorUid,
    required String actorName,
  }) async {
    await _followups.doc(followup.id).update({'status': status.wireValue, 'updatedAt': FieldValue.serverTimestamp()});
    await _auditLog.log(
      actorUid: actorUid,
      actorName: actorName,
      action: AuditAction.update,
      module: 'vehicle_insurance',
      targetId: followup.policyId,
      targetLabel:
          '${followup.vehicleNumber} followup (${formatDisplayDate(followup.followupDate)}) marked ${status.label}',
    );
  }

  Future<void> deleteFollowup({
    required VehicleFollowup followup,
    required String actorUid,
    required String actorName,
  }) async {
    await _followups.doc(followup.id).delete();
    await _auditLog.log(
      actorUid: actorUid,
      actorName: actorName,
      action: AuditAction.delete,
      module: 'vehicle_insurance',
      targetId: followup.policyId,
      targetLabel: '${followup.vehicleNumber} followup (${formatDisplayDate(followup.followupDate)}) deleted',
    );
  }
}
