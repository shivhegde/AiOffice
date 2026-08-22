import 'package:flutter/material.dart';

import '../../../core/services/pdf_report_service.dart';
import '../../../core/utils/date_formatting.dart';
import '../domain/io_document.dart';
import '../domain/io_enums.dart';

/// On-demand filtered report + PDF download, matching the prototype's
/// `generateIoReport`/print-panel pattern (REQUIREMENTS.md §6.5).
class IoReportPanel {
  IoReportPanel._();

  static Future<void> show(
    BuildContext context, {
    required IoType type,
    required List<IoDocument> documents,
  }) {
    return showDialog(
      context: context,
      builder: (context) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720, maxHeight: 600),
          child: _ReportBody(type: type, documents: documents),
        ),
      ),
    );
  }
}

class _ReportBody extends StatelessWidget {
  const _ReportBody({required this.type, required this.documents});

  final IoType type;
  final List<IoDocument> documents;

  List<String> get _headers => type == IoType.inward
      ? const ['Inward No.', 'Date', 'Received From', 'Subject', 'Department', 'Priority', 'Receiver']
      : const ['Outward No.', 'Sent To', 'Subject', 'Dispatch Mode', 'Tracking No.', 'Sent By'];

  List<List<String>> get _rows => [
    for (final d in documents)
      if (type == IoType.inward)
        [
          d.docNumber,
          formatDisplayDate(d.date),
          d.receivedFrom ?? '—',
          d.subject,
          d.department,
          d.priority?.label ?? 'Normal',
          d.receiverName ?? '—',
        ]
      else
        [
          d.docNumber,
          d.sentTo ?? '—',
          d.subject,
          d.dispatchMode?.label ?? '—',
          d.trackingNumber?.isNotEmpty == true ? d.trackingNumber! : '—',
          d.sentBy ?? '—',
        ],
  ];

  @override
  Widget build(BuildContext context) {
    final title = '${type.label} Report';
    final subtitle = 'Generated on ${formatDisplayDateTime(DateTime.now())} • ${documents.length} record${documents.length == 1 ? '' : 's'}';

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
                    Text(title, style: Theme.of(context).textTheme.titleLarge),
                    Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')),
              const SizedBox(width: 4),
              FilledButton.icon(
                onPressed: () => PdfReportService.printReport(title: title, subtitle: subtitle, headers: _headers, rows: _rows),
                icon: const Icon(Icons.download, size: 16),
                label: const Text('Download PDF'),
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
                  for (final row in _rows) DataRow(cells: [for (final cell in row) DataCell(Text(cell))]),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
