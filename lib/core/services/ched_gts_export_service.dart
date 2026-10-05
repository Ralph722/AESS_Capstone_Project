import 'dart:typed_data';

import 'package:excel/excel.dart' hide Border;
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:alumni_system/features/surveys/data/ched_survey_template_seed.dart';
import 'package:alumni_system/features/surveys/ched_gts/ched_gts_form.dart';
import 'package:alumni_system/features/surveys/ched_gts/ched_gts_schema.dart';
import 'package:alumni_system/features/alumni/tracer/models/id_tracer_model.dart';
import 'package:alumni_system/features/surveys/models/survey_model.dart';
import 'package:alumni_system/features/alumni/tracer/models/tracer_profile_model.dart';

/// CHED-aligned Excel export: tracer sections A/B + employment tracer + survey C/D.
class ChedGtsExportService {
  ChedGtsExportService({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  final SupabaseClient _supabase;
  static final _dateFmt = DateFormat('yyyy-MM-dd');
  static final _dateTimeFmt = DateFormat('yyyy-MM-dd HH:mm');

  Future<Uint8List?> buildExcelBytes({
    required Survey survey,
    required List<SurveyQuestion> questions,
    required List<SurveyParticipant> participants,
  }) async {
    final submitted = participants
        .where((p) => !p.isPending && p.response != null)
        .toList();
    if (submitted.isEmpty) return null;

    final userIds = submitted.map((p) => p.assignment.userId).toList();
    final profiles = await _loadProfiles(userIds);
    final employmentByUser = await _loadEmploymentByUserId();

    final excel = Excel.createExcel();
    // Use the template's Sheet1 for README (rename/delete mutates unmodifiable XML).
    _buildReadmeSheet(excel, survey, submitted.length, participants.length);
    _buildSectionASheet(excel, submitted, profiles);
    _buildSectionBSheet(excel, submitted, profiles);
    _buildEmploymentTracerSheet(excel, submitted, employmentByUser);
    if (survey.isChedGtsBuiltin) {
      _buildBuiltinLongSheet(excel, survey, submitted);
      _buildBuiltinWideSheet(excel, submitted);
    } else {
      _buildSurveyLongSheet(excel, survey, questions, submitted);
      _buildSurveyWideSheet(excel, questions, submitted);
    }

    final bytes = excel.save();
    if (bytes == null) return null;
    return Uint8List.fromList(bytes);
  }

  Future<Map<String, TracerProfile>> _loadProfiles(List<String> userIds) async {
    final map = <String, TracerProfile>{};
    if (userIds.isEmpty) return map;
    final rows = await _supabase
        .from('users')
        .select()
        .inFilter('id', userIds.toSet().toList());
    for (final row in rows) {
      map[row['id'] as String] = TracerProfile.fromSupabaseRow(row);
    }
    return map;
  }

  Future<Map<String, EmploymentRecord>> _loadEmploymentByUserId() async {
    final rows = await _supabase.from('gts_employment_records').select();
    final map = <String, EmploymentRecord>{};
    for (final row in rows) {
      final record = EmploymentRecord.fromSupabaseRow(row);
      map[record.userId] = record;
    }
    return map;
  }

  void _buildReadmeSheet(
    Excel excel,
    Survey survey,
    int submittedCount,
    int assignedCount,
  ) {
    final sheet = excel['Sheet1'];
    final rows = <List<String>>[
      ['CHED GTS export — Alumni System'],
      ['Generated', _dateTimeFmt.format(DateTime.now())],
      ['Survey title', survey.title],
      ['Survey ID', survey.id],
      ['Template ID', survey.templateKey ?? survey.templateId ?? '(custom / blank)'],
      ['Template version', survey.schemaVersion ?? survey.templateVersion ?? '—'],
      ['Survey kind', survey.kind ?? (survey.isChedGtsBuiltin ? ChedGtsBuiltin.kind : 'custom')],
      ['Assigned alumni', '$assignedCount'],
      ['Submitted responses', '$submittedCount'],
      [''],
      ['Disclaimer'],
      [ChedSurveyTemplateSeed.disclaimer],
      [''],
      ['Sheet guide'],
      ['A_General', 'Tracer demographics (CHED section A, items 1–11)'],
      ['B_Education', 'Tracer education fields (CHED section B)'],
      [
        'Employment_Tracer',
        'Alumni Tracer employment record (supports section D)',
      ],
      ['Survey_C_D', 'Long format: one row per CHED survey answer'],
      ['Survey_Wide', 'One row per alumni; columns per survey question'],
      [''],
      ['Note', 'Verify all fields before official CHED submission.'],
    ];
    for (final row in rows) {
      sheet.appendRow(row);
    }
  }

  void _buildSectionASheet(
    Excel excel,
    List<SurveyParticipant> submitted,
    Map<String, TracerProfile> profiles,
  ) {
    final sheet = excel['A_General'];
    sheet.appendRow([
      'User ID',
      'CHED Item',
      'Field',
      'Value',
      'Name',
      'Email',
      'Program',
      'Batch',
    ]);

    final fields =
        <(String item, String label, String Function(TracerProfile) get)>[
          ('1', 'Name', (p) => p.displayName),
          ('2', 'Permanent Address', (p) => p.address),
          ('3', 'E-mail Address', (p) => p.email),
          ('4', 'Telephone / Contact', (p) => p.contactNumber),
          ('5', 'Mobile Number', (p) => p.contactNumber),
          ('6', 'Civil Status', (p) => p.civilStatus),
          ('7', 'Sex', (p) => p.gender),
          ('8', 'Birthday', (p) => _formatDate(p.birthDate)),
          ('9', 'Region of Origin', (_) => ''),
          ('10', 'Province', (_) => ''),
          ('11', 'Location of Residence', (_) => ''),
        ];

    for (final p in submitted) {
      final uid = p.assignment.userId;
      final profile = profiles[uid];
      if (profile == null) {
        sheet.appendRow([
          uid,
          '—',
          '(no tracer profile)',
          '',
          p.displayName,
          p.email,
          p.program,
          p.batchYear,
        ]);
        continue;
      }
      for (final field in fields) {
        sheet.appendRow([
          uid,
          field.$1,
          field.$2,
          field.$3(profile),
          profile.displayName,
          profile.email,
          profile.program,
          profile.batchYear,
        ]);
      }
    }
  }

  void _buildSectionBSheet(
    Excel excel,
    List<SurveyParticipant> submitted,
    Map<String, TracerProfile> profiles,
  ) {
    final sheet = excel['B_Education'];
    sheet.appendRow([
      'User ID',
      'CHED Item',
      'Field',
      'Value',
      'Name',
      'Program',
      'Batch',
      'Year Graduated',
      'Student ID',
    ]);

    for (final p in submitted) {
      final uid = p.assignment.userId;
      final profile = profiles[uid];
      if (profile == null) continue;

      final rows = <(String item, String label, String value)>[
        ('12', 'Degree / Program (Baccalaureate)', profile.program),
        (
          '12',
          'Year Graduated',
          profile.yearGraduated.isNotEmpty
              ? profile.yearGraduated
              : profile.batchYear,
        ),
        (
          '12',
          'College or University',
          'See institution code on official form',
        ),
        ('13', 'Professional Examination(s)', '(not in tracer — add manually)'),
        ('14', 'Reason(s) for taking course', '(not in tracer — add manually)'),
      ];

      for (final row in rows) {
        sheet.appendRow([
          uid,
          row.$1,
          row.$2,
          row.$3,
          profile.displayName,
          profile.program,
          profile.batchYear,
          profile.yearGraduated,
          profile.studentId,
        ]);
      }
    }
  }

  void _buildEmploymentTracerSheet(
    Excel excel,
    List<SurveyParticipant> submitted,
    Map<String, EmploymentRecord> employmentByUser,
  ) {
    final sheet = excel['Employment_Tracer'];
    sheet.appendRow([
      'User ID',
      'Name',
      'Email',
      'Program',
      'Batch',
      'Employment Status',
      'Company',
      'Position',
      'Industry',
      'Employment Type',
      'Salary Range (tracer)',
      'City',
      'Province',
      'Country',
      'Submitted At',
      'Verification',
    ]);

    for (final p in submitted) {
      final uid = p.assignment.userId;
      final emp = employmentByUser[uid];
      sheet.appendRow([
        uid,
        p.displayName,
        p.email,
        p.program,
        p.batchYear,
        emp?.employmentStatus ?? '',
        emp?.companyName ?? '',
        emp?.position ?? '',
        emp?.industry ?? '',
        emp?.employmentType ?? '',
        emp?.salaryRange ?? '',
        emp?.city ?? '',
        emp?.province ?? '',
        emp?.country ?? '',
        emp != null ? _formatDateTime(emp.submittedAt) : '',
        emp?.verificationStatus ?? '',
      ]);
    }
  }

  void _buildSurveyLongSheet(
    Excel excel,
    Survey survey,
    List<SurveyQuestion> questions,
    List<SurveyParticipant> submitted,
  ) {
    final sheet = excel['Survey_C_D'];
    sheet.appendRow([
      'User ID',
      'Name',
      'Email',
      'Program',
      'Batch',
      'Section',
      'CHED Item',
      'Question',
      'Answer',
      'Response Status',
      'Submitted At',
      'Survey Title',
      'Template ID',
    ]);

    final sortedQuestions = List<SurveyQuestion>.from(questions)
      ..sort((a, b) => a.order.compareTo(b.order));

    for (final p in submitted) {
      final r = p.response!;
      for (final q in sortedQuestions) {
        sheet.appendRow([
          p.assignment.userId,
          p.displayName,
          p.email,
          p.program,
          p.batchYear,
          q.section ?? '',
          q.chedItemNumber ?? '',
          q.prompt,
          _formatAnswer(r.answers[q.id]),
          r.status.name,
          _formatDateTime(r.submittedAt ?? r.updatedAt),
          survey.title,
          survey.templateId ?? '',
        ]);
      }
    }
  }

  void _buildSurveyWideSheet(
    Excel excel,
    List<SurveyQuestion> questions,
    List<SurveyParticipant> submitted,
  ) {
    final sheet = excel['Survey_Wide'];
    final sortedQuestions = List<SurveyQuestion>.from(questions)
      ..sort((a, b) => a.order.compareTo(b.order));

    final headers = <String>[
      'User ID',
      'Name',
      'Email',
      'Program',
      'Batch',
      'Submitted At',
      ...sortedQuestions.map(_questionColumnHeader),
    ];
    sheet.appendRow(headers);

    for (final p in submitted) {
      final r = p.response!;
      sheet.appendRow([
        p.assignment.userId,
        p.displayName,
        p.email,
        p.program,
        p.batchYear,
        _formatDateTime(r.submittedAt ?? r.updatedAt),
        ...sortedQuestions.map((q) => _formatAnswer(r.answers[q.id])),
      ]);
    }
  }

  void _buildBuiltinLongSheet(
    Excel excel,
    Survey survey,
    List<SurveyParticipant> submitted,
  ) {
    final sheet = excel['Survey_C_D'];
    sheet.appendRow([
      'User ID',
      'Name',
      'Email',
      'Program',
      'Batch',
      'Section',
      'CHED Item',
      'Question',
      'Answer',
      'Response Status',
      'Submitted At',
      'Survey Title',
      'Template Key',
      'Schema Version',
    ]);

    for (final p in submitted) {
      final r = p.response!;
      for (final item in ChedGtsBuiltin.items) {
        if (item.isOthersSpecify && r.answers[item.id] == null) continue;
        final itemObj = item;
        sheet.appendRow([
          p.assignment.userId,
          p.displayName,
          p.email,
          p.program,
          p.batchYear,
          itemObj.sectionTitle,
          itemObj.chedNumber,
          itemObj.prompt,
          formatChedGtsAnswer(itemObj, r.answers[itemObj.id]),
          r.status.name,
          _formatDateTime(r.submittedAt ?? r.updatedAt),
          survey.title,
          survey.templateKey ?? ChedGtsBuiltin.templateKey,
          survey.schemaVersion ?? ChedGtsBuiltin.schemaVersion,
        ]);
      }
    }
  }

  void _buildBuiltinWideSheet(
    Excel excel,
    List<SurveyParticipant> submitted,
  ) {
    final sheet = excel['Survey_Wide'];
    final items = ChedGtsBuiltin.items
        .where((i) => !i.isOthersSpecify)
        .toList();
    final headers = <String>[
      'User ID',
      'Name',
      'Email',
      'Program',
      'Batch',
      'Submitted At',
      ...items.map((i) {
        final short = i.prompt.length > 40
            ? '${i.prompt.substring(0, 40)}…'
            : i.prompt;
        return '[${i.chedNumber}] $short';
      }),
    ];
    sheet.appendRow(headers);

    for (final p in submitted) {
      final r = p.response!;
      sheet.appendRow([
        p.assignment.userId,
        p.displayName,
        p.email,
        p.program,
        p.batchYear,
        _formatDateTime(r.submittedAt ?? r.updatedAt),
        ...items.map((i) => formatChedGtsAnswer(i, r.answers[i.id])),
      ]);
    }
  }

  static String _questionColumnHeader(SurveyQuestion q) {
    final item = q.chedItemNumber;
    if (item != null && item.isNotEmpty) {
      final short = q.prompt.length > 40
          ? '${q.prompt.substring(0, 40)}…'
          : q.prompt;
      return '[$item] $short';
    }
    return q.prompt.length > 60 ? '${q.prompt.substring(0, 60)}…' : q.prompt;
  }

  static String _formatAnswer(dynamic value) {
    if (value == null) return '';
    if (value is List) {
      return value.map((e) => e.toString()).join('; ');
    }
    return value.toString();
  }

  static String _formatDate(DateTime? d) => d == null ? '' : _dateFmt.format(d);

  static String _formatDateTime(DateTime d) => _dateTimeFmt.format(d);
}
