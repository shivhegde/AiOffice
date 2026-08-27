import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/firestore_paths.dart';
import '../../../core/services/storage_upload_service.dart';
import '../../audit/data/audit_log_repository.dart';
import '../../audit/domain/audit_entry.dart';
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

  Stream<List<VehiclePolicy>> watchAll() {
    return _collection
        .orderBy('expiryDate')
        .snapshots()
        .map((snap) => snap.docs.map((d) => VehiclePolicy.fromMap(d.id, d.data())).toList());
  }

  Future<VehiclePolicy> create({
    required VehiclePolicy draft,
    required String actorUid,
    required String actorName,
    ({Uint8List bytes, String name, String contentType})? policyFile,
  }) async {
    final docRef = _collection.doc();

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
      rcDetails: draft.rcDetails,
      vehicleType: draft.vehicleType,
      makeModel: draft.makeModel,
      manufacturingYear: draft.manufacturingYear,
      engineNumber: draft.engineNumber,
      chassisNumber: draft.chassisNumber,
      financerDetails: draft.financerDetails,
      insuranceCompany: draft.insuranceCompany,
      policyNumber: draft.policyNumber,
      policyType: draft.policyType,
      idv: draft.idv,
      ncb: draft.ncb,
      premium: draft.premium,
      commission: draft.commission,
      startDate: draft.startDate,
      expiryDate: draft.expiryDate,
      policyStoragePath: policyStoragePath,
      policyFileName: policyStoragePath != null ? policyFile!.name : null,
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
  }) async {
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
      rcDetails: policy.rcDetails,
      vehicleType: policy.vehicleType,
      makeModel: policy.makeModel,
      manufacturingYear: policy.manufacturingYear,
      engineNumber: policy.engineNumber,
      chassisNumber: policy.chassisNumber,
      financerDetails: policy.financerDetails,
      insuranceCompany: policy.insuranceCompany,
      policyNumber: policy.policyNumber,
      policyType: policy.policyType,
      idv: policy.idv,
      ncb: policy.ncb,
      premium: policy.premium,
      commission: policy.commission,
      startDate: policy.startDate,
      expiryDate: policy.expiryDate,
      policyStoragePath: policyStoragePath,
      policyFileName: policyFileName,
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
}
