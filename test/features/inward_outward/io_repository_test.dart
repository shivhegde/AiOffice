import 'dart:typed_data';

import 'package:aioffice/core/services/storage_upload_service.dart';
import 'package:aioffice/features/audit/data/audit_log_repository.dart';
import 'package:aioffice/features/inward_outward/data/io_repository.dart';
import 'package:aioffice/features/inward_outward/domain/io_document.dart';
import 'package:aioffice/features/inward_outward/domain/io_enums.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockStorageUploadService extends Mock implements StorageUploadService {}

IoDocument _draft({
  required IoType type,
  required DateTime date,
  String subject = 'Test subject',
  String department = 'PWD',
}) {
  return IoDocument(
    id: '',
    type: type,
    docNumber: '',
    year: date.year,
    date: date,
    docType: 'Work Order',
    department: department,
    subject: subject,
    remarks: '',
    receivedFrom: type == IoType.inward ? 'BWSSB' : null,
    senderCompany: type == IoType.inward ? 'BWSSB, Bengaluru' : null,
    priority: type == IoType.inward ? IoPriority.normal : null,
    receiverName: type == IoType.inward ? 'Ravi Kumar' : null,
    sentTo: type == IoType.outward ? 'PWD' : null,
    addressOrEmail: type == IoType.outward ? 'pwd@example.gov.in' : null,
    dispatchMode: type == IoType.outward ? DispatchMode.email : null,
    trackingNumber: type == IoType.outward ? '' : null,
    sentBy: type == IoType.outward ? 'R. Kavya' : null,
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
  late IoRepository repository;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    storage = _MockStorageUploadService();
    repository = IoRepository(
      firestore: firestore,
      storage: storage,
      auditLog: AuditLogRepository(firestore),
    );
  });

  group('document numbering', () {
    test('first inward entry of a year is numbered 0001', () async {
      final saved = await repository.create(
        draft: _draft(type: IoType.inward, date: DateTime(2026, 7, 31)),
        actorUid: 'actor-1',
        actorName: 'Actor One',
      );
      expect(saved.docNumber, 'INW/2026/0001');
    });

    test('sequence increments per type+year independently', () async {
      final firstInward = await repository.create(
        draft: _draft(type: IoType.inward, date: DateTime(2026, 7, 31)),
        actorUid: 'actor-1',
        actorName: 'Actor One',
      );
      final secondInward = await repository.create(
        draft: _draft(type: IoType.inward, date: DateTime(2026, 8, 1)),
        actorUid: 'actor-1',
        actorName: 'Actor One',
      );
      final firstOutward = await repository.create(
        draft: _draft(type: IoType.outward, date: DateTime(2026, 7, 31)),
        actorUid: 'actor-1',
        actorName: 'Actor One',
      );

      expect(firstInward.docNumber, 'INW/2026/0001');
      expect(secondInward.docNumber, 'INW/2026/0002');
      expect(firstOutward.docNumber, 'OUT/2026/0001');
    });
  });

  group('CRUD + audit trail', () {
    test('create writes an audit_log entry', () async {
      await repository.create(
        draft: _draft(type: IoType.inward, date: DateTime(2026, 7, 31)),
        actorUid: 'actor-1',
        actorName: 'Actor One',
      );
      final auditDocs = await firestore.collection('audit_log').get();
      expect(auditDocs.docs, hasLength(1));
      expect(auditDocs.docs.single.data()['action'], 'create');
    });

    test('delete removes the document and logs an audit entry', () async {
      final saved = await repository.create(
        draft: _draft(type: IoType.inward, date: DateTime(2026, 7, 31)),
        actorUid: 'actor-1',
        actorName: 'Actor One',
      );

      await repository.delete(document: saved, actorUid: 'actor-1', actorName: 'Actor One');

      final remaining = await firestore.collection('inward_outward_documents').get();
      expect(remaining.docs, isEmpty);
      final auditDocs = await firestore.collection('audit_log').get();
      expect(auditDocs.docs.map((d) => d.data()['action']), containsAll(['create', 'delete']));
    });

    test('watchByType only returns documents of the requested direction', () async {
      await repository.create(
        draft: _draft(type: IoType.inward, date: DateTime(2026, 7, 31)),
        actorUid: 'actor-1',
        actorName: 'Actor One',
      );
      await repository.create(
        draft: _draft(type: IoType.outward, date: DateTime(2026, 7, 31)),
        actorUid: 'actor-1',
        actorName: 'Actor One',
      );

      final inwardDocs = await repository.watchByType(IoType.inward).first;
      expect(inwardDocs, hasLength(1));
      expect(inwardDocs.single.type, IoType.inward);
    });
  });

  group('create with an attached file', () {
    setUp(() {
      when(
        () => storage.uploadBytes(
          path: any(named: 'path'),
          bytes: any(named: 'bytes'),
          contentType: any(named: 'contentType'),
        ),
      ).thenAnswer((_) async {});
    });

    test('saves successfully and records the file metadata', () async {
      final bytes = Uint8List.fromList([1, 2, 3]);

      final saved = await repository.create(
        draft: _draft(type: IoType.inward, date: DateTime(2026, 7, 31)),
        actorUid: 'actor-1',
        actorName: 'Actor One',
        fileBytes: bytes,
        fileName: 'scan.pdf',
        fileContentType: 'application/pdf',
      );

      expect(saved.hasFile, isTrue);
      expect(saved.fileName, 'scan.pdf');
      expect(saved.fileSizeBytes, 3);

      // Regression check: this must not throw a "FieldValue is not a
      // subtype of Timestamp" cast error, and the document must actually
      // land in Firestore (not just build an in-memory object).
      final stored = await repository.watchByType(IoType.inward).first;
      expect(stored, hasLength(1));
      expect(stored.single.storagePath, saved.storagePath);
    });
  });

  group('setSeen (manager acknowledgement)', () {
    test('new entries default to unseen', () async {
      final saved = await repository.create(
        draft: _draft(type: IoType.inward, date: DateTime(2026, 7, 31)),
        actorUid: 'actor-1',
        actorName: 'Actor One',
      );
      expect(saved.seen, isFalse);
    });

    test('toggles seen without touching other fields', () async {
      final saved = await repository.create(
        draft: _draft(type: IoType.inward, date: DateTime(2026, 7, 31), subject: 'Original subject'),
        actorUid: 'actor-1',
        actorName: 'Actor One',
      );

      await repository.setSeen(document: saved, seen: true, actorUid: 'manager-1', actorName: 'Manager One');

      final updated = await repository.watchByType(IoType.inward).first;
      expect(updated.single.seen, isTrue);
      expect(updated.single.subject, 'Original subject');
      expect(updated.single.docNumber, saved.docNumber);
    });

    test('logs an audit entry distinct from create', () async {
      final saved = await repository.create(
        draft: _draft(type: IoType.inward, date: DateTime(2026, 7, 31)),
        actorUid: 'actor-1',
        actorName: 'Actor One',
      );
      await repository.setSeen(document: saved, seen: true, actorUid: 'manager-1', actorName: 'Manager One');

      final auditDocs = await firestore.collection('audit_log').get();
      expect(auditDocs.docs, hasLength(2));
      expect(
        auditDocs.docs.map((d) => d.data()['targetLabel']),
        contains('${saved.docNumber} marked seen'),
      );
    });
  });
}
