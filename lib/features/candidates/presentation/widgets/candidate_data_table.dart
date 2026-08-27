import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/roles.dart';
import '../../../../shared/widgets/app_data_table.dart';
import '../../../../shared/widgets/role_gate.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../../../users/application/user_providers.dart';
import '../../application/candidate_providers.dart';
import '../../domain/candidate.dart';
import '../../domain/candidate_enums.dart';
import '../candidate_form_slideover.dart';

class CandidateDataTable extends ConsumerWidget {
  const CandidateDataTable({super.key, required this.candidates});

  final List<Candidate> candidates;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppDataTable(
      columns: const [
        DataColumn(label: Text('Candidate ID')),
        DataColumn(label: Text('Name')),
        DataColumn(label: Text('Mobile')),
        DataColumn(label: Text('Age')),
        DataColumn(label: Text('Category')),
        DataColumn(label: Text('District')),
        DataColumn(label: Text('Experience')),
        DataColumn(label: Text('')),
      ],
      rows: [
        for (final c in candidates)
          DataRow(
            cells: [
              DataCell(Text(c.candidateId)),
              DataCell(Text(c.fullName)),
              DataCell(Text(c.mobileNumber)),
              DataCell(Text('${c.age}')),
              DataCell(StatusChip(label: c.category.label, variant: StatusChipVariant.accent)),
              DataCell(Text(c.district.isEmpty ? '—' : c.district)),
              DataCell(
                StatusChip(
                  label: c.experience.label,
                  variant: c.experience == ExperienceLevel.experienced
                      ? StatusChipVariant.good
                      : StatusChipVariant.neutral,
                ),
              ),
              DataCell(_RowActions(candidate: c)),
            ],
          ),
      ],
    );
  }
}

class _RowActions extends ConsumerWidget {
  const _RowActions({required this.candidate});

  final Candidate candidate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RoleGate(
      minRole: AppRole.powerUser,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 17),
            tooltip: 'Edit',
            onPressed: () => CandidateFormSlideover.show(context, existing: candidate),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 17),
            tooltip: 'Delete',
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Delete candidate?'),
                  content: Text('This removes ${candidate.candidateId} — ${candidate.fullName} and its resume.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
                    FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Delete')),
                  ],
                ),
              );
              if (confirmed != true) return;
              final appUser = ref.read(currentAppUserProvider).value;
              await ref
                  .read(candidateRepositoryProvider)
                  .delete(
                    candidate: candidate,
                    actorUid: appUser?.uid ?? '',
                    actorName: appUser?.displayName ?? appUser?.email ?? 'Unknown',
                  );
            },
          ),
        ],
      ),
    );
  }
}
