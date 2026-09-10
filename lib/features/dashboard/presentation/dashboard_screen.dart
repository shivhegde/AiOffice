import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/currency_formatting.dart';
import '../../../shared/widgets/stat_tile.dart';
import '../../inward_outward/domain/io_document.dart';
import '../application/dashboard_providers.dart';
import 'widgets/activity_by_task_group_chart.dart';
import 'widgets/needs_attention_card.dart';
import 'widgets/recent_activity_card.dart';

/// REQUIREMENTS.md §5.1 — cross-module home dashboard. Now backed by
/// Inward/Outward, Tender-EMD, and Work Orders & FD data (Phase 2) — the
/// EMD Pending Refund / FD Maturing tiles Phase 1 omitted (no real data
/// yet) are restored below.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(dashboardStatsProvider);
    final activityAsync = ref.watch(activityByTaskGroupProvider);
    final needsAttentionAsync = ref.watch(needsAttentionProvider);
    final recentAsync = ref.watch(recentActivityProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        statsAsync.when(
          data: (stats) => LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth < 460 ? 1 : (constraints.maxWidth < 980 ? 2 : 4);
              return GridView.count(
                crossAxisCount: columns,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: 3.1,
                children: [
                  StatTile(label: 'Total Inward', value: '${stats.totalInward}'),
                  StatTile(label: 'Total Outward', value: '${stats.totalOutward}'),
                  StatTile(label: "Today's Inward", value: '${stats.todayInward}'),
                  StatTile(label: "Today's Outward", value: '${stats.todayOutward}'),
                  StatTile(
                    label: 'EMD Pending Refund',
                    value: formatCurrencyCompact(stats.emdPendingRefundAmount),
                    deltaText: '${stats.emdPendingRefundCount} tenders awaiting refund',
                    deltaTone: stats.emdPendingRefundCount > 0 ? StatDeltaTone.warn : null,
                  ),
                  StatTile(
                    label: 'FD Maturing (30 days)',
                    value: '${stats.fdMaturingSoonCount}',
                    deltaText: '${formatCurrencyCompact(stats.fdMaturingSoonAmount)} total value',
                    deltaTone: stats.fdMaturingSoonCount > 0 ? StatDeltaTone.warn : null,
                  ),
                ],
              );
            },
          ),
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (err, _) => Text('Could not load dashboard: $err'),
        ),
        const SizedBox(height: 18),
        activityAsync.maybeWhen(
          data: (groups) => ActivityByTaskGroupChart(groups: groups),
          orElse: () => const SizedBox.shrink(),
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            final needsAttention = needsAttentionAsync.maybeWhen(data: (v) => v, orElse: () => const <NeedsAttentionItem>[]);
            final recent = recentAsync.maybeWhen(data: (v) => v, orElse: () => const <IoDocument>[]);
            final cards = [
              NeedsAttentionCard(items: needsAttention),
              RecentActivityCard(items: recent),
            ];
            if (constraints.maxWidth < 760) {
              return Column(children: [for (final c in cards) Padding(padding: const EdgeInsets.only(bottom: 14), child: c)]);
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 13, child: cards[0]),
                const SizedBox(width: 14),
                Expanded(flex: 10, child: cards[1]),
              ],
            );
          },
        ),
      ],
    );
  }
}
