import 'dart:typed_data';

import 'package:aioffice/core/services/storage_upload_service.dart';
import 'package:aioffice/features/audit/data/audit_log_repository.dart';
import 'package:aioffice/features/candidates/data/candidate_repository.dart';
import 'package:aioffice/features/candidates/domain/candidate.dart';
import 'package:aioffice/features/candidates/domain/candidate_enums.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockStorageUploadService extends Mock implements StorageUploadService {}

Candidate _draft({DateTime? dateOfBirth, CandidateCategory category = CandidateCategory.security}) {
  return Candidate(
    id: '',
    candidateId: '',
    year: DateTime.now().year,
    fullName: 'Suresh Gowda',
    mobileNumber: '9845066210',
    dateOfBirth: dateOfBirth ?? DateTime(1998, 6, 20),
    gender: Gender.male,
    maritalStatus: MaritalStatus.single,
    district: 'Mysuru',
    taluk: 'Nanjangud',
    education: const {EducationLevel.puc, EducationLevel.iti},
    category: category,
    experience: ExperienceLevel.fresher,
    languagesKnown: const {Language.kannada, Language.english},
    height: '5\'8"',
    exServiceman: false,
    createdBy: 'actor-1',
    createdByName: 'Actor One',
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(Uint8List(0));
  });

  late FakeFirebaseFirestore firestore;
  late _MockStorageUploadService storage;
  late CandidateRepository repository;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    storage = _MockStorageUploadService();
    repository = CandidateRepository(firestore: firestore, storage: storage, auditLog: AuditLogRepository(firestore));
  });

  test('first candidate of a year is numbered CAND/YYYY/0001', () async {
    final saved = await repository.create(draft: _draft(), actorUid: 'actor-1', actorName: 'Actor One');
    expect(saved.candidateId, 'CAND/${DateTime.now().year}/0001');
  });

  test('create preserves multi-select education and languages', () async {
    final saved = await repository.create(draft: _draft(), actorUid: 'actor-1', actorName: 'Actor One');
    expect(saved.education, {EducationLevel.puc, EducationLevel.iti});
    expect(saved.languagesKnown, {Language.kannada, Language.english});

    final stored = await repository.watchAll().first;
    expect(stored.single.education, saved.education);
  });

  test('create with a resume upload saves successfully (no FieldValue/Timestamp crash)', () async {
    when(
      () => storage.uploadBytes(
        path: any(named: 'path'),
        bytes: any(named: 'bytes'),
        contentType: any(named: 'contentType'),
      ),
    ).thenAnswer((_) async {});

    final saved = await repository.create(
      draft: _draft(),
      actorUid: 'actor-1',
      actorName: 'Actor One',
      resumeFile: (bytes: Uint8List.fromList([1, 2, 3]), name: 'resume.pdf', contentType: 'application/pdf'),
    );

    expect(saved.hasResume, isTrue);
  });

  test('delete removes the document and logs create+delete audit entries', () async {
    final saved = await repository.create(draft: _draft(), actorUid: 'actor-1', actorName: 'Actor One');
    await repository.delete(candidate: saved, actorUid: 'actor-1', actorName: 'Actor One');

    final remaining = await firestore.collection('candidates').get();
    expect(remaining.docs, isEmpty);
    final auditDocs = await firestore.collection('audit_log').get();
    expect(auditDocs.docs.map((d) => d.data()['action']), containsAll(['create', 'delete']));
  });

  test('age is computed from date of birth', () {
    final now = DateTime.now();
    final birthdayToday = DateTime(now.year - 20, now.month, now.day);
    final justTurned = _draft(dateOfBirth: birthdayToday);
    final notYetBirthday = _draft(dateOfBirth: birthdayToday.add(const Duration(days: 5)));
    expect(justTurned.age, 20);
    expect(notYetBirthday.age, 19);
  });
}
