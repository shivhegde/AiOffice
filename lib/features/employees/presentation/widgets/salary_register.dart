import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/utils/currency_formatting.dart';
import '../../../../core/utils/date_formatting.dart';
import '../../../../shared/widgets/app_data_table.dart';
import '../../../../shared/widgets/app_toolbar.dart';
import '../../../users/application/user_providers.dart';
import '../../application/employee_providers.dart';
import '../../application/salary_providers.dart';
import '../../domain/employee.dart';
import '../../domain/salary_payment.dart';
import 'month_picker.dart';
import 'salary_entry_form.dart';

/// Filters for the Salary Payment Register — search, employee (which also
/// opens that employee's history), salary year and month — plus the
/// "Add Salary Entry" button.
class SalaryToolbar extends ConsumerStatefulWidget {
  const SalaryToolbar({super.key});

  @override
  ConsumerState<SalaryToolbar> createState() => _SalaryToolbarState();
}

class _SalaryToolbarState extends ConsumerState<SalaryToolbar> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // "Clear filters" resets the search text too.
    ref.listen(salaryFilterProvider.select((f) => f.search), (_, search) {
      if (search != _searchController.text) _searchController.text = search;
    });

    final filter = ref.watch(salaryFilterProvider);
    final notifier = ref.read(salaryFilterProvider.notifier);
    final employees = [...ref.watch(employeeListProvider).value ?? const <Employee>[]]
      ..sort((a, b) => a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()));
    final thisYear = DateTime.now().year;

    return AppToolbar(
      children: [
        SizedBox(
          width: 230,
          child: TextField(
            controller: _searchController,
            decoration: const InputDecoration(isDense: true, hintText: 'Search name, ID, UTR, narration'),
            onChanged: (v) => notifier.state = ref.read(salaryFilterProvider).copyWith(search: v),
          ),
        ),
        SizedBox(
          width: 240,
          child: DropdownButtonFormField<String?>(
            key: ValueKey('salary-employee-${filter.employeeDocId}'),
            initialValue: employees.any((e) => e.id == filter.employeeDocId) ? filter.employeeDocId : null,
            isExpanded: true,
            decoration: const InputDecoration(isDense: true),
            items: [
              const DropdownMenuItem(value: null, child: Text('All Employees')),
              for (final e in employees)
                DropdownMenuItem(
                  value: e.id,
                  child: Text('${e.employeeId} — ${e.fullName}', overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (v) => notifier.state = ref.read(salaryFilterProvider).copyWith(employeeDocId: v),
          ),
        ),
        SizedBox(
          width: 150,
          child: DropdownButtonFormField<int?>(
            key: ValueKey('salary-year-${filter.year}'),
            initialValue: filter.year,
            isExpanded: true,
            decoration: const InputDecoration(isDense: true),
            items: [
              const DropdownMenuItem(value: null, child: Text('All Years')),
              for (var y = thisYear + 1; y >= thisYear - 10; y--) DropdownMenuItem(value: y, child: Text('Year $y')),
            ],
            onChanged: (v) => notifier.state = ref.read(salaryFilterProvider).copyWith(year: v),
          ),
        ),
        SizedBox(
          width: 150,
          child: DropdownButtonFormField<int?>(
            key: ValueKey('salary-month-${filter.month}'),
            initialValue: filter.month,
            isExpanded: true,
            decoration: const InputDecoration(isDense: true),
            items: [
              const DropdownMenuItem(value: null, child: Text('All Months')),
              for (var m = 1; m <= 12; m++)
                DropdownMenuItem(value: m, child: Text('${m.toString().padLeft(2, '0')} – ${shortMonthName(m)}')),
            ],
            onChanged: (v) => notifier.state = ref.read(salaryFilterProvider).copyWith(month: v),
          ),
        ),
        TextButton(onPressed: () => notifier.state = const SalaryFilterState(), child: const Text('Clear filters')),
        FilledButton.icon(
          onPressed: () => SalaryEntrySlideover.show(context, employeeDocId: filter.employeeDocId),
          icon: const Icon(Icons.add, size: 16),
          label: const Text('Add Salary Entry'),
        ),
      ],
    );
  }
}

/// Per-employee summary shown when the register is filtered to one
/// employee: all-time totals plus a paid / not-paid chip for each month
/// of the selected year.
class SalaryHistoryPanel extends ConsumerWidget {
  const SalaryHistoryPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(salaryFilterProvider);
    final employeeDocId = filter.employeeDocId;
    if (employeeDocId == null) return const SizedBox.shrink();

    final payments = ref.watch(salaryPaymentListProvider).value ?? const <SalaryPayment>[];
    final employee = (ref.watch(employeeListProvider).value ?? const <Employee>[])
        .where((e) => e.id == employeeDocId)
        .firstOrNull;
    final history = SalaryHistory.of(payments, employeeDocId: employeeDocId, year: filter.historyYear);
    final colors = context.appColors;
    final theme = Theme.of(context);

    Widget figure(String value, String caption) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
        Text(caption, style: TextStyle(fontSize: 11.8, color: colors.textMuted)),
      ],
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 28,
            runSpacing: 10,
            children: [
              figure(
                employee?.fullName ??
                    payments.where((p) => p.employeeDocId == employeeDocId).firstOrNull?.employeeName ??
                    '—',
                employee?.employeeId ?? '',
              ),
              figure(formatCurrencyFull(history.totalPaid), 'Total paid (all time)'),
              figure('${history.paymentCount}', 'Payments'),
              figure(
                history.lastPaymentDate != null ? formatDisplayDate(history.lastPaymentDate!) : '—',
                'Last payment',
              ),
              figure('${history.monthsPaid} of 12', 'Months paid in ${history.year}'),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              const spacing = 6.0;
              final columns = (constraints.maxWidth / 96).floor().clamp(3, 12);
              final chipWidth = (constraints.maxWidth - spacing * (columns - 1)) / columns;
              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: [
                  for (var m = 1; m <= 12; m++)
                    _MonthChip(
                      width: chipWidth,
                      label: '${shortMonthName(m)} ${history.year}',
                      total: history.monthTotals[m - 1],
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _MonthChip extends StatelessWidget {
  const _MonthChip({required this.width, required this.label, required this.total});

  final double width;
  final String label;
  final double? total;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final paid = total != null;
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: paid ? colors.good.withValues(alpha: 0.12) : null,
        border: Border.all(color: paid ? colors.good : Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          Text(
            paid ? formatCurrencyFull(total!) : 'Not paid',
            style: TextStyle(fontSize: 12, color: paid ? null : colors.textMuted),
          ),
        ],
      ),
    );
  }
}

/// The register table, with a Total row for the entries shown.
class SalaryRegisterTable extends ConsumerWidget {
  const SalaryRegisterTable({super.key, required this.payments});

  final List<SalaryPayment> payments;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final total = payments.fold<double>(0, (sum, p) => sum + p.amount);
    const bold = TextStyle(fontWeight: FontWeight.w600);

    return AppDataTable(
      columns: const [
        DataColumn(label: Text('#')),
        DataColumn(label: Text('Date')),
        DataColumn(label: Text('Emp ID')),
        DataColumn(label: Text('Name')),
        DataColumn(label: Text('Month')),
        DataColumn(label: Text('Amount'), numeric: true),
        DataColumn(label: Text('Mode')),
        DataColumn(label: Text('Paid By')),
        DataColumn(label: Text('UTR')),
        DataColumn(label: Text('Debit Bank')),
        DataColumn(label: Text('Narration')),
        DataColumn(label: Text('')),
      ],
      rows: [
        for (final (index, p) in payments.indexed)
          DataRow(
            cells: [
              DataCell(Text('${index + 1}')),
              DataCell(Text(formatDisplayDate(p.paymentDate))),
              DataCell(Text(p.employeeId)),
              DataCell(Text(p.employeeName)),
              DataCell(Text(formatDisplayMonth(p.salaryMonthDate))),
              DataCell(Text(formatCurrencyFull(p.amount))),
              DataCell(Text(p.paymentMode.label)),
              DataCell(Text(p.paidBy)),
              DataCell(Text(p.utrNumber)),
              DataCell(Text(p.debitBank)),
              DataCell(SizedBox(width: 220, child: Text(p.narration, overflow: TextOverflow.ellipsis))),
              DataCell(_RowActions(payment: p)),
            ],
          ),
        if (payments.isNotEmpty)
          DataRow(
            cells: [
              const DataCell(Text('')),
              const DataCell(Text('Total', style: bold)),
              for (var i = 0; i < 3; i++) const DataCell(Text('')),
              DataCell(Text(formatCurrencyFull(total), style: bold)),
              for (var i = 0; i < 6; i++) const DataCell(Text('')),
            ],
          ),
      ],
    );
  }
}

class _RowActions extends ConsumerWidget {
  const _RowActions({required this.payment});

  final SalaryPayment payment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.edit_outlined, size: 17),
          tooltip: 'Edit',
          onPressed: () => SalaryEntrySlideover.show(context, existing: payment),
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline, size: 17),
          tooltip: 'Delete',
          onPressed: () async {
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Delete entry?'),
                content: Text(
                  'This removes the ${formatDisplayMonth(payment.salaryMonthDate)} salary entry of '
                  '${formatCurrencyFull(payment.amount)} for ${payment.employeeName}.',
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
                  FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Delete')),
                ],
              ),
            );
            if (confirmed != true) return;
            final appUser = ref.read(currentAppUserProvider).value;
            await ref
                .read(salaryPaymentRepositoryProvider)
                .delete(
                  payment: payment,
                  actorUid: appUser?.uid ?? '',
                  actorName: appUser?.displayName ?? appUser?.email ?? 'Unknown',
                );
          },
        ),
      ],
    );
  }
}
