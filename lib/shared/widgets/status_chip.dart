import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

enum StatusChipVariant { good, warn, critical, neutral, accent }

/// Prototype's `.chip` component — a small pill with an optional dot,
/// color-coded by [variant].
class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.label, this.variant = StatusChipVariant.neutral, this.showDot = true});

  final String label;
  final StatusChipVariant variant;
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final theme = Theme.of(context);

    final (Color fg, Color bg, Color? border) = switch (variant) {
      StatusChipVariant.good => (colors.good, colors.good.withValues(alpha: 0.12), null),
      StatusChipVariant.warn => (colors.warning, colors.warning.withValues(alpha: 0.16), null),
      StatusChipVariant.critical => (
        theme.colorScheme.error,
        theme.colorScheme.error.withValues(alpha: 0.12),
        null,
      ),
      StatusChipVariant.neutral => (
        colors.textMuted,
        theme.scaffoldBackgroundColor,
        theme.colorScheme.outlineVariant,
      ),
      StatusChipVariant.accent => (colors.accentDark, theme.colorScheme.primary.withValues(alpha: 0.16), null),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: border != null ? Border.all(color: border) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showDot) ...[
            Container(width: 6, height: 6, decoration: BoxDecoration(color: fg, shape: BoxShape.circle)),
            const SizedBox(width: 5),
          ],
          Text(label, style: TextStyle(fontSize: 11.3, fontWeight: FontWeight.w600, color: fg)),
        ],
      ),
    );
  }
}
