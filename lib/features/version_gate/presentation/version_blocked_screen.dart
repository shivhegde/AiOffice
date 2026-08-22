import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_theme.dart';
import '../application/version_gate_providers.dart';

/// Full-screen hard block shown instead of the entire app (including
/// login) when the running build falls outside the admin-configured
/// min–max version range — see `VersionGateResult`.
class VersionBlockedScreen extends StatelessWidget {
  const VersionBlockedScreen({super.key, required this.result});

  final VersionGateResult result;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final theme = Theme.of(context);
    final config = result.config!;

    final range = switch (result.status) {
      VersionGateStatus.belowMin => 'Minimum supported version: ${config.minVersion}',
      VersionGateStatus.aboveMax => 'Maximum supported version: ${config.maxVersion}',
      _ => '',
    };

    return Scaffold(
      backgroundColor: colors.ink900,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 30),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 50, offset: Offset(0, 20))],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.system_update_outlined, size: 36, color: theme.colorScheme.primary),
                    const SizedBox(height: 14),
                    Text('Update Required', style: AppFonts.serif(fontSize: 20, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Text(config.blockMessage, style: TextStyle(fontSize: 13.5, color: colors.textMuted)),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: theme.scaffoldBackgroundColor, borderRadius: BorderRadius.circular(8)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Your version: ${result.currentVersion}',
                            style: AppFonts.mono(fontSize: 12.5, color: theme.colorScheme.onSurface),
                          ),
                          if (range.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(range, style: AppFonts.mono(fontSize: 12.5, color: colors.textMuted)),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
