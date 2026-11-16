import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_colors.dart';
import '../../../shared/widgets/app_card.dart';
import '../../users/application/user_providers.dart';
import '../application/system_control_providers.dart';
import '../domain/system_control_config.dart';

/// Admin screen for maintenance mode and the scheduled force refresh. See
/// `SystemControlGate` for how each is enforced.
class SystemControlScreen extends ConsumerStatefulWidget {
  const SystemControlScreen({super.key});

  @override
  ConsumerState<SystemControlScreen> createState() => _SystemControlScreenState();
}

class _SystemControlScreenState extends ConsumerState<SystemControlScreen> {
  final _maintenanceMessageController = TextEditingController();
  final _refreshMessageController = TextEditingController();
  bool _maintenanceMode = false;
  DateTime? _refreshAt;
  bool _initialized = false;
  bool _savingMaintenance = false;
  bool _savingRefresh = false;

  static final _format = DateFormat('d MMM yyyy, h:mm a');

  @override
  void dispose() {
    _maintenanceMessageController.dispose();
    _refreshMessageController.dispose();
    super.dispose();
  }

  void _syncFrom(SystemControlConfig config) {
    if (_initialized) return;
    _initialized = true;
    _maintenanceMode = config.maintenanceMode;
    _maintenanceMessageController.text = config.maintenanceMessage;
    _refreshAt = config.forceRefreshAt;
    _refreshMessageController.text = config.forceRefreshMessage;
  }

  String get _actorName {
    final appUser = ref.read(currentAppUserProvider).value;
    return appUser?.displayName.isNotEmpty == true ? appUser!.displayName : (appUser?.email ?? 'Unknown');
  }

  void _toast(String message) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  Future<void> _saveMaintenance() async {
    setState(() => _savingMaintenance = true);
    try {
      // The admin switching it on doesn't need warning about it.
      if (_maintenanceMode) ref.read(maintenanceWarningAcknowledgedProvider.notifier).state = true;
      await ref
          .read(systemControlRepositoryProvider)
          .saveMaintenance(
            enabled: _maintenanceMode,
            message: _maintenanceMessageController.text,
            updatedByName: _actorName,
          );
      if (mounted) _toast(_maintenanceMode ? 'Maintenance mode is ON.' : 'Maintenance mode is OFF.');
    } catch (e) {
      if (mounted) _toast('Could not save: $e');
    } finally {
      if (mounted) setState(() => _savingMaintenance = false);
    }
  }

  Future<void> _pickRefreshAt() async {
    final now = DateTime.now();
    final initial = _refreshAt ?? now;
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(initial));
    if (time == null) return;
    setState(() => _refreshAt = DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }

  Future<void> _saveRefresh() async {
    setState(() => _savingRefresh = true);
    try {
      await ref
          .read(systemControlRepositoryProvider)
          .saveForceRefresh(at: _refreshAt, message: _refreshMessageController.text, updatedByName: _actorName);
      if (mounted) {
        _toast(_refreshAt == null ? 'Force refresh cleared.' : 'Force refresh set for ${_format.format(_refreshAt!)}.');
      }
    } catch (e) {
      if (mounted) _toast('Could not save: $e');
    } finally {
      if (mounted) setState(() => _savingRefresh = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final muted = TextStyle(fontSize: 12.5, color: colors.textMuted);

    return ref
        .watch(systemControlConfigProvider)
        .when(
          data: (config) {
            _syncFrom(config);
            return Padding(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppCard(
                      title: 'Maintenance mode',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'While on, only administrators can sign in. Everyone else who is signed in sees the '
                            'message below, is signed out and the app closes. Administrators get a warning and '
                            'can continue.',
                            style: muted,
                          ),
                          const SizedBox(height: 10),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Database in maintenance mode'),
                            subtitle: Text(
                              config.maintenanceMode
                                  ? 'Currently ON${config.maintenanceSince != null ? ' since ${_format.format(config.maintenanceSince!)}' : ''}'
                                  : 'Currently OFF',
                            ),
                            value: _maintenanceMode,
                            onChanged: (v) => setState(() => _maintenanceMode = v),
                          ),
                          _Field(label: 'Message shown to users', controller: _maintenanceMessageController),
                          Align(
                            alignment: Alignment.centerRight,
                            child: _SaveButton(saving: _savingMaintenance, onPressed: _saveMaintenance),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    AppCard(
                      title: 'Force refresh',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'At this date and time every running copy of the app — administrators included — shows '
                            'the message below and restarts when the user presses Continue. Apps opened after this '
                            'time are not affected.',
                            style: muted,
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _pickRefreshAt,
                                  icon: const Icon(Icons.schedule_outlined, size: 18),
                                  label: Text(_refreshAt == null ? 'Not scheduled' : _format.format(_refreshAt!)),
                                ),
                              ),
                              const SizedBox(width: 8),
                              TextButton(
                                onPressed: () => setState(() => _refreshAt = DateTime.now()),
                                child: const Text('Now'),
                              ),
                              if (_refreshAt != null)
                                IconButton(
                                  tooltip: 'Clear',
                                  onPressed: () => setState(() => _refreshAt = null),
                                  icon: const Icon(Icons.close_rounded),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _Field(label: 'Message shown to users', controller: _refreshMessageController),
                          Align(
                            alignment: Alignment.centerRight,
                            child: _SaveButton(saving: _savingRefresh, onPressed: _saveRefresh),
                          ),
                        ],
                      ),
                    ),
                    if (config.updatedByName != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          'Last changed by ${config.updatedByName}',
                          style: TextStyle(fontSize: 11.5, color: colors.textMuted),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(child: Text('Could not load system control settings: $err')),
        );
  }
}

class _SaveButton extends StatelessWidget {
  const _SaveButton({required this.saving, required this.onPressed});

  final bool saving;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: saving ? null : onPressed,
      child: saving
          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : const Text('Save'),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.controller});

  final String label;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11.8)),
          const SizedBox(height: 5),
          TextField(controller: controller, maxLines: 2),
        ],
      ),
    );
  }
}
