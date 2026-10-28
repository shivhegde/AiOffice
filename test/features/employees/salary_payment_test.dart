import 'package:aioffice/features/audit/data/audit_log_repository.dart';
import 'package:aioffice/features/employees/application/salary_providers.dart';
import 'package:aioffice/features/employees/data/salary_payment_repository.dart';
import 'package:aioffice/features/employees/domain/salary_payment.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

SalaryPayment _payment({
  String employeeDocId = 'emp-1',
  String employeeName = 'Ravi Kumar',
  String salaryMonth = '2026-09',
  double amount = 18000,
  DateTime? paymentDate,
  String utrNumber = 'UTR123',
}) {
  return SalaryPayment(
    id: '',
    employeeDocId: employeeDocId,
    employeeId: 'EMP/2026/0001',
    employeeName: employeeName,
    paymentDate: paymentDate ?? DateTime(2026, 10, 1),
    salaryMonth: salaryMonth,
    amount: amount,
    paymentMode: SalaryPaymentMode.neft,
    paidBy: 'Accounts',
    utrNumber: utrNumber,
    debitBank: 'SBI',
    narration: 'Salary for September',
    createdBy: 'actor-1',
    createdByName: 'Actor One',
  );
}

void main() {
  group('SalaryPaymentRepository', () {
    late FakeFirebaseFirestore firestore;
    late SalaryPaymentRepository repository;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      repository = SalaryPaymentRepository(firestore: firestore, auditLog: AuditLogRepository(firestore));
    });

    test('create, update and delete round-trip and are audit-logged', () async {
      final saved = await repository.create(draft: _payment(), actorUid: 'actor-1', actorName: 'Actor One');
      final stored = await firestore.collection('salary_payments').doc(saved.id).get();
      expect(stored.data()!['salaryMonth'], '2026-09');
      expect(stored.data()!['paymentMode'], 'neft');

      final edited = SalaryPayment.fromMap(saved.id, {...stored.data()!, 'amount': 19500});
      await repository.update(payment: edited, actorUid: 'actor-1', actorName: 'Actor One');
      final afterUpdate = await firestore.collection('salary_payments').doc(saved.id).get();
      expect(afterUpdate.data()!['amount'], 19500);

      await repository.delete(payment: edited, actorUid: 'actor-1', actorName: 'Actor One');
      expect((await firestore.collection('salary_payments').get()).docs, isEmpty);

      final audit = await firestore.collection('audit_log').get();
      expect(audit.docs.map((d) => d.data()['action']), containsAll(['create', 'update', 'delete']));
    });
  });

  test('salaryMonthDate reads the yyyy-MM key', () {
    expect(_payment(salaryMonth: '2026-03').salaryMonthDate, DateTime(2026, 3));
    expect(SalaryPayment.monthKey(DateTime(2026, 3, 17)), '2026-03');
    expect(SalaryPayment.parseMonthKey('2026-13'), isNull);
  });

  test('SalaryHistory totals all time and splits the chosen year by month', () {
    final payments = [
      _payment(salaryMonth: '2026-01', amount: 18000, paymentDate: DateTime(2026, 2, 1)),
      _payment(salaryMonth: '2026-01', amount: 2000, paymentDate: DateTime(2026, 2, 10)),
      _payment(salaryMonth: '2026-02', amount: 18000, paymentDate: DateTime(2026, 3, 1)),
      _payment(salaryMonth: '2025-12', amount: 17000, paymentDate: DateTime(2026, 1, 2)),
      _payment(employeeDocId: 'emp-2', salaryMonth: '2026-01', amount: 99999),
    ];

    final history = SalaryHistory.of(payments, employeeDocId: 'emp-1', year: 2026);
    expect(history.totalPaid, 55000);
    expect(history.paymentCount, 4);
    expect(history.lastPaymentDate, DateTime(2026, 3, 1));
    expect(history.monthTotals[0], 20000);
    expect(history.monthTotals[1], 18000);
    expect(history.monthTotals[2], isNull);
    expect(history.monthsPaid, 2);
  });

  test('SalaryFilterState matches on year, month, employee and search text', () {
    final p = _payment();
    expect(const SalaryFilterState().matches(p), isTrue);
    expect(const SalaryFilterState(year: 2026).matches(p), isTrue);
    expect(const SalaryFilterState(year: 2025).matches(p), isFalse);
    expect(const SalaryFilterState(month: 9).matches(p), isTrue);
    expect(const SalaryFilterState(year: 2026, month: 8).matches(p), isFalse);
    expect(const SalaryFilterState(employeeDocId: 'emp-2').matches(p), isFalse);
    expect(const SalaryFilterState(search: 'utr12').matches(p), isTrue);
    expect(const SalaryFilterState(search: 'sbi').matches(p), isTrue);
    expect(const SalaryFilterState(search: 'nobody').matches(p), isFalse);
  });

  test('SalarySummary counts by salary month, distinct employees per month', () {
    final now = DateTime(2026, 11, 15);
    final payments = [
      _payment(employeeDocId: 'emp-1', salaryMonth: '2026-11', amount: 18000, paymentDate: DateTime(2026, 12, 2)),
      _payment(employeeDocId: 'emp-1', salaryMonth: '2026-11', amount: 2000, paymentDate: DateTime(2026, 12, 9)),
      _payment(employeeDocId: 'emp-2', salaryMonth: '2026-11', amount: 15000, paymentDate: DateTime(2026, 11, 30)),
      // Paid this calendar month, but for October's salary.
      _payment(employeeDocId: 'emp-1', salaryMonth: '2026-10', amount: 18000, paymentDate: DateTime(2026, 11, 2)),
      _payment(employeeDocId: 'emp-1', salaryMonth: '2025-11', amount: 9999, paymentDate: DateTime(2025, 12, 2)),
    ];
    final summary = SalarySummary.of(payments, now: now);
    expect(summary.employeesPaidThisMonth, 2);
    expect(summary.amountPaidThisMonth, 35000);
    expect(summary.employeesPaidLastMonth, 1);
    expect(summary.amountPaidLastMonth, 18000);
  });

  test('SalarySummary last salary month wraps across the year boundary', () {
    final payments = [_payment(salaryMonth: '2026-12', amount: 18000, paymentDate: DateTime(2027, 1, 3))];
    final summary = SalarySummary.of(payments, now: DateTime(2027, 1, 10));
    expect(summary.employeesPaidLastMonth, 1);
    expect(summary.amountPaidLastMonth, 18000);
    expect(summary.employeesPaidThisMonth, 0);
  });

  test('the register opens on the current year and month', () {
    final now = DateTime.now();
    final filter = SalaryFilterState.currentMonth();
    expect(filter.year, now.year);
    expect(filter.month, now.month);
    final fromEmployee = SalaryFilterState.forEmployee('emp-1');
    expect(fromEmployee.employeeDocId, 'emp-1');
    expect(fromEmployee.year, now.year);
    expect(fromEmployee.month, isNull);
  });
}
