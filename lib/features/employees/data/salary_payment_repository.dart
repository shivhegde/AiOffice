import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/firestore_paths.dart';
import '../../../core/utils/currency_formatting.dart';
import '../../../core/utils/date_formatting.dart';
import '../../audit/data/audit_log_repository.dart';
import '../../audit/domain/audit_entry.dart';
import '../domain/salary_payment.dart';

/// Salary Payment Register CRUD (`salary_payments`). Same pattern as the
/// other repositories: the saved [SalaryPayment] is built directly via its
/// constructor rather than round-tripped through `toMap()`/`fromMap()`.
class SalaryPaymentRepository {
  SalaryPaymentRepository({required FirebaseFirestore firestore, required AuditLogRepository auditLog})
    : _firestore = firestore,
      _auditLog = auditLog;

  final FirebaseFirestore _firestore;
  final AuditLogRepository _auditLog;

  CollectionReference<Map<String, dynamic>> get _collection => _firestore.collection(FirestorePaths.salaryPayments);

  Stream<List<SalaryPayment>> watchAll() {
    return _collection
        .orderBy('paymentDate', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => SalaryPayment.fromMap(d.id, d.data())).toList());
  }

  String _label(SalaryPayment p) =>
      'Salary ${p.employeeId} — ${p.employeeName}, ${formatDisplayMonth(p.salaryMonthDate)} '
      '(${formatCurrencyFull(p.amount)})';

  Future<SalaryPayment> create({
    required SalaryPayment draft,
    required String actorUid,
    required String actorName,
  }) async {
    final docRef = _collection.doc();
    final toSave = SalaryPayment(
      id: docRef.id,
      employeeDocId: draft.employeeDocId,
      employeeId: draft.employeeId,
      employeeName: draft.employeeName,
      paymentDate: draft.paymentDate,
      salaryMonth: draft.salaryMonth,
      amount: draft.amount,
      paymentMode: draft.paymentMode,
      paidBy: draft.paidBy,
      utrNumber: draft.utrNumber,
      debitBank: draft.debitBank,
      narration: draft.narration,
      createdBy: actorUid,
      createdByName: actorName,
    );

    await docRef.set(toSave.toMap());
    await _auditLog.log(
      actorUid: actorUid,
      actorName: actorName,
      action: AuditAction.create,
      module: 'employees',
      targetId: docRef.id,
      targetLabel: _label(toSave),
    );
    return toSave;
  }

  Future<void> update({required SalaryPayment payment, required String actorUid, required String actorName}) async {
    await _collection.doc(payment.id).update(payment.toMap());
    await _auditLog.log(
      actorUid: actorUid,
      actorName: actorName,
      action: AuditAction.update,
      module: 'employees',
      targetId: payment.id,
      targetLabel: _label(payment),
    );
  }

  Future<void> delete({required SalaryPayment payment, required String actorUid, required String actorName}) async {
    await _collection.doc(payment.id).delete();
    await _auditLog.log(
      actorUid: actorUid,
      actorName: actorName,
      action: AuditAction.delete,
      module: 'employees',
      targetId: payment.id,
      targetLabel: _label(payment),
    );
  }
}
