import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/firestore_paths.dart';
import '../../../core/services/firestore_counter_service.dart';
import '../../../core/services/storage_upload_service.dart';
import '../../audit/data/audit_log_repository.dart';
import '../../audit/domain/audit_entry.dart';
import '../domain/candidate.dart';

/// Candidate CRUD (REQUIREMENTS.md §9.2). Same pattern as
/// `EmployeeRepository`/`WorkOrderRepository`: doc numbers via
/// [FirestoreCounterService], and the final [Candidate] is always built
/// directly via its constructor (never round-tripped through
/// `toMap()`/`fromMap()`).
class CandidateRepository {
  CandidateRepository({
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

  CollectionReference<Map<String, dynamic>> get _collection => _firestore.collection(FirestorePaths.candidates);

  Stream<List<Candidate>> watchAll() {
    return _collection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => Candidate.fromMap(d.id, d.data())).toList());
  }

  Future<Candidate> create({
    required Candidate draft,
    required String actorUid,
    required String actorName,
    ({Uint8List bytes, String name, String contentType})? resumeFile,
  }) async {
    final year = DateTime.now().year;
    final sequence = await _counter.nextSequence(type: 'cand', year: year);
    final candidateId = FirestoreCounterService.formatDocNumber(prefix: 'CAND', year: year, sequence: sequence);

    final docRef = _collection.doc();

    String? resumeStoragePath;
    if (resumeFile != null) {
      resumeStoragePath = 'candidates/$year/${docRef.id}/${resumeFile.name}';
      await _storage.uploadBytes(path: resumeStoragePath, bytes: resumeFile.bytes, contentType: resumeFile.contentType);
    }

    final toSave = Candidate(
      id: docRef.id,
      candidateId: candidateId,
      year: year,
      fullName: draft.fullName,
      mobileNumber: draft.mobileNumber,
      alternateNumber: draft.alternateNumber,
      referredBy: draft.referredBy,
      whatsappNumber: draft.whatsappNumber,
      dateOfBirth: draft.dateOfBirth,
      gender: draft.gender,
      maritalStatus: draft.maritalStatus,
      village: draft.village,
      cityTown: draft.cityTown,
      taluk: draft.taluk,
      district: draft.district,
      state: draft.state,
      pincode: draft.pincode,
      education: draft.education,
      category: draft.category,
      experience: draft.experience,
      languagesKnown: draft.languagesKnown,
      height: draft.height,
      exServiceman: draft.exServiceman,
      resumeStoragePath: resumeStoragePath,
      resumeFileName: resumeStoragePath != null ? resumeFile!.name : null,
      createdBy: actorUid,
      createdByName: actorName,
    );

    await docRef.set(toSave.toMap());
    await _auditLog.log(
      actorUid: actorUid,
      actorName: actorName,
      action: AuditAction.create,
      module: 'candidates',
      targetId: docRef.id,
      targetLabel: '$candidateId — ${draft.fullName}',
    );

    return toSave;
  }

  Future<void> update({
    required Candidate candidate,
    required String actorUid,
    required String actorName,
    ({Uint8List bytes, String name, String contentType})? resumeFile,
  }) async {
    var resumeStoragePath = candidate.resumeStoragePath;
    var resumeFileName = candidate.resumeFileName;
    if (resumeFile != null) {
      resumeStoragePath = 'candidates/${candidate.year}/${candidate.id}/${resumeFile.name}';
      await _storage.uploadBytes(path: resumeStoragePath, bytes: resumeFile.bytes, contentType: resumeFile.contentType);
      resumeFileName = resumeFile.name;
    }

    final toSave = Candidate(
      id: candidate.id,
      candidateId: candidate.candidateId,
      year: candidate.year,
      fullName: candidate.fullName,
      mobileNumber: candidate.mobileNumber,
      alternateNumber: candidate.alternateNumber,
      referredBy: candidate.referredBy,
      whatsappNumber: candidate.whatsappNumber,
      dateOfBirth: candidate.dateOfBirth,
      gender: candidate.gender,
      maritalStatus: candidate.maritalStatus,
      village: candidate.village,
      cityTown: candidate.cityTown,
      taluk: candidate.taluk,
      district: candidate.district,
      state: candidate.state,
      pincode: candidate.pincode,
      education: candidate.education,
      category: candidate.category,
      experience: candidate.experience,
      languagesKnown: candidate.languagesKnown,
      height: candidate.height,
      exServiceman: candidate.exServiceman,
      resumeStoragePath: resumeStoragePath,
      resumeFileName: resumeFileName,
      createdBy: candidate.createdBy,
      createdByName: candidate.createdByName,
      createdAt: candidate.createdAt,
    );

    await _collection.doc(toSave.id).update(toSave.toMap());
    await _auditLog.log(
      actorUid: actorUid,
      actorName: actorName,
      action: AuditAction.update,
      module: 'candidates',
      targetId: toSave.id,
      targetLabel: '${toSave.candidateId} — ${toSave.fullName}',
    );
  }

  Future<void> delete({required Candidate candidate, required String actorUid, required String actorName}) async {
    if (candidate.hasResume) {
      await _storage.delete(candidate.resumeStoragePath!);
    }
    await _collection.doc(candidate.id).delete();
    await _auditLog.log(
      actorUid: actorUid,
      actorName: actorName,
      action: AuditAction.delete,
      module: 'candidates',
      targetId: candidate.id,
      targetLabel: '${candidate.candidateId} — ${candidate.fullName}',
    );
  }
}
