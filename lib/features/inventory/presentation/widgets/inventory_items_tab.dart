import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/app_card.dart';
import '../../application/inventory_providers.dart';
import 'inventory_data_table.dart';
import 'inventory_toolbar.dart';

/// Item master — name, size, opening stock, reorder level, target.
class InventoryItemsTab extends ConsumerWidget {
  const InventoryItemsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filteredAsync = ref.watch(filteredInventoryListProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
  }
}
