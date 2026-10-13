import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:excel/excel.dart' hide Border;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:alumni_system/core/utils/csv_safe.dart';
import 'package:alumni_system/core/utils/pdf_safe_text.dart';
import 'package:alumni_system/features/admin/reports/application/gts_report_chart.dart';
import 'package:alumni_system/features/admin/reports/application/gts_report_engine.dart';
import 'package:alumni_system/features/admin/reports/application/gts_report_tables.dart';
import 'package:alumni_system/features/admin/reports/data/gts_report_pdf_chart.dart';
import 'package:alumni_system/features/admin/reports/models/custom_report_template.dart';

/// PDF, Excel and CSV of one [GtsReportResult]; every format prints the
/// same [GtsReportTables] layout, so numbers never differ between them.
abstract final class GtsReportExportService {
  static const _reportSheet = 'Report';
  static const _groupSheet = 'By group';
  static const _notesSheet = 'Notes';

  /// Group lines printed in a PDF; Excel and CSV always have every line.
  static const pdfRowLimit = 1000;

  static Future<Uint8List> exportBytes(
    GtsReportResult result,
    CustomReportFormat format,
  ) async => switch (format) {
    CustomReportFormat.pdf => await toPdf(result),
    CustomReportFormat.excel => toExcel(result),
    CustomReportFormat.csv => Uint8List.fromList(
      utf8.encode('\uFEFF${toCsv(result)}'),
    ),
  };

  /// e.g. `gts_presently_employed_20261012.pdf`.
  static String fileName(GtsReportResult result, CustomReportFormat format) {
    final slug = GtsReportTables.title(result)
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    final short = slug.length > 40 ? slug.substring(0, 40) : slug;
    final date = DateFormat('yyyyMMdd').format(result.generatedAt);
    return 'gts_${short.isEmpty ? 'report' : short}_$date.'
        '${format.fileExtension}';
  }

  static String toCsv(GtsReportResult result) {
    final b = StringBuffer();
    void line(List<Object?> cells) => b.write('${_csvRow(cells)}\r\n');

    for (final (label, value) in GtsReportTables.about(result)) {
      line([label, value]);
    }
    line(const []);
    final table = GtsReportTables.main(result);
    line(table.headers);
    for (final row in table.rows) {
      line(row);
    }
    final notes = GtsReportTables.notes(result);
    if (notes.isNotEmpty) {
      line(const []);
      line(const ['Notes']);
      for (final n in notes) {
        line([n]);
      }
    }
    return b.toString();
  }

  static Uint8List toExcel(GtsReportResult result) {
    final excel = Excel.createExcel();
    void sheet(String name, List<List<Object?>> rows) {
      final s = excel[name];
      for (final row in rows) {
        s.appendRow([for (final c in row) c ?? '']);
      }
    }

    final title = GtsReportTables.title(result);
    final crosstab = GtsReportTables.crosstab(result);

    // The excel package cannot rename or delete its default sheet safely.
    final def = excel.getDefaultSheet();
    if (def != null && def != _reportSheet) {
      sheet(def, [
        [title],
        [
          'The report is on the tabs: $_reportSheet, '
              '${crosstab == null ? '' : '$_groupSheet, '}$_notesSheet.',
        ],
      ]);
    }

    final table = GtsReportTables.main(result);
    sheet(_reportSheet, [
      for (final (label, value) in GtsReportTables.about(result))
        [label, value],
      const [''],
      table.headers,
      ...table.rows,
    ]);
    if (crosstab != null) {
      sheet(_groupSheet, [crosstab.headers, ...crosstab.rows]);
    }
    sheet(_notesSheet, [
      const ['Note'],
      for (final n in GtsReportTables.notes(result)) [n],
    ]);
    excel.setDefaultSheet(_reportSheet);

    final bytes = excel.save();
    return Uint8List.fromList(bytes ?? const []);
  }

  static Future<Uint8List> toPdf(GtsReportResult result) async {
    final table = GtsReportTables.main(result);
    final notes = GtsReportTables.notes(result);
    final about = GtsReportTables.about(result);
    final chart = GtsChartData.of(result);
    final pdf = pw.Document();
    final safe = PdfSafeText.sanitize;
    bool isTotal(List<Object?> row) =>
        row.isNotEmpty && row.first == GtsReportTables.allGraduates;
    final groupRows = table.rows.where((r) => !isTotal(r)).toList();
    final rows = groupRows.length > pdfRowLimit
        ? [...groupRows.take(pdfRowLimit), ...table.rows.where(isTotal)]
        : table.rows;
    final numeric = {
      for (var i = 0; i < table.headers.length; i++)
        if (rows.any((r) => r[i] is num)) i,
    };

    pdf.addPage(
      pw.MultiPage(
        maxPages: 200,
        pageFormat: table.headers.length > 7
            ? PdfPageFormat.a4.landscape
            : PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        header: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              safe(GtsReportTables.title(result)),
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blue900,
              ),
            ),
            pw.Text(
              'CHED Graduate Tracer Study report',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
            ),
            pw.SizedBox(height: 4),
            pw.Divider(color: PdfColors.blue900),
            pw.SizedBox(height: 6),
          ],
        ),
        footer: (ctx) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
          ),
        ),
        build: (ctx) => [
          _section('About this report'),
          pw.Table(
            columnWidths: const {
              0: pw.IntrinsicColumnWidth(),
              1: pw.FlexColumnWidth(),
            },
            children: [
              for (final (label, value) in about)
                pw.TableRow(
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(right: 12, bottom: 2),
                      child: pw.Text(
                        safe(label),
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                    pw.Text(
                      safe(value),
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                  ],
                ),
            ],
          ),
          pw.SizedBox(height: 12),
          if (chart != null && !result.isEmpty) ...[
            ..._withHeading('Chart', GtsReportPdfChart.build(chart)),
            pw.SizedBox(height: 12),
          ],
          _section('Results'),
          if (rows.length < table.rows.length)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 6),
              child: pw.Text(
                'This report has ${groupRows.length} group lines. The PDF '
                'shows the first $pdfRowLimit and the All graduates totals; '
                'download Excel or CSV for every line.',
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.red800),
              ),
            ),
          if (table.rows.isEmpty)
            pw.Text(
              'No graduates matched this report.',
              style: const pw.TextStyle(fontSize: 10),
            )
          else
            pw.TableHelper.fromTextArray(
              headers: PdfSafeText.sanitizeRow(table.headers),
              data: [
                for (final row in rows)
                  [for (final c in row) safe(GtsReportTables.display(c))],
              ],
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
                fontSize: 8,
              ),
              cellStyle: const pw.TextStyle(fontSize: 8),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.blue900,
              ),
              cellAlignment: pw.Alignment.centerLeft,
              cellAlignments: {
                for (final i in numeric) i: pw.Alignment.centerRight,
              },
              columnWidths: {
                for (var i = 0; i < table.headers.length; i++)
                  i: numeric.contains(i)
                      ? const pw.FixedColumnWidth(54)
                      : pw.FlexColumnWidth(
                          _textFlex(table.headers[i], rows, i),
                        ),
              },
              headerAlignment: pw.Alignment.centerLeft,
            ),
          if (notes.isNotEmpty) ...[
            pw.SizedBox(height: 12),
            ..._withHeading('Notes', [
              for (final n in notes)
                pw.Bullet(
                  text: safe(n),
                  style: const pw.TextStyle(fontSize: 9),
                ),
            ]),
          ],
        ],
      ),
    );
    return pdf.save();
  }

  /// Share of the free width for a text column: 1 to 3, by its longest entry.
  static double _textFlex(String header, List<List<Object?>> rows, int i) {
    final longest = rows.fold<int>(
      header.length,
      (m, r) => math.max(m, GtsReportTables.display(r[i]).length),
    );
    return (longest / 15).clamp(1, 3).toDouble();
  }

  /// Keeps a heading on the same page as the first item under it. A bare
  /// Column may split across pages; a Container may not.
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

  static String _csvRow(List<Object?> cells) => cells.map(_csvCell).join(',');

  /// Numbers stay numeric; text is quoted when needed and guarded so a
  /// spreadsheet never runs it as a formula.
  static String _csvCell(Object? value) {
    if (value == null) return '';
    if (value is num) return value.toString();
    return CsvSafe.cell(value.toString());
  }
}
