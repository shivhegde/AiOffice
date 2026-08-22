import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/app_card.dart';
import '../application/io_providers.dart';
import 'widgets/io_data_table.dart';
import 'widgets/io_toolbar.dart';

class OutwardListView extends ConsumerWidget {
  const OutwardListView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allAsync = ref.watch(outwardListProvider);
    final filteredAsync = ref.watch(filteredOutwardListProvider);

    return allAsync.when(
      data: (all) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OutwardToolbar(allDocuments: all),
          const SizedBox(height: 14),
          AppCard(
            child: filteredAsync.when(
              data: (docs) => OutwardDataTable(documents: docs),
              loading: () => const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (err, _) => Text('Could not load: $err'),
            ),
          ),
        ],
      ),
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 60),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (err, _) => Padding(padding: const EdgeInsets.all(20), child: Text('Could not load outward entries: $err')),
    );
  }
}
