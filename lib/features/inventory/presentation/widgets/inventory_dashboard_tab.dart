import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_data_table.dart';
import '../../../../shared/widgets/stat_tile.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../../application/inventory_providers.dart';
import '../../domain/stock_summary.dart';
import 'inventory_export_button.dart';

/// In store / At sites / Damaged / Items low tiles + per-item stock summary.
class InventoryDashboardTab extends ConsumerWidget {
  const InventoryDashboardTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(inventoryStockProvider)
        .when(
          data: (stockById) {
            final stock = stockById.values.toList();
            int total(int Function(ItemStock) f) => stock.fold(0, (sum, s) => sum + f(s));
            final low = stock.where((s) => s.needsReorder).length;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.maxWidth < 460 ? 1 : (constraints.maxWidth < 980 ? 2 : 4);
                    return GridView.count(
                      crossAxisCount: columns,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 14,
                      crossAxisSpacing: 14,
                      childAspectRatio: 3.3,
                      children: [
                        StatTile(label: 'In Store', value: '${total((s) => s.inStore)}'),
                        StatTile(label: 'At Sites', value: '${total((s) => s.atSitesTotal)}'),
                        StatTile(label: 'Damaged (Total)', value: '${total((s) => s.damaged)}'),
                        StatTile(
                          label: 'Items Low',
                          value: '$low',
                          deltaText: low > 0 ? 'See Next Order' : null,
                          deltaTone: low > 0 ? StatDeltaTone.bad : null,
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 18),
                AppCard(
                  title: 'Stock Summary',
                  trailing: InventoryExportButton(
                    title: 'Uniform Stock Summary',
                    headers: _headers,
                    rows: () => _rows(stock),
                  ),
                  child: stock.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 30),
                          child: Center(child: Text('Start by adding uniform items in the Items tab.')),
                        )
                      : AppDataTable(
                          columns: [for (final h in _headers) DataColumn(label: Text(h))],
                          rows: [
                            for (final (index, s) in stock.indexed)
                              DataRow(
                                cells: [
                                  DataCell(Text('${index + 1}')),
                                  DataCell(Text(s.item.displayName)),
                                  DataCell(_StoreQty(stock: s)),
                                  DataCell(Text('${s.atSitesTotal}')),
                                  DataCell(Text('${s.damaged}')),
                                  DataCell(Text('${s.lost}')),
                                  DataCell(
                                    s.needsReorder
                                        ? const StatusChip(label: 'Reorder', variant: StatusChipVariant.critical)
                                        : const StatusChip(label: 'OK', variant: StatusChipVariant.good),
                                  ),
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
          error: (err, _) => Padding(padding: const EdgeInsets.all(20), child: Text('Could not load inventory: $err')),
        );
  }
}

const _headers = ['S.No.', 'Item', 'In Store', 'At Sites', 'Damaged', 'Lost', 'Status'];

List<List<String>> _rows(List<ItemStock> stock) => [
  for (final (index, s) in stock.indexed)
    [
      '${index + 1}',
      s.item.displayName,
      '${s.inStore}',
      '${s.atSitesTotal}',
      '${s.damaged}',
      '${s.lost}',
      s.needsReorder ? 'Reorder' : 'OK',
    ],
];

/// Store quantity, highlighted when at or below the reorder level.
class _StoreQty extends StatelessWidget {
  const _StoreQty({required this.stock});

  final ItemStock stock;

  @override
  Widget build(BuildContext context) {
    return Text(
      '${stock.inStore}',
      style: stock.needsReorder
          ? TextStyle(color: Theme.of(context).colorScheme.error, fontWeight: FontWeight.w600)
          : null,
    );
  }
}
