import 'dart:typed_data';

import 'package:aioffice/core/services/storage_upload_service.dart';
import 'package:aioffice/features/audit/data/audit_log_repository.dart';
import 'package:aioffice/features/epf_consultancy/data/epf_case_repository.dart';
import 'package:aioffice/features/epf_consultancy/domain/epf_case.dart';
import 'package:aioffice/features/epf_consultancy/domain/epf_enums.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockStorageUploadService extends Mock implements StorageUploadService {}

EpfCase _draft({
  CaseStage stage = CaseStage.newClient,
  double fee = 2000,
  double amountPaid = 0,
  DateTime? feePaidAt,
  DateTime? updatedAt,
}) {
  return EpfCase(
    id: '',
    clientId: '',
    year: DateTime.now().year,
    name: 'Ramesh Babu',
    mobile: '9845066210',
    dateOfBirth: DateTime(1988, 4, 12),
    gender: Gender.male,
    service: EpfService.pfWithdrawal,
    stage: stage,
    fee: fee,
    amountPaid: amountPaid,
    feePaidAt: feePaidAt,
    createdBy: 'actor-1',
    createdByName: 'Actor One',
    updatedAt: updatedAt,
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(Uint8List(0));
  });

  late FakeFirebaseFirestore firestore;
  late _MockStorageUploadService storage;
  late EpfCaseRepository repository;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    storage = _MockStorageUploadService();
    repository = EpfCaseRepository(firestore: firestore, storage: storage, auditLog: AuditLogRepository(firestore));
  });

  test('first case of a year is numbered CL/YYYY/0001', () async {
    final saved = await repository.create(draft: _draft(), actorUid: 'actor-1', actorName: 'Actor One');
    expect(saved.clientId, 'CL/${DateTime.now().year}/0001');
  });

  test('create with document uploads saves successfully (no FieldValue/Timestamp crash)', () async {
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
      documentFiles: {
        EpfDocumentSlot.aadhaar: (
          bytes: Uint8List.fromList([1, 2, 3]),
          name: 'aadhaar.pdf',
          contentType: 'application/pdf',
        ),
      },
    );

    expect(saved.documentPaths.containsKey(EpfDocumentSlot.aadhaar), isTrue);

    final stored = await repository.watchAll().first;
    expect(stored.single.documentPaths[EpfDocumentSlot.aadhaar], saved.documentPaths[EpfDocumentSlot.aadhaar]);
  });

  test('delete removes the document and logs create+delete audit entries', () async {
    final saved = await repository.create(draft: _draft(), actorUid: 'actor-1', actorName: 'Actor One');
    await repository.delete(epfCase: saved, actorUid: 'actor-1', actorName: 'Actor One');

    final remaining = await firestore.collection('epf_cases').get();
    expect(remaining.docs, isEmpty);
    final auditDocs = await firestore.collection('audit_log').get();
    expect(auditDocs.docs.map((d) => d.data()['action']), containsAll(['create', 'delete']));
  });

  group('computed flags', () {
    test('pendingAmount and isFullyPaid', () {
      final unpaid = _draft(fee: 2000, amountPaid: 0);
      final partial = _draft(fee: 2000, amountPaid: 1000);
      final paid = _draft(fee: 2000, amountPaid: 2000);
      expect(unpaid.pendingAmount, 2000);
      expect(unpaid.isFullyPaid, isFalse);
      expect(partial.pendingAmount, 1000);
      expect(paid.isFullyPaid, isTrue);
    });

    test('isPending / isCompleted based on stage', () {
      final pending = _draft(stage: CaseStage.epfoProcessing);
      final completed = _draft(stage: CaseStage.completed);
      final rejected = _draft(stage: CaseStage.rejected);
      expect(pending.isPending, isTrue);
      expect(completed.isPending, isFalse);
      expect(completed.isCompleted, isTrue);
      expect(rejected.isPending, isFalse);
    });

    test('needsRenewalAlert true only when pending and stale 30+ days', () {
      final stale = _draft(
        stage: CaseStage.epfoProcessing,
        updatedAt: DateTime.now().subtract(const Duration(days: 40)),
      );
      final fresh = _draft(
        stage: CaseStage.epfoProcessing,
        updatedAt: DateTime.now().subtract(const Duration(days: 2)),
      );
      final completedStale = _draft(
        stage: CaseStage.completed,
        updatedAt: DateTime.now().subtract(const Duration(days: 40)),
      );
      expect(stale.needsRenewalAlert, isTrue);
      expect(fresh.needsRenewalAlert, isFalse);
      expect(completedStale.needsRenewalAlert, isFalse);
    });
  });
}
