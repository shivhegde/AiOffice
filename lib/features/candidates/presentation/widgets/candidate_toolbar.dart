import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/roles.dart';
import '../../../../shared/widgets/app_toolbar.dart';
import '../../../../shared/widgets/role_gate.dart';
import '../../application/candidate_providers.dart';
import '../../domain/candidate_enums.dart';
import '../candidate_form_slideover.dart';

class CandidateToolbar extends ConsumerWidget {
  const CandidateToolbar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(candidateFilterProvider);

    return AppToolbar(
      children: [
        SizedBox(
          width: 220,
          child: TextField(
            decoration: const InputDecoration(isDense: true, hintText: 'Search name, district, taluk'),
            onChanged: (v) => ref.read(candidateFilterProvider.notifier).state = filter.copyWith(search: v),
          ),
        ),
        SizedBox(
          width: 180,
          child: DropdownButtonFormField<CandidateCategory?>(
            initialValue: filter.category,
            isExpanded: true,
            decoration: const InputDecoration(isDense: true),
            items: [
              const DropdownMenuItem(value: null, child: Text('All Categories')),
              for (final c in CandidateCategory.values) DropdownMenuItem(value: c, child: Text(c.label)),
            ],
            onChanged: (v) => ref.read(candidateFilterProvider.notifier).state = filter.copyWith(category: v),
          ),
        ),
        RoleGate(
          minRole: AppRole.powerUser,
          child: FilledButton.icon(
            onPressed: () => CandidateFormSlideover.show(context),
            icon: const Icon(Icons.add, size: 16),
            label: const Text('New Candidate'),
          ),
        ),
      ],
    );
  }
}
