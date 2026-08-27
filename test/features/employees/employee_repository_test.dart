import 'dart:typed_data';

import 'package:aioffice/core/services/storage_upload_service.dart';
import 'package:aioffice/features/audit/data/audit_log_repository.dart';
import 'package:aioffice/features/employees/data/employee_repository.dart';
import 'package:aioffice/features/employees/domain/employee.dart';
import 'package:aioffice/features/employees/domain/employee_enums.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockStorageUploadService extends Mock implements StorageUploadService {}

Employee _draft({DateTime? dateOfAppointment, WorkStatus status = WorkStatus.active}) {
  final appointed = dateOfAppointment ?? DateTime(2026, 7, 31);
  return Employee(
    id: '',
    employeeId: '',
    year: appointed.year,
    fullName: 'Ravi Kumar',
    gender: Gender.male,
    dateOfBirth: DateTime(1992, 3, 14),
    mobileNumber: '9845066210',
    aadhaarNumber: '123456789012',
    dateOfAppointment: appointed,
    joiningDate: appointed,
    department: 'Operations',
    designation: 'Supervisor',
    employeeType: EmployeeType.permanent,
    workStatus: status,
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
  late EmployeeRepository repository;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    storage = _MockStorageUploadService();
    repository = EmployeeRepository(firestore: firestore, storage: storage, auditLog: AuditLogRepository(firestore));
  });

  test('first employee of a year is numbered EMP/YYYY/0001', () async {
    final saved = await repository.create(draft: _draft(), actorUid: 'actor-1', actorName: 'Actor One');
    expect(saved.employeeId, 'EMP/2026/0001');
  });

  test('create without documents leaves hasPhoto/hasAadhaarFile/hasPanFile false', () async {
    final saved = await repository.create(draft: _draft(), actorUid: 'actor-1', actorName: 'Actor One');
    expect(saved.hasPhoto, isFalse);
    expect(saved.hasAadhaarFile, isFalse);
    expect(saved.hasPanFile, isFalse);
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
      aadhaarFile: (bytes: Uint8List.fromList([1, 2, 3]), name: 'aadhaar.pdf', contentType: 'application/pdf'),
      panFile: (bytes: Uint8List.fromList([1, 2, 3]), name: 'pan.pdf', contentType: 'application/pdf'),
    );

    expect(saved.hasAadhaarFile, isTrue);
    expect(saved.hasPanFile, isTrue);
    expect(saved.hasPhoto, isFalse);

    final stored = await repository.watchAll().first;
    expect(stored.single.aadhaarStoragePath, saved.aadhaarStoragePath);
    expect(stored.single.panStoragePath, saved.panStoragePath);
  });

  test('delete removes the document and logs create+delete audit entries', () async {
    final saved = await repository.create(draft: _draft(), actorUid: 'actor-1', actorName: 'Actor One');
    await repository.delete(employee: saved, actorUid: 'actor-1', actorName: 'Actor One');

    final remaining = await firestore.collection('employees').get();
    expect(remaining.docs, isEmpty);
    final auditDocs = await firestore.collection('audit_log').get();
    expect(auditDocs.docs.map((d) => d.data()['action']), containsAll(['create', 'delete']));
  });

  test('isNewAppointment true only for appointments in the current month', () async {
    final thisMonth = _draft(dateOfAppointment: DateTime.now());
    final lastYear = _draft(dateOfAppointment: DateTime.now().subtract(const Duration(days: 400)));
    expect(thisMonth.isNewAppointment, isTrue);
    expect(lastYear.isNewAppointment, isFalse);
  });
}
