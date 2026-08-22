import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/roles.dart';
import '../../../../core/services/whatsapp_launcher.dart';
import '../../../../core/utils/currency_formatting.dart';
import '../../../../core/utils/date_formatting.dart';
import '../../../../shared/widgets/app_data_table.dart';
import '../../../../shared/widgets/role_gate.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../../../users/application/user_providers.dart';
import '../../application/tender_providers.dart';
import '../../domain/tender.dart';
import '../../domain/tender_enums.dart';
import '../tender_form_slideover.dart';

class TenderDataTable extends ConsumerWidget {
  const TenderDataTable({super.key, required this.tenders});

  final List<Tender> tenders;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppDataTable(
      columns: const [
        DataColumn(label: Text('Tender No.')),
        DataColumn(label: Text('Tender Name')),
        DataColumn(label: Text('Department')),
        DataColumn(label: Text('Category')),
        DataColumn(label: Text('EMD Amount')),
        DataColumn(label: Text('Type')),
        DataColumn(label: Text('Publish Date')),
        DataColumn(label: Text('Submitted')),
        DataColumn(label: Text('Refund Status')),
        DataColumn(label: Text('')),
      ],
      rows: [
        for (final tender in tenders)
          DataRow(
            cells: [
              DataCell(Text(tender.tenderNumber)),
              DataCell(SizedBox(width: 220, child: Text(tender.tenderName, overflow: TextOverflow.ellipsis))),
              DataCell(Text(tender.departmentName)),
              DataCell(StatusChip(label: tender.category.label, variant: StatusChipVariant.neutral)),
              DataCell(Text(formatCurrencyFull(tender.emdAmount))),
              DataCell(Text(tender.emdType.label)),
              DataCell(Text(formatDisplayDate(tender.publishDate))),
              DataCell(Text(formatDisplayDate(tender.submissionDate))),
              DataCell(_RefundStatusChip(tender: tender)),
              DataCell(_RowActions(tender: tender)),
            ],
          ),
      ],
    );
  }
}

class _RefundStatusChip extends StatelessWidget {
  const _RefundStatusChip({required this.tender});

  final Tender tender;

  @override
  Widget build(BuildContext context) {
    if (tender.refundStatus == RefundStatus.refunded) {
      return const StatusChip(label: 'Refunded', variant: StatusChipVariant.good);
    }
    if (tender.refundStatus == RefundStatus.forfeited) {
      return const StatusChip(label: 'Forfeited', variant: StatusChipVariant.neutral);
    }
    if (tender.isRefundOverdue) {
      return StatusChip(label: 'Overdue ${tender.refundOverdueDays}d', variant: StatusChipVariant.critical);
    }
    return const StatusChip(label: 'Pending', variant: StatusChipVariant.warn);
  }
}

class _RowActions extends ConsumerWidget {
  const _RowActions({required this.tender});

  final Tender tender;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (tender.refundStatus == RefundStatus.pending)
          IconButton(
            icon: const Icon(Icons.chat_outlined, size: 17),
            tooltip: 'Send refund reminder',
            onPressed: () {
              // §7.8 exact template.
              final message =
                  'Sir, kindly refund of EMD refund against Tender No. ${tender.tenderNumber} '
                  'for Rs. ${tender.emdAmount.toStringAsFixed(0)} — ${tender.tenderName}.';
              final digits = tender.deptContactMobile.replaceAll(RegExp(r'\D'), '');
              WhatsappLauncher.open(phone: digits.isNotEmpty ? '91$digits' : null, message: message);
            },
          ),
        RoleGate(
          minRole: AppRole.powerUser,
          child: IconButton(
            icon: const Icon(Icons.edit_outlined, size: 17),
            tooltip: 'Edit',
            onPressed: () => TenderFormSlideover.show(context, existing: tender),
          ),
        ),
        RoleGate(
          minRole: AppRole.powerUser,
          child: IconButton(
            icon: const Icon(Icons.delete_outline, size: 17),
            tooltip: 'Delete',
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Delete tender?'),
                  content: Text('This removes ${tender.tenderNumber} and its EMD record.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
                    FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Delete')),
                  ],
                ),
              );
              if (confirmed != true) return;
              final appUser = ref.read(currentAppUserProvider).value;
              await ref
                  .read(tenderRepositoryProvider)
                  .delete(
                    tender: tender,
                    actorUid: appUser?.uid ?? '',
                    actorName: appUser?.displayName ?? appUser?.email ?? 'Unknown',
                  );
            },
          ),
        ),
      ],
    );
  }
}
