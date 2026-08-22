import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/app_card.dart';
import '../application/io_providers.dart';
import 'widgets/io_data_table.dart';
import 'widgets/io_toolbar.dart';

class InwardListView extends ConsumerWidget {
  const InwardListView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allAsync = ref.watch(inwardListProvider);
    final filteredAsync = ref.watch(filteredInwardListProvider);

    return allAsync.when(
      data: (all) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InwardToolbar(allDocuments: all),
          const SizedBox(height: 14),
          AppCard(
            child: filteredAsync.when(
              data: (docs) => InwardDataTable(documents: docs),
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
      error: (err, _) => Padding(padding: const EdgeInsets.all(20), child: Text('Could not load inward entries: $err')),
    );
  }
}
