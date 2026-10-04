import 'dart:typed_data';

import 'package:alumni_system/core/utils/pdf_safe_text.dart';
import 'package:alumni_system/features/admin/dss/application/dss_copy.dart';
import 'package:alumni_system/features/admin/dss/application/dss_impact.dart';
import 'package:alumni_system/features/admin/dss/application/dss_metrics.dart';
import 'package:alumni_system/features/admin/dss/models/dss_models.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Headline CHED GTS measures for one group in one wave.
class DssProgramSnapshot {
  const DssProgramSnapshot({
    required this.responses,
    required this.roster,
    this.notEmployed,
    this.mismatch,
    this.clerical,
    this.longWait,
    this.medianSalaryRank,
  });

  factory DssProgramSnapshot.from(
    List<Map<String, dynamic>> answers, {
    required int roster,
  }) {
    final ranks = DssMetrics.salaryRanks(answers);
    return DssProgramSnapshot(
      responses: answers.length,
      roster: roster,
      notEmployed: DssMetrics.unemployment(answers),
      mismatch: DssMetrics.relatedness(answers)?.mismatchShare,
      clerical: DssMetrics.clerical(answers),
      longWait: DssMetrics.longTimeToFirstJob(answers),
      medianSalaryRank: ranks.isEmpty
          ? null
          : DssMetrics.median(ranks.map((e) => e.toDouble())),
    );
  }

  final int responses;

  /// Whole active roster for the group (current roster).
  final int roster;
  final DssProportion? notEmployed;
  final DssProportion? mismatch;
  final DssProportion? clerical;
  final DssProportion? longWait;
  final double? medianSalaryRank;

  double? get responseRate => roster <= 0 ? null : responses / roster;

  String get medianSalaryLabel {
    final rank = medianSalaryRank;
    if (rank == null) return '-';
    final i = rank.round().clamp(0, DssMetrics.salaryBrackets.length - 1);
    return DssMetrics.salaryBrackets[i];
  }
}

/// One tracer wave compared for the program and the whole institution.
class DssReportCardWave {
  const DssReportCardWave({
    required this.title,
    required this.date,
    required this.program,
    required this.institution,
  });

  final String title;
  final DateTime date;
  final DssProgramSnapshot program;
  final DssProgramSnapshot institution;
}

class DssReportCardAction {
  const DssReportCardAction({required this.flag, required this.note});

  final DssFlag flag;
  final DssFlagNote note;
}

class DssReportCardData {
  const DssReportCardData({
    required this.course,
    required this.generatedAt,
    required this.waves,
    required this.flags,
    required this.actions,
  });

  final String course;
  final DateTime generatedAt;

  /// Oldest first.
  final List<DssReportCardWave> waves;

  /// Flags for this course (any batch or all batches).
  final List<DssFlag> flags;

  /// Logged actions on those flags, newest first.
  final List<DssReportCardAction> actions;

  List<DssFlag> get activeFlags => flags
      .where(
        (f) =>
            f.status == DssFlagStatus.open ||
            f.status == DssFlagStatus.inProgress,
      )
      .toList();

  List<DssFlag> get closedFlags => flags
      .where(
        (f) =>
            f.status == DssFlagStatus.resolved ||
            f.status == DssFlagStatus.dismissed,
      )
      .toList();
}

/// One-page-style program report card (CHED / AACCUP review pack).
abstract final class DssReportCardPdf {
  static const _navy = PdfColor.fromInt(0xFF1F3A5F);
  static const _muted = PdfColors.grey700;
  static const _rule = PdfColors.grey400;

  static Future<Uint8List> build(DssReportCardData data) async {
    final doc = pw.Document(
      title: 'Program report card - ${data.course}',
      author: 'AESS Program Insights',
    );
    final stamp = DateFormat.yMMMd().add_jm().format(data.generatedAt);
    final latest = data.waves.isEmpty ? null : data.waves.last;

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(36, 32, 36, 32),
        header: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'Program Report Card',
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
                color: _navy,
              ),
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              _s(data.course),
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              _s('Generated $stamp - AESS Program Insights (CHED GTS)'),
              style: const pw.TextStyle(fontSize: 8.5, color: _muted),
            ),
            pw.SizedBox(height: 6),
            pw.Divider(color: _rule, height: 1),
            pw.SizedBox(height: 8),
          ],
        ),
        footer: (ctx) => pw.Column(
          children: [
            pw.Divider(color: _rule, height: 1),
            pw.SizedBox(height: 4),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Text(
                    _s(
                      'Based on submitted CHED GTS responses. Ranges are 95% '
                      'margins of error; figures from fewer than 20 responses '
                      'are indicative. Response rates use the current roster.',
                    ),
                    style: const pw.TextStyle(fontSize: 7.5, color: _muted),
                  ),
                ),
                pw.SizedBox(width: 12),
                pw.Text(
                  'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
                  style: const pw.TextStyle(fontSize: 7.5, color: _muted),
                ),
              ],
            ),
          ],
        ),
        build: (ctx) => [
          _heading(
            latest == null
                ? 'Latest wave'
                : 'Latest wave: ${latest.title}',
          ),
          if (latest == null)
            _para('No published or closed CHED GTS wave has responses yet.')
          else
            _comparisonTable(latest),
          if (data.waves.length > 1) ...[
            _heading('Across tracer waves'),
            _wavesTable(data.waves),
          ],
          _heading('Open findings (${data.activeFlags.length})'),
          if (data.activeFlags.isEmpty)
            _para('No open or in-progress Program Insights flags.')
          else
            _flagsTable(data.activeFlags, closed: false),
          _heading('Resolved and dismissed (${data.closedFlags.length})'),
          if (data.closedFlags.isEmpty)
            _para('None yet.')
          else
            _flagsTable(data.closedFlags, closed: true),
          _heading('Actions taken'),
          if (data.actions.isEmpty)
            _para('No actions have been logged on these flags yet.')
          else
            _actionsTable(data.actions),
        ],
      ),
    );
    return doc.save();
  }

  static pw.Widget _comparisonTable(DssReportCardWave w) {
    final p = w.program;
    final i = w.institution;
    String gap(DssProportion? a, DssProportion? b) {
      if (a == null || b == null) return '-';
      return _points(a.rate - b.rate);
    }

    final rows = <List<String>>[
      [
        'Responses',
        '${p.responses} of ${p.roster} (${_rate(p.responseRate)})',
        '${i.responses} of ${i.roster} (${_rate(i.responseRate)})',
        p.responseRate == null || i.responseRate == null
            ? '-'
            : _points(p.responseRate! - i.responseRate!),
      ],
      [
        'Not employed (Q16)',
        _share(p.notEmployed, withRange: true),
        _share(i.notEmployed),
        gap(p.notEmployed, i.notEmployed),
      ],
      [
        'Course / curriculum mismatch (Q24, Q32)',
        _share(p.mismatch, withRange: true),
        _share(i.mismatch),
        gap(p.mismatch, i.mismatch),
      ],
      [
        'Rank or clerical, employed (Q30)',
        _share(p.clerical, withRange: true),
        _share(i.clerical),
        gap(p.clerical, i.clerical),
      ],
      [
        '1+ year to first job (Q29)',
        _share(p.longWait, withRange: true),
        _share(i.longWait),
        gap(p.longWait, i.longWait),
      ],
      [
        'Median first-job salary (Q31)',
        p.medianSalaryLabel,
        i.medianSalaryLabel,
        '',
      ],
    ];
    return _table(
      const ['Measure', 'This program', 'Institution (all programs)', 'Gap'],
      rows,
      widths: const [2.6, 2.4, 2.0, 0.9],
    );
  }

  static pw.Widget _wavesTable(List<DssReportCardWave> waves) {
    final df = DateFormat.yMMM();
    return _table(
      const [
        'Wave',
        'Responses',
        'Not employed',
        'Mismatch',
        'Clerical',
        '1+ yr to job',
        'Median salary',
      ],
      [
        for (final w in waves)
          [
            '${w.title} (${df.format(w.date)})',
            '${w.program.responses}',
            _share(w.program.notEmployed),
            _share(w.program.mismatch),
            _share(w.program.clerical),
            _share(w.program.longWait),
            _shortSalary(w.program.medianSalaryLabel),
          ],
      ],
      widths: const [2.6, 1.0, 1.1, 1.0, 1.0, 1.1, 1.4],
    );
  }

  static pw.Widget _flagsTable(List<DssFlag> flags, {required bool closed}) {
    final df = DateFormat.yMMMd();
    return _table(
      closed
          ? const ['Finding', 'Group', 'Outcome', 'Intervention', 'Impact']
          : const ['Finding', 'Group', 'Value', 'Certainty', 'Status', 'Since'],
      [
        for (final f in flags)
          closed
              ? [
                  DssCopy.displayTitle(f),
                  f.cohortLabel,
                  f.status.label,
                  f.interventionType ?? '-',
                  DssImpactVerdictX.fromDb(f.impactVerdict)?.label ?? '-',
                ]
              : [
                  DssCopy.displayTitle(f),
                  f.cohortLabel,
                  DssCopy.metricValueLabel(f),
                  f.certainty?.label ?? '-',
                  f.status.label,
                  df.format(f.createdAt.toLocal()),
                ],
      ],
      widths: closed
          ? const [2.4, 1.8, 1.0, 1.8, 1.1]
          : const [2.2, 1.6, 1.8, 0.9, 0.9, 1.0],
    );
  }

  static pw.Widget _actionsTable(List<DssReportCardAction> actions) {
    final df = DateFormat.yMMMd();
    return _table(
      const ['Date', 'Finding', 'What was done', 'By'],
      [
        for (final a in actions)
          [
            df.format(a.note.createdAt.toLocal()),
            '${DssCopy.displayTitle(a.flag)} (${a.flag.cohortLabel})',
            a.note.note.trim().isEmpty
                ? a.note.eventType.label
                : a.note.note.trim(),
            a.note.authorName.trim().isEmpty ? '-' : a.note.authorName.trim(),
          ],
      ],
      widths: const [1.0, 2.2, 3.6, 1.1],
    );
  }

  static pw.Widget _table(
    List<String> headers,
    List<List<String>> rows, {
    required List<double> widths,
  }) {
    return pw.TableHelper.fromTextArray(
      headers: PdfSafeText.sanitizeRow(headers),
      data: PdfSafeText.sanitizeRows(rows),
      columnWidths: {
        for (var i = 0; i < widths.length; i++)
          i: pw.FlexColumnWidth(widths[i]),
      },
      headerStyle: pw.TextStyle(
        fontSize: 8.5,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.white,
      ),
      headerDecoration: const pw.BoxDecoration(color: _navy),
      cellStyle: const pw.TextStyle(fontSize: 8.5),
      cellAlignment: pw.Alignment.centerLeft,
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
      border: const pw.TableBorder(
        horizontalInside: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
      ),
    );
  }

  static pw.Widget _heading(String text) => pw.Padding(
    padding: const pw.EdgeInsets.only(top: 10, bottom: 4),
    child: pw.Text(
      _s(text),
      style: pw.TextStyle(
        fontSize: 11,
        fontWeight: pw.FontWeight.bold,
        color: _navy,
      ),
    ),
  );

  static pw.Widget _para(String text) => pw.Text(
    _s(text),
    style: const pw.TextStyle(fontSize: 9, color: _muted),
  );

  static String _s(String text) => PdfSafeText.sanitize(text);

  static String _rate(double? r) =>
      r == null ? '-' : '${(r * 100).toStringAsFixed(0)}%';

  static String _share(DssProportion? p, {bool withRange = false}) {
    if (p == null || p.total == 0) return '-';
    final base = '${(p.rate * 100).toStringAsFixed(0)}% (n=${p.total})';
    if (!withRange) return base;
    final ci = DssMetrics.wilson(p.hits, p.total);
    return '$base, likely ${(ci.low * 100).toStringAsFixed(0)}-'
        '${(ci.high * 100).toStringAsFixed(0)}%';
  }

  static String _points(double change) {
    final pts = (change * 100).round();
    return pts > 0 ? '+$pts pts' : '$pts pts';
  }

  static String _shortSalary(String label) => label
      .replaceAll(' to less than ', '-')
      .replaceAll('.00', '')
      .replaceAll(' and above', '+');
}
