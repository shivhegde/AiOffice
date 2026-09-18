import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/pdf_report_service.dart';
import '../../../../core/utils/currency_formatting.dart';
import '../../../../core/utils/date_formatting.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../application/epf_case_providers.dart';
import '../../domain/epf_case.dart';
import '../../domain/epf_enums.dart';

enum _ReportPeriod { daily, monthly, yearly }

/// REQUIREMENTS.md §9.5.7 (Income) + §9.5.9 (Reports) — both sections group
/// cases into cohorts by the day/month/year they were *created* rather than
/// by individual payment/stage-change events: the case-tracking model
/// (`EpfCase.stage` + a single `updatedAt`) has no per-transition history,
/// so "reached Application Submitted on day X" isn't reconstructable for a
/// case that has since moved further along — but "of the clients who came
/// in on day X, how many have since applied/been approved/paid" is, and
/// stays accurate as cases progress. Same reasoning covers the Income
/// section's Fees Billed/Collected/Pending-by-period breakdown (there's no
/// expense/cost field to net against revenue, so this is the closest
/// available reading of the source sheet's "Profit report").
class EpfReportsTab extends ConsumerStatefulWidget {
  const EpfReportsTab({super.key});

  @override
  ConsumerState<EpfReportsTab> createState() => _EpfReportsTabState();
}

class _EpfReportsTabState extends ConsumerState<EpfReportsTab> {
  _ReportPeriod _incomePeriod = _ReportPeriod.daily;

  @override
  Widget build(BuildContext context) {
    final allAsync = ref.watch(epfCaseListProvider);

    return allAsync.when(
      data: (all) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _IncomeSection(
              cases: all,
              period: _incomePeriod,
              onPeriodChanged: (p) => setState(() => _incomePeriod = p),
            ),
            const SizedBox(height: 18),
            _StatisticsSection(cases: all),
          ],
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 60),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (err, _) => Padding(padding: const EdgeInsets.all(20), child: Text('Could not load reports: $err')),
    );
  }
}

String _periodLabel(_ReportPeriod period, DateTime key) {
  return switch (period) {
    _ReportPeriod.daily => formatDisplayDate(key),
    _ReportPeriod.monthly => formatDisplayMonth(key),
    _ReportPeriod.yearly => '${key.year}',
  };
}

DateTime _periodKey(_ReportPeriod period, DateTime date) {
  return switch (period) {
    _ReportPeriod.daily => DateTime(date.year, date.month, date.day),
    _ReportPeriod.monthly => DateTime(date.year, date.month),
    _ReportPeriod.yearly => DateTime(date.year),
  };
}

/// Cases whose current stage has reached (or passed) [stage] in the normal
/// pipeline order — `rejected` is excluded since a rejected case may have
/// been turned away before or after reaching it and there's no way to tell
/// which from the data available (see class doc comment).
bool _hasReached(EpfCase c, CaseStage stage) {
  return c.stage != CaseStage.rejected && c.stage.index >= stage.index;
}

class _PeriodToggle extends StatelessWidget {
  const _PeriodToggle({required this.value, required this.onChanged});

  final _ReportPeriod value;
  final ValueChanged<_ReportPeriod> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final p in _ReportPeriod.values)
          value == p
              ? FilledButton(onPressed: () => onChanged(p), child: Text(_toggleLabel(p)))
              : OutlinedButton(onPressed: () => onChanged(p), child: Text(_toggleLabel(p))),
      ],
    );
  }

  String _toggleLabel(_ReportPeriod p) => switch (p) {
    _ReportPeriod.daily => 'Daily',
    _ReportPeriod.monthly => 'Monthly',
    _ReportPeriod.yearly => 'Yearly',
  };
}

class _IncomeSection extends StatelessWidget {
  const _IncomeSection({required this.cases, required this.period, required this.onPeriodChanged});

  final List<EpfCase> cases;
  final _ReportPeriod period;
  final ValueChanged<_ReportPeriod> onPeriodChanged;

  static const _headers = ['Period', 'Fees Billed', 'Collected', 'Pending'];

  @override
  Widget build(BuildContext context) {
    final buckets = <DateTime, List<EpfCase>>{};
    for (final c in cases) {
      final created = c.createdAt;
      if (created == null) continue;
      buckets.putIfAbsent(_periodKey(period, created), () => []).add(c);
    }
    final keys = buckets.keys.toList()..sort((a, b) => b.compareTo(a));

    final rows = [
      for (final k in keys)
        (
          label: _periodLabel(period, k),
          billed: buckets[k]!.fold<double>(0, (s, c) => s + c.fee),
          collected: buckets[k]!.fold<double>(0, (s, c) => s + c.amountPaid),
        ),
    ];
    final tableRows = [
      for (final r in rows)
        [
          r.label,
          formatCurrencyFull(r.billed),
          formatCurrencyFull(r.collected),
          formatCurrencyFull(r.billed - r.collected),
        ],
    ];
    final totalBilled = rows.fold<double>(0, (s, r) => s + r.billed);
    final totalCollected = rows.fold<double>(0, (s, r) => s + r.collected);
    final title = 'Income & P&L';
    final subtitle =
        '${formatDisplayDateTime(DateTime.now())} • ${rows.length} period${rows.length == 1 ? '' : 's'} • '
        'Billed ${formatCurrencyCompact(totalBilled)} • Collected ${formatCurrencyCompact(totalCollected)} • '
        'Pending ${formatCurrencyCompact(totalBilled - totalCollected)}';

    return AppCard(
      title: title,
      trailing: FilledButton.icon(
        onPressed: tableRows.isEmpty
            ? null
            : () => PdfReportService.printReport(title: title, subtitle: subtitle, headers: _headers, rows: tableRows),
        icon: const Icon(Icons.download, size: 16),
        label: const Text('Download PDF'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PeriodToggle(value: period, onChanged: onPeriodChanged),
          const SizedBox(height: 10),
          Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 10),
          if (tableRows.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: Text('No income data yet.')),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: [for (final h in _headers) DataColumn(label: Text(h))],
                rows: [
                  for (final row in tableRows) DataRow(cells: [for (final cell in row) DataCell(Text(cell))]),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _StatisticsSection extends StatelessWidget {
  const _StatisticsSection({required this.cases});

  final List<EpfCase> cases;

  static const _headers = ['Date', 'New Clients', 'Claims Applied', 'Approved', 'Pending', 'Income'];

  @override
  Widget build(BuildContext context) {
    final buckets = <DateTime, List<EpfCase>>{};
    for (final c in cases) {
      final created = c.createdAt;
      if (created == null) continue;
      buckets.putIfAbsent(_periodKey(_ReportPeriod.daily, created), () => []).add(c);
    }
    final keys = buckets.keys.toList()..sort((a, b) => b.compareTo(a));

    final rows = [
      for (final k in keys)
        (
          label: _periodLabel(_ReportPeriod.daily, k),
          newClients: buckets[k]!.length,
          claimsApplied: buckets[k]!.where((c) => _hasReached(c, CaseStage.applicationSubmitted)).length,
          approved: buckets[k]!.where((c) => _hasReached(c, CaseStage.approved)).length,
          pending: buckets[k]!.where((c) => c.isPending).length,
          income: buckets[k]!.fold<double>(0, (s, c) => s + c.amountPaid),
        ),
    ];
    final tableRows = [
      for (final r in rows)
        [r.label, '${r.newClients}', '${r.claimsApplied}', '${r.approved}', '${r.pending}', formatCurrencyFull(r.income)],
    ];
    const title = 'Daily Report';
    final subtitle = '${formatDisplayDateTime(DateTime.now())} • ${rows.length} day${rows.length == 1 ? '' : 's'}';

    return AppCard(
      title: title,
      trailing: FilledButton.icon(
        onPressed: tableRows.isEmpty
            ? null
            : () => PdfReportService.printReport(title: title, subtitle: subtitle, headers: _headers, rows: tableRows),
        icon: const Icon(Icons.download, size: 16),
        label: const Text('Download PDF'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 10),
          if (tableRows.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: Text('No cases yet.')),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: [for (final h in _headers) DataColumn(label: Text(h))],
                rows: [
                  for (final row in tableRows) DataRow(cells: [for (final cell in row) DataCell(Text(cell))]),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
