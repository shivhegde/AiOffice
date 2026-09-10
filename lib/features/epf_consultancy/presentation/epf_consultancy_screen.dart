import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/currency_formatting.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/stat_tile.dart';
import '../application/epf_case_providers.dart';
import 'widgets/epf_case_data_table.dart';
import 'widgets/epf_case_toolbar.dart';

/// REQUIREMENTS.md §9.5.1 — EPF Consultancy dashboard + case register.
class EpfConsultancyScreen extends ConsumerWidget {
  const EpfConsultancyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allAsync = ref.watch(epfCaseListProvider);
    final filteredAsync = ref.watch(filteredEpfCaseListProvider);

    return allAsync.when(
      data: (all) {
        final todaysApplications = all.where((c) => c.isCreatedToday).length;
        final pending = all.where((c) => c.isPending).length;
        final completed = all.where((c) => c.isCompleted).length;
        final todaysIncome = all.where((c) => c.isPaidToday).fold<double>(0, (sum, c) => sum + c.amountPaid);
        final todaysFollowUps = all.where((c) => c.hasFollowUpToday).length;
        final renewalAlerts = all.where((c) => c.needsRenewalAlert).length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _StatRow(
              tiles: [
                StatTile(label: 'Total Clients', value: '${all.length}'),
                StatTile(label: "Today's Applications", value: '$todaysApplications'),
                StatTile(label: 'Pending Cases', value: '$pending'),
                StatTile(label: 'Completed Cases', value: '$completed'),
                StatTile(label: "Today's Income", value: formatCurrencyCompact(todaysIncome)),
                StatTile(label: "Today's Follow-ups", value: '$todaysFollowUps'),
                StatTile(label: 'Renewal Alerts', value: '$renewalAlerts'),
              ],
            ),
            const SizedBox(height: 18),
            const EpfCaseToolbar(),
            const SizedBox(height: 14),
            AppCard(
              child: filteredAsync.when(
                data: (docs) => EpfCaseDataTable(cases: docs),
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
      error: (err, _) => Padding(padding: const EdgeInsets.all(20), child: Text('Could not load cases: $err')),
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
        final columns = constraints.maxWidth < 460
            ? 1
            : (constraints.maxWidth < 760 ? 2 : (constraints.maxWidth < 1080 ? 3 : 4));
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
