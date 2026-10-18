import 'dart:typed_data';

import 'package:aioffice/core/services/storage_upload_service.dart';
import 'package:aioffice/features/audit/data/audit_log_repository.dart';
import 'package:aioffice/features/vehicle_insurance/data/vehicle_policy_repository.dart';
import 'package:aioffice/features/vehicle_insurance/domain/vehicle_followup.dart';
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
    policyTypes: const [PolicyType.comprehensive],
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

  test('Other vehicle type keeps its typed text; other types ignore it', () {
    VehiclePolicy withType(VehicleType type, String other) {
      final d = _draft();
      final map = VehiclePolicy(
        id: '',
        customerName: d.customerName,
        customerMobile: d.customerMobile,
        vehicleNumber: d.vehicleNumber,
        vehicleType: type,
        vehicleTypeOther: other,
        insuranceCompany: d.insuranceCompany,
        policyNumber: d.policyNumber,
        policyTypes: d.policyTypes,
        startDate: d.startDate,
        expiryDate: d.expiryDate,
        status: d.status,
        createdBy: d.createdBy,
        createdByName: d.createdByName,
        createdAt: DateTime(2026),
      ).toMap()..remove('updatedAt');
      return VehiclePolicy.fromMap('x', map);
    }

    expect(withType(VehicleType.other, 'Tractor').vehicleTypeLabel, 'Tractor');
    expect(withType(VehicleType.other, '').vehicleTypeLabel, 'Other');
    final swm = withType(VehicleType.swmVehicle, 'stale');
    expect(swm.vehicleTypeLabel, 'SWM Vehicle');
    expect(swm.vehicleTypeOther, '');
  });

  test('multiple policy types round-trip; Other uses its typed text', () {
    final d = _draft();
    final map = VehiclePolicy(
      id: '',
      customerName: d.customerName,
      customerMobile: d.customerMobile,
      vehicleNumber: d.vehicleNumber,
      vehicleType: d.vehicleType,
      insuranceCompany: d.insuranceCompany,
      policyNumber: d.policyNumber,
      policyTypes: const [PolicyType.thirdParty, PolicyType.ownDamage, PolicyType.other],
      policyTypeOther: 'Engine Protect',
      startDate: d.startDate,
      expiryDate: d.expiryDate,
      status: d.status,
      createdBy: d.createdBy,
      createdByName: d.createdByName,
      createdAt: DateTime(2026),
    ).toMap()..remove('updatedAt');
    final restored = VehiclePolicy.fromMap('x', map);
    expect(restored.policyTypes, [PolicyType.thirdParty, PolicyType.ownDamage, PolicyType.other]);
    expect(restored.policyTypesLabel, 'Third Party, Own Damage, Engine Protect');
  });

  test('reads legacy single policyType records', () {
    final restored = VehiclePolicy.fromMap('x', {'policyType': 'third_party'});
    expect(restored.policyTypes, [PolicyType.thirdParty]);
  });

  test('supporting documents upload per slot and are removed with the policy', () async {
    when(
      () => storage.uploadBytes(
        path: any(named: 'path'),
        bytes: any(named: 'bytes'),
        contentType: any(named: 'contentType'),
      ),
    ).thenAnswer((_) async {});
    when(() => storage.delete(any())).thenAnswer((_) async {});

    final saved = await repository.create(
      draft: _draft(),
      actorUid: 'actor-1',
      actorName: 'Actor One',
      documentFiles: {
        VehicleDocumentSlot.rc: (bytes: Uint8List.fromList([1]), name: 'rc.pdf', contentType: 'application/pdf'),
        VehicleDocumentSlot.pan: (bytes: Uint8List.fromList([2]), name: 'pan.jpg', contentType: 'image/jpeg'),
      },
    );
    expect(saved.documentPaths[VehicleDocumentSlot.rc], 'vehicle_policies/${saved.id}/rc__rc.pdf');
    expect(saved.documentFileNames[VehicleDocumentSlot.pan], 'pan.jpg');

    final stored = VehiclePolicy.fromMap(
      saved.id,
      (await firestore.collection('vehicle_policies').doc(saved.id).get()).data()!,
    );
    expect(stored.documentPaths.keys, containsAll([VehicleDocumentSlot.rc, VehicleDocumentSlot.pan]));

    await repository.delete(policy: stored, actorUid: 'actor-1', actorName: 'Actor One');
    verify(() => storage.delete('vehicle_policies/${saved.id}/rc__rc.pdf')).called(1);
    verify(() => storage.delete('vehicle_policies/${saved.id}/pan__pan.jpg')).called(1);
  });

  test('followups: add, update, close, delete, and removed with the policy', () async {
    final saved = await repository.create(draft: _draft(), actorUid: 'actor-1', actorName: 'Actor One');
    await repository.addFollowup(
      policy: saved,
      followupDate: DateTime(2026, 11, 2),
      remark: 'Call for renewal',
      status: FollowupStatus.active,
      actorUid: 'actor-1',
      actorName: 'Actor One',
    );
    var followups = await repository.watchFollowups().first;
    expect(followups.single.policyId, saved.id);
    expect(followups.single.vehicleNumber, saved.vehicleNumber);

    await repository.updateFollowup(
      followup: followups.single,
      followupDate: DateTime(2026, 11, 4),
      remark: 'Customer agreed',
      status: FollowupStatus.active,
      actorUid: 'actor-1',
      actorName: 'Actor One',
    );
    await repository.setFollowupStatus(
      followup: followups.single,
      status: FollowupStatus.closed,
      actorUid: 'actor-1',
      actorName: 'Actor One',
    );
    followups = await repository.watchFollowups().first;
    expect(followups.single.remark, 'Customer agreed');
    expect(followups.single.status, FollowupStatus.closed);
    expect(currentVehicleFollowup(followups)!.id, followups.single.id);

    await repository.deleteFollowup(followup: followups.single, actorUid: 'actor-1', actorName: 'Actor One');
    expect(await repository.watchFollowups().first, isEmpty);

    await repository.addFollowup(
      policy: saved,
      followupDate: DateTime(2026, 12, 1),
      remark: 'Again',
      status: FollowupStatus.active,
      actorUid: 'actor-1',
      actorName: 'Actor One',
    );
    await repository.delete(policy: saved, actorUid: 'actor-1', actorName: 'Actor One');
    expect(await repository.watchFollowups().first, isEmpty);
  });
}
