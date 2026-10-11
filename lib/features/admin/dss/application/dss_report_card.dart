import 'dart:typed_data';

import 'package:alumni_system/core/utils/pdf_safe_text.dart';
import 'package:alumni_system/features/admin/dss/application/dss_copy.dart';
import 'package:alumni_system/features/admin/dss/application/dss_history.dart';
import 'package:alumni_system/features/admin/dss/application/dss_impact.dart';
import 'package:alumni_system/features/admin/dss/application/dss_metrics.dart';
import 'package:alumni_system/features/admin/dss/application/dss_policy.dart';
import 'package:alumni_system/features/admin/dss/application/dss_priority.dart';
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
    this.seekingWork,
    this.mismatch,
    this.clerical,
    this.longWait,
    this.medianSalaryRank,
    this.salaryAnswers = 0,
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
      seekingWork: DssMetrics.seekingWork(answers),
      mismatch: DssMetrics.relatedness(answers)?.mismatchShare,
      clerical: DssMetrics.clerical(answers),
      longWait: DssMetrics.longTimeToFirstJob(answers),
      medianSalaryRank: ranks.isEmpty
          ? null
          : DssMetrics.median(ranks.map((e) => e.toDouble())),
      salaryAnswers: ranks.length,
    );
  }

  final int responses;

  /// Whole active roster for the group (current roster).
  final int roster;
  final DssProportion? notEmployed;

  /// Looking for work among employed + looking (Q16 + Q17).
  final DssProportion? seekingWork;
  final DssProportion? mismatch;
  final DssProportion? clerical;
  final DssProportion? longWait;
  final double? medianSalaryRank;

  /// Respondents with a usable Q31 salary answer.
  final int salaryAnswers;

  double? get responseRate => roster <= 0 ? null : responses / roster;

  String get medianSalaryLabel {
    final rank = medianSalaryRank;
    if (rank == null) return '-';
    if (salaryAnswers < DssPolicy.notEnoughBelow) {
      return DssEvidenceStrength.insufficient.label;
    }
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
    this.interventions = const [],
    this.institution = false,
  });

  /// Program name, or the institution label when [institution].
  final String course;
  final DateTime generatedAt;

  /// Whole-institution report: every program's flags and outcomes; wave
  /// measures in `program` and `institution` are the same.
  final bool institution;

  /// Interventions on these flags, newest first.
  final List<DssIntervention> interventions;

  /// Oldest first.
  final List<DssReportCardWave> waves;

  /// Flags for this course (any batch or all batches).
  final List<DssFlag> flags;

  /// Logged actions on those flags, newest first.
  final List<DssReportCardAction> actions;

  /// Open or in-progress findings (enough answers to act on), most urgent
  /// first.
  List<DssFlag> get activeFlags =>
      flags.where((f) => f.isActive && f.isFinding).toList()
        ..sort((a, b) => DssPriorityCalc.compare(a, b, now: generatedAt));

  /// Open items from small samples (Watch or Not enough data).
  List<DssFlag> get watchFlags =>
      flags.where((f) => f.isActive && !f.isFinding).toList();

  List<DssFlag> get closedFlags => flags
      .where(
        (f) =>
            f.status == DssFlagStatus.resolved ||
            f.status == DssFlagStatus.dismissed,
      )
      .toList();

  DssOutcomeSummary get outcomes => DssOutcomeSummary.from(interventions);

  DssFlag? flagOf(DssIntervention i) {
    for (final f in flags) {
      if (f.id == i.flagId) return f;
    }
    return null;
  }
}

/// One-page-style program report card (CHED / AACCUP review pack).
abstract final class DssReportCardPdf {
  static const _navy = PdfColor.fromInt(0xFF1F3A5F);
  static const _muted = PdfColors.grey700;
  static const _rule = PdfColors.grey400;

  /// Rows listed in the institution report before "N more in the app".
  static const institutionListMax = 15;
  static const _outcomeRowsMax = 25;

  static Future<Uint8List> build(DssReportCardData data) async {
    final kind = data.institution
        ? 'Institution report card'
        : 'Program report card';
    final doc = pw.Document(
      title: '$kind - ${data.course}',
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
              data.institution
                  ? 'Institution Report Card'
                  : 'Program Report Card',
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
                      'Based on submitted CHED GTS responses from alumni '
                      'linked to a roster course. Ranges are 95% margins of '
                      'error. n = alumni who answered that question; fewer '
                      'than ${DssPolicy.notEnoughBelow} shows "Not enough '
                      'data", fewer than ${DssPolicy.findingMin} is a small '
                      'sample. Response rates use the current roster.',
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
            latest == null ? 'Latest wave' : 'Latest wave: ${latest.title}',
          ),
          if (latest == null)
            _para('No published or closed CHED GTS wave has responses yet.')
          else if (data.institution)
            _institutionTable(latest)
          else
            _comparisonTable(latest),
          if (data.waves.length > 1) ...[
            _heading('Across tracer waves'),
            _wavesTable(data.waves),
          ],
          ..._flagSections(data),
          ..._outcomeSections(data),
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

  static List<pw.Widget> _flagSections(DssReportCardData data) {
    final now = data.generatedAt;
    final active = data.activeFlags;
    final watch = data.watchFlags;
    final closed = data.closedFlags;
    if (!data.institution) {
      return [
        _heading('Open findings (${active.length})'),
        if (active.isEmpty)
          _para('No open or in-progress Program Insights flags.')
        else
          _flagsTable(active, closed: false, now: now),
        if (watch.isNotEmpty) ...[
          _heading('Small samples to watch (${watch.length})'),
          _para(
            'These crossed a rule threshold, but too few alumni answered '
            'to treat them as findings.',
          ),
          _flagsTable(watch, closed: false, now: now),
        ],
        _heading('Resolved and dismissed (${closed.length})'),
        if (closed.isEmpty)
          _para('None yet.')
        else
          _flagsTable(closed, closed: true),
      ];
    }
    const max = institutionListMax;
    return [
      _heading(
        active.length > max
            ? 'Top open findings across programs ($max of ${active.length})'
            : 'Open findings across programs (${active.length})',
      ),
      if (active.isEmpty)
        _para('No open or in-progress Program Insights flags.')
      else ...[
        _para('Most urgent first, by the rule-based priority.'),
        _flagsTable(active.take(max).toList(), closed: false, now: now),
        if (active.length > max)
          _para('${active.length - max} more are listed in Program Insights.'),
      ],
      if (watch.isNotEmpty) ...[
        _heading('Small samples to watch (${watch.length})'),
        _para(
          '${watch.length} group result(s) crossed a rule threshold, but too '
          'few alumni answered to treat them as findings. They are listed in '
          'Program Insights.',
        ),
      ],
      _heading('Resolved and dismissed (${closed.length})'),
      if (closed.isEmpty)
        _para('None yet.')
      else ...[
        _flagsTable(closed.take(max).toList(), closed: true),
        if (closed.length > max)
          _para('Showing the $max most recent of ${closed.length}.'),
      ],
    ];
  }

  static List<pw.Widget> _outcomeSections(DssReportCardData data) {
    final all = data.interventions;
    if (all.isEmpty) {
      return [
        _heading('Intervention outcomes'),
        _para('No interventions have been recorded on these flags yet.'),
      ];
    }
    final summary = data.outcomes;
    final o = summary.overall;
    return [
      _heading('Intervention outcomes (${all.length})'),
      _para(
        'Each outcome compares the next CHED tracer wave with the baseline. '
        'It shows what changed after the intervention, not what caused it. '
        '${o.count(DssOutcomeStatus.successful)} successful, '
        '${o.count(DssOutcomeStatus.partiallySuccessful)} partially '
        'successful, ${o.count(DssOutcomeStatus.unsuccessful)} unsuccessful, '
        '${o.count(DssOutcomeStatus.inconclusive)} inconclusive, '
        '${o.count(DssOutcomeStatus.noComparableData)} with no comparable '
        'data, ${o.waiting} waiting for the next wave.',
      ),
      if (data.institution && summary.byType.length > 1) ...[
        pw.SizedBox(height: 4),
        _outcomeTallyTable(summary),
      ],
      pw.SizedBox(height: 4),
      _interventionsTable(data, all.take(_outcomeRowsMax).toList()),
      if (all.length > _outcomeRowsMax)
        _para('Showing the $_outcomeRowsMax most recent of ${all.length}.'),
    ];
  }

  static pw.Widget _outcomeTallyTable(DssOutcomeSummary summary) => _table(
    const [
      'Intervention type',
      'Recorded',
      'Successful',
      'Partially',
      'Unsuccessful',
      'Inconclusive',
      'No data',
      'Waiting',
    ],
    [
      for (final e in summary.byType.entries)
        [
          e.key,
          '${e.value.total}',
          '${e.value.count(DssOutcomeStatus.successful)}',
          '${e.value.count(DssOutcomeStatus.partiallySuccessful)}',
          '${e.value.count(DssOutcomeStatus.unsuccessful)}',
          '${e.value.count(DssOutcomeStatus.inconclusive)}',
          '${e.value.count(DssOutcomeStatus.noComparableData)}',
          '${e.value.waiting}',
        ],
    ],
    widths: const [2.0, 0.9, 1.0, 0.9, 1.2, 1.15, 0.8, 0.8],
  );

  static pw.Widget _interventionsTable(
    DssReportCardData data,
    List<DssIntervention> rows,
  ) {
    final df = DateFormat.yMMMd();
    return _table(
      const [
        'Started',
        'Finding',
        'Intervention',
        'Baseline',
        'Next wave',
        'Outcome',
        'Decision',
      ],
      [
        for (final i in rows)
          [
            df.format(i.startedOn),
            _findingOf(data, i),
            DssOutcomeSummary.typeLabel(i.interventionType),
            DssCopy.outcomeValue(i.successMetric, i.baselineValue),
            i.outcomeStatus.isFinal && i.followupValue != null
                ? '${DssCopy.outcomeValue(i.successMetric, i.followupValue)}'
                      '${i.followupN == null ? '' : ' (n=${i.followupN})'}'
                : '-',
            i.outcomeStatus.label,
            i.decision?.label ?? '-',
          ],
      ],
      widths: const [0.9, 2.2, 1.5, 0.8, 0.9, 1.1, 0.8],
    );
  }

  static String _findingOf(DssReportCardData data, DssIntervention i) {
    final flag = data.flagOf(i);
    if (flag != null) {
      return '${DssCopy.displayTitle(flag)} (${flag.cohortLabel})';
    }
    final parts = i.findingKey.split('|');
    final group = parts.length >= 4
        ? [parts[2], if (parts[3].isNotEmpty) 'Batch ${parts[3]}']
              .where((s) => s.isNotEmpty)
              .join(' · ')
        : '';
    final stored = data.flags
        .where((f) => f.ruleId == i.ruleId && (f.ruleName ?? '').isNotEmpty)
        .map((f) => f.ruleName!)
        .firstOrNull;
    final name = dssRuleDisplayName(i.ruleId, stored ?? i.ruleId);
    return group.isEmpty ? name : '$name ($group)';
  }

  /// Latest-wave measures for the whole institution.
  static pw.Widget _institutionTable(DssReportCardWave w) {
    final i = w.institution;
    return _table(
      const ['Measure', 'Institution (all programs)'],
      [
        [
          'Responses',
          '${i.responses} of ${i.roster} (${_rate(i.responseRate)})',
        ],
        [
          'Not currently employed (Q16)',
          _share(i.notEmployed, withRange: true),
        ],
        [
          'Looking for work, of employed + looking (Q16, Q17)',
          _share(i.seekingWork, withRange: true),
        ],
        [
          'Course / curriculum mismatch (Q24, Q32)',
          _share(i.mismatch, withRange: true),
        ],
        [
          'Rank or clerical, employed (Q30)',
          _share(i.clerical, withRange: true),
        ],
        ['1+ year to first job (Q29)', _share(i.longWait, withRange: true)],
        ['Median first-job salary (Q31)', i.medianSalaryLabel],
      ],
      widths: const [3.0, 4.0],
    );
  }

  static pw.Widget _comparisonTable(DssReportCardWave w) {
    final p = w.program;
    final i = w.institution;
    String gap(DssProportion? a, DssProportion? b) {
      if (a == null || b == null) return '-';
      if (a.total < DssPolicy.notEnoughBelow ||
          b.total < DssPolicy.notEnoughBelow) {
        return '-';
      }
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
        'Not currently employed (Q16)',
        _share(p.notEmployed, withRange: true),
        _share(i.notEmployed),
        gap(p.notEmployed, i.notEmployed),
      ],
      [
        'Looking for work, of employed + looking (Q16, Q17)',
        _share(p.seekingWork, withRange: true),
        _share(i.seekingWork),
        gap(p.seekingWork, i.seekingWork),
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
        'Looking for work',
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
            _share(w.program.seekingWork),
            _share(w.program.mismatch),
            _share(w.program.clerical),
            _share(w.program.longWait),
            _shortSalary(w.program.medianSalaryLabel),
          ],
      ],
      widths: const [2.4, 0.9, 1.0, 1.0, 1.0, 1.0, 1.0, 1.3],
    );
  }

  static pw.Widget _flagsTable(
    List<DssFlag> flags, {
    required bool closed,
    DateTime? now,
  }) {
    final df = DateFormat.yMMMd();
    return _table(
      closed
          ? const ['Finding', 'Group', 'Closed as', 'Intervention', 'Re-check']
          : const [
              'Finding',
              'Group',
              'Value',
              'Certainty',
              'Priority',
              'Status',
              'Since',
            ],
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
                  f.isFinding
                      ? f.certainty?.label ?? '-'
                      : f.evidenceStrength?.label ?? '-',
                  DssPriorityCalc.of(f, now: now ?? DateTime.now()).level.label,
                  f.status.label,
                  df.format(f.createdAt.toLocal()),
                ],
      ],
      widths: closed
          ? const [2.4, 1.8, 1.0, 1.8, 1.1]
          : const [2.0, 1.5, 1.6, 0.8, 0.8, 0.9, 0.9],
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

  static pw.Widget _para(String text) =>
      pw.Text(_s(text), style: const pw.TextStyle(fontSize: 9, color: _muted));

  static String _s(String text) => PdfSafeText.sanitize(text);

  static String _rate(double? r) =>
      r == null ? '-' : '${(r * 100).toStringAsFixed(0)}%';

  static String _share(DssProportion? p, {bool withRange = false}) {
    if (p == null || p.total == 0) return '-';
    if (p.total < DssPolicy.notEnoughBelow) {
      return 'Not enough data (n=${p.total})';
    }
    final base = '${(p.rate * 100).toStringAsFixed(0)}% (n=${p.total})';
    if (p.total < DssPolicy.findingMin) return '$base, small sample';
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
