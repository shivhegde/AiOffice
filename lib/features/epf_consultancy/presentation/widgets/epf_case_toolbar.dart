import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/roles.dart';
import '../../../../shared/widgets/app_toolbar.dart';
import '../../../../shared/widgets/role_gate.dart';
import '../../application/epf_case_providers.dart';
import '../../domain/epf_enums.dart';
import '../epf_case_form_slideover.dart';

class EpfCaseToolbar extends ConsumerWidget {
  const EpfCaseToolbar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(epfCaseFilterProvider);

    return AppToolbar(
      children: [
        SizedBox(
          width: 240,
          child: TextField(
            decoration: const InputDecoration(isDense: true, hintText: 'Search name, mobile, Aadhaar, PAN, UAN'),
            onChanged: (v) => ref.read(epfCaseFilterProvider.notifier).state = filter.copyWith(search: v),
          ),
        ),
        SizedBox(
          width: 180,
          child: DropdownButtonFormField<CaseStage?>(
            initialValue: filter.stage,
            isExpanded: true,
            decoration: const InputDecoration(isDense: true),
            items: [
              const DropdownMenuItem(value: null, child: Text('All Stages')),
              for (final s in CaseStage.values) DropdownMenuItem(value: s, child: Text(s.label)),
            ],
            onChanged: (v) => ref.read(epfCaseFilterProvider.notifier).state = filter.copyWith(stage: v),
          ),
        ),
        RoleGate(
          minRole: AppRole.powerUser,
          child: FilledButton.icon(
            onPressed: () => EpfCaseFormSlideover.show(context),
            icon: const Icon(Icons.add, size: 16),
            label: const Text('New Case'),
          ),
        ),
      ],
    );
  }
}
