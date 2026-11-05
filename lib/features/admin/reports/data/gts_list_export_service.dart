import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:excel/excel.dart' hide Border;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:alumni_system/core/pdf/aess_pdf_components.dart';
import 'package:alumni_system/core/utils/csv_safe.dart';
import 'package:alumni_system/core/utils/pdf_safe_text.dart';
import 'package:alumni_system/core/utils/personal_data_notice.dart';
import 'package:alumni_system/features/admin/reports/application/gts_alumni_list.dart';
import 'package:alumni_system/features/admin/reports/application/gts_list_narrative.dart';
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
    CustomReportFormat format, {
    String? explanation,
  }) async => switch (format) {
    CustomReportFormat.pdf => await toPdf(result, explanation: explanation),
    CustomReportFormat.excel => toExcel(result, explanation: explanation),
    CustomReportFormat.csv => Uint8List.fromList(
      utf8.encode('\uFEFF${toCsv(result, explanation: explanation)}'),
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
  /// numbers; rates keep their "3 of 5" text. Subtotals use one column per
  /// group so the sheet matches the on-screen tally.
  static List<List<Object>> _tallyRows(GtsAlumniListResult result) {
    final groups = result.groups;
    final by = GtsListTables.groupHeading(result.config.subtotalBy);
    return [
      for (final section in GtsListTables.sections(result)) ...[
        if (groups.isEmpty) ...[
          [section.title],
          GtsListTables.tallyHeaders,
          for (final line in section.lines) _tallyLine(line),
        ] else ...[
          ['${section.title} by ${by.toLowerCase()}'],
          [
            'Category',
            for (final group in groups) group.label,
            GtsListTables.overallHeading,
          ],
          for (var i = 0; i < section.lines.length; i++)
            [
              section.lines[i].label,
              for (final lines in section.groupLines) _both(lines[i]),
              _both(section.lines[i]),
            ],
        ],
        if (section.note != null) [section.note!],
        const [''],
      ],
    ];
  }

  static List<Object> _tallyLine(GtsTallyLine line) => [
    line.label,
    int.tryParse(line.count) ?? line.count,
    line.share,
  ];

  static String _both(GtsTallyLine line) =>
      line.share.isEmpty ? line.count : '${line.count} (${line.share})';

  static List<List<Object>> _chartRows(GtsAlumniListResult result) => [
    for (final chart in GtsListTables.charts(result)) ...[
      [chart.title],
      const ['Category', 'Alumni'],
      for (var i = 0; i < chart.labels.length; i++)
        [chart.labels[i], chart.series.first.values[i]?.round() ?? 0],
      if (chart.omittedNote case final note?) [note],
      const [''],
    ],
  ];

  static List<List<Object>> _sheetRows(
    GtsAlumniListResult result, {
    String? explanation,
  }) {
    final config = result.config;
    final rows = <List<Object>>[
      for (final (label, value) in GtsListTables.about(result)) [label, value],
      const [''],
      ['Explanation'],
      [explanation ?? GtsListNarrative.compose(result)],
      const [''],
    ];
    if (config.includeCharts) rows.addAll(_chartRows(result));
    if (config.includeTable) {
      final headers = GtsListTables.headers(result);
      if (headers.isEmpty) {
        rows.add(const ['No columns were picked.']);
      } else if (result.rows.isEmpty) {
        rows.add(const ['No alumni match these settings.']);
      } else {
        rows.add(headers);
        rows.addAll(GtsListTables.rows(result));
      }
      rows.add(const ['']);
    }
    if (config.includeTally) {
      final tally = _tallyRows(result);
      if (tally.isNotEmpty) {
        rows.addAll(tally.take(tally.length - 1));
      }
    }
    if (!config.includeTable && !config.includeTally && !config.includeCharts) {
      rows.add(const [
        'No table, tally, or chart was included in this export.',
      ]);
    }
    if (result.tally.count(GtsTracerStatus.offRoster) > 0 &&
        (config.includeTable || config.includeTally)) {
      rows.add(const [GtsListTables.offRosterNote]);
    }
    return rows;
  }

  static String toCsv(GtsAlumniListResult result, {String? explanation}) {
    final b = StringBuffer();
    for (final row in _sheetRows(result, explanation: explanation)) {
      b.write('${row.map(_csvCell).join(',')}\r\n');
    }
    return b.toString();
  }

  static Uint8List toExcel(GtsAlumniListResult result, {String? explanation}) {
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
    sheet(_listSheet, _sheetRows(result, explanation: explanation));
    sheet(_columnsSheet, [
      const ['Column', 'Question or source'],
      for (final (header, about) in GtsListTables.columnNotes(result))
        [header, about],
    ]);
    excel.setDefaultSheet(_listSheet);
    return Uint8List.fromList(excel.save() ?? const []);
  }

  static Future<Uint8List> toPdf(
    GtsAlumniListResult result, {
    String? explanation,
  }  ) async {
    await AessPdfHeader.ensureLoaded();
    final safe = PdfSafeText.sanitize;
    final config = result.config;
    final headers = GtsListTables.headers(result);
    final allRows = GtsListTables.rows(result);
    final rows = allRows.take(pdfRowLimit).toList();
    final charts = GtsListTables.charts(result);
    final wide = headers.length > pdfWideColumns;
    final fontSize = wide ? 6.0 : 7.5;
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        maxPages: 400,
        pageFormat: PdfPageFormat.a4.landscape,
        margin: AessPdfTheme.pageMarginLandscape,
        header: (ctx) => AessPdfHeader.build(
          title: safe(GtsListTables.title(result)),
          subtitle: 'CHED Graduate Tracer Study Alumni Directory',
          classification: 'CONFIDENTIAL',
          isLandscape: true,
        ),
        footer: (ctx) => AessPdfFooter.build(
          ctx,
          containsPersonalData: true,
        ),
        build: (ctx) => [
          _section('About this list'),
          _pairs(GtsListTables.about(result)),
          pw.SizedBox(height: 12),
          _section('Explanation'),
          pw.Text(
            safe(explanation ?? GtsListNarrative.compose(result)),
            style: const pw.TextStyle(fontSize: 9, lineSpacing: 2),
          ),
          pw.SizedBox(height: 12),
          for (final chart in charts) ...[
            ..._withHeading(chart.title, GtsReportPdfChart.build(chart)),
            if (chart.omittedNote case final note?)
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 4),
                child: pw.Text(
                  safe(note),
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                ),
              ),
            pw.SizedBox(height: 12),
          ],
          if (config.includeTable) ...[
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
                headerCount: 1,
                headerStyle:
                    AessPdfTheme.tableHeader.copyWith(fontSize: fontSize),
                cellStyle: AessPdfTheme.tableCell.copyWith(fontSize: fontSize),
                headerDecoration: const pw.BoxDecoration(
                  color: AessPdfTheme.primaryNavy,
                ),
                oddRowDecoration: const pw.BoxDecoration(
                  color: AessPdfTheme.zebraBg,
                ),
                border: const pw.TableBorder(
                  horizontalInside: pw.BorderSide(
                    color: AessPdfTheme.borderColor,
                    width: 0.5,
                  ),
                  bottom: pw.BorderSide(
                    color: AessPdfTheme.borderDark,
                    width: 0.8,
                  ),
                ),
                cellAlignment: pw.Alignment.topLeft,
                headerAlignment: pw.Alignment.centerLeft,
                columnWidths: {
                  for (var i = 0; i < headers.length; i++)
                    i: pw.FlexColumnWidth(_flex(headers[i], rows, i)),
                },
                cellPadding: AessPdfTheme.cellPaddingCompact,
              ),
            pw.SizedBox(height: 14),
          ],
          if (config.includeTally)
            for (final section in GtsListTables.sections(result)) ...[
              _tallyTable(result, section),
              if (section.note != null)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 3, bottom: 8),
                  child: pw.Text(
                    safe(section.note!),
                    style: const pw.TextStyle(
                      fontSize: 8,
                      color: PdfColors.grey700,
                    ),
                  ),
                )
              else
                pw.SizedBox(height: 10),
            ],
          if (!config.includeTable &&
              !config.includeTally &&
              !config.includeCharts)
            pw.Text(
              'No table, tally, or chart was included in this export.',
              style: const pw.TextStyle(fontSize: 10),
            ),
          if (result.tally.count(GtsTracerStatus.offRoster) > 0 &&
              (config.includeTable || config.includeTally))
            pw.Text(
              GtsListTables.offRosterNote,
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
            ),
        ],
      ),
    );
    return pdf.save();
  }

  static pw.Widget _tallyTable(
    GtsAlumniListResult result,
    GtsTallySection section,
  ) {
    final safe = PdfSafeText.sanitize;
    final groups = result.groups;
    final headers = groups.isEmpty
        ? [section.title, ...GtsListTables.tallyHeaders.skip(1)]
        : [
            '${section.title} by ${GtsListTables.groupHeading(result.config.subtotalBy).toLowerCase()}',
            for (final group in groups) group.label,
            GtsListTables.overallHeading,
          ];
    final data = [
      for (var i = 0; i < section.lines.length; i++)
        [
          safe(section.lines[i].label),
          if (groups.isEmpty) ...[
            safe(section.lines[i].count),
            safe(section.lines[i].share),
          ] else ...[
            for (final lines in section.groupLines) safe(_both(lines[i])),
            safe(_both(section.lines[i])),
          ],
        ],
    ];
    return pw.TableHelper.fromTextArray(
      headers: [for (final header in headers) safe(header)],
      data: data,
      headerCount: 1,
      headerStyle: AessPdfTheme.tableHeader.copyWith(fontSize: 8),
      cellStyle: AessPdfTheme.tableCell.copyWith(fontSize: 8),
      headerDecoration: const pw.BoxDecoration(color: AessPdfTheme.subHeaderBg),
      oddRowDecoration: const pw.BoxDecoration(color: AessPdfTheme.zebraBg),
      border: const pw.TableBorder(
        horizontalInside: pw.BorderSide(
          color: AessPdfTheme.borderColor,
          width: 0.5,
        ),
        bottom: pw.BorderSide(color: AessPdfTheme.borderDark, width: 0.8),
      ),
      cellPadding: AessPdfTheme.cellPaddingCompact,
      cellAlignment: pw.Alignment.centerLeft,
      columnWidths: {
        0: const pw.FlexColumnWidth(2.8),
        for (var i = 1; i < headers.length; i++)
          i: const pw.FlexColumnWidth(1.2),
      },
    );
  }

  /// Share of the width for a column: 1.2 to 4.5, by header and cell length.
  static double _flex(String header, List<List<String>> rows, int i) {
    final headerWeight = math.max(header.length, 12);
    final longest = rows.fold<int>(
      headerWeight,
      (m, r) => math.max(m, r[i].length),
    );
    return (longest / 12).clamp(1.2, 4.5).toDouble();
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

  static pw.Widget _section(String text) => AessPdfTable.sectionHeading(text);

  static String _csvCell(Object value) =>
      value is num ? value.toString() : CsvSafe.cell(value.toString());
}
