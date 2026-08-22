import 'dart:typed_data';

import 'package:aioffice/core/services/storage_upload_service.dart';
import 'package:aioffice/features/audit/data/audit_log_repository.dart';
import 'package:aioffice/features/work_orders/data/work_order_repository.dart';
import 'package:aioffice/features/work_orders/domain/work_order.dart';
import 'package:aioffice/features/work_orders/domain/work_order_enums.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockStorageUploadService extends Mock implements StorageUploadService {}

WorkOrder _draft({
  DateTime? workOrderDate,
  DateTime? endDate,
  WorkOrderStatus status = WorkOrderStatus.active,
  String? fdNumber,
  FdStatus? fdStatus,
  DateTime? fdMaturityDate,
}) {
  final date = workOrderDate ?? DateTime(2026, 7, 31);
  return WorkOrder(
    id: '',
    workOrderNumber: '',
    year: date.year,
    workOrderDate: date,
    departmentName: 'PWD',
    contractType: ContractType.fixed,
    startDate: date,
    endDate: endDate,
    extensionAvailable: false,
    status: status,
    remarks: '',
    deptOfficeAddress: 'PWD Office',
    deptContactPerson: 'S. Reddy',
    deptPhoneNumber: '9845066210',
    deptEmail: '',
    deptGSTIN: '',
    contractValue: 1800000,
    securityDeposit: 90000,
    emdAmount: 125000,
    tenderNumber: 'TND/2026/0142',
    tenderName: 'Facility Management Contract',
    fdNumber: fdNumber,
    fdAmount: fdNumber != null ? 840000 : null,
    fdStatus: fdStatus,
    fdMaturityDate: fdMaturityDate,
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
  late WorkOrderRepository repository;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    storage = _MockStorageUploadService();
    repository = WorkOrderRepository(
      firestore: firestore,
      storage: storage,
      auditLog: AuditLogRepository(firestore),
    );
  });

  test('first work order of a year is numbered WO/YYYY/0001', () async {
    final saved = await repository.create(draft: _draft(), actorUid: 'actor-1', actorName: 'Actor One');
    expect(saved.workOrderNumber, 'WO/2026/0001');
  });

  test('create without an FD leaves hasFd false', () async {
    final saved = await repository.create(draft: _draft(), actorUid: 'actor-1', actorName: 'Actor One');
    expect(saved.hasFd, isFalse);
  });

  test('create with an FD attachment saves successfully (no FieldValue/Timestamp crash)', () async {
    when(
      () => storage.uploadBytes(
        path: any(named: 'path'),
        bytes: any(named: 'bytes'),
        contentType: any(named: 'contentType'),
      ),
    ).thenAnswer((_) async {});

    final saved = await repository.create(
      draft: _draft(fdNumber: 'FD/2026/0031', fdStatus: FdStatus.active),
      actorUid: 'actor-1',
      actorName: 'Actor One',
      fdFileBytes: Uint8List.fromList([1, 2, 3]),
      fdFileName: 'fd-scan.pdf',
      fdFileContentType: 'application/pdf',
    );

    expect(saved.hasFd, isTrue);
    expect(saved.hasFdFile, isTrue);

    final stored = await repository.watchAll().first;
    expect(stored.single.fdStoragePath, saved.fdStoragePath);
  });

  test('delete removes the document and logs create+delete audit entries', () async {
    final saved = await repository.create(draft: _draft(), actorUid: 'actor-1', actorName: 'Actor One');
    await repository.delete(workOrder: saved, actorUid: 'actor-1', actorName: 'Actor One');

    final remaining = await firestore.collection('work_orders').get();
    expect(remaining.docs, isEmpty);
    final auditDocs = await firestore.collection('audit_log').get();
    expect(auditDocs.docs.map((d) => d.data()['action']), containsAll(['create', 'delete']));
  });

  group('computed alert flags', () {
    test('isExpiringSoon true only when active and ending within 60 days', () {
      final soon = _draft(endDate: DateTime.now().add(const Duration(days: 30)));
      final far = _draft(endDate: DateTime.now().add(const Duration(days: 200)));
      final expired = _draft(status: WorkOrderStatus.expired, endDate: DateTime.now().add(const Duration(days: 10)));
      expect(soon.isExpiringSoon, isTrue);
      expect(far.isExpiringSoon, isFalse);
      expect(expired.isExpiringSoon, isFalse);
    });

    test('isFdMaturingSoon / isFdExpired / isFdReleasePending', () {
      final maturingSoon = _draft(
        fdNumber: 'FD/1',
        fdStatus: FdStatus.active,
        fdMaturityDate: DateTime.now().add(const Duration(days: 10)),
      );
      final expired = _draft(
        fdNumber: 'FD/2',
        fdStatus: FdStatus.active,
        fdMaturityDate: DateTime.now().subtract(const Duration(days: 5)),
      );
      final releasePending = _draft(
        status: WorkOrderStatus.expired,
        fdNumber: 'FD/3',
        fdStatus: FdStatus.active,
        fdMaturityDate: DateTime.now().add(const Duration(days: 400)),
      );

      expect(maturingSoon.isFdMaturingSoon, isTrue);
      expect(expired.isFdExpired, isTrue);
      expect(releasePending.isFdReleasePending, isTrue);
    });
  });
}
