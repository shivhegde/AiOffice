import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_data_table.dart';
import '../../application/inventory_providers.dart';
import 'inventory_export_button.dart';

/// "Site Holdings" — site × item matrix of the stock held at each site,
/// with a Total column. Only sites holding something are listed. Stock
/// with employees who have no Site set is grouped under a blank site name,
/// listed last.
class InventorySitesTab extends ConsumerWidget {
  const InventorySitesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(inventoryStockProvider)
        .when(
          data: (stockById) {
            final stock = stockById.values.toList();
            final sites =
                {
                  for (final s in stock)
                    for (final entry in s.atSite.entries)
                      if (entry.value != 0) entry.key,
                }.toList()..sort((a, b) {
                  if (a.isEmpty != b.isEmpty) return a.isEmpty ? 1 : -1;
                  return a.toLowerCase().compareTo(b.toLowerCase());
                });

            final headers = ['S.No.', 'Site', for (final s in stock) s.item.displayName, 'Total'];
            List<String> rowOf(int index, String site) {
              final quantities = [for (final s in stock) s.atSite[site] ?? 0];
              return [
                '${index + 1}',
                site,
                for (final q in quantities) '$q',
                '${quantities.fold(0, (total, q) => total + q)}',
              ];
            }

            return AppCard(
              title: 'Site Holdings',
              trailing: InventoryExportButton(
                title: 'Site Holdings',
                headers: headers,
                rows: () => [for (final (index, site) in sites.indexed) rowOf(index, site)],
              ),
              child: sites.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 30),
                      child: Center(
                        child: Text('Issue items to an employee in Movements and their site will show here.'),
                      ),
                    )
                  : AppDataTable(
                      columns: [for (final h in headers) DataColumn(label: Text(h))],
                      rows: [
                        for (final (index, site) in sites.indexed)
                          DataRow(
                            cells: [
                              for (final (col, value) in rowOf(index, site).indexed)
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
