import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/constants/roles.dart';
import '../../../../core/services/whatsapp_launcher.dart';
import '../../../../core/utils/date_formatting.dart';
import '../../../../shared/widgets/app_data_table.dart';
import '../../../../shared/widgets/role_gate.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../../../users/application/user_providers.dart';
import '../../application/io_providers.dart';
import '../../domain/io_document.dart';
import '../../domain/io_enums.dart';
import '../../domain/io_followup.dart';
import '../io_form_slideover.dart';
import 'followup_history_dialog.dart';

class InwardDataTable extends ConsumerWidget {
  const InwardDataTable({super.key, required this.documents});

  final List<IoDocument> documents;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final followups = ref.watch(ioFollowupsByDocumentProvider(IoType.inward)).value ?? const {};
    return AppDataTable(
      columns: const [
        DataColumn(label: Text('S.No.')),
        DataColumn(label: Text('Inward No.')),
        DataColumn(label: Text('Date')),
        DataColumn(label: Text('Document Type')),
        DataColumn(label: Text('Received From')),
        DataColumn(label: Text('Subject')),
        DataColumn(label: Text('Department')),
        DataColumn(label: Text('Priority')),
        DataColumn(label: Text('Receiver Name')),
        DataColumn(label: Text('Followup Date')),
        DataColumn(label: Text('Followup Remark')),
        DataColumn(label: Text('Followup Status')),
        DataColumn(label: Text('Seen')),
        DataColumn(label: Text('')),
      ],
      rows: [
        for (final (index, doc) in documents.indexed)
          DataRow(
            cells: [
              DataCell(Text('${index + 1}')),
              DataCell(Text(doc.docNumber)),
              DataCell(Text(formatDisplayDate(doc.date))),
              DataCell(Text(doc.docType.isEmpty ? '—' : doc.docType)),
              DataCell(Text(doc.receivedFrom ?? '—')),
              DataCell(SizedBox(width: 220, child: Text(doc.subject, overflow: TextOverflow.ellipsis))),
              DataCell(Text(doc.department)),
              DataCell(
                StatusChip(
                  label: doc.priority?.label ?? 'Normal',
                  variant: doc.priority == IoPriority.urgent ? StatusChipVariant.critical : StatusChipVariant.neutral,
                ),
              ),
              DataCell(Text(doc.receiverName ?? '—')),
              ..._followupCells(followups[doc.id]),
              DataCell(_SeenCell(document: doc)),
              DataCell(_RowActions(document: doc)),
            ],
          ),
      ],
    );
  }
}

class OutwardDataTable extends ConsumerWidget {
  const OutwardDataTable({super.key, required this.documents});

  final List<IoDocument> documents;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final followups = ref.watch(ioFollowupsByDocumentProvider(IoType.outward)).value ?? const {};
    return AppDataTable(
      columns: const [
        DataColumn(label: Text('S.No.')),
        DataColumn(label: Text('Outward No.')),
        DataColumn(label: Text('Sent To')),
        DataColumn(label: Text('Subject')),
        DataColumn(label: Text('Dispatch Mode')),
        DataColumn(label: Text('Tracking No.')),
        DataColumn(label: Text('Sent By')),
        DataColumn(label: Text('Followup Date')),
        DataColumn(label: Text('Followup Remark')),
        DataColumn(label: Text('Followup Status')),
        DataColumn(label: Text('Seen')),
        DataColumn(label: Text('')),
      ],
      rows: [
        for (final (index, doc) in documents.indexed)
          DataRow(
            cells: [
              DataCell(Text('${index + 1}')),
              DataCell(Text(doc.docNumber)),
              DataCell(Text(doc.sentTo ?? '—')),
              DataCell(SizedBox(width: 220, child: Text(doc.subject, overflow: TextOverflow.ellipsis))),
              DataCell(StatusChip(label: doc.dispatchMode?.label ?? '—', variant: StatusChipVariant.neutral)),
              DataCell(Text(doc.trackingNumber?.isNotEmpty == true ? doc.trackingNumber! : '—')),
              DataCell(Text(doc.sentBy ?? '—')),
              ..._followupCells(followups[doc.id]),
              DataCell(_SeenCell(document: doc)),
              DataCell(_RowActions(document: doc)),
            ],
          ),
      ],
    );
  }
}

/// Followup Date / Remark / Status cells showing [currentFollowup] — the
/// earliest active followup, else the latest closed one.
List<DataCell> _followupCells(List<IoFollowup>? followups) {
  final current = currentFollowup(followups ?? const []);
  if (current == null) {
    return const [DataCell(Text('—')), DataCell(Text('—')), DataCell(Text('—'))];
  }
  return [
    DataCell(Text(formatDisplayDate(current.followupDate))),
    DataCell(SizedBox(width: 200, child: Text(current.remark, overflow: TextOverflow.ellipsis))),
    DataCell(
      StatusChip(
        label: current.status.label,
        variant: current.isActive ? StatusChipVariant.warn : StatusChipVariant.good,
      ),
    ),
  ];
}

class _RowActions extends ConsumerWidget {
  const _RowActions({required this.document});

  final IoDocument document;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (document.hasFile)
          IconButton(
            icon: const Icon(Icons.download_outlined, size: 17),
            tooltip: 'Download attached file',
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              try {
                final bytes = await ref.read(storageUploadServiceProvider).fetchBytes(document.storagePath!);
                if (bytes == null) throw Exception('File not found in storage.');
                await FilePicker.saveFile(
                  fileName: document.fileName ?? '${document.docNumber}.pdf',
                  bytes: bytes,
                  mimeType: document.fileContentType ?? 'application/octet-stream',
                );
              } catch (e) {
                messenger.showSnackBar(SnackBar(content: Text('Could not download file: $e')));
              }
            },
          ),
        IconButton(
          icon: const Icon(Icons.history, size: 17),
          tooltip: 'Followup History',
          onPressed: () => FollowupHistoryDialog.show(context, document),
        ),
        IconButton(
          icon: const Icon(Icons.chat_outlined, size: 17),
          tooltip: 'Share via WhatsApp',
          onPressed: () => WhatsappLauncher.open(
            message:
                'Regarding ${document.type.label} ${document.docNumber} — ${document.subject} (${document.department}).',
          ),
        ),
        RoleGate(
          minRole: AppRole.powerUser,
          child: IconButton(
            icon: const Icon(Icons.edit_outlined, size: 17),
            tooltip: 'Edit',
            onPressed: () => IoFormSlideover.show(context, type: document.type, existing: document),
          ),
        ),
        RoleGate(
          minRole: AppRole.powerUser,
          child: IconButton(
            icon: const Icon(Icons.delete_outline, size: 17),
            tooltip: 'Delete',
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Delete entry?'),
                  content: Text('This removes ${document.docNumber}, its followups, and its attached file, if any.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
                    FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Delete')),
                  ],
                ),
              );
              if (confirmed != true) return;
              final appUser = ref.read(currentAppUserProvider).value;
              await ref
                  .read(ioRepositoryProvider)
                  .delete(
                    document: document,
                    actorUid: appUser?.uid ?? '',
                    actorName: appUser?.displayName ?? appUser?.email ?? 'Unknown',
                  );
            },
          ),
        ),
      ],
    );
  }
}

/// "Seen" acknowledgement (see [AppRole.manager], [IoDocument.seen]).
/// Power User, Manager, and Admin get an interactive checkbox (manager
/// outranks power_user but inherits all of its rights, see
/// firestore.rules `canManageDocuments()`); General User sees a read-only
/// indicator, since only those three roles can write this field
/// server-side.
class _SeenCell extends ConsumerWidget {
  const _SeenCell({required this.document});

  final IoDocument document;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(effectiveRoleProvider);
    final colors = context.appColors;

    if (!role.isAtLeast(AppRole.powerUser)) {
      return Icon(
        document.seen ? Icons.check_circle : Icons.radio_button_unchecked,
        size: 18,
        color: document.seen ? colors.good : colors.textMuted,
      );
    }

    return Checkbox(
      value: document.seen,
      onChanged: (value) async {
        if (value == null) return;
        final appUser = ref.read(currentAppUserProvider).value;
        await ref
            .read(ioRepositoryProvider)
            .setSeen(
              document: document,
              seen: value,
              actorUid: appUser?.uid ?? '',
              actorName: appUser?.displayName ?? appUser?.email ?? 'Unknown',
            );
      },
    );
  }
}
