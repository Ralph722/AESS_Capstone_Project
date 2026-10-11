import 'package:alumni_system/features/surveys/models/current_tracer.dart';
import 'package:alumni_system/features/surveys/models/survey_model.dart';
import 'package:flutter_test/flutter_test.dart';

Survey _survey(
  String id, {
  bool tracer = true,
  DateTime? publishedAt,
  SurveyStatus status = SurveyStatus.published,
  bool archived = false,
}) => Survey(
  id: id,
  title: id,
  description: '',
  status: status,
  targetPrograms: const [],
  targetBatchYears: const [],
  createdBy: 'admin',
  createdAt: DateTime(2020),
  publishedAt: publishedAt,
  kind: tracer ? 'ched_gts_builtin' : null,
  archived: archived,
);

SurveyAssignment _assignment(
  String surveyId, {
  SurveyAssignmentStatus status = SurveyAssignmentStatus.notStarted,
}) => SurveyAssignment(
  id: 'a-$surveyId',
  surveyId: surveyId,
  userId: 'u1',
  surveyTitle: surveyId,
  status: status,
  // Same moment, as when several tracers are auto-assigned at sign-up.
  assignedAt: DateTime(2026, 10, 7),
);

void main() {
  final old = _survey('old', publishedAt: DateTime(2024, 6));
  final current = _survey('current', publishedAt: DateTime(2026, 6));
  final other = _survey('other', tracer: false, publishedAt: DateTime(2027));
  final surveys = {
    for (final s in [old, current, other]) s.id: s,
  };
  Survey? lookup(String id) => surveys[id];

  test('picks the newest tracer regardless of assignment order', () {
    final picked = CurrentTracer.pick([
      _assignment('old'),
      _assignment('other'),
      _assignment('current'),
    ], lookup);
    expect(picked?.surveyId, 'current');
  });

  test('a completed current tracer does not bring back the old one', () {
    final assignments = [
      _assignment('old'),
      _assignment('current', status: SurveyAssignmentStatus.completed),
    ];
    final picked = CurrentTracer.pick(assignments, lookup);
    expect(picked?.surveyId, 'current');
    expect(CurrentTracer.isStale(assignments.first, old, picked), isTrue);
  });

  test('a closed current tracer still outranks an older open one', () {
    final closed = _survey(
      'current',
      publishedAt: DateTime(2026, 6),
      status: SurveyStatus.closed,
    );
    final picked = CurrentTracer.pick([
      _assignment('old'),
      _assignment('current'),
    ], (id) => id == 'current' ? closed : lookup(id));
    expect(picked?.surveyId, 'current');
  });

  test('archived and draft tracers are ignored', () {
    final archived = _survey(
      'current',
      publishedAt: DateTime(2026, 6),
      archived: true,
    );
    final picked = CurrentTracer.pick([
      _assignment('old'),
      _assignment('current'),
    ], (id) => id == 'current' ? archived : lookup(id));
    expect(picked?.surveyId, 'old');

    final draft = _survey(
      'current',
      publishedAt: DateTime(2026, 6),
      status: SurveyStatus.draft,
    );
    expect(
      CurrentTracer.pick([
        _assignment('old'),
        _assignment('current'),
      ], (id) => id == 'current' ? draft : lookup(id))?.surveyId,
      'old',
    );
  });

  test('regular surveys are never stale', () {
    final picked = CurrentTracer.pick([_assignment('current')], lookup);
    expect(CurrentTracer.isStale(_assignment('other'), other, picked), isFalse);
    expect(CurrentTracer.pick([_assignment('other')], lookup), isNull);
  });
}
