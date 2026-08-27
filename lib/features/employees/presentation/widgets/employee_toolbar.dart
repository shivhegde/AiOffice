import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/roles.dart';
import '../../../../shared/widgets/app_toolbar.dart';
import '../../../../shared/widgets/role_gate.dart';
import '../../application/employee_providers.dart';
import '../../domain/employee_enums.dart';
import '../employee_form_slideover.dart';

class EmployeeToolbar extends ConsumerWidget {
  const EmployeeToolbar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(employeeFilterProvider);

    return AppToolbar(
      children: [
        SizedBox(
          width: 220,
          child: TextField(
            decoration: const InputDecoration(isDense: true, hintText: 'Search name, ID, mobile, Aadhaar'),
            onChanged: (v) => ref.read(employeeFilterProvider.notifier).state = filter.copyWith(search: v),
          ),
        ),
        SizedBox(
          width: 160,
          child: DropdownButtonFormField<WorkStatus?>(
            initialValue: filter.workStatus,
            isExpanded: true,
            decoration: const InputDecoration(isDense: true),
            items: [
              const DropdownMenuItem(value: null, child: Text('All Status')),
              for (final s in WorkStatus.values) DropdownMenuItem(value: s, child: Text(s.label)),
            ],
            onChanged: (v) => ref.read(employeeFilterProvider.notifier).state = filter.copyWith(workStatus: v),
          ),
        ),
        RoleGate(
          minRole: AppRole.powerUser,
          child: FilledButton.icon(
            onPressed: () => EmployeeFormSlideover.show(context),
            icon: const Icon(Icons.add, size: 16),
            label: const Text('New Employee'),
          ),
        ),
      ],
    );
  }
}
