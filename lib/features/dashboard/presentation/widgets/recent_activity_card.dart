import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../../../inward_outward/domain/io_document.dart';
import '../../../inward_outward/domain/io_enums.dart';

class RecentActivityCard extends StatelessWidget {
  const RecentActivityCard({super.key, required this.items});

  final List<IoDocument> items;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return AppCard(
      title: 'Recent activity',
      child: items.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text('No activity yet.', style: TextStyle(color: colors.textMuted)),
            )
          : Column(
              children: [
                for (final item in items)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        StatusChip(
                          label: item.type == IoType.inward ? 'In' : 'Out',
                          variant: item.type == IoType.inward ? StatusChipVariant.good : StatusChipVariant.accent,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: RichText(
                            text: TextSpan(
                              style: DefaultTextStyle.of(context).style.copyWith(fontSize: 12.6),
                              children: [
                                TextSpan(text: item.docNumber, style: const TextStyle(fontWeight: FontWeight.w700)),
                                TextSpan(text: ' — ${item.subject}'),
                              ],
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}
