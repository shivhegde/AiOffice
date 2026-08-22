import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/roles.dart';
import '../../../../core/utils/currency_formatting.dart';
import '../../../../core/utils/date_formatting.dart';
import '../../../../shared/widgets/app_data_table.dart';
import '../../../../shared/widgets/role_gate.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../../../users/application/user_providers.dart';
import '../../application/work_order_providers.dart';
import '../../domain/work_order.dart';
import '../../domain/work_order_enums.dart';
import '../work_order_form_slideover.dart';

class WorkOrderDataTable extends ConsumerWidget {
  const WorkOrderDataTable({super.key, required this.workOrders});

  final List<WorkOrder> workOrders;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppDataTable(
      columns: const [
        DataColumn(label: Text('WO No.')),
        DataColumn(label: Text('Department')),
        DataColumn(label: Text('Contract Type')),
        DataColumn(label: Text('Start')),
        DataColumn(label: Text('End')),
        DataColumn(label: Text('Extension Available')),
        DataColumn(label: Text('Status')),
        DataColumn(label: Text('Value')),
        DataColumn(label: Text('Remarks')),
        DataColumn(label: Text('')),
      ],
      rows: [
        for (final wo in workOrders)
          DataRow(
            cells: [
              DataCell(Text(wo.workOrderNumber)),
              DataCell(Text(wo.departmentName)),
              DataCell(
                StatusChip(
                  label: wo.contractType.label,
                  variant: wo.contractType == ContractType.extension ? StatusChipVariant.accent : StatusChipVariant.neutral,
                ),
              ),
              DataCell(Text(formatDisplayDate(wo.startDate))),
              DataCell(Text(wo.endDate != null ? formatDisplayDate(wo.endDate!) : '—')),
              DataCell(StatusChip(label: wo.extensionAvailable ? 'Yes' : 'No', variant: StatusChipVariant.neutral)),
              DataCell(_StatusChipForWorkOrder(wo: wo)),
              DataCell(Text(formatCurrencyCompact(wo.contractValue))),
              DataCell(SizedBox(width: 160, child: Text(wo.remarks.isEmpty ? '—' : wo.remarks, overflow: TextOverflow.ellipsis))),
              DataCell(_RowActions(workOrder: wo)),
            ],
          ),
      ],
    );
  }
}

class _StatusChipForWorkOrder extends StatelessWidget {
  const _StatusChipForWorkOrder({required this.wo});

  final WorkOrder wo;

  @override
  Widget build(BuildContext context) {
    if (wo.status == WorkOrderStatus.expired) {
      return const StatusChip(label: 'Expired', variant: StatusChipVariant.critical);
    }
    if (wo.isExpiringSoon) {
      final days = wo.endDate!.difference(DateTime.now()).inDays;
      return StatusChip(label: 'Expiring ${days}d', variant: StatusChipVariant.warn);
    }
    if (wo.status == WorkOrderStatus.extended) {
      return const StatusChip(label: 'Extended', variant: StatusChipVariant.accent);
    }
    return const StatusChip(label: 'Active', variant: StatusChipVariant.good);
  }
}

class _RowActions extends ConsumerWidget {
  const _RowActions({required this.workOrder});

  final WorkOrder workOrder;

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
            onPressed: () => WorkOrderFormSlideover.show(context, existing: workOrder),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 17),
            tooltip: 'Delete',
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Delete work order?'),
                  content: Text('This removes ${workOrder.workOrderNumber} and its linked FD record, if any.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
                    FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Delete')),
                  ],
                ),
              );
              if (confirmed != true) return;
              final appUser = ref.read(currentAppUserProvider).value;
              await ref
                  .read(workOrderRepositoryProvider)
                  .delete(
                    workOrder: workOrder,
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
