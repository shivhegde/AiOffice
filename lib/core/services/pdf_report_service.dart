import 'package:file_picker/file_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Builds a tabular report PDF and saves it straight to disk via the
/// platform save dialog. Originally handed off to `Printing.layoutPdf`
/// (the OS print dialog, with "Save as PDF" as one printer option among
/// others), but that requires a reachable print service — on at least one
/// macOS setup it failed outright with "This application doesn't support
/// printing". Saving the bytes directly sidesteps printing entirely and
/// matches how every other "download" action in this app already works
/// (see `document_actions.dart`).
class PdfReportService {
  PdfReportService._();

  static Future<void> printReport({
    required String title,
    required String subtitle,
    required List<String> headers,
    required List<List<String>> rows,
  }) async {
    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        build: (context) => [
          pw.Text(title, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Text(subtitle, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
          pw.SizedBox(height: 14),
          pw.TableHelper.fromTextArray(
            headers: headers,
            data: rows,
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
            cellStyle: const pw.TextStyle(fontSize: 8.5),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            cellAlignment: pw.Alignment.centerLeft,
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
          ),
        ],
      ),
    );

    final bytes = await doc.save();
    await FilePicker.saveFile(fileName: '${_slugify(title)}.pdf', bytes: bytes, mimeType: 'application/pdf');
  }

  static String _slugify(String input) {
    final cleaned = input.trim().replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_');
    return cleaned.isEmpty ? 'report' : cleaned;
  }
}
