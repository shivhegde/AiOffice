import 'package:flutter/material.dart';

/// Prototype's `.toolbar` — a wrapping row of filter fields with actions
/// pushed to the end via a spacer.
class AppToolbar extends StatelessWidget {
  const AppToolbar({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Wrap(spacing: 10, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: children);
  }
}
