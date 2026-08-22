import 'package:flutter/material.dart';

import '../../../../core/utils/currency_formatting.dart';
import '../../../../core/utils/date_formatting.dart';
import '../../../../shared/widgets/app_data_table.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../../domain/work_order.dart';
import '../../domain/work_order_enums.dart';
import '../work_order_form_slideover.dart';

/// §8.4 Fixed Deposit list — a filtered view over Work Orders that have an
/// FD recorded (see Phase 2 plan decision #1), not a separate collection.
class FixedDepositDataTable extends StatelessWidget {
  const FixedDepositDataTable({super.key, required this.workOrders});

  final List<WorkOrder> workOrders;

  @override
  Widget build(BuildContext context) {
    return AppDataTable(
      columns: const [
        DataColumn(label: Text('FD No.')),
        DataColumn(label: Text('Bank')),
        DataColumn(label: Text('Linked Work Order')),
        DataColumn(label: Text('Amount')),
        DataColumn(label: Text('Maturity')),
        DataColumn(label: Text('Status')),
        DataColumn(label: Text('')),
      ],
      rows: [
        for (final wo in workOrders)
          DataRow(
            cells: [
              DataCell(Text(wo.fdNumber ?? '—')),
              DataCell(Text(wo.fdBankName ?? '—')),
              DataCell(Text(wo.workOrderNumber)),
              DataCell(Text(wo.fdAmount != null ? formatCurrencyFull(wo.fdAmount!) : '—')),
              DataCell(Text(wo.fdMaturityDate != null ? formatDisplayDate(wo.fdMaturityDate!) : '—')),
              DataCell(_FdStatusChip(wo: wo)),
              DataCell(
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 17),
                  tooltip: 'Edit',
                  onPressed: () => WorkOrderFormSlideover.show(context, existing: wo),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _FdStatusChip extends StatelessWidget {
  const _FdStatusChip({required this.wo});

  final WorkOrder wo;

  @override
  Widget build(BuildContext context) {
    if (wo.fdStatus == FdStatus.released) {
      return const StatusChip(label: 'Released', variant: StatusChipVariant.good);
    }
    if (wo.fdStatus == FdStatus.renewed) {
      return const StatusChip(label: 'Renewed', variant: StatusChipVariant.accent);
    }
    if (wo.isFdExpired) {
      return const StatusChip(label: 'Expired', variant: StatusChipVariant.critical);
    }
    if (wo.isFdReleasePending) {
      return const StatusChip(label: 'Release pending', variant: StatusChipVariant.critical);
    }
    if (wo.isFdMaturingSoon) {
      final days = wo.fdMaturityDate!.difference(DateTime.now()).inDays;
      return StatusChip(label: 'Maturing ${days}d', variant: StatusChipVariant.warn);
    }
    return const StatusChip(label: 'Active', variant: StatusChipVariant.good);
  }
}
