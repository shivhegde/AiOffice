import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text_theme.dart';

enum StatDeltaTone { good, warn, bad }

/// Prototype's `.stat-tile` — a card with a small-caps label, a large mono
/// value, and an optional colored delta line.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.deltaText,
    this.deltaTone,
  });

  final String label;
  final String value;
  final String? deltaText;
  final StatDeltaTone? deltaTone;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final theme = Theme.of(context);
    final deltaColor = switch (deltaTone) {
      StatDeltaTone.good => colors.good,
      StatDeltaTone.warn => colors.warning,
      StatDeltaTone.bad => theme.colorScheme.error,
      null => null,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 11.5,
              letterSpacing: 0.6,
              fontWeight: FontWeight.w600,
              color: colors.textMuted,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: AppFonts.mono(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
            ),
          ),
          if (deltaText != null) ...[
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (deltaColor != null)
                  Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.only(right: 5),
                    decoration: BoxDecoration(color: deltaColor, shape: BoxShape.circle),
                  ),
                Flexible(
                  child: Text(
                    deltaText!,
                    style: TextStyle(fontSize: 12, color: deltaColor ?? colors.textMuted),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
