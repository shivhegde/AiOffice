import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/roles.dart';
import '../../../../core/utils/date_formatting.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_data_table.dart';
import '../../../../shared/widgets/app_toolbar.dart';
import '../../../../shared/widgets/role_gate.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../../../users/application/user_providers.dart';
import '../../application/inventory_providers.dart';
import '../../domain/inventory_item.dart';
import '../../domain/inventory_movement.dart';
import '../../domain/stock_summary.dart';
import '../movement_form_slideover.dart';
import 'inventory_export_button.dart';

/// Movement history (newest first) with a "Record Movement" action. With
/// [damagedOnly] it's the Damaged tab: the Damaged & Lost log.
class InventoryMovementsTab extends ConsumerWidget {
  const InventoryMovementsTab({super.key, this.damagedOnly = false});

  final bool damagedOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsById = {for (final i in ref.watch(inventoryListProvider).value ?? const <InventoryItem>[]) i.id: i};

    return ref
        .watch(inventoryMovementsProvider)
        .when(
          data: (all) {
            final movements = damagedOnly ? all.where((m) => m.type.isWriteOff).toList() : all;
            String itemName(InventoryMovement m) => itemsById[m.itemId]?.displayName ?? '${m.itemLabel} (deleted)';
            final title = damagedOnly ? 'Damaged & Lost Log' : 'Uniform Movements';

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppToolbar(
                  children: [
                    InventoryExportButton(
                      title: title,
                      headers: _headers,
                      rows: () => [
                        for (final (index, m) in movements.indexed)
                          [
                            '${index + 1}',
                            formatDisplayDate(m.date),
                            m.type.label,
                            itemName(m),
                            '${m.qty}',
                            _orDash(m.site),
                            _orDash(m.employeeId),
                            _orDash(m.employeeName),
                            _orDash(m.employeeRole),
                            m.note.isEmpty ? '—' : m.note,
                            m.createdByName,
                          ],
                      ],
                    ),
                    RoleGate(
                      minRole: AppRole.powerUser,
                      child: FilledButton.icon(
                        onPressed: () => MovementFormSlideover.show(
                          context,
                          initialType: damagedOnly ? MovementType.damaged : MovementType.received,
                        ),
                        icon: const Icon(Icons.add, size: 16),
                        label: Text(damagedOnly ? 'Record Damaged / Lost' : 'Record Movement'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                AppCard(
                  title: damagedOnly ? 'Damaged & Lost Log' : 'History',
                  child: AppDataTable(
                    columns: [
                      for (final h in _headers) DataColumn(label: Text(h)),
                      const DataColumn(label: Text('')),
                    ],
                    rows: [
                      for (final (index, m) in movements.indexed)
                        DataRow(
                          cells: [
                            DataCell(Text('${index + 1}')),
                            DataCell(Text(formatDisplayDate(m.date))),
                            DataCell(StatusChip(label: m.type.label, variant: _variantOf(m.type))),
                            DataCell(Text(itemName(m))),
                            DataCell(Text('${m.qty}')),
                            DataCell(Text(_orDash(m.site))),
                            DataCell(Text(_orDash(m.employeeId))),
                            DataCell(Text(_orDash(m.employeeName))),
                            DataCell(Text(_orDash(m.employeeRole))),
                            DataCell(
                              SizedBox(
                                width: 200,
                                child: Text(m.note.isEmpty ? '—' : m.note, overflow: TextOverflow.ellipsis),
                              ),
                            ),
                            DataCell(Text(m.createdByName)),
                            DataCell(_DeleteMovementButton(movement: m)),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 60),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (err, _) => Padding(padding: const EdgeInsets.all(20), child: Text('Could not load movements: $err')),
        );
  }
}

const _headers = [
  'S.No.',
  'Date',
  'Type',
  'Item',
  'Qty',
  'Site',
  'Employee ID',
  'Employee Name',
  'Role',
  'Note',
  'Recorded By',
];

String _orDash(String value) => value.isEmpty ? '—' : value;

StatusChipVariant _variantOf(MovementType type) => switch (type) {
  MovementType.received => StatusChipVariant.good,
  MovementType.issueToSite => StatusChipVariant.accent,
  MovementType.returnFromSite => StatusChipVariant.neutral,
  MovementType.damaged => StatusChipVariant.warn,
  MovementType.lost => StatusChipVariant.critical,
};

class _DeleteMovementButton extends ConsumerWidget {
  const _DeleteMovementButton({required this.movement});

  final InventoryMovement movement;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RoleGate(
      minRole: AppRole.powerUser,
      child: IconButton(
        icon: const Icon(Icons.delete_outline, size: 17),
        tooltip: 'Delete',
        onPressed: () async {
          // Deleting e.g. a receipt that later issues relied on would leave
          // stock negative — refuse rather than let the figures go wrong.
          final items = ref.read(inventoryListProvider).value ?? const <InventoryItem>[];
          final remaining = (ref.read(inventoryMovementsProvider).value ?? const <InventoryMovement>[])
              .where((m) => m.id != movement.id)
              .toList();
          final after = computeStock(items, remaining)[movement.itemId];
          if (after != null && after.hasNegative) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Cannot delete: later movements depend on this stock and it would go negative. '
                  'Delete those first.',
                ),
              ),
            );
            return;
          }
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Delete this record?'),
              content: Text(
                '${movement.type.label} of ${movement.qty} × ${movement.itemLabel} on '
                '${formatDisplayDate(movement.date)}. Stock figures will be recalculated.',
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
              .read(inventoryRepositoryProvider)
              .deleteMovement(
                movement: movement,
                actorUid: appUser?.uid ?? '',
                actorName: appUser?.displayName ?? appUser?.email ?? 'Unknown',
              );
        },
      ),
    );
  }
}
