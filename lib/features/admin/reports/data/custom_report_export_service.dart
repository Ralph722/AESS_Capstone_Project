import 'dart:convert';
import 'dart:typed_data';

import 'package:excel/excel.dart' hide Border;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:alumni_system/features/admin/reports/application/admin_reports_analytics.dart';
import 'package:alumni_system/features/admin/reports/models/custom_report_template.dart';
import 'package:alumni_system/features/admin/roster/models/alumni_member_model.dart';
import 'package:alumni_system/features/alumni/tracer/models/id_tracer_model.dart';
import 'package:alumni_system/features/alumni/tracer/models/tracer_profile_model.dart';
import 'package:alumni_system/features/announcements/models/announcement_model.dart';
import 'package:alumni_system/features/events/models/event_model.dart';
import 'package:alumni_system/features/forum/models/forum_model.dart';
import 'package:alumni_system/features/jobs/models/job_posting_model.dart';
import 'package:alumni_system/features/surveys/data/survey_report_pack_service.dart';
import 'package:alumni_system/features/surveys/models/survey_model.dart';
import 'package:alumni_system/features/surveys/models/survey_reports_aggregate.dart';

/// One tabular section inside a generated custom report.
class CustomReportSectionData {
  const CustomReportSectionData({
    required this.id,
    required this.title,
    required this.headers,
    required this.rows,
  });

  final CustomReportSectionId id;
  final String title;
  final List<String> headers;
  final List<List<String>> rows;

  int get rowCount => rows.length;
}

/// Format-neutral custom report document.
class CustomReportDocument {
  const CustomReportDocument({
    required this.title,
    required this.generatedAt,
    required this.sections,
    this.filterSummary = const [],
  });

  final String title;
  final DateTime generatedAt;
  final List<CustomReportSectionData> sections;
  final List<String> filterSummary;

  int get totalRows =>
      sections.fold<int>(0, (sum, s) => sum + s.rowCount);
}

/// Builds and exports multi-section custom reports.
class CustomReportExportService {
  CustomReportExportService._();

  static CustomReportDocument buildDocument({
    required CustomReportTemplate template,
    required AdminReportsAnalytics analytics,
    required List<AlumniEvent> events,
    required List<JobPosting> jobs,
    List<SurveyReportRollup> rollups = const [],
    Map<String, TracerProfile> profilesByAuthUid = const {},
  }) {
    final filters = template.filters;
    final sections = <CustomReportSectionData>[];

    // Built lazily; shared by the participation and question sections.
    SurveyReportPack? pack;
    SurveyReportPack ensurePack() => pack ??=
        SurveyReportPackService.buildPortfolioPack(
          analytics: analytics,
          rollups: rollups,
        );

    for (final id in template.sections) {
      switch (id) {
        case CustomReportSectionId.executiveKpis:
          sections.add(_executiveKpis(analytics));
        case CustomReportSectionId.alumniRoster:
          sections.add(
            _alumniRoster(analytics.activeRoster, filters, profilesByAuthUid),
          );
        case CustomReportSectionId.employmentRecords:
          sections.add(
            _employmentRecords(analytics.reportEmploymentRecords, filters),
          );
        case CustomReportSectionId.surveySummary:
          sections.add(_surveySummary(analytics, analytics.surveys));
        case CustomReportSectionId.surveyParticipation:
          sections.add(_surveyParticipation(ensurePack()));
        case CustomReportSectionId.surveyQuestions:
          sections.add(_surveyQuestions(ensurePack()));
        case CustomReportSectionId.events:
          sections.add(_events(events, filters));
        case CustomReportSectionId.jobPostings:
          sections.add(_jobPostings(jobs, filters));
        case CustomReportSectionId.announcements:
          sections.add(_announcements(analytics.announcements, filters));
        case CustomReportSectionId.forumTopics:
          sections.add(_forumTopics(analytics.forumTopics, filters));
      }
    }

    final title = template.name.trim().isEmpty
        ? 'Custom Report'
        : template.name.trim();

    return CustomReportDocument(
      title: title,
      generatedAt: DateTime.now(),
      sections: sections,
      filterSummary: _filterSummary(filters),
    );
  }

  /// Estimated row counts without fully exporting (for builder UI).
  static Map<CustomReportSectionId, int> estimateRowCounts({
    required CustomReportTemplate template,
    required AdminReportsAnalytics analytics,
    required List<AlumniEvent> events,
    required List<JobPosting> jobs,
    List<SurveyReportRollup> rollups = const [],
    Map<String, TracerProfile> profilesByAuthUid = const {},
  }) {
    final doc = buildDocument(
      template: template,
      analytics: analytics,
      events: events,
      jobs: jobs,
      rollups: rollups,
      profilesByAuthUid: profilesByAuthUid,
    );
    return {
      for (final s in doc.sections) s.id: s.rowCount,
    };
  }

  static Future<Uint8List> toPdf(CustomReportDocument doc) async {
    final pdf = pw.Document();
    final date = DateFormat.yMMMMEEEEd().add_jm().format(doc.generatedAt);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(28),
        header: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              doc.title,
              style: pw.TextStyle(
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blue900,
              ),
            ),
            pw.Text(
              'Custom report · $date',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
            ),
            if (doc.filterSummary.isNotEmpty) ...[
              pw.SizedBox(height: 4),
              pw.Text(
                'Filters: ${doc.filterSummary.join(' · ')}',
                style:
                    const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
              ),
            ],
            pw.SizedBox(height: 6),
            pw.Divider(color: PdfColors.blue900),
            pw.SizedBox(height: 8),
          ],
        ),
        footer: (ctx) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
          ),
        ),
        build: (ctx) {
          final widgets = <pw.Widget>[];
          for (var i = 0; i < doc.sections.length; i++) {
            final section = doc.sections[i];
            if (i > 0) widgets.add(pw.SizedBox(height: 16));
            widgets.add(
              pw.Text(
                section.title,
                style: pw.TextStyle(
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue900,
                ),
              ),
            );
            widgets.add(pw.SizedBox(height: 6));
            if (section.rows.isEmpty) {
              widgets.add(
                pw.Text(
                  'No rows matched the selected filters.',
                  style: const pw.TextStyle(fontSize: 10),
                ),
              );
            } else {
              widgets.add(_pdfTable(section.headers, section.rows));
            }
          }
          if (widgets.isEmpty) {
            widgets.add(
              pw.Text(
                'No sections selected.',
                style: const pw.TextStyle(fontSize: 10),
              ),
            );
          }
          return widgets;
        },
      ),
    );

    return pdf.save();
  }

  static Uint8List toExcel(CustomReportDocument doc) {
    final excel = Excel.createExcel();

    void writeSheet(String name, List<List<dynamic>> rows) {
      final sheet = excel[name];
      for (final row in rows) {
        sheet.appendRow(row);
      }
    }

    final def = excel.getDefaultSheet();
    if (def != null &&
        (doc.sections.isEmpty || def != _sheetName(doc.sections.first))) {
      writeSheet(def, [
        [doc.title],
        ['Custom report'],
        ['Generated', DateFormat.yMMMd().add_jm().format(doc.generatedAt)],
        if (doc.filterSummary.isNotEmpty)
          ['Filters', doc.filterSummary.join(' · ')],
        [''],
        [
          'Data is on the following tabs: '
              '${doc.sections.map((s) => _sheetName(s)).join(', ')}',
        ],
      ]);
    }

    for (final section in doc.sections) {
      final name = _sheetName(section);
      writeSheet(name, [
        section.headers,
        ...section.rows,
      ]);
    }

    if (doc.sections.isNotEmpty) {
      excel.setDefaultSheet(_sheetName(doc.sections.first));
    }

    final bytes = excel.save();
    if (bytes == null) {
      return Uint8List.fromList(utf8.encode(''));
    }
    return Uint8List.fromList(bytes);
  }

  static String toCsv(CustomReportDocument doc) {
    final b = StringBuffer();
    b.writeln(_csvRow(['Report', doc.title]));
    b.writeln(
      _csvRow([
        'Generated',
        DateFormat.yMMMd().add_jm().format(doc.generatedAt),
      ]),
    );
    if (doc.filterSummary.isNotEmpty) {
      b.writeln(_csvRow(['Filters', doc.filterSummary.join(' · ')]));
    }
    b.writeln();

    for (final section in doc.sections) {
      b.writeln(_csvRow(['SECTION', section.title]));
      b.writeln(_csvRow(section.headers));
      for (final row in section.rows) {
        b.writeln(_csvRow(row));
      }
      b.writeln();
    }
    return b.toString();
  }

  static Future<Uint8List> exportBytes({
    required CustomReportDocument doc,
    required CustomReportFormat format,
  }) async {
    switch (format) {
      case CustomReportFormat.pdf:
        return toPdf(doc);
      case CustomReportFormat.excel:
        return toExcel(doc);
      case CustomReportFormat.csv:
        return Uint8List.fromList(utf8.encode(toCsv(doc)));
    }
  }

  // —— section builders ——

  static CustomReportSectionData _executiveKpis(AdminReportsAnalytics a) {
    return CustomReportSectionData(
      id: CustomReportSectionId.executiveKpis,
      title: 'Executive KPIs',
      headers: const ['Metric', 'Value'],
      rows: [
        ['Roster total', '${a.rosterTotal}'],
        ['Registered on roster', '${a.registeredOnRoster}'],
        [
          'Registration rate',
          '${(a.registrationRate * 100).toStringAsFixed(1)}%',
        ],
        ['Tracer complete', '${a.tracerCompleteCount}'],
        [
          'Tracer completion rate',
          '${(a.tracerCompletionRate * 100).toStringAsFixed(1)}%',
        ],
        [
          'Registered without complete tracer',
          '${a.registeredWithoutTracerComplete}',
        ],
        ['Employment submissions', '${a.reportEmploymentCount}'],
        ['Employed', '${a.employedCount}'],
        ['Unemployed', '${a.unemployedCount}'],
        [
          'Employed % of submissions',
          '${(a.employmentRateAmongSubmissions * 100).toStringAsFixed(1)}%',
        ],
        ['Survey assignments', '${a.totalSurveyAssignments}'],
        ['Survey responses', '${a.totalSurveyResponses}'],
        [
          'Survey response rate',
          '${(a.surveyResponseRate * 100).toStringAsFixed(1)}%',
        ],
        ['Pending survey assignments', '${a.pendingSurveyAssignments}'],
        ['Published surveys', '${a.publishedSurveys}'],
        ['Draft surveys', '${a.draftSurveys}'],
      ],
    );
  }

  /// Effective batch year for a roster member. The `alumni_members` mirror
  /// often has blank legacy fields, so this falls back to the registered
  /// account's live profile (batch year, then graduation year).
  static String memberBatch(AlumniMember m, [TracerProfile? profile]) {
    final batch = m.batchYear.trim();
    if (batch.isNotEmpty) return batch;
    final profileBatch = profile?.batchYear.trim() ?? '';
    if (profileBatch.isNotEmpty) return profileBatch;
    final grad = (m.yearGraduated ?? '').trim();
    if (grad.isNotEmpty) return grad;
    return profile?.yearGraduated.trim() ?? '';
  }

  /// Effective email: legacy roster field, registered email, then the live
  /// account email.
  static String memberEmail(AlumniMember m, [TracerProfile? profile]) {
    final email = m.emailAddress.trim();
    if (email.isNotEmpty) return email;
    final registered = (m.registeredEmail ?? '').trim();
    if (registered.isNotEmpty) return registered;
    return profile?.email.trim() ?? '';
  }

  static TracerProfile? profileFor(
    AlumniMember m,
    Map<String, TracerProfile> profilesByAuthUid,
  ) {
    final uid = (m.authUid ?? '').trim();
    if (uid.isEmpty) return null;
    return profilesByAuthUid[uid];
  }

  static CustomReportSectionData _alumniRoster(
    List<AlumniMember> members,
    CustomReportFilters filters,
    Map<String, TracerProfile> profilesByAuthUid,
  ) {
    final rows = <List<String>>[];
    for (final m in members) {
      final profile = profileFor(m, profilesByAuthUid);
      if (!_matchesBatch(memberBatch(m, profile), filters)) continue;
      if (!_matchesCourse(m.course, filters)) continue;
      if (!_matchesRegistration(m.isRegisteredUser, filters)) continue;
      if (!_matchesTracer(m.tracerProfileComplete, filters)) continue;
      if (!_matchesDate(m.createdAt, filters)) continue;
      rows.add([
        m.fullName,
        m.course,
        m.studentId,
        memberBatch(m, profile),
        memberEmail(m, profile),
        m.isRegisteredUser ? 'Yes' : 'No',
        m.tracerProfileComplete ? 'Yes' : 'No',
        DateFormat('yyyy-MM-dd').format(m.createdAt),
      ]);
    }
    return CustomReportSectionData(
      id: CustomReportSectionId.alumniRoster,
      title: 'Alumni roster',
      headers: const [
        'Name',
        'Course',
        'ID',
        'Batch',
        'Email',
        'Registered',
        'Tracer complete',
        'Added',
      ],
      rows: rows,
    );
  }

  static CustomReportSectionData _employmentRecords(
    List<EmploymentRecord> records,
    CustomReportFilters filters,
  ) {
    final rows = <List<String>>[];
    for (final r in records) {
      if (!_matchesEmploymentStatus(r.employmentStatus, filters)) continue;
      if (!_matchesDate(r.lastUpdated, filters)) continue;
      rows.add([
        r.userName,
        r.userEmail,
        r.employmentStatus,
        r.companyName ?? '',
        r.position ?? '',
        r.industry ?? '',
        DateFormat('yyyy-MM-dd').format(r.lastUpdated),
      ]);
    }
    return CustomReportSectionData(
      id: CustomReportSectionId.employmentRecords,
      title: 'Employment records',
      headers: const [
        'Name',
        'Email',
        'Status',
        'Company',
        'Position',
        'Industry',
        'Updated',
      ],
      rows: rows,
    );
  }

  static CustomReportSectionData _surveySummary(
    AdminReportsAnalytics a,
    List<Survey> surveys,
  ) {
    final rows = <List<String>>[];
    for (final s in surveys.where((s) => !s.archived)) {
      final assigned = a.assignmentCount(s);
      final submitted = a.submittedResponseCount(s);
      final rate = assigned == 0
          ? ''
          : (100 * submitted / assigned).toStringAsFixed(1);
      rows.add([
        s.title.isEmpty ? 'Untitled' : s.title,
        s.status.name,
        s.isChedGtsBuiltin
            ? 'Official CHED'
            : (s.isFromTemplate ? 'CHED preset' : 'Custom'),
        '$assigned',
        '$submitted',
        rate,
        s.targetPrograms.join(', '),
      ]);
    }
    return CustomReportSectionData(
      id: CustomReportSectionId.surveySummary,
      title: 'Survey summary',
      headers: const [
        'Title',
        'Status',
        'Kind',
        'Assigned',
        'Responses',
        'Rate %',
        'Programs',
      ],
      rows: rows,
    );
  }

  static CustomReportSectionData _surveyParticipation(SurveyReportPack pack) {
    final p = pack.participation;
    final rate = p.assigned == 0
        ? '—'
        : '${(100 * p.completed / p.assigned).toStringAsFixed(1)}%';
    return CustomReportSectionData(
      id: CustomReportSectionId.surveyParticipation,
      title: 'Survey participation & insights',
      headers: const ['Category', 'Detail'],
      rows: [
        [
          'Funnel',
          '${p.assigned} assigned · ${p.notStarted + p.inProgress} pending · '
              '${p.completed} completed ($rate completion)',
        ],
        for (final line in pack.executiveBullets) ['KPI', line],
        for (final insight in pack.insights) ['Insight', insight],
        for (final rec in pack.recommendations) ['Recommendation', rec],
      ],
    );
  }

  static CustomReportSectionData _surveyQuestions(SurveyReportPack pack) {
    return CustomReportSectionData(
      id: CustomReportSectionId.surveyQuestions,
      title: 'Survey question summaries',
      headers: const [
        'Survey',
        'Question',
        'Type',
        'Answered',
        'Total',
        'Skipped',
        'Detail',
      ],
      rows: [
        for (final q in pack.questionRows)
          [
            q.surveyTitle,
            q.prompt,
            q.type,
            '${q.answered}',
            '${q.total}',
            '${q.skipped}',
            q.detail,
          ],
      ],
    );
  }

  static CustomReportSectionData _events(
    List<AlumniEvent> events,
    CustomReportFilters filters,
  ) {
    final rows = <List<String>>[];
    for (final e in events) {
      if (!_matchesBatch(e.batchYear, filters)) continue;
      if (!_matchesDate(e.date, filters)) continue;
      rows.add([
        e.theme,
        e.batchYear,
        DateFormat('yyyy-MM-dd').format(e.date),
        e.venue,
        e.status,
      ]);
    }
    return CustomReportSectionData(
      id: CustomReportSectionId.events,
      title: 'Events',
      headers: const ['Theme', 'Batch', 'Date', 'Venue', 'Status'],
      rows: rows,
    );
  }

  static CustomReportSectionData _jobPostings(
    List<JobPosting> jobs,
    CustomReportFilters filters,
  ) {
    final rows = <List<String>>[];
    for (final j in jobs) {
      if (filters.hasDateRange) {
        final inPosted = _matchesDate(j.postedDate, filters);
        final inDeadline = _matchesDate(j.applicationDeadline, filters);
        if (!inPosted && !inDeadline) continue;
      }
      rows.add([
        j.jobTitle,
        j.companyName,
        j.jobType,
        j.location,
        DateFormat('yyyy-MM-dd').format(j.applicationDeadline),
        j.status,
      ]);
    }
    return CustomReportSectionData(
      id: CustomReportSectionId.jobPostings,
      title: 'Job postings',
      headers: const [
        'Title',
        'Company',
        'Type',
        'Location',
        'Deadline',
        'Status',
      ],
      rows: rows,
    );
  }

  static CustomReportSectionData _announcements(
    List<Announcement> items,
    CustomReportFilters filters,
  ) {
    final rows = <List<String>>[];
    for (final a in items) {
      if (filters.batchYears.isNotEmpty) {
        final hit = a.targetBatchYears.isEmpty ||
            a.targetBatchYears.any(
              (b) => filters.batchYears.any(
                (f) => b.trim().toLowerCase() == f.trim().toLowerCase(),
              ),
            );
        if (!hit) continue;
      }
      if (filters.courses.isNotEmpty) {
        final hit = a.targetPrograms.isEmpty ||
            a.targetPrograms.any(
              (p) => filters.courses.any(
                (f) => p.trim().toLowerCase() == f.trim().toLowerCase(),
              ),
            );
        if (!hit) continue;
      }
      final stamp = a.publishedAt ?? a.createdAt;
      if (!_matchesDate(stamp, filters)) continue;
      rows.add([
        a.title,
        a.status.name,
        a.priority.name,
        '${a.recipientCount}',
        a.publishedAt != null
            ? DateFormat('yyyy-MM-dd').format(a.publishedAt!)
            : '',
      ]);
    }
    return CustomReportSectionData(
      id: CustomReportSectionId.announcements,
      title: 'Announcements',
      headers: const [
        'Title',
        'Status',
        'Priority',
        'Recipients',
        'Published',
      ],
      rows: rows,
    );
  }

  static CustomReportSectionData _forumTopics(
    List<ForumTopic> topics,
    CustomReportFilters filters,
  ) {
    final rows = <List<String>>[];
    for (final t in topics) {
      if (!_matchesDate(t.createdAt, filters)) continue;
      if (filters.courses.isNotEmpty &&
          !_matchesCourse(t.authorProgram, filters)) {
        continue;
      }
      if (!_matchesBatch(t.authorBatch, filters)) continue;
      rows.add([
        t.title,
        t.authorName,
        t.authorProgram,
        t.authorBatch,
        '${t.replyCount}',
        t.isPinned ? 'Yes' : 'No',
        t.isLocked ? 'Yes' : 'No',
        t.isSolved ? 'Yes' : 'No',
        t.isAnnouncement ? 'Yes' : 'No',
        t.tags.map((e) => e.label).join('; '),
        DateFormat('yyyy-MM-dd').format(t.createdAt),
      ]);
    }
    return CustomReportSectionData(
      id: CustomReportSectionId.forumTopics,
      title: 'Forum topics',
      headers: const [
        'Title',
        'Author',
        'Program',
        'Batch',
        'Replies',
        'Pinned',
        'Locked',
        'Solved',
        'Announcement',
        'Tags',
        'Created',
      ],
      rows: rows,
    );
  }

  // —— filters ——

  static bool _matchesBatch(String batch, CustomReportFilters filters) {
    if (filters.batchYears.isEmpty) return true;
    final b = batch.trim().toLowerCase();
    return filters.batchYears.any((f) => b == f.trim().toLowerCase());
  }

  static bool _matchesCourse(String course, CustomReportFilters filters) {
    if (filters.courses.isEmpty) return true;
    final c = course.trim().toLowerCase();
    return filters.courses.any((f) => c == f.trim().toLowerCase());
  }

  static bool _matchesRegistration(
    bool isRegistered,
    CustomReportFilters filters,
  ) {
    switch (filters.registration) {
      case CustomReportRegistrationFilter.all:
        return true;
      case CustomReportRegistrationFilter.registeredOnly:
        return isRegistered;
      case CustomReportRegistrationFilter.unregisteredOnly:
        return !isRegistered;
    }
  }

  static bool _matchesTracer(bool complete, CustomReportFilters filters) {
    switch (filters.tracer) {
      case CustomReportTracerFilter.all:
        return true;
      case CustomReportTracerFilter.completeOnly:
        return complete;
      case CustomReportTracerFilter.incompleteOnly:
        return !complete;
    }
  }

  static bool _matchesEmploymentStatus(
    String status,
    CustomReportFilters filters,
  ) {
    final lower = status.toLowerCase();
    switch (filters.employment) {
      case CustomReportEmploymentFilter.all:
        return true;
      case CustomReportEmploymentFilter.employedOnly:
        return lower == 'employed';
      case CustomReportEmploymentFilter.unemployedOnly:
        return lower != 'employed';
    }
  }

  static bool _matchesDate(DateTime date, CustomReportFilters filters) {
    if (!filters.hasDateRange) return true;
    final d = DateTime(date.year, date.month, date.day);
    if (filters.dateStart != null) {
      final start = DateTime(
        filters.dateStart!.year,
        filters.dateStart!.month,
        filters.dateStart!.day,
      );
      if (d.isBefore(start)) return false;
    }
    if (filters.dateEnd != null) {
      final end = DateTime(
        filters.dateEnd!.year,
        filters.dateEnd!.month,
        filters.dateEnd!.day,
      );
      if (d.isAfter(end)) return false;
    }
    return true;
  }

  static List<String> _filterSummary(CustomReportFilters filters) {
    final parts = <String>[];
    if (filters.batchYears.isNotEmpty) {
      parts.add('Batch: ${filters.batchYears.join(', ')}');
    }
    if (filters.courses.isNotEmpty) {
      parts.add('Course: ${filters.courses.join(', ')}');
    }
    if (filters.registration != CustomReportRegistrationFilter.all) {
      parts.add('Registration: ${filters.registration.name}');
    }
    if (filters.tracer != CustomReportTracerFilter.all) {
      parts.add('Tracer: ${filters.tracer.name}');
    }
    if (filters.employment != CustomReportEmploymentFilter.all) {
      parts.add('Employment: ${filters.employment.name}');
    }
    if (filters.hasDateRange) {
      final fmt = DateFormat('yyyy-MM-dd');
      final start =
          filters.dateStart != null ? fmt.format(filters.dateStart!) : '…';
      final end = filters.dateEnd != null ? fmt.format(filters.dateEnd!) : '…';
      parts.add('Dates: $start → $end');
    }
    return parts;
  }

  static String _sheetName(CustomReportSectionData section) {
    final raw = section.title
        .replaceAll(RegExp(r'[^A-Za-z0-9 ]'), '')
        .trim()
        .replaceAll(' ', '_');
    if (raw.isEmpty) return section.id.name;
    return raw.length > 28 ? raw.substring(0, 28) : raw;
  }

  static pw.Widget _pdfTable(List<String> headers, List<List<String>> rows) {
    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: rows,
      headerStyle: pw.TextStyle(
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.white,
        fontSize: 8,
      ),
      cellStyle: const pw.TextStyle(fontSize: 8),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blue900),
      cellAlignment: pw.Alignment.centerLeft,
      headerAlignment: pw.Alignment.centerLeft,
    );
  }

  static String _csvRow(List<String> cells) =>
      cells.map(_escCsv).join(',');

  static String _escCsv(String v) {
    final s = v.replaceAll('"', '""');
    if (s.contains(',') || s.contains('"') || s.contains('\n')) {
      return '"$s"';
    }
    return s;
  }
}
