import 'package:cloud_firestore/cloud_firestore.dart';

enum SalaryPaymentMode {
  neft('neft', 'NEFT'),
  imps('imps', 'IMPS'),
  rtgs('rtgs', 'RTGS'),
  upi('upi', 'UPI'),
  cheque('cheque', 'Cheque'),
  cash('cash', 'Cash');

  const SalaryPaymentMode(this.wireValue, this.label);

  final String wireValue;
  final String label;

  static SalaryPaymentMode fromWireValue(String? value) {
    return SalaryPaymentMode.values.firstWhere((m) => m.wireValue == value, orElse: () => SalaryPaymentMode.neft);
  }
}

/// One entry in the Salary Payment Register (docs/Salary Payment
/// Register.html), stored in its own `salary_payments` collection.
/// Linked to the employee by [employeeDocId] (the stable Firestore id);
/// [employeeId] and [employeeName] are copied in at save time so the
/// register still reads correctly if the employee record later changes
/// or is deleted.
class SalaryPayment {
  const SalaryPayment({
    required this.id,
    required this.employeeDocId,
    required this.employeeId,
    required this.employeeName,
    required this.paymentDate,
    required this.salaryMonth,
    required this.amount,
    required this.paymentMode,
    this.paidBy = '',
    this.utrNumber = '',
    this.debitBank = '',
    this.narration = '',
    required this.createdBy,
    required this.createdByName,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String employeeDocId;
  final String employeeId;
  final String employeeName;
  final DateTime paymentDate;

  /// The month the salary is for, as `yyyy-MM` (e.g. `2026-10`) — sorts
  /// and filters as plain text.
  final String salaryMonth;
  final double amount;
  final SalaryPaymentMode paymentMode;
  final String paidBy;
  final String utrNumber;
  final String debitBank;
  final String narration;

  final String createdBy;
  final String createdByName;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  static String monthKey(DateTime month) => '${month.year}-${month.month.toString().padLeft(2, '0')}';

  /// First day of the month a `yyyy-MM` [key] names, or null if [key]
  /// isn't in that form.
  static DateTime? parseMonthKey(String key) {
    final parts = key.split('-');
    if (parts.length != 2) return null;
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    if (year == null || month == null || month < 1 || month > 12) return null;
    return DateTime(year, month);
  }

  /// First day of [salaryMonth] (the payment date's month if unreadable).
  DateTime get salaryMonthDate => parseMonthKey(salaryMonth) ?? DateTime(paymentDate.year, paymentDate.month);

  factory SalaryPayment.fromMap(String id, Map<String, dynamic> data) {
    return SalaryPayment(
      id: id,
      employeeDocId: data['employeeDocId'] as String? ?? '',
      employeeId: data['employeeId'] as String? ?? '',
      employeeName: data['employeeName'] as String? ?? '',
      paymentDate: (data['paymentDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      salaryMonth: data['salaryMonth'] as String? ?? '',
      amount: (data['amount'] as num?)?.toDouble() ?? 0,
      paymentMode: SalaryPaymentMode.fromWireValue(data['paymentMode'] as String?),
      paidBy: data['paidBy'] as String? ?? '',
      utrNumber: data['utrNumber'] as String? ?? '',
      debitBank: data['debitBank'] as String? ?? '',
      narration: data['narration'] as String? ?? '',
      createdBy: data['createdBy'] as String? ?? '',
      createdByName: data['createdByName'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'employeeDocId': employeeDocId,
      'employeeId': employeeId,
      'employeeName': employeeName,
      'paymentDate': Timestamp.fromDate(paymentDate),
      'salaryMonth': salaryMonth,
      'amount': amount,
      'paymentMode': paymentMode.wireValue,
      'paidBy': paidBy,
      'utrNumber': utrNumber,
      'debitBank': debitBank,
      'narration': narration,
      'createdBy': createdBy,
      'createdByName': createdByName,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}

/// The register's per-employee summary: all-time totals plus a
/// month-by-month view of one calendar year.
class SalaryHistory {
  const SalaryHistory({
    required this.totalPaid,
    required this.paymentCount,
    required this.lastPaymentDate,
    required this.year,
    required this.monthTotals,
  });

  final double totalPaid;
  final int paymentCount;
  final DateTime? lastPaymentDate;
  final int year;

  /// Index 0 = January. Null = nothing paid for that month.
  final List<double?> monthTotals;

  int get monthsPaid => monthTotals.where((t) => t != null).length;

  factory SalaryHistory.of(Iterable<SalaryPayment> payments, {required String employeeDocId, required int year}) {
    final mine = payments.where((p) => p.employeeDocId == employeeDocId).toList();
    final monthTotals = List<double?>.filled(12, null);
    for (final p in mine) {
      final month = p.salaryMonthDate;
      if (month.year != year) continue;
      monthTotals[month.month - 1] = (monthTotals[month.month - 1] ?? 0) + p.amount;
    }
    DateTime? last;
    for (final p in mine) {
      if (last == null || p.paymentDate.isAfter(last)) last = p.paymentDate;
    }
    return SalaryHistory(
      totalPaid: mine.fold<double>(0, (total, p) => total + p.amount),
      paymentCount: mine.length,
      lastPaymentDate: last,
      year: year,
      monthTotals: monthTotals,
    );
  }
}

/// Totals for the Salary Details stat tiles. "This salary month" and
/// "last salary month" go by each entry's Salary Month (the month the
/// salary is for), not by when it was paid.
class SalarySummary {
  const SalarySummary({
    required this.employeesPaidThisMonth,
    required this.amountPaidThisMonth,
    required this.employeesPaidLastMonth,
    required this.amountPaidLastMonth,
  });

  final int employeesPaidThisMonth;
  final double amountPaidThisMonth;
  final int employeesPaidLastMonth;
  final double amountPaidLastMonth;

  factory SalarySummary.of(Iterable<SalaryPayment> payments, {DateTime? now}) {
    final today = now ?? DateTime.now();
    final thisMonth = DateTime(today.year, today.month);
    final lastMonth = DateTime(today.year, today.month - 1);
    bool paidIn(SalaryPayment p, DateTime month) =>
        p.salaryMonthDate.year == month.year && p.salaryMonthDate.month == month.month;

    final thisMonthPayments = payments.where((p) => paidIn(p, thisMonth)).toList();
    final lastMonthPayments = payments.where((p) => paidIn(p, lastMonth)).toList();
    return SalarySummary(
      employeesPaidThisMonth: thisMonthPayments.map((p) => p.employeeDocId).toSet().length,
      amountPaidThisMonth: thisMonthPayments.fold<double>(0, (total, p) => total + p.amount),
      employeesPaidLastMonth: lastMonthPayments.map((p) => p.employeeDocId).toSet().length,
      amountPaidLastMonth: lastMonthPayments.fold<double>(0, (total, p) => total + p.amount),
    );
  }
}
