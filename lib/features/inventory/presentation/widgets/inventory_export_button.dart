import 'package:flutter/material.dart';

import '../../../../core/services/report_export_service.dart';
import '../../../../core/utils/date_formatting.dart';

/// "Export" menu offering PDF / Excel for one inventory table.
class InventoryExportButton extends StatelessWidget {
  const InventoryExportButton({
    super.key,
    required this.title,
    required this.headers,
    required this.rows,
    this.label = 'Export',
  });

  final String title;
  final List<String> headers;

  /// Built lazily so the export always reflects the latest data.
  final List<List<String>> Function() rows;
  final String label;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<ReportFormat>(
      tooltip: 'Export table',
      onSelected: (format) async {
        final messenger = ScaffoldMessenger.of(context);
        final data = rows();
        try {
          await ReportExportService.save(
            format: format,
            title: title,
            subtitle:
                'Generated on ${formatDisplayDateTime(DateTime.now())} • '
                '${data.length} row${data.length == 1 ? '' : 's'}',
            headers: headers,
            rows: data,
          );
        } catch (e) {
          messenger.showSnackBar(SnackBar(content: Text('Could not export: $e')));
        }
      },
      itemBuilder: (_) => [
        for (final f in ReportFormat.values)
          PopupMenuItem(
            value: f,
            child: Row(
              children: [
                Icon(f == ReportFormat.pdf ? Icons.picture_as_pdf_outlined : Icons.table_chart_outlined, size: 18),
                const SizedBox(width: 10),
                Text('Export as ${f.label}'),
              ],
            ),
          ),
      ],
      child: IgnorePointer(
        child: OutlinedButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.file_download_outlined, size: 16),
          label: Text(label),
        ),
      ),
    );
  }
}
