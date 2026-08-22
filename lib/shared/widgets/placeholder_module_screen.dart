import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

/// Stands in for the 6 modules not yet built in this phase (Tender-EMD,
/// Work Orders & FD, Employees, Candidate Bank, Inventory, Vehicle
/// Insurance, EPF Consultancy), so the app's information architecture
/// matches `docs/prototype.html` end-to-end even before each module's
/// business logic exists.
class PlaceholderModuleScreen extends StatelessWidget {
  const PlaceholderModuleScreen({super.key, required this.moduleName, required this.requirementsSection});

  final String moduleName;
  final String requirementsSection;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.construction_outlined, size: 40, color: colors.textMuted),
            const SizedBox(height: 14),
            Text('$moduleName — coming soon', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Specified in REQUIREMENTS.md $requirementsSection. Not yet built in this phase.',
              style: TextStyle(color: colors.textMuted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
