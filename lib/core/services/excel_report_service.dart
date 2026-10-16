import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';

/// Builds a tabular report as an Excel (.xlsx) workbook and saves it via
/// the platform save dialog — the Excel counterpart of [PdfReportService].
///
/// Writes the OOXML parts directly (an .xlsx is a zip of a few XML files)
/// rather than using the `excel` package, whose every release pins
/// `xml <7` and so can't resolve alongside `pdf ^3.13` (needs `xml ^7`).
/// Output is one sheet: title row, subtitle row, a bold shaded header row
/// frozen in place, then the data rows as text cells.
class ExcelReportService {
  ExcelReportService._();

  static Future<void> saveReport({
    required String title,
    required String subtitle,
    required List<String> headers,
    required List<List<String>> rows,
  }) async {
    final bytes = buildXlsx(title: title, subtitle: subtitle, headers: headers, rows: rows);
    await FilePicker.saveFile(
      fileName: '${_slugify(title)}.xlsx',
      bytes: bytes,
      mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );
  }

  static const _headerRow = 4;

  // Style indexes into the cellXfs list in [_stylesXml].
  static const _styleHeader = 1;
  static const _styleTitle = 2;
  static const _styleSubtitle = 3;

  /// Pure workbook builder, separate from [saveReport] so it can be tested
  /// without a save dialog.
  static Uint8List buildXlsx({
    required String title,
    required String subtitle,
    required List<String> headers,
    required List<List<String>> rows,
  }) {
    final archive = Archive()
      ..addFile(ArchiveFile.string('[Content_Types].xml', _contentTypesXml))
      ..addFile(ArchiveFile.string('_rels/.rels', _rootRelsXml))
      ..addFile(ArchiveFile.string('xl/workbook.xml', _workbookXml(_sheetName(title))))
      ..addFile(ArchiveFile.string('xl/_rels/workbook.xml.rels', _workbookRelsXml))
      ..addFile(ArchiveFile.string('xl/styles.xml', _stylesXml))
      ..addFile(
        ArchiveFile.string(
          'xl/worksheets/sheet1.xml',
          _sheetXml(title: title, subtitle: subtitle, headers: headers, rows: rows),
        ),
      );
    return ZipEncoder().encodeBytes(archive);
  }

  static String _sheetXml({
    required String title,
    required String subtitle,
    required List<String> headers,
    required List<List<String>> rows,
  }) {
    final colCount = headers.length;
    final widths = List<int>.generate(colCount, (c) {
      var longest = headers[c].length;
      for (final row in rows) {
        if (c < row.length && row[c].length > longest) longest = row[c].length;
      }
      return (longest + 2).clamp(8, 60);
    });

    final buffer = StringBuffer()
      ..write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>')
      ..write('<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">')
      ..write('<sheetViews><sheetView workbookViewId="0">')
      ..write('<pane ySplit="$_headerRow" topLeftCell="A${_headerRow + 1}" activePane="bottomLeft" state="frozen"/>')
      ..write('</sheetView></sheetViews>')
      ..write('<cols>');
    for (var c = 0; c < colCount; c++) {
      buffer.write('<col min="${c + 1}" max="${c + 1}" width="${widths[c]}" customWidth="1"/>');
    }
    buffer
      ..write('</cols><sheetData>')
      ..write(_rowXml(1, [title], style: _styleTitle))
      ..write(_rowXml(2, [subtitle], style: _styleSubtitle))
      ..write(_rowXml(_headerRow, headers, style: _styleHeader));
    for (var r = 0; r < rows.length; r++) {
      buffer.write(_rowXml(_headerRow + 1 + r, rows[r]));
    }
    buffer.write('</sheetData></worksheet>');
    return buffer.toString();
  }

  static String _rowXml(int rowNumber, List<String> values, {int style = 0}) {
    final buffer = StringBuffer('<row r="$rowNumber">');
    for (var c = 0; c < values.length; c++) {
      final styleAttr = style == 0 ? '' : ' s="$style"';
      buffer.write(
        '<c r="${columnLetters(c)}$rowNumber" t="inlineStr"$styleAttr><is><t xml:space="preserve">${_escape(values[c])}</t></is></c>',
      );
    }
    buffer.write('</row>');
    return buffer.toString();
  }

  /// 0 → A, 25 → Z, 26 → AA.
  static String columnLetters(int index) {
    var n = index + 1;
    var letters = '';
    while (n > 0) {
      final rem = (n - 1) % 26;
      letters = String.fromCharCode(65 + rem) + letters;
      n = (n - 1) ~/ 26;
    }
    return letters;
  }

  static String _escape(String input) {
    return input
        // XML 1.0 forbids most control characters; drop them rather than
        // produce a file Excel refuses to open.
        .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]'), '')
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;');
  }

  /// Excel sheet names: max 31 chars, none of `[]:*?/\`.
  static String _sheetName(String title) {
    final cleaned = title.replaceAll(RegExp(r'[\[\]:*?/\\]'), ' ').trim();
    if (cleaned.isEmpty) return 'Report';
    return cleaned.length > 31 ? cleaned.substring(0, 31) : cleaned;
  }

  static String _slugify(String input) {
    final cleaned = input.trim().replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_');
    return cleaned.isEmpty ? 'report' : cleaned;
  }

  static const _contentTypesXml =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
      '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
      '<Default Extension="xml" ContentType="application/xml"/>'
      '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>'
      '<Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>'
      '<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>'
      '</Types>';

  static const _rootRelsXml =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
      '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>'
      '</Relationships>';

  static String _workbookXml(String sheetName) =>
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" '
      'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
      '<sheets><sheet name="${_escape(sheetName)}" sheetId="1" r:id="rId1"/></sheets>'
      '</workbook>';

  static const _workbookRelsXml =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
      '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>'
      '<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>'
      '</Relationships>';

  // cellXfs: 0 default, 1 header (bold, grey fill, thin border),
  // 2 title (bold 14pt), 3 subtitle (grey 10pt).
  static const _stylesXml =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
      '<fonts count="4">'
      '<font><sz val="11"/><name val="Calibri"/></font>'
      '<font><b/><sz val="11"/><name val="Calibri"/></font>'
      '<font><b/><sz val="14"/><name val="Calibri"/></font>'
      '<font><sz val="10"/><color rgb="FF666666"/><name val="Calibri"/></font>'
      '</fonts>'
      '<fills count="3">'
      '<fill><patternFill patternType="none"/></fill>'
      '<fill><patternFill patternType="gray125"/></fill>'
      '<fill><patternFill patternType="solid"><fgColor rgb="FFD9D9D9"/><bgColor indexed="64"/></patternFill></fill>'
      '</fills>'
      '<borders count="2">'
      '<border><left/><right/><top/><bottom/><diagonal/></border>'
      '<border><left style="thin"/><right style="thin"/><top style="thin"/><bottom style="thin"/><diagonal/></border>'
      '</borders>'
      '<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>'
      '<cellXfs count="4">'
      '<xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>'
      '<xf numFmtId="0" fontId="1" fillId="2" borderId="1" xfId="0" applyFont="1" applyFill="1" applyBorder="1"/>'
      '<xf numFmtId="0" fontId="2" fillId="0" borderId="0" xfId="0" applyFont="1"/>'
      '<xf numFmtId="0" fontId="3" fillId="0" borderId="0" xfId="0" applyFont="1"/>'
      '</cellXfs>'
      '<cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles>'
      '</styleSheet>';
}
