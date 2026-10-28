import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/firebase_providers.dart';
import '../../audit/presentation/audit_log_screen.dart';
import '../data/salary_payment_repository.dart';
import '../domain/salary_payment.dart';

final salaryPaymentRepositoryProvider = Provider<SalaryPaymentRepository>((ref) {
  return SalaryPaymentRepository(
    firestore: ref.watch(firestoreProvider),
    auditLog: ref.watch(auditLogRepositoryProvider),
  );
});

final salaryPaymentListProvider = StreamProvider<List<SalaryPayment>>((ref) {
  return ref.watch(salaryPaymentRepositoryProvider).watchAll();
});

/// Selected tab on the Employees screen: 0 = Employee Details,
/// 1 = Salary Details. Lets the employee table's "Salary details" action
/// switch tabs.
final employeesTabProvider = StateProvider<int>((ref) => 0);

/// Client-side filter state for the Salary Details register. [year] and
/// [month] (1–12) narrow the table by salary month; [employeeDocId] also
/// opens that employee's history panel, whose month chips show [year]
/// (the current year when no year is picked).
class SalaryFilterState {
  const SalaryFilterState({this.search = '', this.employeeDocId, this.year, this.month});

  /// What the register opens with: the current year and month.
  factory SalaryFilterState.currentMonth() {
    final now = DateTime.now();
    return SalaryFilterState(year: now.year, month: now.month);
  }

  /// Arriving from an employee's "Salary details" action: that employee's
  /// payments for the whole of the current year, so their history and the
  /// table agree.
  factory SalaryFilterState.forEmployee(String employeeDocId) {
    return SalaryFilterState(employeeDocId: employeeDocId, year: DateTime.now().year);
  }

  final String search;
  final String? employeeDocId;
  final int? year;
  final int? month;

  int get historyYear => year ?? DateTime.now().year;

  SalaryFilterState copyWith({
    String? search,
    Object? employeeDocId = _unset,
    Object? year = _unset,
    Object? month = _unset,
  }) {
    return SalaryFilterState(
      search: search ?? this.search,
      employeeDocId: employeeDocId == _unset ? this.employeeDocId : employeeDocId as String?,
      year: year == _unset ? this.year : year as int?,
      month: month == _unset ? this.month : month as int?,
    );
  }

  bool matches(SalaryPayment p) {
    final salaryMonth = p.salaryMonthDate;
    if (year != null && salaryMonth.year != year) return false;
    if (month != null && salaryMonth.month != month) return false;
    if (employeeDocId != null && p.employeeDocId != employeeDocId) return false;
    final needle = search.trim().toLowerCase();
    if (needle.isNotEmpty) {
      final haystack = [
        p.employeeId,
        p.employeeName,
        p.paidBy,
        p.utrNumber,
        p.narration,
        p.debitBank,
      ].join(' ').toLowerCase();
      if (!haystack.contains(needle)) return false;
    }
    return true;
  }
}

const _unset = Object();

final salaryFilterProvider = StateProvider((ref) => SalaryFilterState.currentMonth());

final filteredSalaryPaymentListProvider = Provider<AsyncValue<List<SalaryPayment>>>((ref) {
  final filter = ref.watch(salaryFilterProvider);
  return ref.watch(salaryPaymentListProvider).whenData((all) => all.where(filter.matches).toList());
});

/// The fields shared across a batch of salary entries, remembered from the
/// last entry added so the next "Add Salary Entry" starts with them filled.
typedef SalaryBatchDefaults = ({
  DateTime paymentDate,
  DateTime salaryMonth,
  SalaryPaymentMode paymentMode,
  String paidBy,
  String debitBank,
});

final salaryBatchDefaultsProvider = StateProvider<SalaryBatchDefaults?>((ref) => null);
