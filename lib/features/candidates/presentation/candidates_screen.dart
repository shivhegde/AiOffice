import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/stat_tile.dart';
import '../application/candidate_providers.dart';
import '../domain/candidate_enums.dart';
import 'widgets/candidate_data_table.dart';
import 'widgets/candidate_toolbar.dart';

/// REQUIREMENTS.md §9.2 — Resume/Candidate Database (manpower pool).
class CandidatesScreen extends ConsumerWidget {
  const CandidatesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allAsync = ref.watch(candidateListProvider);
    final filteredAsync = ref.watch(filteredCandidateListProvider);

    return allAsync.when(
      data: (all) {
        final security = all.where((c) => c.category == CandidateCategory.security).length;
        final housekeeping = all.where((c) => c.category == CandidateCategory.housekeeping).length;
        final addedThisMonth = all.where((c) => c.isAddedThisMonth).length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _StatRow(
              tiles: [
                StatTile(label: 'Total Candidates', value: '${all.length}'),
                StatTile(label: 'Security', value: '$security'),
                StatTile(label: 'Housekeeping', value: '$housekeeping'),
                StatTile(label: 'Added This Month', value: '$addedThisMonth'),
              ],
            ),
            const SizedBox(height: 18),
            const CandidateToolbar(),
            const SizedBox(height: 14),
            AppCard(
              child: filteredAsync.when(
                data: (docs) => CandidateDataTable(candidates: docs),
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
      error: (err, _) => Padding(padding: const EdgeInsets.all(20), child: Text('Could not load candidates: $err')),
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
        final columns = constraints.maxWidth < 460 ? 1 : (constraints.maxWidth < 980 ? 2 : 4);
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
