import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/currency_formatting.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/stat_tile.dart';
import '../application/tender_providers.dart';
import '../domain/tender_enums.dart';
import 'widgets/tender_data_table.dart';
import 'widgets/tender_toolbar.dart';

/// REQUIREMENTS.md §7 — Tender-EMD tracking.
class TenderEmdScreen extends ConsumerWidget {
  const TenderEmdScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allAsync = ref.watch(tenderListProvider);
    final filteredAsync = ref.watch(filteredTenderListProvider);

    return allAsync.when(
      data: (all) {
        final deposited = all.fold<double>(0, (sum, t) => sum + t.emdAmount);
        final pending = all
            .where((t) => t.refundStatus == RefundStatus.pending)
            .fold<double>(0, (sum, t) => sum + t.emdAmount);
        final refunded = all
            .where((t) => t.refundStatus == RefundStatus.refunded)
            .fold<double>(0, (sum, t) => sum + t.emdAmount);
        final expiringSoon = all.where((t) => t.isEmdValidityExpiringSoon).length;

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
                  childAspectRatio: 2.3,
                  children: [
                    StatTile(label: 'Total EMD Deposited', value: formatCurrencyCompact(deposited)),
                    StatTile(label: 'Total EMD Pending', value: formatCurrencyCompact(pending)),
                    StatTile(label: 'Total EMD Refunded', value: formatCurrencyCompact(refunded)),
                    StatTile(label: 'Expiring in 15 Days', value: '$expiringSoon'),
                  ],
                );
              },
            ),
            const SizedBox(height: 18),
            TenderToolbar(allTenders: all),
            const SizedBox(height: 14),
            AppCard(
              child: filteredAsync.when(
                data: (tenders) => TenderDataTable(tenders: tenders),
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
      error: (err, _) => Padding(padding: const EdgeInsets.all(20), child: Text('Could not load tenders: $err')),
    );
  }
}
