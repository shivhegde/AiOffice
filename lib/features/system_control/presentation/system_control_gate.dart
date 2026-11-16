import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_theme.dart';
import '../../auth/application/auth_providers.dart';
import '../application/system_control_providers.dart';
import '../domain/system_control_config.dart';

/// Sits above every screen (login included) and enforces the admin's
/// System Control switches:
/// - maintenance mode: non-admins get a sign-out notice, and pressing
///   Continue signs them out and closes the app; admins get a one-time
///   warning they can dismiss.
/// - force refresh: once the scheduled time is reached, everyone
///   (admins too) must restart the app.
class SystemControlGate extends ConsumerWidget {
  const SystemControlGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(systemControlConfigProvider).value ?? SystemControlConfig.unset;
    final access = ref.watch(maintenanceAccessProvider);

    if (access == MaintenanceAccess.blocked) {
      return _NoticeScreen(
        icon: Icons.construction_outlined,
        title: 'Maintenance in progress',
        message: '${config.maintenanceMessage}\n\nYou will now be signed out and the app will close.',
        onContinue: () async {
          try {
            await ref.read(authRepositoryProvider).signOut();
          } finally {
            ref.read(appExitProvider)();
          }
        },
      );
    }

    if (ref.watch(forceRefreshDueProvider)) {
      return _NoticeScreen(
        icon: Icons.refresh_rounded,
        title: 'Refresh required',
        message: config.forceRefreshMessage,
        onContinue: () async => ref.read(appRestartProvider)(context),
      );
    }

    if (access == MaintenanceAccess.adminWarning && !ref.watch(maintenanceWarningAcknowledgedProvider)) {
      return Stack(
        children: [
          child,
          const ModalBarrier(dismissible: false, color: Colors.black54),
          _NoticeCard(
            icon: Icons.warning_amber_rounded,
            iconColor: context.appColors.warning,
            title: 'WARNING: Database in maintenance mode',
            message: '${config.maintenanceMessage}\n\nOnly administrators can use the app right now. You may continue.',
            onContinue: () async => ref.read(maintenanceWarningAcknowledgedProvider.notifier).state = true,
          ),
        ],
      );
    }

    return child;
  }
}

class _NoticeScreen extends StatelessWidget {
  const _NoticeScreen({required this.icon, required this.title, required this.message, required this.onContinue});

  final IconData icon;
  final String title;
  final String message;
  final Future<void> Function() onContinue;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appColors.ink900,
      body: _NoticeCard(icon: icon, title: title, message: message, onContinue: onContinue),
    );
  }
}

class _NoticeCard extends StatefulWidget {
  const _NoticeCard({
    required this.icon,
    required this.title,
    required this.message,
    required this.onContinue,
    this.iconColor,
  });

  final IconData icon;
  final Color? iconColor;
  final String title;
  final String message;
  final Future<void> Function() onContinue;

  @override
  State<_NoticeCard> createState() => _NoticeCardState();
}

class _NoticeCardState extends State<_NoticeCard> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Material(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              elevation: 12,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 30),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(widget.icon, size: 36, color: widget.iconColor ?? theme.colorScheme.primary),
                    const SizedBox(height: 14),
                    Text(widget.title, style: AppFonts.serif(fontSize: 20, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Text(widget.message, style: TextStyle(fontSize: 13.5, color: colors.textMuted)),
                    const SizedBox(height: 20),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton(
                        onPressed: _busy
                            ? null
                            : () async {
                                setState(() => _busy = true);
                                try {
                                  await widget.onContinue();
                                } finally {
                                  if (mounted) setState(() => _busy = false);
                                }
                              },
                        child: const Text('Continue'),
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
