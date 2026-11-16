import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../application/system_control_providers.dart';

/// Amber strip across every authenticated screen while maintenance mode
/// is on — only admins get this far then, so it reminds them it's still on.
class MaintenanceBanner extends ConsumerWidget {
  const MaintenanceBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(systemControlConfigProvider).value?.maintenanceMode != true) return const SizedBox.shrink();
    final color = context.appColors.warning;
    return Container(
      width: double.infinity,
      color: color.withValues(alpha: 0.18),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(Icons.construction_outlined, size: 17, color: color),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'DATABASE IN MAINTENANCE MODE — only administrators can sign in. Turn it off under Admin › System Control.',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

/// Notice on the login screen while maintenance mode is on.
class MaintenanceLoginNotice extends ConsumerWidget {
  const MaintenanceLoginNotice({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(systemControlConfigProvider).value;
    if (config == null || !config.maintenanceMode) return const SizedBox.shrink();
    final color = context.appColors.warning;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        border: Border.all(color: color.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.construction_outlined, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${config.maintenanceMessage} Only administrators can sign in right now.',
              style: const TextStyle(fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }
}
