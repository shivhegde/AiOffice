import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/roles.dart';
import '../../../../shared/widgets/app_data_table.dart';
import '../../../../shared/widgets/role_gate.dart';
import '../../../users/application/user_providers.dart';
import '../../application/inventory_providers.dart';
import '../../domain/inventory_item.dart';
import '../inventory_form_slideover.dart';

class InventoryDataTable extends ConsumerWidget {
  const InventoryDataTable({super.key, required this.items});

  final List<InventoryItem> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppDataTable(
      columns: const [
        DataColumn(label: Text('Item')),
        DataColumn(label: Text('Size')),
        DataColumn(label: Text('Qty')),
        DataColumn(label: Text('')),
      ],
      rows: [
        for (final i in items)
          DataRow(
            cells: [
              DataCell(Text(i.item)),
              DataCell(Text(i.size.isEmpty ? '—' : i.size)),
              DataCell(Text('${i.qty}')),
              DataCell(_RowActions(item: i)),
            ],
          ),
      ],
    );
  }
}

class _RowActions extends ConsumerWidget {
  const _RowActions({required this.item});

  final InventoryItem item;

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
            onPressed: () => InventoryFormSlideover.show(context, existing: item),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 17),
            tooltip: 'Delete',
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Delete inventory item?'),
                  content: Text('This removes ${item.item} (${item.size}).'),
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
                  .delete(
                    item: item,
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
