import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_data_table.dart';
import '../../application/inventory_providers.dart';
import 'inventory_export_button.dart';

/// Items at or below their reorder level, with the quantity needed to get
/// back up to target stock.
class InventoryNextOrderTab extends ConsumerWidget {
  const InventoryNextOrderTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(inventoryStockProvider)
        .when(
          data: (stockById) {
            final need = stockById.values.where((s) => s.needsReorder).toList();
            final error = Theme.of(context).colorScheme.error;

            return AppCard(
              title: 'Next Order (items at or below reorder level)',
              trailing: InventoryExportButton(
                title: 'Uniform Next Order',
                headers: _headers,
                rows: () => [
                  for (final (index, s) in need.indexed)
                    [
                      '${index + 1}',
                      s.item.item,
                      s.item.size.isEmpty ? '—' : s.item.size,
                      '${s.inStore}',
                      '${s.item.reorderLevel}',
                      '${s.orderQty}',
                    ],
                ],
              ),
              child: need.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 30),
                      child: Center(child: Text('Nothing to order right now 👍')),
                    )
                  : AppDataTable(
                      columns: [for (final h in _headers) DataColumn(label: Text(h))],
                      rows: [
                        for (final (index, s) in need.indexed)
                          DataRow(
                            cells: [
                              DataCell(Text('${index + 1}')),
                              DataCell(Text(s.item.item)),
                              DataCell(Text(s.item.size.isEmpty ? '—' : s.item.size)),
                              DataCell(
                                Text(
                                  '${s.inStore}',
                                  style: TextStyle(color: error, fontWeight: FontWeight.w600),
                                ),
                              ),
                              DataCell(Text('${s.item.reorderLevel}')),
                              DataCell(Text('${s.orderQty}', style: const TextStyle(fontWeight: FontWeight.w700))),
                            ],
                          ),
                      ],
                    ),
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 60),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (err, _) => Padding(padding: const EdgeInsets.all(20), child: Text('Could not load inventory: $err')),
        );
  }
}

const _headers = ['S.No.', 'Item', 'Size', 'In Store', 'Reorder ≤', 'Order Qty'];
