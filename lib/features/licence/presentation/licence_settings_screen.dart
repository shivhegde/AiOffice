import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_colors.dart';
import '../../../shared/widgets/app_card.dart';
import '../../users/application/user_providers.dart';
import '../application/licence_providers.dart';
import '../domain/licence_config.dart';

/// Admin screen to set (or clear) the app-wide licence expiry date. From
/// [licenceWarningWindowDays] days out, every signed-in user sees a banner
/// counting down; the banner disappears again once the date has passed.
/// Leaving the date blank means the licence never expires.
class LicenceSettingsScreen extends ConsumerStatefulWidget {
  const LicenceSettingsScreen({super.key});

  @override
  ConsumerState<LicenceSettingsScreen> createState() => _LicenceSettingsScreenState();
}

class _LicenceSettingsScreenState extends ConsumerState<LicenceSettingsScreen> {
  DateTime? _expiryDate;
  bool _initialized = false;
  bool _saving = false;

  void _syncFrom(LicenceConfig config) {
    if (_initialized) return;
    _initialized = true;
    _expiryDate = config.expiryDate;
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiryDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 20),
    );
    if (picked != null) setState(() => _expiryDate = picked);
  }

  Future<void> _save() async {
    final appUser = ref.read(currentAppUserProvider).value;
    final actorName = appUser?.displayName.isNotEmpty == true ? appUser!.displayName : (appUser?.email ?? 'Unknown');

    setState(() => _saving = true);
    try {
      await ref
          .read(licenceRepositoryProvider)
          .save(config: LicenceConfig(expiryDate: _expiryDate), updatedByName: actorName);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Licence expiry saved.')));
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
    final configAsync = ref.watch(licenceConfigProvider);

    return configAsync.when(
      data: (config) {
        _syncFrom(config);
        return Padding(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: AppCard(
              title: 'Licence expiry',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'From $licenceWarningWindowDays days before this date, every user sees a banner counting down '
                    'the days left. Leave it blank for a licence that never expires.',
                    style: TextStyle(fontSize: 12.5, color: colors.textMuted),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pickDate,
                          icon: const Icon(Icons.event_outlined, size: 18),
                          label: Text(
                            _expiryDate == null ? 'No expiry date set' : DateFormat.yMMMd().format(_expiryDate!),
                          ),
                        ),
                      ),
                      if (_expiryDate != null) ...[
                        const SizedBox(width: 8),
                        IconButton(
                          tooltip: 'Clear expiry date',
                          onPressed: () => setState(() => _expiryDate = null),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ],
                  ),
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
      error: (err, _) => Center(child: Text('Could not load licence settings: $err')),
    );
  }
}
