import 'package:pdf/pdf.dart';

import 'excel_report_service.dart';
import 'pdf_report_service.dart';

enum ReportFormat {
  pdf('PDF'),
  excel('Excel');

  const ReportFormat(this.label);

  final String label;
}

/// Saves a tabular report in the chosen [ReportFormat], so report panels
/// offer one "Download" action with a format picker instead of wiring
/// each service separately.
class ReportExportService {
  ReportExportService._();

  static Future<void> save({
    required ReportFormat format,
    required String title,
    required String subtitle,
    required List<String> headers,
    required List<List<String>> rows,
    PdfPageFormat? pdfPageFormat,
  }) {
    return switch (format) {
      ReportFormat.pdf => PdfReportService.printReport(
        title: title,
        subtitle: subtitle,
        headers: headers,
        rows: rows,
        pageFormat: pdfPageFormat,
      ),
      ReportFormat.excel => ExcelReportService.saveReport(
        title: title,
        subtitle: subtitle,
        headers: headers,
        rows: rows,
      ),
    };
  }
}
