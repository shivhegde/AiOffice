import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/constants/roles.dart';
import '../../../../core/utils/date_formatting.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../../../users/application/user_providers.dart';
import '../../application/io_providers.dart';
import '../../domain/io_document.dart';
import '../../domain/io_followup.dart';

/// Full followup history for one Inward/Outward document. Power User,
/// Manager and Admin can add followups, close/reopen them, and delete
/// them; General User sees the history read-only (matches the
/// `io_followups` rules in firestore.rules).
class FollowupHistoryDialog extends ConsumerStatefulWidget {
  const FollowupHistoryDialog({super.key, required this.document});

  final IoDocument document;

  static Future<void> show(BuildContext context, IoDocument document) {
    return showDialog(context: context, builder: (_) => FollowupHistoryDialog(document: document));
  }

  @override
  ConsumerState<FollowupHistoryDialog> createState() => _FollowupHistoryDialogState();
}

class _FollowupHistoryDialogState extends ConsumerState<FollowupHistoryDialog> {
  final _remarkController = TextEditingController();
  DateTime _followupDate = DateTime.now();
  FollowupStatus _status = FollowupStatus.active;
  bool _saving = false;

  /// The followup loaded into the input row for editing; null = adding new.
  IoFollowup? _editing;

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

  void _startEdit(IoFollowup followup) {
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
      final repo = ref.read(ioRepositoryProvider);
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
          document: widget.document,
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

  Future<void> _toggleStatus(IoFollowup followup) async {
    final actor = _actor;
    await ref
        .read(ioRepositoryProvider)
        .setFollowupStatus(
          followup: followup,
          status: followup.isActive ? FollowupStatus.closed : FollowupStatus.active,
          actorUid: actor.uid,
          actorName: actor.name,
        );
  }

  Future<void> _delete(IoFollowup followup) async {
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
    await ref.read(ioRepositoryProvider).deleteFollowup(followup: followup, actorUid: actor.uid, actorName: actor.name);
  }

  @override
  Widget build(BuildContext context) {
    final doc = widget.document;
    final colors = context.appColors;
    final canManage = ref.watch(effectiveRoleProvider).isAtLeast(AppRole.powerUser);
    final followupsAsync = ref.watch(ioFollowupsByDocumentProvider(doc.type));

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
                      'Followup History — ${doc.docNumber}',
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
              Text(doc.subject, style: TextStyle(color: colors.textMuted), overflow: TextOverflow.ellipsis),
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
                    final followups = grouped[doc.id] ?? const <IoFollowup>[];
                    if (followups.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        child: Center(
                          child: Text('No followups recorded yet', style: TextStyle(color: colors.textMuted)),
                        ),
                      );
                    }
                    return ListView.separated(
                      shrinkWrap: true,
                      itemCount: followups.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final f = followups[index];
                        return ListTile(
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
                        );
                      },
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

/// Date + status + remark input with Add/Update button, shared by the
/// Inward/Outward and EPF followup history dialogs.
class FollowupInputRow extends StatelessWidget {
  const FollowupInputRow({
    super.key,
    required this.isEditing,
    required this.onCancelEdit,
    required this.date,
    required this.status,
    required this.remarkController,
    required this.saving,
    required this.onDateChanged,
    required this.onStatusChanged,
    required this.onAdd,
  });

  final bool isEditing;
  final VoidCallback onCancelEdit;
  final DateTime date;
  final FollowupStatus status;
  final TextEditingController remarkController;
  final bool saving;
  final ValueChanged<DateTime> onDateChanged;
  final ValueChanged<FollowupStatus> onStatusChanged;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            SizedBox(
              width: 150,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.event, size: 16),
                label: Text(formatDisplayDate(date)),
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: date,
                    firstDate: DateTime(2015),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) onDateChanged(picked);
                },
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 130,
              child: DropdownButtonFormField<FollowupStatus>(
                initialValue: status,
                isExpanded: true,
                decoration: const InputDecoration(isDense: true),
                items: [for (final s in FollowupStatus.values) DropdownMenuItem(value: s, child: Text(s.label))],
                onChanged: (v) => onStatusChanged(v ?? FollowupStatus.active),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: remarkController,
                decoration: const InputDecoration(hintText: 'Followup remark', isDense: true),
                onSubmitted: (_) => saving ? null : onAdd(),
              ),
            ),
            if (isEditing) ...[
              const SizedBox(width: 10),
              TextButton(onPressed: saving ? null : onCancelEdit, child: const Text('Cancel')),
            ],
            const SizedBox(width: 10),
            FilledButton(
              onPressed: saving ? null : onAdd,
              child: saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(isEditing ? 'Update Followup' : 'Add Followup'),
            ),
          ],
        ),
      ],
    );
  }
}
