import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:excel/excel.dart' hide Border;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:alumni_system/core/utils/csv_safe.dart';
import 'package:alumni_system/core/utils/pdf_safe_text.dart';
import 'package:alumni_system/core/utils/personal_data_notice.dart';
import 'package:alumni_system/features/admin/reports/application/gts_alumni_list.dart';
import 'package:alumni_system/features/admin/reports/application/gts_list_tables.dart';
import 'package:alumni_system/features/admin/reports/data/gts_report_pdf_chart.dart';
import 'package:alumni_system/features/admin/reports/models/custom_report_template.dart';
import 'package:alumni_system/features/admin/reports/models/gts_list_config.dart';

/// Excel, CSV and PDF of one [GtsAlumniListResult]. Every format prints the
/// same [GtsListTables] layout: about lines, the list, then the tally.
abstract final class GtsListExportService {
  static const _listSheet = 'Alumni list';
  static const _columnsSheet = 'Columns';

  /// Rows printed in a PDF; Excel and CSV always have every row.
  static const pdfRowLimit = 1000;

  /// Past this many columns the PDF gets hard to read; Excel fits better.
  static const pdfWideColumns = 10;

  static Future<Uint8List> exportBytes(
    GtsAlumniListResult result,
    CustomReportFormat format,
  ) async => switch (format) {
    CustomReportFormat.pdf => await toPdf(result),
    CustomReportFormat.excel => toExcel(result),
    CustomReportFormat.csv => Uint8List.fromList(
      utf8.encode('\uFEFF${toCsv(result)}'),
    ),
  };

  /// e.g. `alumni_list_employment_status_20261014.xlsx`.
  static String fileName(
    GtsAlumniListResult result,
    CustomReportFormat format,
  ) {
    final slug = GtsListTables.title(result)
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    final short = slug.length > 40 ? slug.substring(0, 40) : slug;
    final date = DateFormat('yyyyMMdd').format(result.generatedAt);
    final name = short.isEmpty || short == 'alumni_list'
        ? 'alumni_list'
        : 'alumni_list_$short';
    return '${name}_$date.${format.fileExtension}';
  }

  /// Tally block rows: heading, column headers, then the lines. Counts are
  /// numbers; rates keep their "3 of 5" text.
  static List<List<Object>> _tallyRows(GtsAlumniListResult result) => [
    for (final (heading, lines) in GtsListTables.tallyBlocks(result)) ...[
      [heading],
      GtsListTables.tallyHeaders,
      for (final l in lines)
        [l.label, int.tryParse(l.count) ?? l.count, l.share],
      const [''],
    ],
  ];

  static List<List<Object>> _sheetRows(GtsAlumniListResult result) {
    final tally = _tallyRows(result);
    return [
      for (final (label, value) in GtsListTables.about(result)) [label, value],
      const [''],
      GtsListTables.headers(result),
      ...GtsListTables.rows(result),
      const [''],
      ...tally.take(tally.length - 1),
      if (result.tally.count(GtsTracerStatus.offRoster) > 0)
        const [GtsListTables.offRosterNote],
    ];
  }

  static String toCsv(GtsAlumniListResult result) {
    final b = StringBuffer();
    for (final row in _sheetRows(result)) {
      b.write('${row.map(_csvCell).join(',')}\r\n');
    }
    return b.toString();
  }

  static Uint8List toExcel(GtsAlumniListResult result) {
    final excel = Excel.createExcel();
    void sheet(String name, List<List<Object>> rows) {
      final s = excel[name];
      for (final row in rows) {
        s.appendRow(row);
      }
    }

    // The excel package cannot rename or delete its default sheet safely.
    final def = excel.getDefaultSheet();
    if (def != null && def != _listSheet) {
      sheet(def, [
        [GtsListTables.title(result)],
        ['The list is on the tabs: $_listSheet, $_columnsSheet.'],
        [personalDataNotice],
      ]);
    }
    sheet(_listSheet, _sheetRows(result));
    sheet(_columnsSheet, [
      const ['Column', 'Question or source'],
      for (final (header, about) in GtsListTables.columnNotes(result))
        [header, about],
    ]);
    excel.setDefaultSheet(_listSheet);
    return Uint8List.fromList(excel.save() ?? const []);
  }

  static Future<Uint8List> toPdf(GtsAlumniListResult result) async {
    final safe = PdfSafeText.sanitize;
    final headers = GtsListTables.headers(result);
    final allRows = GtsListTables.rows(result);
    final rows = allRows.take(pdfRowLimit).toList();
    final chart = GtsListTables.chart(result);
    final wide = headers.length > pdfWideColumns;
    final fontSize = wide ? 6.0 : 7.5;
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        maxPages: 400,
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        header: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              safe(GtsListTables.title(result)),
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blue900,
              ),
            ),
            pw.Text(
              'CHED Graduate Tracer Study alumni list',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
            ),
            pw.SizedBox(height: 4),
            pw.Divider(color: PdfColors.blue900),
            pw.SizedBox(height: 6),
          ],
        ),
        footer: (ctx) => pdfPageFooter(ctx),
        build: (ctx) => [
          _section('About this list'),
          _pairs(GtsListTables.about(result)),
          pw.SizedBox(height: 12),
          if (chart != null) ...[
            ..._withHeading('Tracer status', GtsReportPdfChart.build(chart)),
            pw.SizedBox(height: 12),
          ],
          _section('Alumni'),
          if (allRows.length > rows.length)
            _warning(
              'This list has ${allRows.length} alumni. The PDF shows the '
              'first $pdfRowLimit; download Excel or CSV for every row. The '
              'tally below counts everyone.',
            ),
          if (wide)
            _warning(
              'This list has ${headers.length} columns, so the print is '
              'small. Excel is easier to read for wide lists.',
            ),
          if (headers.isEmpty)
            pw.Text(
              'No columns were picked.',
              style: const pw.TextStyle(fontSize: 10),
            )
          else if (rows.isEmpty)
            pw.Text(
              'No alumni match these settings.',
              style: const pw.TextStyle(fontSize: 10),
            )
          else
            pw.TableHelper.fromTextArray(
              headers: PdfSafeText.sanitizeRow(headers),
              data: PdfSafeText.sanitizeRows(rows),
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
                fontSize: fontSize,
              ),
              cellStyle: pw.TextStyle(fontSize: fontSize),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.blue900,
              ),
              cellAlignment: pw.Alignment.topLeft,
              headerAlignment: pw.Alignment.centerLeft,
              columnWidths: {
                for (var i = 0; i < headers.length; i++)
                  i: pw.FlexColumnWidth(_flex(headers[i], rows, i)),
              },
              cellPadding: const pw.EdgeInsets.all(3),
            ),
          pw.SizedBox(height: 14),
          // The block heading is the table's first header so it repeats on
          // a new page and never sits alone at the foot of one.
          for (final (heading, lines) in GtsListTables.tallyBlocks(result)) ...[
            pw.TableHelper.fromTextArray(
              headers: [safe(heading), ...GtsListTables.tallyHeaders.skip(1)],
              data: [
                for (final l in lines)
                  [safe(l.label), safe(l.count), safe(l.share)],
              ],
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
                fontSize: 9,
              ),
              cellStyle: const pw.TextStyle(fontSize: 8),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.blue900,
              ),
              cellAlignment: pw.Alignment.centerLeft,
              cellAlignments: const {
                1: pw.Alignment.centerRight,
                2: pw.Alignment.centerRight,
              },
              columnWidths: const {
                0: pw.FixedColumnWidth(300),
                1: pw.FixedColumnWidth(60),
                2: pw.FixedColumnWidth(50),
              },
              tableWidth: pw.TableWidth.min,
            ),
            pw.SizedBox(height: 10),
          ],
          if (result.tally.count(GtsTracerStatus.offRoster) > 0)
            pw.Text(
              GtsListTables.offRosterNote,
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
            ),
        ],
      ),
    );
    return pdf.save();
  }

  /// Share of the width for a column: 1 to 4, by its longest entry.
  static double _flex(String header, List<List<String>> rows, int i) {
    final longest = rows.fold<int>(
      math.min(header.length, 24),
      (m, r) => math.max(m, r[i].length),
    );
    return (longest / 14).clamp(1, 4).toDouble();
  }

  static pw.Widget _pairs(List<(String, String)> pairs) => pw.Table(
    columnWidths: const {0: pw.IntrinsicColumnWidth(), 1: pw.FlexColumnWidth()},
    children: [
      for (final (label, value) in pairs)
        pw.TableRow(
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.only(right: 12, bottom: 2),
              child: pw.Text(
                PdfSafeText.sanitize(label),
                style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.Text(
              PdfSafeText.sanitize(value),
              style: const pw.TextStyle(fontSize: 9),
            ),
          ],
        ),
    ],
  );

  static pw.Widget _warning(String text) => pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 6),
    child: pw.Text(
      text,
      style: const pw.TextStyle(fontSize: 9, color: PdfColors.red800),
    ),
  );

  static List<pw.Widget> _withHeading(String title, List<pw.Widget> body) => [
    pw.Container(
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [_section(title), ?body.firstOrNull],
      ),
    ),
    ...body.skip(1),
  ];

  static pw.Widget _section(String text) => pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 4),
    child: pw.Text(
      text,
      style: pw.TextStyle(
        fontSize: 12,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.blue900,
      ),
    ),
  );

  static String _csvCell(Object value) =>
      value is num ? value.toString() : CsvSafe.cell(value.toString());
}
