import 'dart:convert';

import 'package:aioffice/core/services/excel_report_service.dart';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('columnLetters converts indexes to Excel column names', () {
    expect(ExcelReportService.columnLetters(0), 'A');
    expect(ExcelReportService.columnLetters(25), 'Z');
    expect(ExcelReportService.columnLetters(26), 'AA');
    expect(ExcelReportService.columnLetters(701), 'ZZ');
    expect(ExcelReportService.columnLetters(702), 'AAA');
  });

  test('buildXlsx produces a workbook with escaped header and data cells', () {
    final bytes = ExcelReportService.buildXlsx(
      title: 'Inward Report',
      subtitle: 'Generated today',
      headers: ['Inward No.', 'Subject'],
      rows: [
        ['INW/2026/001', 'Tender <A> & "B"'],
      ],
    );
    final archive = ZipDecoder().decodeBytes(bytes);
    final names = archive.files.map((f) => f.name).toSet();
    expect(
      names,
      containsAll([
        '[Content_Types].xml',
        '_rels/.rels',
        'xl/workbook.xml',
        'xl/_rels/workbook.xml.rels',
        'xl/styles.xml',
        'xl/worksheets/sheet1.xml',
      ]),
    );

    final sheet = utf8.decode(archive.findFile('xl/worksheets/sheet1.xml')!.content);
    expect(sheet, contains('<c r="A4" t="inlineStr" s="1"><is><t xml:space="preserve">Inward No.</t>'));
    expect(sheet, contains('<c r="A5" t="inlineStr"><is><t xml:space="preserve">INW/2026/001</t>'));
    expect(sheet, contains('Tender &lt;A&gt; &amp; &quot;B&quot;'));
  });
}
