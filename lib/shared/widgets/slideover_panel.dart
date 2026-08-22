import 'package:flutter/material.dart';

/// Flutter equivalent of the prototype's `.slideover` — a right-anchored
/// panel (420px on wide layouts, full-width on mobile) with a backdrop,
/// header, scrollable body, and a footer action row. Opened via
/// [SlideoverPanel.show].
class SlideoverPanel extends StatelessWidget {
  const SlideoverPanel({
    super.key,
    required this.title,
    required this.body,
    required this.actions,
    this.width = 420,
  });

  final String title;
  final Widget body;
  final List<Widget> actions;
  final double width;

  static Future<T?> show<T>(
    BuildContext context, {
    required String title,
    required Widget body,
    required List<Widget> actions,
    double width = 420,
  }) {
    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: true,
      barrierLabel: title,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, _, _) => SlideoverPanel(title: title, body: body, actions: actions, width: width),
      transitionBuilder: (context, animation, _, child) {
        final curved = CurvedAnimation(parent: animation, curve: Curves.easeOut);
        return SlideTransition(
          position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero).animate(curved),
          child: child,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final effectiveWidth = screenWidth < 760 ? screenWidth : width;

    return Align(
      alignment: Alignment.centerRight,
      child: Material(
        color: theme.colorScheme.surface,
        elevation: 8,
        child: SizedBox(
          width: effectiveWidth,
          height: double.infinity,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(18, 16, 10, 16),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: theme.colorScheme.outlineVariant)),
                ),
                child: Row(
                  children: [
                    Expanded(child: Text(title, style: theme.textTheme.titleMedium)),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(18, 16, 18, 16), child: body),
              ),
              if (actions.isNotEmpty)
                Container(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: theme.colorScheme.outlineVariant)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [for (final (i, action) in actions.indexed) ...[if (i > 0) const SizedBox(width: 8), action]],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Prototype's `.form-row label` + input composition — a labeled form
/// field wrapper so slideover forms read like the prototype's markup.
class FormRowLabel extends StatelessWidget {
  const FormRowLabel({super.key, required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: Text(label, style: TextStyle(fontSize: 11.8, color: theme.colorScheme.onSurfaceVariant)),
          ),
          child,
        ],
      ),
    );
  }
}
