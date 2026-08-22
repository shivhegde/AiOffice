import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/roles.dart';
import '../../../../shared/widgets/app_toolbar.dart';
import '../../../../shared/widgets/role_gate.dart';
import '../../application/io_providers.dart';
import '../../domain/io_document.dart';
import '../../domain/io_enums.dart';
import '../io_form_slideover.dart';
import '../io_report_panel.dart';
import 'friendly_features_bar.dart';

class InwardToolbar extends ConsumerWidget {
  const InwardToolbar({super.key, required this.allDocuments});

  final List<IoDocument> allDocuments;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(inwardFilterProvider);
    final departments = {for (final d in allDocuments) d.department}.toList()..sort();

    return AppToolbar(
      children: [
        SizedBox(
          width: 220,
          child: TextField(
            decoration: const InputDecoration(isDense: true, hintText: 'Search document no. / subject'),
            onChanged: (v) => ref.read(inwardFilterProvider.notifier).state = filter.copyWith(search: v),
          ),
        ),
        _DateRangeFilterButton(
          filter: filter,
          onChanged: (f) => ref.read(inwardFilterProvider.notifier).state = f,
        ),
        SizedBox(
          width: 160,
          child: DropdownButtonFormField<String?>(
            initialValue: filter.department,
            isExpanded: true,
            decoration: const InputDecoration(isDense: true),
            items: [
              const DropdownMenuItem(value: null, child: Text('All Departments')),
              for (final d in departments) DropdownMenuItem(value: d, child: Text(d, overflow: TextOverflow.ellipsis)),
            ],
            onChanged: (v) => ref.read(inwardFilterProvider.notifier).state = filter.copyWith(department: v),
          ),
        ),
        SizedBox(
          width: 150,
          child: DropdownButtonFormField<IoPriority?>(
            initialValue: filter.priority,
            isExpanded: true,
            decoration: const InputDecoration(isDense: true),
            items: [
              const DropdownMenuItem(value: null, child: Text('All Priorities')),
              for (final p in IoPriority.values) DropdownMenuItem(value: p, child: Text(p.label)),
            ],
            onChanged: (v) => ref.read(inwardFilterProvider.notifier).state = filter.copyWith(priority: v),
          ),
        ),
        const FriendlyFeaturesBar(type: IoType.inward),
        OutlinedButton.icon(
          onPressed: () => IoReportPanel.show(context, type: IoType.inward, documents: allDocuments.where(filter.matches).toList()),
          icon: const Icon(Icons.description_outlined, size: 16),
          label: const Text('Generate Report'),
        ),
        RoleGate(
          minRole: AppRole.powerUser,
          child: FilledButton.icon(
            onPressed: () => IoFormSlideover.show(context, type: IoType.inward),
            icon: const Icon(Icons.add, size: 16),
            label: const Text('New Inward Entry'),
          ),
        ),
      ],
    );
  }
}

class OutwardToolbar extends ConsumerWidget {
  const OutwardToolbar({super.key, required this.allDocuments});

  final List<IoDocument> allDocuments;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(outwardFilterProvider);
    final departments = {for (final d in allDocuments) d.department}.toList()..sort();

    return AppToolbar(
      children: [
        SizedBox(
          width: 220,
          child: TextField(
            decoration: const InputDecoration(isDense: true, hintText: 'Search document no. / subject'),
            onChanged: (v) => ref.read(outwardFilterProvider.notifier).state = filter.copyWith(search: v),
          ),
        ),
        _DateRangeFilterButton(
          filter: filter,
          onChanged: (f) => ref.read(outwardFilterProvider.notifier).state = f,
        ),
        SizedBox(
          width: 160,
          child: DropdownButtonFormField<String?>(
            initialValue: filter.department,
            isExpanded: true,
            decoration: const InputDecoration(isDense: true),
            items: [
              const DropdownMenuItem(value: null, child: Text('All Departments')),
              for (final d in departments) DropdownMenuItem(value: d, child: Text(d, overflow: TextOverflow.ellipsis)),
            ],
            onChanged: (v) => ref.read(outwardFilterProvider.notifier).state = filter.copyWith(department: v),
          ),
        ),
        SizedBox(
          width: 170,
          child: DropdownButtonFormField<DispatchMode?>(
            initialValue: filter.dispatchMode,
            isExpanded: true,
            decoration: const InputDecoration(isDense: true),
            items: [
              const DropdownMenuItem(value: null, child: Text('All Dispatch Modes')),
              for (final m in DispatchMode.values) DropdownMenuItem(value: m, child: Text(m.label)),
            ],
            onChanged: (v) => ref.read(outwardFilterProvider.notifier).state = filter.copyWith(dispatchMode: v),
          ),
        ),
        const FriendlyFeaturesBar(type: IoType.outward),
        OutlinedButton.icon(
          onPressed: () => IoReportPanel.show(context, type: IoType.outward, documents: allDocuments.where(filter.matches).toList()),
          icon: const Icon(Icons.description_outlined, size: 16),
          label: const Text('Generate Report'),
        ),
        RoleGate(
          minRole: AppRole.powerUser,
          child: FilledButton.icon(
            onPressed: () => IoFormSlideover.show(context, type: IoType.outward),
            icon: const Icon(Icons.add, size: 16),
            label: const Text('New Outward Entry'),
          ),
        ),
      ],
    );
  }
}

/// Date-range filter (an enhancement over the prototype's single-date
/// filter): shows "Any date" until a range is picked, then the range as
/// "dd/MM–dd/MM"; a clear (×) button appears once a range is set.
class _DateRangeFilterButton extends StatelessWidget {
  const _DateRangeFilterButton({required this.filter, required this.onChanged});

  final IoFilterState filter;
  final ValueChanged<IoFilterState> onChanged;

  String _fmt(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final label = filter.hasDateRange
        ? (filter.dateFrom != null && filter.dateTo != null
              ? '${_fmt(filter.dateFrom!)} – ${_fmt(filter.dateTo!)}'
              : filter.dateFrom != null
              ? 'From ${_fmt(filter.dateFrom!)}'
              : 'Until ${_fmt(filter.dateTo!)}')
        : 'Any date';

    return OutlinedButton.icon(
      onPressed: () async {
        final now = DateTime.now();
        final picked = await showDateRangePicker(
          context: context,
          firstDate: DateTime(2015),
          lastDate: DateTime(now.year + 2),
          initialDateRange: filter.dateFrom != null && filter.dateTo != null
              ? DateTimeRange(start: filter.dateFrom!, end: filter.dateTo!)
              : null,
        );
        if (picked != null) {
          onChanged(filter.copyWith(dateFrom: picked.start, dateTo: picked.end));
        }
      },
      icon: const Icon(Icons.date_range_outlined, size: 16),
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          if (filter.hasDateRange) ...[
            const SizedBox(width: 6),
            GestureDetector(
              onTap: () => onChanged(filter.copyWith(dateFrom: null, dateTo: null)),
              child: const Icon(Icons.close, size: 14),
            ),
          ],
        ],
      ),
    );
  }
}
