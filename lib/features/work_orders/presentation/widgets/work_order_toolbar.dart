import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/roles.dart';
import '../../../../shared/widgets/app_toolbar.dart';
import '../../../../shared/widgets/role_gate.dart';
import '../../application/work_order_providers.dart';
import '../../domain/work_order_enums.dart';
import '../work_order_form_slideover.dart';

class WorkOrderToolbar extends ConsumerWidget {
  const WorkOrderToolbar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(workOrderFilterProvider);

    return AppToolbar(
      children: [
        SizedBox(
          width: 200,
          child: TextField(
            decoration: const InputDecoration(isDense: true, hintText: 'Search work order no.'),
            onChanged: (v) => ref.read(workOrderFilterProvider.notifier).state = filter.copyWith(search: v),
          ),
        ),
        SizedBox(
          width: 160,
          child: DropdownButtonFormField<WorkOrderStatus?>(
            initialValue: filter.status,
            isExpanded: true,
            decoration: const InputDecoration(isDense: true),
            items: [
              const DropdownMenuItem(value: null, child: Text('All Status')),
              for (final s in WorkOrderStatus.values) DropdownMenuItem(value: s, child: Text(s.label)),
            ],
            onChanged: (v) => ref.read(workOrderFilterProvider.notifier).state = filter.copyWith(status: v),
          ),
        ),
        RoleGate(
          minRole: AppRole.powerUser,
          child: FilledButton.icon(
            onPressed: () => WorkOrderFormSlideover.show(context),
            icon: const Icon(Icons.add, size: 16),
            label: const Text('New Work Order'),
          ),
        ),
      ],
    );
  }
}

class FixedDepositToolbar extends ConsumerWidget {
  const FixedDepositToolbar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(fdFilterProvider);

    return AppToolbar(
      children: [
        SizedBox(
          width: 200,
          child: TextField(
            decoration: const InputDecoration(isDense: true, hintText: 'Search FD number'),
            onChanged: (v) => ref.read(fdFilterProvider.notifier).state = filter.copyWith(search: v),
          ),
        ),
        SizedBox(
          width: 160,
          child: DropdownButtonFormField<FdStatus?>(
            initialValue: filter.status,
            isExpanded: true,
            decoration: const InputDecoration(isDense: true),
            items: [
              const DropdownMenuItem(value: null, child: Text('All Status')),
              for (final s in FdStatus.values) DropdownMenuItem(value: s, child: Text(s.label)),
            ],
            onChanged: (v) => ref.read(fdFilterProvider.notifier).state = filter.copyWith(status: v),
          ),
        ),
        RoleGate(
          minRole: AppRole.powerUser,
          child: FilledButton.icon(
            onPressed: () => WorkOrderFormSlideover.show(context),
            icon: const Icon(Icons.add, size: 16),
            label: const Text('New Fixed Deposit'),
          ),
        ),
      ],
    );
  }
}
