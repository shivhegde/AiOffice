import 'package:aioffice/features/audit/data/audit_log_repository.dart';
import 'package:aioffice/features/tender_emd/data/tender_repository.dart';
import 'package:aioffice/features/tender_emd/domain/tender.dart';
import 'package:aioffice/features/tender_emd/domain/tender_enums.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

Tender _draft({DateTime? submissionDate, RefundStatus refundStatus = RefundStatus.pending}) {
  return Tender(
    id: '',
    tenderNumber: '',
    year: (submissionDate ?? DateTime(2026, 7, 2)).year,
    tenderName: 'Security Services — District Hospital',
    departmentName: 'BWSSB',
    category: TenderCategory.service,
    publishDate: DateTime(2026, 6, 18),
    submissionDate: submissionDate ?? DateTime(2026, 7, 2),
    emdAmount: 125000,
    emdType: EmdType.dd,
    utrNumber: 'DD/2026/004521',
    refundStatus: refundStatus,
    deptContactPerson: 'K. Manjunath',
    deptContactMobile: '9448011223',
    deptContactEmail: 'manjunath.bwssb@example.com',
    deptOfficeAddress: 'BWSSB HQ, Bengaluru',
    remarks: '',
    createdBy: 'actor-1',
    createdByName: 'Actor One',
  );
}

void main() {
  late FakeFirebaseFirestore firestore;
  late TenderRepository repository;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    repository = TenderRepository(firestore: firestore, auditLog: AuditLogRepository(firestore));
  });

  test('first tender of a year is numbered TND/YYYY/0001', () async {
    final saved = await repository.create(draft: _draft(), actorUid: 'actor-1', actorName: 'Actor One');
    expect(saved.tenderNumber, 'TND/2026/0001');
  });

  test('sequence increments within a year', () async {
    final first = await repository.create(draft: _draft(), actorUid: 'actor-1', actorName: 'Actor One');
    final second = await repository.create(draft: _draft(), actorUid: 'actor-1', actorName: 'Actor One');
    expect(first.tenderNumber, 'TND/2026/0001');
    expect(second.tenderNumber, 'TND/2026/0002');
  });

  test('create writes an audit_log entry and delete adds another', () async {
    final saved = await repository.create(draft: _draft(), actorUid: 'actor-1', actorName: 'Actor One');
    await repository.delete(tender: saved, actorUid: 'actor-1', actorName: 'Actor One');

    final auditDocs = await firestore.collection('audit_log').get();
    expect(auditDocs.docs.map((d) => d.data()['action']), containsAll(['create', 'delete']));
    final remaining = await firestore.collection('tenders').get();
    expect(remaining.docs, isEmpty);
  });

  test('isRefundOverdue is true only when pending and >30 days since submission', () {
    final overdue = _draft(submissionDate: DateTime.now().subtract(const Duration(days: 31)));
    final recent = _draft(submissionDate: DateTime.now().subtract(const Duration(days: 5)));
    final refunded = _draft(
      submissionDate: DateTime.now().subtract(const Duration(days: 40)),
      refundStatus: RefundStatus.refunded,
    );
    expect(overdue.isRefundOverdue, isTrue);
    expect(recent.isRefundOverdue, isFalse);
    expect(refunded.isRefundOverdue, isFalse);
  });

  test('isEmdValidityExpiringSoon is false when emdValidUntil is unset', () {
    expect(_draft().isEmdValidityExpiringSoon, isFalse);
  });
}
