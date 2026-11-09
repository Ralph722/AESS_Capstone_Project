import 'package:flutter_test/flutter_test.dart';
import 'package:alumni_system/features/admin/reports/application/tracer_coverage.dart';
import 'package:alumni_system/features/admin/reports/models/reports_dashboard_filters.dart';
import 'package:alumni_system/features/admin/roster/models/alumni_member_model.dart';
import 'package:alumni_system/features/surveys/models/survey_model.dart';

AlumniMember _member({
  required String id,
  required DateTime createdAt,
  String? authUid,
  bool registered = false,
}) {
  return AlumniMember(
    id: id,
    fullName: id,
    course: 'BSIT',
    studentId: id,
    authUid: authUid,
    isRegisteredUser: registered,
    createdAt: createdAt,
  );
}

Survey _wave({
  required String id,
  DateTime? openAt,
  DateTime? publishedAt,
  DateTime? createdAt,
}) {
  return Survey(
    id: id,
    title: 'Wave $id',
    description: '',
    status: SurveyStatus.published,
    createdBy: 'admin',
    createdAt: createdAt ?? DateTime.utc(2024, 1, 1),
    updatedAt: createdAt ?? DateTime.utc(2024, 1, 1),
    openAt: openAt,
    publishedAt: publishedAt,
    templateKey: 'ched_gts_builtin',
  );
}

void main() {
  final early = _member(
    id: 'early',
    createdAt: DateTime.utc(2023, 6, 1),
    authUid: 'u-early',
    registered: true,
  );
  final mid = _member(
    id: 'mid',
    createdAt: DateTime.utc(2024, 6, 1),
    authUid: 'u-mid',
    registered: true,
  );
  final late = _member(
    id: 'late',
    createdAt: DateTime.utc(2025, 6, 1),
    authUid: 'u-late',
    registered: true,
  );
  final unregisteredEarly = _member(
    id: 'unreg',
    createdAt: DateTime.utc(2023, 1, 1),
  );

  final wave2024 = _wave(
    id: 'w2024',
    openAt: DateTime.utc(2024, 6, 1),
    publishedAt: DateTime.utc(2024, 5, 20),
  );

  test('all waves keep the current alumni list', () {
    final coverage = buildTracerCoverage(
      members: [early, mid, late, unregisteredEarly],
      tracerSubmitterUserIds: {'u-early', 'u-mid'},
      filters: ReportsDashboardFilters.empty,
      surveys: [wave2024],
    );

    expect(coverage.scopedToWave, isFalse);
    expect(coverage.rosterTotal, 4);
    expect(coverage.registered, 3);
    expect(coverage.tookTracer, 2);
    expect(coverage.notRegistered, 1);
  });

  test('one wave counts only alumni already on the list when it opened', () {
    final coverage = buildTracerCoverage(
      members: [early, mid, late, unregisteredEarly],
      tracerSubmitterUserIds: {'u-early', 'u-mid', 'u-late'},
      filters: const ReportsDashboardFilters(surveyId: 'w2024'),
      surveys: [wave2024],
    );

    expect(coverage.scopedToWave, isTrue);
    // early + mid + unregisteredEarly; late joined after open
    expect(coverage.rosterTotal, 3);
    expect(coverage.registered, 2);
    expect(coverage.tookTracer, 2);
    expect(coverage.notRegistered, 1);
    expect(coverage.definition, contains('2024-06-01'));
  });

  test('falls back to publishedAt when openAt is missing', () {
    final wave = _wave(
      id: 'w-pub',
      publishedAt: DateTime.utc(2024, 3, 15),
    );
    final coverage = buildTracerCoverage(
      members: [
        _member(id: 'before', createdAt: DateTime.utc(2024, 3, 15)),
        _member(id: 'after', createdAt: DateTime.utc(2024, 3, 16)),
      ],
      tracerSubmitterUserIds: const {},
      filters: const ReportsDashboardFilters(surveyId: 'w-pub'),
      surveys: [wave],
    );

    expect(coverage.rosterTotal, 1);
    expect(coverage.scopedToWave, isTrue);
  });
}
