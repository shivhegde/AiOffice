import 'dart:typed_data';

import 'package:aioffice/core/services/storage_upload_service.dart';
import 'package:aioffice/features/audit/data/audit_log_repository.dart';
import 'package:aioffice/features/vehicle_insurance/data/vehicle_policy_repository.dart';
import 'package:aioffice/features/vehicle_insurance/domain/vehicle_insurance_enums.dart';
import 'package:aioffice/features/vehicle_insurance/domain/vehicle_policy.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockStorageUploadService extends Mock implements StorageUploadService {}

VehiclePolicy _draft({DateTime? expiryDate, PolicyStatus status = PolicyStatus.active, DateTime? renewedAt}) {
  final now = DateTime.now();
  return VehiclePolicy(
    id: '',
    customerName: 'Manju Nath',
    customerMobile: '9845066210',
    vehicleNumber: 'KA09MX1234',
    vehicleType: VehicleType.car,
    insuranceCompany: 'ICICI Lombard',
    policyNumber: 'POL/2026/9981',
    policyType: PolicyType.comprehensive,
    premium: 12500,
    startDate: now.subtract(const Duration(days: 300)),
    expiryDate: expiryDate ?? now.add(const Duration(days: 400)),
    status: status,
    renewedAt: renewedAt,
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
  late VehiclePolicyRepository repository;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    storage = _MockStorageUploadService();
    repository = VehiclePolicyRepository(
      firestore: firestore,
      storage: storage,
      auditLog: AuditLogRepository(firestore),
    );
  });

  test('create saves policy fields as given (no auto-generated ID)', () async {
    final saved = await repository.create(draft: _draft(), actorUid: 'actor-1', actorName: 'Actor One');
    expect(saved.policyNumber, 'POL/2026/9981');
    expect(saved.vehicleNumber, 'KA09MX1234');
  });

  test('create with a policy PDF saves successfully (no FieldValue/Timestamp crash)', () async {
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
      policyFile: (bytes: Uint8List.fromList([1, 2, 3]), name: 'policy.pdf', contentType: 'application/pdf'),
    );

    expect(saved.hasPolicyFile, isTrue);
    final stored = await repository.watchAll().first;
    expect(stored.single.policyStoragePath, saved.policyStoragePath);
  });

  test('delete removes the document and logs create+delete audit entries', () async {
    final saved = await repository.create(draft: _draft(), actorUid: 'actor-1', actorName: 'Actor One');
    await repository.delete(policy: saved, actorUid: 'actor-1', actorName: 'Actor One');

    final remaining = await firestore.collection('vehicle_policies').get();
    expect(remaining.docs, isEmpty);
    final auditDocs = await firestore.collection('audit_log').get();
    expect(auditDocs.docs.map((d) => d.data()['action']), containsAll(['create', 'delete']));
  });

  group('computed alert flags', () {
    test('isExpiringWithin true only when active and within the window', () {
      final soon = _draft(expiryDate: DateTime.now().add(const Duration(days: 10)));
      final far = _draft(expiryDate: DateTime.now().add(const Duration(days: 200)));
      final expired = _draft(status: PolicyStatus.expired, expiryDate: DateTime.now().add(const Duration(days: 5)));

      expect(soon.isExpiringWithin(15), isTrue);
      expect(far.isExpiringWithin(15), isFalse);
      expect(expired.isExpiringWithin(15), isFalse);
    });

    test('isOverdue true only when active and past expiry', () {
      final overdue = _draft(expiryDate: DateTime.now().subtract(const Duration(days: 5)));
      final active = _draft(expiryDate: DateTime.now().add(const Duration(days: 5)));
      expect(overdue.isOverdue, isTrue);
      expect(active.isOverdue, isFalse);
    });

    test('isRenewedThisMonth true only when status renewed and renewedAt is this month', () {
      final renewedNow = _draft(status: PolicyStatus.renewed, renewedAt: DateTime.now());
      final renewedLastYear = _draft(
        status: PolicyStatus.renewed,
        renewedAt: DateTime.now().subtract(const Duration(days: 400)),
      );
      expect(renewedNow.isRenewedThisMonth, isTrue);
      expect(renewedLastYear.isRenewedThisMonth, isFalse);
    });
  });
}
