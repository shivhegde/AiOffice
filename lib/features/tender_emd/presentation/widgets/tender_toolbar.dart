import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/roles.dart';
import '../../../../shared/widgets/app_toolbar.dart';
import '../../../../shared/widgets/role_gate.dart';
import '../../application/tender_providers.dart';
import '../../domain/tender.dart';
import '../../domain/tender_enums.dart';
import '../tender_form_slideover.dart';
import '../tender_report_panel.dart';

class TenderToolbar extends ConsumerWidget {
  const TenderToolbar({super.key, required this.allTenders});

  final List<Tender> allTenders;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(tenderFilterProvider);
    final departments = {for (final t in allTenders) t.departmentName}.toList()..sort();

    return AppToolbar(
      children: [
        SizedBox(
          width: 200,
          child: TextField(
            decoration: const InputDecoration(isDense: true, hintText: 'Search tender number / name'),
            onChanged: (v) => ref.read(tenderFilterProvider.notifier).state = filter.copyWith(search: v),
          ),
        ),
        SizedBox(
          width: 160,
          child: DropdownButtonFormField<RefundStatus?>(
            initialValue: filter.refundStatus,
            isExpanded: true,
            decoration: const InputDecoration(isDense: true),
            items: [
              const DropdownMenuItem(value: null, child: Text('All Refund Status')),
              for (final s in RefundStatus.values) DropdownMenuItem(value: s, child: Text(s.label)),
            ],
            onChanged: (v) => ref.read(tenderFilterProvider.notifier).state = filter.copyWith(refundStatus: v),
          ),
        ),
        SizedBox(
          width: 170,
          child: DropdownButtonFormField<String?>(
            initialValue: filter.department,
            isExpanded: true,
            decoration: const InputDecoration(isDense: true),
            items: [
              const DropdownMenuItem(value: null, child: Text('All Departments')),
              for (final d in departments) DropdownMenuItem(value: d, child: Text(d, overflow: TextOverflow.ellipsis)),
            ],
            onChanged: (v) => ref.read(tenderFilterProvider.notifier).state = filter.copyWith(department: v),
          ),
        ),
        OutlinedButton.icon(
          onPressed: () => TenderReportPanel.show(context, tenders: allTenders.where(filter.matches).toList()),
          icon: const Icon(Icons.description_outlined, size: 16),
          label: const Text('Generate Report'),
        ),
        RoleGate(
          minRole: AppRole.powerUser,
          child: FilledButton.icon(
            onPressed: () => TenderFormSlideover.show(context),
            icon: const Icon(Icons.add, size: 16),
            label: const Text('New Tender / EMD'),
          ),
        ),
      ],
    );
  }
}
