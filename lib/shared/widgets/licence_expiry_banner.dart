import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_colors.dart';
import '../../features/licence/application/licence_providers.dart';

/// Persistent strip shown across the top of every authenticated screen once
/// the admin-configured licence is within [licenceWarningWindowDays] days of
/// expiry. Hidden when no expiry date is set, when expiry is more than
/// [licenceWarningWindowDays] days away, and — per spec — once the licence
/// has actually expired.
class LicenceExpiryBanner extends ConsumerWidget {
  const LicenceExpiryBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(licenceStatusProvider);
    if (status.kind != LicenceStatusKind.expiringSoon) return const SizedBox.shrink();

    final colors = context.appColors;
    final daysLeft = status.daysLeft!;
    final message = daysLeft == 0
        ? 'Licence expires today.'
        : 'Licence expires in $daysLeft day${daysLeft == 1 ? '' : 's'}.';

    return Container(
      width: double.infinity,
      color: colors.warning,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, size: 17, color: colors.onAccent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$message Contact your administrator to renew it.',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: colors.onAccent),
            ),
          ),
        ],
      ),
    );
  }
}
