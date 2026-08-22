import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../shared/widgets/app_card.dart';
import '../../users/application/user_providers.dart';
import '../application/version_gate_providers.dart';
import '../domain/version_gate_config.dart';

/// Admin screen to set the allowed app-version range (§"version number
/// concept"). A build outside `[minVersion, maxVersion]` is hard-blocked
/// before it can even reach the login screen — see `VersionBlockedScreen`.
class AppVersionSettingsScreen extends ConsumerStatefulWidget {
  const AppVersionSettingsScreen({super.key});

  @override
  ConsumerState<AppVersionSettingsScreen> createState() => _AppVersionSettingsScreenState();
}

class _AppVersionSettingsScreenState extends ConsumerState<AppVersionSettingsScreen> {
  final _minController = TextEditingController();
  final _maxController = TextEditingController();
  final _messageController = TextEditingController();
  bool _initialized = false;
  bool _saving = false;

  @override
  void dispose() {
    _minController.dispose();
    _maxController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _syncFrom(VersionGateConfig config) {
    if (_initialized) return;
    _initialized = true;
    _minController.text = config.minVersion;
    _maxController.text = config.maxVersion;
    _messageController.text = config.blockMessage;
  }

  Future<void> _save() async {
    final appUser = ref.read(currentAppUserProvider).value;
    final actorName = appUser?.displayName.isNotEmpty == true ? appUser!.displayName : (appUser?.email ?? 'Unknown');

    setState(() => _saving = true);
    try {
      await ref
          .read(versionGateRepositoryProvider)
          .save(
            config: VersionGateConfig(
              minVersion: _minController.text.trim(),
              maxVersion: _maxController.text.trim(),
              blockMessage: _messageController.text.trim(),
            ),
            updatedByName: actorName,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Version range saved.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not save: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final configAsync = ref.watch(versionGateConfigProvider);
    final currentVersionAsync = ref.watch(currentAppVersionProvider);

    return configAsync.when(
      data: (config) {
        _syncFrom(config);
        return Padding(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: AppCard(
              title: 'Allowed app version range',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Builds outside this range are blocked before sign-in, on every platform. Leave a field '
                    'blank for no bound in that direction.',
                    style: TextStyle(fontSize: 12.5, color: colors.textMuted),
                  ),
                  const SizedBox(height: 6),
                  currentVersionAsync.when(
                    data: (v) => Text('This admin console is running version $v.', style: TextStyle(fontSize: 12, color: colors.textMuted)),
                    loading: () => const SizedBox.shrink(),
                    error: (_, _) => const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _Field(label: 'Minimum version', controller: _minController, hint: 'e.g. 1.0.0'),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _Field(label: 'Maximum version', controller: _maxController, hint: 'e.g. 1.4.0'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  _Field(label: 'Message shown to blocked users', controller: _messageController, maxLines: 3),
                  const SizedBox(height: 16),
                  if (config.updatedByName != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        'Last set by ${config.updatedByName}',
                        style: TextStyle(fontSize: 11.5, color: colors.textMuted),
                      ),
                    ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton(
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Save'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Could not load version settings: $err')),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.controller, this.hint, this.maxLines = 1});

  final String label;
  final TextEditingController controller;
  final String? hint;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11.8)),
          const SizedBox(height: 5),
          TextField(controller: controller, maxLines: maxLines, decoration: InputDecoration(hintText: hint)),
        ],
      ),
    );
  }
}
