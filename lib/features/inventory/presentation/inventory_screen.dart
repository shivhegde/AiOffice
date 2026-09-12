import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/stat_tile.dart';
import '../application/inventory_providers.dart';
import 'widgets/inventory_data_table.dart';
import 'widgets/inventory_toolbar.dart';

/// REQUIREMENTS.md §9.3 — Inventory. Deliberately minimal (see
/// [InventoryItem] doc comment): the source spec defines only Item, Size,
/// Qty, with no dashboard/alerts section, so the stats here are limited to
/// what's directly derivable from that flat list.
class InventoryScreen extends ConsumerWidget {
  const InventoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allAsync = ref.watch(inventoryListProvider);
    final filteredAsync = ref.watch(filteredInventoryListProvider);

    return allAsync.when(
      data: (all) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _StatRow(
              tiles: [
                StatTile(label: 'Number of Items', value: '${all.length}'),
              ],
            ),
            const SizedBox(height: 18),
            const InventoryToolbar(),
            const SizedBox(height: 14),
            AppCard(
              child: filteredAsync.when(
                data: (docs) => InventoryDataTable(items: docs),
                loading: () => const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (err, _) => Text('Could not load: $err'),
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

class _StatRow extends StatelessWidget {
  const _StatRow({required this.tiles});

  final List<Widget> tiles;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 460 ? 1 : 2;
        return GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: 3.3,
          children: tiles,
        );
      },
    );
  }
}
