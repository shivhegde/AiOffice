import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/constants/roles.dart';
import '../../../../core/utils/date_formatting.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../../../inward_outward/presentation/widgets/followup_history_dialog.dart' show FollowupInputRow;
import '../../../users/application/user_providers.dart';
import '../../application/epf_case_providers.dart';
import '../../domain/epf_case.dart';
import '../../domain/epf_followup.dart';

/// Full followup history for one EPF case — same behaviour as the
/// Inward/Outward Followup History: Power User, Manager and Admin can add,
/// edit, close/reopen and delete followups; General User sees it read-only
/// (matches the `epf_followups` rules in firestore.rules). Notes from the
/// earlier free-text follow-up log are listed underneath, read-only.
class EpfFollowupHistoryDialog extends ConsumerStatefulWidget {
  const EpfFollowupHistoryDialog({super.key, required this.epfCase});

  final EpfCase epfCase;

  static Future<void> show(BuildContext context, EpfCase epfCase) {
    return showDialog(context: context, builder: (_) => EpfFollowupHistoryDialog(epfCase: epfCase));
  }

  @override
  ConsumerState<EpfFollowupHistoryDialog> createState() => _EpfFollowupHistoryDialogState();
}

class _EpfFollowupHistoryDialogState extends ConsumerState<EpfFollowupHistoryDialog> {
  final _remarkController = TextEditingController();
  DateTime _followupDate = DateTime.now();
  FollowupStatus _status = FollowupStatus.active;
  bool _saving = false;

  /// The followup loaded into the input row for editing; null = adding new.
  EpfFollowup? _editing;

  @override
  void dispose() {
    _remarkController.dispose();
    super.dispose();
  }

  ({String uid, String name}) get _actor {
    final appUser = ref.read(currentAppUserProvider).value;
    return (
      uid: appUser?.uid ?? '',
      name: appUser?.displayName.isNotEmpty == true ? appUser!.displayName : (appUser?.email ?? 'Unknown'),
    );
  }

  void _startEdit(EpfFollowup followup) {
    setState(() {
      _editing = followup;
      _followupDate = followup.followupDate;
      _status = followup.status;
      _remarkController.text = followup.remark;
    });
  }

  void _resetInput() {
    setState(() {
      _editing = null;
      _remarkController.clear();
      _followupDate = DateTime.now();
      _status = FollowupStatus.active;
    });
  }

  Future<void> _save() async {
    final remark = _remarkController.text.trim();
    if (remark.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Followup remark is required.')));
      return;
    }
    setState(() => _saving = true);
    try {
      final actor = _actor;
      final repo = ref.read(epfCaseRepositoryProvider);
      final editing = _editing;
      if (editing != null) {
        await repo.updateFollowup(
          followup: editing,
          followupDate: _followupDate,
          remark: remark,
          status: _status,
          actorUid: actor.uid,
          actorName: actor.name,
        );
      } else {
        await repo.addFollowup(
          epfCase: widget.epfCase,
          followupDate: _followupDate,
          remark: remark,
          status: _status,
          actorUid: actor.uid,
          actorName: actor.name,
        );
      }
      if (mounted) _resetInput();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not save followup: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _toggleStatus(EpfFollowup followup) async {
    final actor = _actor;
    await ref
        .read(epfCaseRepositoryProvider)
        .setFollowupStatus(
          followup: followup,
          status: followup.isActive ? FollowupStatus.closed : FollowupStatus.active,
          actorUid: actor.uid,
          actorName: actor.name,
        );
  }

  Future<void> _delete(EpfFollowup followup) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete followup?'),
        content: Text('This removes the followup dated ${formatDisplayDate(followup.followupDate)}.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;
    if (_editing?.id == followup.id) _resetInput();
    final actor = _actor;
    await ref
        .read(epfCaseRepositoryProvider)
        .deleteFollowup(followup: followup, actorUid: actor.uid, actorName: actor.name);
  }

  @override
  Widget build(BuildContext context) {
    final epfCase = widget.epfCase;
    final colors = context.appColors;
    final canManage = ref.watch(effectiveRoleProvider).isAtLeast(AppRole.powerUser);
    final followupsAsync = ref.watch(epfFollowupsByCaseProvider);
    final legacyNotes = epfCase.followUps.reversed.toList();

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640, maxHeight: 640),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Followup History — ${epfCase.clientId}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              Text(
                '${epfCase.name} — ${epfCase.servicesLabel}',
                style: TextStyle(color: colors.textMuted),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 14),
              if (canManage) ...[
                FollowupInputRow(
                  // Re-key on edit target so the status dropdown picks up the loaded value.
                  key: ValueKey(_editing?.id),
                  isEditing: _editing != null,
                  onCancelEdit: _resetInput,
                  date: _followupDate,
                  status: _status,
                  remarkController: _remarkController,
                  saving: _saving,
                  onDateChanged: (d) => setState(() => _followupDate = d),
                  onStatusChanged: (s) => setState(() => _status = s),
                  onAdd: _save,
                ),
                const SizedBox(height: 14),
              ],
              const Divider(height: 1),
              Flexible(
                child: followupsAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, _) => Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('Could not load followups: $e'),
                  ),
                  data: (grouped) {
                    final followups = grouped[epfCase.id] ?? const <EpfFollowup>[];
                    if (followups.isEmpty && legacyNotes.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        child: Center(
                          child: Text('No followups recorded yet', style: TextStyle(color: colors.textMuted)),
                        ),
                      );
                    }
                    return ListView(
                      shrinkWrap: true,
                      children: [
                        for (final (index, f) in followups.indexed) ...[
                          if (index > 0) const Divider(height: 1),
                          ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                            title: Row(
                              children: [
                                Text(formatDisplayDate(f.followupDate)),
                                const SizedBox(width: 10),
                                StatusChip(
                                  label: f.status.label,
                                  variant: f.isActive ? StatusChipVariant.warn : StatusChipVariant.good,
                                ),
                              ],
                            ),
                            subtitle: Text(
                              '${f.remark}\nRecorded by ${f.createdByName}'
                              '${f.createdAt != null ? ' on ${formatDisplayDateTime(f.createdAt!)}' : ''}',
                            ),
                            isThreeLine: true,
                            trailing: canManage
                                ? Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined, size: 17),
                                        tooltip: 'Edit followup',
                                        onPressed: () => _startEdit(f),
                                      ),
                                      TextButton(
                                        onPressed: () => _toggleStatus(f),
                                        child: Text(f.isActive ? 'Close' : 'Reopen'),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, size: 17),
                                        tooltip: 'Delete followup',
                                        onPressed: () => _delete(f),
                                      ),
                                    ],
                                  )
                                : null,
                          ),
                        ],
                        if (legacyNotes.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(4, 16, 4, 6),
                            child: Text(
                              'Earlier follow-up log notes',
                              style: Theme.of(context).textTheme.labelLarge?.copyWith(color: colors.textMuted),
                            ),
                          ),
                          for (final note in legacyNotes)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(4, 0, 4, 6),
                              child: Text(
                                '${formatDisplayDate(note.date)} — ${note.note}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                        ],
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
