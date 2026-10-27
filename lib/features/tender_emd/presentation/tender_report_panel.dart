import 'package:flutter/material.dart';

import '../../../core/services/report_export_service.dart';
import '../../../core/utils/currency_formatting.dart';
import '../../../core/utils/date_formatting.dart';
import '../domain/tender.dart';
import '../domain/tender_enums.dart';

enum _TenderReportType { all, pendingRefund, deposited, refunded }

/// §7.5 — Pending Refund Report, Total EMD Deposited Report, Total EMD
/// Refunded Report, plus "All" over the toolbar's current filter — same
/// on-demand filtered-PDF pattern as `IoReportPanel`.
class TenderReportPanel {
  TenderReportPanel._();

  static Future<void> show(BuildContext context, {required List<Tender> tenders}) {
    return showDialog(
      context: context,
      builder: (context) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960, maxHeight: 600),
          child: _ReportBody(tenders: tenders),
        ),
      ),
    );
  }
}

class _ReportBody extends StatefulWidget {
  const _ReportBody({required this.tenders});

  final List<Tender> tenders;

  @override
  State<_ReportBody> createState() => _ReportBodyState();
}

class _ReportBodyState extends State<_ReportBody> {
  _TenderReportType _type = _TenderReportType.all;
  ReportFormat _format = ReportFormat.pdf;
  bool _saving = false;

  Future<void> _download(String subtitle) async {
    setState(() => _saving = true);
    try {
      await ReportExportService.save(
        format: _format,
        title: _title,
        subtitle: subtitle,
        headers: _headers,
        rows: _tableRows,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not save report: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  List<Tender> get _rows {
    switch (_type) {
      case _TenderReportType.all:
        return widget.tenders;
      case _TenderReportType.pendingRefund:
        return widget.tenders.where((t) => t.refundStatus == RefundStatus.pending).toList();
      case _TenderReportType.deposited:
        return widget.tenders;
      case _TenderReportType.refunded:
        return widget.tenders.where((t) => t.refundStatus == RefundStatus.refunded).toList();
    }
  }

  String get _title {
    switch (_type) {
      case _TenderReportType.all:
        return 'Tender-EMD Report';
      case _TenderReportType.pendingRefund:
        return 'Pending Refund Report';
      case _TenderReportType.deposited:
        return 'Total EMD Deposited Report';
      case _TenderReportType.refunded:
        return 'Total EMD Refunded Report';
    }
  }

  static const _headers = [
    'Tender No.',
    'Tender Description',
    'Department',
    'EMD Amount',
    'Type',
    'Submitted',
    'Refund Status',
  ];

  List<List<String>> get _tableRows => [
    for (final t in _rows)
      [
        t.tenderNumber,
        t.tenderName,
        t.departmentName,
        formatCurrencyFull(t.emdAmount),
        t.emdType.label,
        formatDisplayDate(t.submissionDate),
        t.refundStatus.label,
      ],
  ];

  @override
  Widget build(BuildContext context) {
    final totalEmd = _rows.fold<double>(0, (sum, t) => sum + t.emdAmount);
    final subtitle =
        '${formatDisplayDateTime(DateTime.now())} • ${_rows.length} record${_rows.length == 1 ? '' : 's'} • Total EMD ${formatCurrencyCompact(totalEmd)}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 12, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_title, style: Theme.of(context).textTheme.titleLarge),
                    Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              SizedBox(
                width: 190,
                child: DropdownButtonFormField<_TenderReportType>(
                  initialValue: _type,
                  isExpanded: true,
                  decoration: const InputDecoration(isDense: true),
                  items: const [
                    DropdownMenuItem(value: _TenderReportType.all, child: Text('All (current filter)')),
                    DropdownMenuItem(value: _TenderReportType.pendingRefund, child: Text('Pending Refund')),
                    DropdownMenuItem(value: _TenderReportType.deposited, child: Text('Total Deposited')),
                    DropdownMenuItem(value: _TenderReportType.refunded, child: Text('Total Refunded')),
                  ],
                  onChanged: (v) => setState(() => _type = v ?? _TenderReportType.all),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')),
              const SizedBox(width: 4),
              SegmentedButton<ReportFormat>(
                segments: [for (final f in ReportFormat.values) ButtonSegment(value: f, label: Text(f.label))],
                selected: {_format},
                showSelectedIcon: false,
                onSelectionChanged: (s) => setState(() => _format = s.first),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _saving ? null : () => _download(subtitle),
                icon: const Icon(Icons.download, size: 16),
                label: Text('Download ${_format.label}'),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Flexible(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SingleChildScrollView(
              child: DataTable(
                columns: [for (final h in _headers) DataColumn(label: Text(h))],
                rows: [
                  for (final row in _tableRows) DataRow(cells: [for (final cell in row) DataCell(Text(cell))]),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
