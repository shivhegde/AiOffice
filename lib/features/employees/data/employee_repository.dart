import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/firestore_paths.dart';
import '../../../core/services/firestore_counter_service.dart';
import '../../../core/services/storage_upload_service.dart';
import '../../audit/data/audit_log_repository.dart';
import '../../audit/domain/audit_entry.dart';
import '../domain/employee.dart';

/// Employee CRUD (REQUIREMENTS.md §9.1). Same pattern as
/// `WorkOrderRepository`: doc numbers via [FirestoreCounterService], and
/// the final [Employee] is always built directly via its constructor
/// (never round-tripped through `toMap()`/`fromMap()`).
class EmployeeRepository {
  EmployeeRepository({
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

  CollectionReference<Map<String, dynamic>> get _collection => _firestore.collection(FirestorePaths.employees);

  Stream<List<Employee>> watchAll() {
    return _collection
        .orderBy('dateOfAppointment', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => Employee.fromMap(d.id, d.data())).toList());
  }

  Future<String?> _uploadIfPresent({
    required String docId,
    required String slot,
    required int year,
    ({Uint8List bytes, String name, String contentType})? file,
  }) async {
    if (file == null) return null;
    final path = 'employees/$year/$docId/$slot/${file.name}';
    await _storage.uploadBytes(path: path, bytes: file.bytes, contentType: file.contentType);
    return path;
  }

  Future<Employee> create({
    required Employee draft,
    required String actorUid,
    required String actorName,
    ({Uint8List bytes, String name, String contentType})? photoFile,
    ({Uint8List bytes, String name, String contentType})? aadhaarFile,
    ({Uint8List bytes, String name, String contentType})? panFile,
  }) async {
    final year = draft.dateOfAppointment.year;
    final sequence = await _counter.nextSequence(type: 'emp', year: year);
    final employeeId = FirestoreCounterService.formatDocNumber(prefix: 'EMP', year: year, sequence: sequence);

    final docRef = _collection.doc();

    final photoPath = await _uploadIfPresent(docId: docRef.id, slot: 'photo', year: year, file: photoFile);
    final aadhaarPath = await _uploadIfPresent(docId: docRef.id, slot: 'aadhaar', year: year, file: aadhaarFile);
    final panPath = await _uploadIfPresent(docId: docRef.id, slot: 'pan', year: year, file: panFile);

    final toSave = Employee(
      id: docRef.id,
      employeeId: employeeId,
      year: year,
      fullName: draft.fullName,
      gender: draft.gender,
      dateOfBirth: draft.dateOfBirth,
      mobileNumber: draft.mobileNumber,
      alternateNumber: draft.alternateNumber,
      email: draft.email,
      currentAddress: draft.currentAddress,
      permanentAddress: draft.permanentAddress,
      city: draft.city,
      state: draft.state,
      pincode: draft.pincode,
      aadhaarNumber: draft.aadhaarNumber,
      panNumber: draft.panNumber,
      dateOfAppointment: draft.dateOfAppointment,
      joiningDate: draft.joiningDate,
      department: draft.department,
      designation: draft.designation,
      employeeType: draft.employeeType,
      branchLocation: draft.branchLocation,
      reportingManager: draft.reportingManager,
      workStatus: draft.workStatus,
      photoStoragePath: photoPath,
      photoFileName: photoPath != null ? photoFile!.name : null,
      aadhaarStoragePath: aadhaarPath,
      aadhaarFileName: aadhaarPath != null ? aadhaarFile!.name : null,
      panStoragePath: panPath,
      panFileName: panPath != null ? panFile!.name : null,
      createdBy: actorUid,
      createdByName: actorName,
    );

    await docRef.set(toSave.toMap());
    await _auditLog.log(
      actorUid: actorUid,
      actorName: actorName,
      action: AuditAction.create,
      module: 'employees',
      targetId: docRef.id,
      targetLabel: '$employeeId — ${draft.fullName}',
    );

    return toSave;
  }

  Future<void> update({
    required Employee employee,
    required String actorUid,
    required String actorName,
    ({Uint8List bytes, String name, String contentType})? photoFile,
    ({Uint8List bytes, String name, String contentType})? aadhaarFile,
    ({Uint8List bytes, String name, String contentType})? panFile,
  }) async {
    final photoPath = await _uploadIfPresent(docId: employee.id, slot: 'photo', year: employee.year, file: photoFile);
    final aadhaarPath = await _uploadIfPresent(
      docId: employee.id,
      slot: 'aadhaar',
      year: employee.year,
      file: aadhaarFile,
    );
    final panPath = await _uploadIfPresent(docId: employee.id, slot: 'pan', year: employee.year, file: panFile);

    final toSave = Employee(
      id: employee.id,
      employeeId: employee.employeeId,
      year: employee.year,
      fullName: employee.fullName,
      gender: employee.gender,
      dateOfBirth: employee.dateOfBirth,
      mobileNumber: employee.mobileNumber,
      alternateNumber: employee.alternateNumber,
      email: employee.email,
      currentAddress: employee.currentAddress,
      permanentAddress: employee.permanentAddress,
      city: employee.city,
      state: employee.state,
      pincode: employee.pincode,
      aadhaarNumber: employee.aadhaarNumber,
      panNumber: employee.panNumber,
      dateOfAppointment: employee.dateOfAppointment,
      joiningDate: employee.joiningDate,
      department: employee.department,
      designation: employee.designation,
      employeeType: employee.employeeType,
      branchLocation: employee.branchLocation,
      reportingManager: employee.reportingManager,
      workStatus: employee.workStatus,
      photoStoragePath: photoPath ?? employee.photoStoragePath,
      photoFileName: photoPath != null ? photoFile!.name : employee.photoFileName,
      aadhaarStoragePath: aadhaarPath ?? employee.aadhaarStoragePath,
      aadhaarFileName: aadhaarPath != null ? aadhaarFile!.name : employee.aadhaarFileName,
      panStoragePath: panPath ?? employee.panStoragePath,
      panFileName: panPath != null ? panFile!.name : employee.panFileName,
      createdBy: employee.createdBy,
      createdByName: employee.createdByName,
      createdAt: employee.createdAt,
    );

    await _collection.doc(toSave.id).update(toSave.toMap());
    await _auditLog.log(
      actorUid: actorUid,
      actorName: actorName,
      action: AuditAction.update,
      module: 'employees',
      targetId: toSave.id,
      targetLabel: '${toSave.employeeId} — ${toSave.fullName}',
    );
  }

  Future<void> delete({required Employee employee, required String actorUid, required String actorName}) async {
    for (final path in [employee.photoStoragePath, employee.aadhaarStoragePath, employee.panStoragePath]) {
      if (path != null && path.isNotEmpty) {
        await _storage.delete(path);
      }
    }
    await _collection.doc(employee.id).delete();
    await _auditLog.log(
      actorUid: actorUid,
      actorName: actorName,
      action: AuditAction.delete,
      module: 'employees',
      targetId: employee.id,
      targetLabel: '${employee.employeeId} — ${employee.fullName}',
    );
  }
}
