import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/roles.dart';
import '../../../../core/utils/currency_formatting.dart';
import '../../../../shared/widgets/app_data_table.dart';
import '../../../../shared/widgets/role_gate.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../../../users/application/user_providers.dart';
import '../../application/epf_case_providers.dart';
import '../../domain/epf_case.dart';
import '../../domain/epf_enums.dart';
import '../epf_case_form_slideover.dart';

class EpfCaseDataTable extends ConsumerWidget {
  const EpfCaseDataTable({super.key, required this.cases});

  final List<EpfCase> cases;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppDataTable(
      columns: const [
        DataColumn(label: Text('Client ID')),
        DataColumn(label: Text('Name')),
        DataColumn(label: Text('Mobile')),
        DataColumn(label: Text('Service')),
        DataColumn(label: Text('Stage')),
        DataColumn(label: Text('Fee')),
        DataColumn(label: Text('Pending')),
        DataColumn(label: Text('')),
      ],
      rows: [
        for (final c in cases)
          DataRow(
            cells: [
              DataCell(Text(c.clientId)),
              DataCell(Text(c.name)),
              DataCell(Text(c.mobile)),
              DataCell(Text(c.service.label)),
              DataCell(_StageChip(stage: c.stage)),
              DataCell(Text(formatCurrencyCompact(c.fee))),
              DataCell(
                Text(
                  c.isFullyPaid ? 'Paid' : formatCurrencyCompact(c.pendingAmount),
                  style: c.isFullyPaid ? null : const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              DataCell(_RowActions(epfCase: c)),
            ],
          ),
      ],
    );
  }
}

class _StageChip extends StatelessWidget {
  const _StageChip({required this.stage});

  final CaseStage stage;

  @override
  Widget build(BuildContext context) {
    final variant = switch (stage) {
      CaseStage.rejected => StatusChipVariant.critical,
      CaseStage.completed => StatusChipVariant.good,
      CaseStage.newClient || CaseStage.documentsReceived => StatusChipVariant.neutral,
      CaseStage.applicationSubmitted || CaseStage.epfoProcessing => StatusChipVariant.warn,
      CaseStage.approved || CaseStage.paymentCredited || CaseStage.feesCollected => StatusChipVariant.accent,
    };
    return StatusChip(label: stage.label, variant: variant);
  }
}

class _RowActions extends ConsumerWidget {
  const _RowActions({required this.epfCase});

  final EpfCase epfCase;

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
            onPressed: () => EpfCaseFormSlideover.show(context, existing: epfCase),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 17),
            tooltip: 'Delete',
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Delete case?'),
                  content: Text('This removes ${epfCase.clientId} — ${epfCase.name} and its documents.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
                    FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Delete')),
                  ],
                ),
              );
              if (confirmed != true) return;
              final appUser = ref.read(currentAppUserProvider).value;
              await ref
                  .read(epfCaseRepositoryProvider)
                  .delete(
                    epfCase: epfCase,
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
