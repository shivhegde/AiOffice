import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/utils/date_formatting.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../../application/dashboard_providers.dart';

/// REQUIREMENTS.md §5.1 — visible to all roles (surfaces document
/// references, not actor-level detail; the Audit Log stays Admin-only).
/// Merges urgent Inward items with Tender-EMD/Work-Order/FD alerts (see
/// `dashboard_providers.dart`'s `needsAttentionProvider`).
class NeedsAttentionCard extends StatelessWidget {
  const NeedsAttentionCard({super.key, required this.items});

  final List<NeedsAttentionItem> items;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return AppCard(
      title: 'Needs attention',
      trailing: Text('${items.length} item${items.length == 1 ? '' : 's'}', style: TextStyle(fontSize: 11.5, color: colors.textMuted)),
      child: items.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text('Nothing urgent right now.', style: TextStyle(color: colors.textMuted)),
            )
          : Column(
              children: [
                for (final item in items)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        StatusChip(
                          label: item.badgeLabel,
                          variant: item.severity == AttentionSeverity.critical
                              ? StatusChipVariant.critical
                              : StatusChipVariant.warn,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: RichText(
                            text: TextSpan(
                              style: DefaultTextStyle.of(context).style.copyWith(fontSize: 12.6),
                              children: [
                                TextSpan(text: item.reference, style: const TextStyle(fontWeight: FontWeight.w700)),
                                TextSpan(text: ' — ${item.description}'),
                              ],
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(formatDisplayDate(item.date), style: TextStyle(fontSize: 11.5, color: colors.textMuted)),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}
