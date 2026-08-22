import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/firestore_paths.dart';
import '../../../core/services/firestore_counter_service.dart';
import '../../../core/services/storage_upload_service.dart';
import '../../audit/data/audit_log_repository.dart';
import '../../audit/domain/audit_entry.dart';
import '../domain/work_order.dart';

/// Work Order + embedded Fixed Deposit CRUD (REQUIREMENTS.md §8). Same
/// pattern as `IoRepository`/`TenderRepository`: doc numbers via
/// [FirestoreCounterService], and the final [WorkOrder] is always built
/// directly via its constructor (never round-tripped through
/// `toMap()`/`fromMap()`, which would crash on the unresolved
/// `FieldValue.serverTimestamp()` sentinel in `createdAt` — see
/// `IoRepository` for the incident this pattern was fixed after).
class WorkOrderRepository {
  WorkOrderRepository({
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

  CollectionReference<Map<String, dynamic>> get _collection => _firestore.collection(FirestorePaths.workOrders);

  Stream<List<WorkOrder>> watchAll() {
    return _collection
        .orderBy('startDate', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => WorkOrder.fromMap(d.id, d.data())).toList());
  }

  Future<WorkOrder> create({
    required WorkOrder draft,
    required String actorUid,
    required String actorName,
    Uint8List? fdFileBytes,
    String? fdFileName,
    String? fdFileContentType,
  }) async {
    final year = draft.workOrderDate.year;
    final sequence = await _counter.nextSequence(type: 'wo', year: year);
    final workOrderNumber = FirestoreCounterService.formatDocNumber(prefix: 'WO', year: year, sequence: sequence);

    final docRef = _collection.doc();

    String? fdStoragePath;
    if (fdFileBytes != null && fdFileName != null) {
      fdStoragePath = 'work_orders/$year/${docRef.id}/$fdFileName';
      await _storage.uploadBytes(
        path: fdStoragePath,
        bytes: fdFileBytes,
        contentType: fdFileContentType ?? 'application/octet-stream',
      );
    }

    final toSave = WorkOrder(
      id: docRef.id,
      workOrderNumber: workOrderNumber,
      year: year,
      workOrderDate: draft.workOrderDate,
      departmentName: draft.departmentName,
      contractType: draft.contractType,
      startDate: draft.startDate,
      endDate: draft.endDate,
      extensionAvailable: draft.extensionAvailable,
      status: draft.status,
      remarks: draft.remarks,
      extensionStartDate: draft.extensionStartDate,
      extensionEndDate: draft.extensionEndDate,
      extensionOrderNumber: draft.extensionOrderNumber,
      extensionReason: draft.extensionReason,
      deptOfficeAddress: draft.deptOfficeAddress,
      deptContactPerson: draft.deptContactPerson,
      deptPhoneNumber: draft.deptPhoneNumber,
      deptEmail: draft.deptEmail,
      deptGSTIN: draft.deptGSTIN,
      contractValue: draft.contractValue,
      securityDeposit: draft.securityDeposit,
      emdAmount: draft.emdAmount,
      tenderNumber: draft.tenderNumber,
      tenderName: draft.tenderName,
      fdNumber: draft.fdNumber,
      fdBankName: draft.fdBankName,
      fdBranchName: draft.fdBranchName,
      fdAmount: draft.fdAmount,
      fdIssueDate: draft.fdIssueDate,
      fdMaturityDate: draft.fdMaturityDate,
      fdInterestRate: draft.fdInterestRate,
      fdStoragePath: fdStoragePath ?? draft.fdStoragePath,
      fdFileName: fdStoragePath != null ? fdFileName : draft.fdFileName,
      fdStatus: draft.fdStatus,
      fdReleasedAt: draft.fdReleasedAt,
      createdBy: actorUid,
      createdByName: actorName,
    );

    await docRef.set(toSave.toMap());
    await _auditLog.log(
      actorUid: actorUid,
      actorName: actorName,
      action: AuditAction.create,
      module: 'work_orders',
      targetId: docRef.id,
      targetLabel: '$workOrderNumber — ${draft.departmentName}',
    );

    return toSave;
  }

  Future<void> update({
    required WorkOrder workOrder,
    required String actorUid,
    required String actorName,
    Uint8List? fdFileBytes,
    String? fdFileName,
    String? fdFileContentType,
  }) async {
    var toSave = workOrder;
    if (fdFileBytes != null && fdFileName != null) {
      final fdStoragePath = 'work_orders/${workOrder.year}/${workOrder.id}/$fdFileName';
      await _storage.uploadBytes(
        path: fdStoragePath,
        bytes: fdFileBytes,
        contentType: fdFileContentType ?? 'application/octet-stream',
      );
      toSave = WorkOrder(
        id: workOrder.id,
        workOrderNumber: workOrder.workOrderNumber,
        year: workOrder.year,
        workOrderDate: workOrder.workOrderDate,
        departmentName: workOrder.departmentName,
        contractType: workOrder.contractType,
        startDate: workOrder.startDate,
        endDate: workOrder.endDate,
        extensionAvailable: workOrder.extensionAvailable,
        status: workOrder.status,
        remarks: workOrder.remarks,
        extensionStartDate: workOrder.extensionStartDate,
        extensionEndDate: workOrder.extensionEndDate,
        extensionOrderNumber: workOrder.extensionOrderNumber,
        extensionReason: workOrder.extensionReason,
        deptOfficeAddress: workOrder.deptOfficeAddress,
        deptContactPerson: workOrder.deptContactPerson,
        deptPhoneNumber: workOrder.deptPhoneNumber,
        deptEmail: workOrder.deptEmail,
        deptGSTIN: workOrder.deptGSTIN,
        contractValue: workOrder.contractValue,
        securityDeposit: workOrder.securityDeposit,
        emdAmount: workOrder.emdAmount,
        tenderNumber: workOrder.tenderNumber,
        tenderName: workOrder.tenderName,
        fdNumber: workOrder.fdNumber,
        fdBankName: workOrder.fdBankName,
        fdBranchName: workOrder.fdBranchName,
        fdAmount: workOrder.fdAmount,
        fdIssueDate: workOrder.fdIssueDate,
        fdMaturityDate: workOrder.fdMaturityDate,
        fdInterestRate: workOrder.fdInterestRate,
        fdStoragePath: fdStoragePath,
        fdFileName: fdFileName,
        fdStatus: workOrder.fdStatus,
        fdReleasedAt: workOrder.fdReleasedAt,
        createdBy: workOrder.createdBy,
        createdByName: workOrder.createdByName,
        createdAt: workOrder.createdAt,
      );
    }

    await _collection.doc(toSave.id).update(toSave.toMap());
    await _auditLog.log(
      actorUid: actorUid,
      actorName: actorName,
      action: AuditAction.update,
      module: 'work_orders',
      targetId: toSave.id,
      targetLabel: '${toSave.workOrderNumber} — ${toSave.departmentName}',
    );
  }

  Future<void> delete({required WorkOrder workOrder, required String actorUid, required String actorName}) async {
    if (workOrder.hasFdFile) {
      await _storage.delete(workOrder.fdStoragePath!);
    }
    await _collection.doc(workOrder.id).delete();
    await _auditLog.log(
      actorUid: actorUid,
      actorName: actorName,
      action: AuditAction.delete,
      module: 'work_orders',
      targetId: workOrder.id,
      targetLabel: '${workOrder.workOrderNumber} — ${workOrder.departmentName}',
    );
  }
}
