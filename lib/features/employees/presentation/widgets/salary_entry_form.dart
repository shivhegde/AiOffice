import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/date_formatting.dart';
import '../../../../shared/widgets/slideover_panel.dart';
import '../../../users/application/user_providers.dart';
import '../../application/employee_providers.dart';
import '../../application/salary_providers.dart';
import '../../domain/employee.dart';
import '../../domain/salary_payment.dart';
import 'month_picker.dart';

/// Create/edit slideover for a Salary Payment Register entry
/// (docs/Salary Payment Register.html). A new entry starts with the
/// Payment Date, Salary Month, Payment Mode, Paid By and Debit Bank of
/// the last entry added (see [salaryBatchDefaultsProvider]), so a month's
/// salaries can be entered one after another without retyping them.
class SalaryEntrySlideover {
  SalaryEntrySlideover._();

  static Future<void> show(BuildContext context, {SalaryPayment? existing, String? employeeDocId}) {
    return SlideoverPanel.show(
      context,
      title: existing != null ? 'Salary Entry — ${existing.employeeName}' : 'Add Salary Entry',
      body: _SalaryEntryForm(existing: existing, employeeDocId: employeeDocId),
      actions: const [],
    );
  }
}

class _SalaryEntryForm extends ConsumerStatefulWidget {
  const _SalaryEntryForm({this.existing, this.employeeDocId});

  final SalaryPayment? existing;

  /// Employee to pre-select on a new entry.
  final String? employeeDocId;

  @override
  ConsumerState<_SalaryEntryForm> createState() => _SalaryEntryFormState();
}

class _SalaryEntryFormState extends ConsumerState<_SalaryEntryForm> {
  final _employeeController = TextEditingController();
  final _amountController = TextEditingController();
  final _paidByController = TextEditingController();
  final _utrController = TextEditingController();
  final _debitBankController = TextEditingController();
  final _narrationController = TextEditingController();

  late DateTime _paymentDate;
  late DateTime _salaryMonth;
  late SalaryPaymentMode _paymentMode;
  bool _submitting = false;
  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    final now = DateTime.now();
    if (e != null) {
      _paymentDate = e.paymentDate;
      _salaryMonth = e.salaryMonthDate;
      _paymentMode = e.paymentMode;
      _employeeController.text = '${e.employeeId} — ${e.employeeName}';
      _amountController.text = e.amount == e.amount.roundToDouble()
          ? e.amount.toStringAsFixed(0)
          : e.amount.toStringAsFixed(2);
      _paidByController.text = e.paidBy;
      _utrController.text = e.utrNumber;
      _debitBankController.text = e.debitBank;
      _narrationController.text = e.narration;
    } else {
      final batch = ref.read(salaryBatchDefaultsProvider);
      _paymentDate = batch?.paymentDate ?? now;
      _salaryMonth = batch?.salaryMonth ?? DateTime(now.year, now.month);
      _paymentMode = batch?.paymentMode ?? SalaryPaymentMode.neft;
      _paidByController.text = batch?.paidBy ?? '';
      _debitBankController.text = batch?.debitBank ?? '';
      final preselected = _employees.where((e) => e.id == widget.employeeDocId).firstOrNull;
      if (preselected != null) _employeeController.text = _employeeLabel(preselected);
    }
  }

  @override
  void dispose() {
    _employeeController.dispose();
    _amountController.dispose();
    _paidByController.dispose();
    _utrController.dispose();
    _debitBankController.dispose();
    _narrationController.dispose();
    super.dispose();
  }

  static String _employeeLabel(Employee e) => '${e.employeeId} — ${e.fullName}';

  List<Employee> get _employees => ref.read(employeeListProvider).value ?? const <Employee>[];

  void _showMessage(String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _submit() async {
    final existing = widget.existing;
    final employeeText = _employeeController.text.trim();
    final employee = _employees.where((e) => _employeeLabel(e) == employeeText).firstOrNull;
    // An entry being edited may belong to an employee who has since been
    // deleted or renamed; keep its stored employee details in that case.
    final keepStoredEmployee =
        employee == null && existing != null && employeeText == '${existing.employeeId} — ${existing.employeeName}';
    if (employee == null && !keepStoredEmployee) {
      _showMessage('Pick an employee from the list.');
      return;
    }
    final amount = double.tryParse(_amountController.text.trim().replaceAll(',', ''));
    if (amount == null || amount <= 0) {
      _showMessage('Enter the amount paid.');
      return;
    }

    final utr = _utrController.text.trim();
    if (utr.isNotEmpty) {
      final all = ref.read(salaryPaymentListProvider).value ?? const <SalaryPayment>[];
      final duplicate = all.any((p) => p.id != existing?.id && p.utrNumber.trim().toLowerCase() == utr.toLowerCase());
      if (duplicate) {
        final proceed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('UTR already used'),
            content: Text('UTR number $utr is already on another entry. Save anyway?'),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
              FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Save anyway')),
            ],
          ),
        );
        if (proceed != true) return;
      }
    }

    final appUser = ref.read(currentAppUserProvider).value;
    final actorUid = appUser?.uid ?? '';
    final actorName = appUser?.displayName.isNotEmpty == true ? appUser!.displayName : (appUser?.email ?? 'Unknown');

    setState(() => _submitting = true);
    try {
      final payment = SalaryPayment(
        id: existing?.id ?? '',
        employeeDocId: employee?.id ?? existing!.employeeDocId,
        employeeId: employee?.employeeId ?? existing!.employeeId,
        employeeName: employee?.fullName ?? existing!.employeeName,
        paymentDate: _paymentDate,
        salaryMonth: SalaryPayment.monthKey(_salaryMonth),
        amount: amount,
        paymentMode: _paymentMode,
        paidBy: _paidByController.text.trim(),
        utrNumber: utr,
        debitBank: _debitBankController.text.trim(),
        narration: _narrationController.text.trim(),
        createdBy: existing?.createdBy ?? actorUid,
        createdByName: existing?.createdByName ?? actorName,
        createdAt: existing?.createdAt,
      );

      final repo = ref.read(salaryPaymentRepositoryProvider);
      if (_isEditing) {
        await repo.update(payment: payment, actorUid: actorUid, actorName: actorName);
      } else {
        await repo.create(draft: payment, actorUid: actorUid, actorName: actorName);
        ref.read(salaryBatchDefaultsProvider.notifier).state = (
          paymentDate: payment.paymentDate,
          salaryMonth: _salaryMonth,
          paymentMode: payment.paymentMode,
          paidBy: payment.paidBy,
          debitBank: payment.debitBank,
        );
      }

      if (mounted) {
        Navigator.of(context).pop();
        _showMessage(_isEditing ? 'Salary entry updated.' : 'Salary entry added.');
      }
    } catch (e) {
      if (mounted) _showMessage('Could not save: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  /// Pulldown of values already used in the register that still accepts
  /// free text — same pattern as the Department fields elsewhere.
  Widget _pickOrTypeField(TextEditingController controller, Iterable<String> values) {
    final options = {
      for (final v in values)
        if (v.trim().isNotEmpty) v.trim(),
    }.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return DropdownMenu<String>(
      controller: controller,
      expandedInsets: EdgeInsets.zero,
      enableFilter: true,
      requestFocusOnTap: true,
      dropdownMenuEntries: [for (final o in options) DropdownMenuEntry(value: o, label: o)],
      onSelected: (value) {
        if (value != null) controller.text = value;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final employees = ref.watch(employeeListProvider).value ?? const <Employee>[];
    final payments = ref.watch(salaryPaymentListProvider).value ?? const <SalaryPayment>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FormRowLabel(
          label: 'Employee',
          child: DropdownMenu<String>(
            controller: _employeeController,
            expandedInsets: EdgeInsets.zero,
            enableFilter: true,
            requestFocusOnTap: true,
            hintText: 'Search ID or name',
            dropdownMenuEntries: [for (final e in employees) DropdownMenuEntry(value: e.id, label: _employeeLabel(e))],
          ),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: FormRowLabel(
                label: 'Payment Date',
                child: OutlinedButton(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _paymentDate,
                      firstDate: DateTime(2015),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) setState(() => _paymentDate = picked);
                  },
                  child: Align(alignment: Alignment.centerLeft, child: Text(formatDisplayDate(_paymentDate))),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FormRowLabel(
                label: 'Salary Month',
                child: OutlinedButton(
                  onPressed: () async {
                    final picked = await showMonthPicker(context, initial: _salaryMonth);
                    if (picked != null) setState(() => _salaryMonth = picked);
                  },
                  child: Align(alignment: Alignment.centerLeft, child: Text(formatDisplayMonth(_salaryMonth))),
                ),
              ),
            ),
          ],
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: FormRowLabel(
                label: 'Amount (Rs.)',
                child: TextField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FormRowLabel(
                label: 'Payment Mode',
                child: DropdownButtonFormField<SalaryPaymentMode>(
                  initialValue: _paymentMode,
                  isExpanded: true,
                  items: [for (final m in SalaryPaymentMode.values) DropdownMenuItem(value: m, child: Text(m.label))],
                  onChanged: (v) => setState(() => _paymentMode = v ?? SalaryPaymentMode.neft),
                ),
              ),
            ),
          ],
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: FormRowLabel(
                label: 'Paid By (Person)',
                child: _pickOrTypeField(_paidByController, payments.map((p) => p.paidBy)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FormRowLabel(
                label: 'UTR Number',
                child: TextField(controller: _utrController),
              ),
            ),
          ],
        ),
        FormRowLabel(
          label: 'Debit Bank Name',
          child: _pickOrTypeField(_debitBankController, payments.map((p) => p.debitBank)),
        ),
        FormRowLabel(
          label: 'Narration',
          child: TextField(
            controller: _narrationController,
            maxLines: 2,
            decoration: const InputDecoration(hintText: 'e.g. Salary for the month paid to ...'),
          ),
        ),
        const SizedBox(height: 14),
        // Wrap rather than Row so the longer button labels can't overflow
        // a narrow panel.
        Wrap(
          alignment: WrapAlignment.end,
          spacing: 8,
          runSpacing: 8,
          children: [
            TextButton(onPressed: () => Navigator.of(context).maybePop(), child: const Text('Cancel')),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(_isEditing ? 'Update Salary Entry' : 'Add Salary Entry'),
            ),
          ],
        ),
      ],
    );
  }
}
