import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/roles.dart';
import '../../../../core/utils/date_formatting.dart';
import '../../../../shared/widgets/app_data_table.dart';
import '../../../../shared/widgets/role_gate.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../../../users/application/user_providers.dart';
import '../../application/employee_providers.dart';
import '../../domain/employee.dart';
import '../../domain/employee_enums.dart';
import '../employee_form_slideover.dart';

class EmployeeDataTable extends ConsumerWidget {
  const EmployeeDataTable({super.key, required this.employees});

  final List<Employee> employees;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppDataTable(
      columns: const [
        DataColumn(label: Text('Employee ID')),
        DataColumn(label: Text('Name')),
        DataColumn(label: Text('Mobile')),
        DataColumn(label: Text('Department')),
        DataColumn(label: Text('Designation')),
        DataColumn(label: Text('Type')),
        DataColumn(label: Text('Appointed')),
        DataColumn(label: Text('Status')),
        DataColumn(label: Text('')),
      ],
      rows: [
        for (final e in employees)
          DataRow(
            cells: [
              DataCell(Text(e.employeeId)),
              DataCell(Text(e.fullName)),
              DataCell(Text(e.mobileNumber)),
              DataCell(Text(e.department)),
              DataCell(Text(e.designation)),
              DataCell(Text(e.employeeType.label)),
              DataCell(Text(formatDisplayDate(e.dateOfAppointment))),
              DataCell(_StatusChipForEmployee(status: e.workStatus)),
              DataCell(_RowActions(employee: e)),
            ],
          ),
      ],
    );
  }
}

class _StatusChipForEmployee extends StatelessWidget {
  const _StatusChipForEmployee({required this.status});

  final WorkStatus status;

  @override
  Widget build(BuildContext context) {
    final variant = switch (status) {
      WorkStatus.active => StatusChipVariant.good,
      WorkStatus.inactive => StatusChipVariant.neutral,
      WorkStatus.resigned => StatusChipVariant.warn,
      WorkStatus.retired => StatusChipVariant.accent,
      WorkStatus.contractClosed => StatusChipVariant.critical,
    };
    return StatusChip(label: status.label, variant: variant);
  }
}

class _RowActions extends ConsumerWidget {
  const _RowActions({required this.employee});

  final Employee employee;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RoleGate(
      minRole: AppRole.powerUser,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 17),
            tooltip: 'Edit',
            onPressed: () => EmployeeFormSlideover.show(context, existing: employee),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 17),
            tooltip: 'Delete',
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Delete employee?'),
                  content: Text('This removes ${employee.employeeId} — ${employee.fullName} and its documents.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
                    FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Delete')),
                  ],
                ),
              );
              if (confirmed != true) return;
              final appUser = ref.read(currentAppUserProvider).value;
              await ref
                  .read(employeeRepositoryProvider)
                  .delete(
                    employee: employee,
                    actorUid: appUser?.uid ?? '',
                    actorName: appUser?.displayName ?? appUser?.email ?? 'Unknown',
                  );
            },
          ),
        ],
      ),
    );
  }
}
