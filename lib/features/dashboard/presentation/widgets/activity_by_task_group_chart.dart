import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../application/dashboard_providers.dart';

/// REQUIREMENTS.md §5.1 "Activity by Task Group" — one bar per module with
/// real data (Tender-EMD, Work Orders, Fixed Deposit, General
/// Correspondence). Modules still built as placeholders simply don't
/// contribute a bar yet.
class ActivityByTaskGroupChart extends StatelessWidget {
  const ActivityByTaskGroupChart({super.key, required this.groups});

  final List<TaskGroupActivity> groups;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final maxCount = groups.map((g) => g.count).fold<int>(0, (a, b) => a > b ? a : b);

    return AppCard(
      title: 'Activity by Task Group',
      trailing: Text('All time', style: TextStyle(fontSize: 11.5, color: colors.textMuted)),
      child: Column(
        children: [
          for (final group in groups)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(width: 110, child: Text(group.label, style: TextStyle(fontSize: 12, color: colors.chartText2))),
                  Expanded(
                    child: Container(
                      height: 12,
                      decoration: BoxDecoration(color: colors.chartGrid, borderRadius: BorderRadius.circular(4)),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: maxCount == 0 ? 0.0 : (group.count / maxCount).clamp(0, 1),
                        child: Container(
                          decoration: BoxDecoration(color: colors.seriesIn, borderRadius: BorderRadius.circular(4)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 44,
                    child: Text(
                      '${group.count}',
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
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
