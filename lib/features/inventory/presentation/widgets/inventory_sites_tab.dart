import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_data_table.dart';
import '../../application/inventory_providers.dart';
import '../../domain/stock_summary.dart';
import 'inventory_export_button.dart';

/// "Uniforms at each site" — item × site matrix with a Total column.
class InventorySitesTab extends ConsumerWidget {
  const InventorySitesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sites = sitesOf(ref.watch(inventoryMovementsProvider).value ?? const []);

    return ref
        .watch(inventoryStockProvider)
        .when(
          data: (stockById) {
            final stock = stockById.values.toList();
            final headers = ['S.No.', 'Item', ...sites, 'Total'];
            List<String> rowOf(int index, ItemStock s) => [
              '${index + 1}',
              s.item.displayName,
              for (final site in sites) '${s.atSite[site] ?? 0}',
              '${s.atSitesTotal}',
            ];

            return AppCard(
              title: 'Uniforms at Each Site',
              trailing: InventoryExportButton(
                title: 'Uniforms at Each Site',
                headers: headers,
                rows: () => [for (final (index, s) in stock.indexed) rowOf(index, s)],
              ),
              child: sites.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 30),
                      child: Center(child: Text('Issue items to a site in Movements and they will show here.')),
                    )
                  : AppDataTable(
                      columns: [for (final h in headers) DataColumn(label: Text(h))],
                      rows: [
                        for (final (index, s) in stock.indexed)
                          DataRow(
                            cells: [
                              for (final (col, value) in rowOf(index, s).indexed)
                                DataCell(
                                  Text(
                                    value,
                                    style: col == headers.length - 1
                                        ? const TextStyle(fontWeight: FontWeight.w700)
                                        : null,
                                  ),
                                ),
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
