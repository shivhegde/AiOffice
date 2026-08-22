import 'package:flutter/material.dart';

/// Prototype's `.card` + `.card-head` / `.card-body` composition.
class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child, this.title, this.trailing, this.padding});

  final Widget child;
  final String? title;
  final Widget? trailing;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(title!, style: theme.textTheme.titleMedium),
                  ),
                  ?trailing,
                ],
              ),
            ),
          Padding(
            padding: padding ?? const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: child,
          ),
        ],
      ),
    );
  }
}
