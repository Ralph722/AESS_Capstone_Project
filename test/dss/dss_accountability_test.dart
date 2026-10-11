// DSS Phase 6: owner office, responsible person, dates, evidence and
// cause-specific playbooks.
import 'package:alumni_system/core/services/audit_service.dart';
import 'package:alumni_system/features/admin/dss/application/dss_copy.dart';
import 'package:alumni_system/features/admin/dss/data/dss_repository.dart';
import 'package:alumni_system/features/admin/dss/models/dss_models.dart';
import 'package:alumni_system/features/admin/dss/widgets/admin_dss_ui.dart';
import 'package:alumni_system/features/admin/dss/widgets/dss_accountability_cards.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

DateTime _day(int offset) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day + offset);
}

DssFlag _flag({
  String ruleId = 'UNEMPLOYMENT_HIGH',
  String status = 'open',
  Map<String, dynamic> evidence = const {},
  List<Map<String, dynamic>> playbook = const [],
  String? office,
  String? person,
  String? start,
  String? due,
  String? review,
}) => DssFlag.fromSupabaseRow({
  'id': 'f1',
  'rule_id': ruleId,
  'cohort_level': 'batch',
  'course': 'BSIT',
  'batch_year': '2024',
  'survey_id': 'w',
  'status': status,
  'metric_value': 0.5,
  'threshold_snapshot': 0.25,
  'sample_n': 20,
  'title': 't',
  'evidence': {
    'valid_answers': 20,
    'evidence_strength': 'limited',
    ...evidence,
  },
  'created_at': '2026-10-01T00:00:00Z',
  'updated_at': '2026-10-01T00:00:00Z',
  'owner_office': office,
  'responsible_name': person,
  'start_date': start,
  'due_date': due,
  'review_date': review,
  'dss_rules': {
    'name': ruleId,
    'severity': 'warning',
    'operator': 'gte',
    'min_n': 10,
    'category': ruleId == 'DATA_QUALITY_LOW' ? 'data_quality' : 'outcome',
    'playbook': playbook,
  },
});

const _unemploymentPlaybook = [
  {'step': 'Read Q17'},
  {'cause': 'seeking', 'step': 'Job postings'},
  {'cause': 'not_seeking', 'step': 'Counseling'},
  {'cause': 'default', 'step': 'Review in Reports'},
  {'step': 'Record and recheck'},
];

Map<String, dynamic> _q17(int seeking, int notSeeking, [Map? reasons]) => {
  'q17': {
    'seeking': seeking,
    'not_seeking': notSeeking,
    'reason_unknown': 0,
    'reasons': reasons ?? {},
  },
};

DssRepository _repo() {
  final client = SupabaseClient(
    'http://localhost',
    'test-anon-key',
    authOptions: const AuthClientOptions(autoRefreshToken: false),
  );
  return DssRepository(
    supabase: client,
    auditService: AuditService(supabase: client),
  );
}

Widget _host(Widget child) => MaterialApp(
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

void main() {
  group('flag fields', () {
    test('office, person and dates parse; blanks read as null', () {
      final f = _flag(
        office: ' Alumni Affairs Office ',
        person: '  ',
        start: '2026-03-10',
        due: '2026-04-30',
      );
      expect(f.ownerOffice, 'Alumni Affairs Office');
      expect(f.responsibleName, isNull);
      expect(f.startDate, DateTime(2026, 3, 10));
      expect(f.dueDate, DateTime(2026, 4, 30));
      expect(f.reviewDate, isNull);
    });

    test('databases without the columns parse as empty', () {
      final f = _flag();
      expect(f.ownerOffice, isNull);
      expect(f.dueDate, isNull);
      expect(f.isOverdue(DateTime.now()), isFalse);
    });

    test('overdue only for open and in-progress flags past the due day', () {
      final now = DateTime(2026, 10, 11, 15);
      expect(_flag(due: '2026-10-10').isOverdue(now), isTrue);
      expect(_flag(due: '2026-10-11').isOverdue(now), isFalse);
      expect(_flag(due: '2026-10-11').daysUntilDue(now), 0);
      expect(_flag(due: '2026-10-18').daysUntilDue(now), 7);
      expect(
        _flag(status: 'in_progress', due: '2026-10-01').isOverdue(now),
        isTrue,
      );
      for (final status in ['resolved', 'dismissed', 'watch', 'superseded']) {
        final f = _flag(status: status, due: '2026-10-01');
        expect(f.isOverdue(now), isFalse, reason: status);
        expect(f.daysUntilDue(now), isNull, reason: status);
      }
    });

    test('date column value', () {
      expect(dssDateValue(DateTime(2026, 3, 9, 23, 59)), '2026-03-09');
    });
  });

  group('evidence', () {
    test('row parses; unknown type reads as Other', () {
      final e = DssFlagEvidence.fromSupabaseRow({
        'id': 'e1',
        'flag_id': 'f1',
        'evidence_type': 'meeting',
        'title': 'Dean meeting',
        'evidence_date': '2026-10-05',
        'description': 'Agreed on OJT partners.',
        'link': ' ',
        'created_by_name': 'Admin One',
        'created_at': '2026-10-05T03:00:00Z',
      });
      expect(e.type, DssEvidenceType.meeting);
      expect(e.type.label, 'Meeting / consultation');
      expect(e.date, DateTime(2026, 10, 5));
      expect(e.link, isNull);
      expect(e.isRemoved, isFalse);
      expect(DssEvidenceTypeX.fromDb('photo'), DssEvidenceType.other);
    });

    test('evidence note event type', () {
      expect(DssNoteEventTypeX.fromDb('evidence'), DssNoteEventType.evidence);
      expect(DssNoteEventType.evidence.label, 'Evidence');
    });

    test('link must be a web address', () {
      expect(dssEvidenceLinkError(''), isNull);
      expect(dssEvidenceLinkError('https://drive.example.org/minutes'), isNull);
      expect(dssEvidenceLinkError('http://example.org'), isNull);
      expect(dssEvidenceLinkError('javascript:alert(1)'), isNotNull);
      expect(dssEvidenceLinkError('ftp://example.org/file'), isNotNull);
      expect(dssEvidenceLinkError('https://'), isNotNull);
      expect(dssEvidenceLinkError('https://a.org/x y'), isNotNull);
    });
  });

  group('playbook steps', () {
    test('cause round-trips; untagged steps stay untagged', () {
      final tagged = DssPlaybookStep.fromJson({'cause': 'sparse', 'step': 's'});
      expect(tagged.cause, 'sparse');
      expect(tagged.toJson(), {'step': 's', 'cause': 'sparse'});
      final plain = DssPlaybookStep.fromJson({'step': 'p', 'cause': ''});
      expect(plain.cause, isNull);
      expect(plain.toJson(), {'step': 'p'});
    });

    test('not employed: majority looking for work', () {
      final f = _flag(evidence: _q17(6, 3), playbook: _unemploymentPlaybook);
      expect(DssCopy.playbookCause(f)?.key, 'seeking');
      expect(DssCopy.playbookCause(f)?.label, contains('6 of 9'));
      expect(DssCopy.displayPlaybook(f).map((s) => s.step), [
        'Read Q17',
        'Job postings',
        'Record and recheck',
      ]);
    });

    test('not employed: majority not looking', () {
      final f = _flag(evidence: _q17(1, 4), playbook: _unemploymentPlaybook);
      expect(DssCopy.playbookCause(f)?.key, 'not_seeking');
      expect(
        DssCopy.displayPlaybook(f).map((s) => s.step),
        contains('Counseling'),
      );
    });

    test('a tie or no Q17 facts shows the default steps', () {
      for (final evidence in [_q17(2, 2), const <String, dynamic>{}]) {
        final f = _flag(evidence: evidence, playbook: _unemploymentPlaybook);
        expect(DssCopy.playbookCause(f), isNull);
        expect(DssCopy.displayPlaybook(f).map((s) => s.step), [
          'Read Q17',
          'Review in Reports',
          'Record and recheck',
        ]);
      }
    });

    test('looking for work: the more common Q17 reason picks the steps', () {
      Map<String, dynamic> reasons(int noJob, int noExp) => _q17(5, 0, {
        'No job opportunity': noJob,
        'Lack of work experience': noExp,
      });
      expect(
        DssCopy.playbookCause(
          _flag(ruleId: 'SEEKING_WORK_HIGH', evidence: reasons(4, 1)),
        )?.key,
        'no_opportunity',
      );
      expect(
        DssCopy.playbookCause(
          _flag(ruleId: 'SEEKING_WORK_HIGH', evidence: reasons(1, 3)),
        )?.key,
        'lack_experience',
      );
      expect(
        DssCopy.playbookCause(
          _flag(ruleId: 'SEEKING_WORK_HIGH', evidence: reasons(2, 2)),
        ),
        isNull,
      );
    });

    test('data quality: the stored reason picks the steps', () {
      final f = _flag(
        ruleId: 'DATA_QUALITY_LOW',
        evidence: {'reason': 'sparse'},
        playbook: const [
          {'cause': 'sparse', 'step': 'Invite more'},
          {'cause': 'low_rate', 'step': 'Remind'},
          {'cause': 'default', 'step': 'General'},
        ],
      );
      expect(DssCopy.playbookCause(f)?.key, 'sparse');
      expect(DssCopy.displayPlaybook(f).map((s) => s.step), ['Invite more']);
    });

    test('a detected cause without its own steps falls back to default', () {
      final f = _flag(
        evidence: _q17(6, 1),
        playbook: const [
          {'cause': 'not_seeking', 'step': 'Counseling'},
          {'cause': 'default', 'step': 'General'},
        ],
      );
      expect(DssCopy.displayPlaybook(f).map((s) => s.step), ['General']);
    });

    test('untagged playbooks (older databases) show every step', () {
      final f = _flag(
        evidence: _q17(6, 1),
        playbook: const [
          {'step': 'One'},
          {'step': 'Two'},
        ],
      );
      expect(DssCopy.displayPlaybook(f).map((s) => s.step), ['One', 'Two']);
    });

    test('rules without causes have no cause', () {
      expect(DssCopy.playbookCause(_flag(ruleId: 'RELATEDNESS_LOW')), isNull);
    });
  });

  group('widgets', () {
    testWidgets('open flag: editable, Save waits for a change', (tester) async {
      await tester.pumpWidget(
        _host(
          DssAccountabilityCard(
            flag: _flag(office: 'Curriculum Committee'),
            repository: _repo(),
            onSaved: () async {},
          ),
        ),
      );
      expect(find.text('Curriculum Committee'), findsOneWidget);
      final save = find.widgetWithText(FilledButton, 'Save');
      expect(tester.widget<FilledButton>(save).onPressed, isNull);

      await tester.enterText(
        find.widgetWithText(TextField, 'Responsible person'),
        'Dr. Cruz, Program Chair',
      );
      await tester.pump();
      expect(tester.widget<FilledButton>(save).onPressed, isNotNull);
    });

    testWidgets('a due date before the start blocks Save', (tester) async {
      await tester.pumpWidget(
        _host(
          DssAccountabilityCard(
            flag: _flag(start: '2026-03-10', due: '2026-03-09'),
            repository: _repo(),
            onSaved: () async {},
          ),
        ),
      );
      expect(
        find.text('The due date cannot be before the start date.'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Save'))
            .onPressed,
        isNull,
      );
    });

    testWidgets('resolved flag: read-only summary', (tester) async {
      await tester.pumpWidget(
        _host(
          DssAccountabilityCard(
            flag: _flag(
              status: 'resolved',
              office: 'Guidance & Counseling Office',
              due: '2026-04-30',
            ),
            repository: _repo(),
            onSaved: () async {},
          ),
        ),
      );
      expect(find.byType(TextField), findsNothing);
      expect(find.text('Guidance & Counseling Office'), findsNothing);
      expect(
        find.textContaining('Guidance & Counseling Office', findRichText: true),
        findsOneWidget,
      );
    });

    testWidgets('evidence list: Add and Remove only when editable', (
      tester,
    ) async {
      final entry = DssFlagEvidence(
        id: 'e1',
        flagId: 'f1',
        type: DssEvidenceType.document,
        title: 'Memo to the dean',
        date: DateTime(2026, 10, 5),
        createdAt: DateTime(2026, 10, 5),
        createdByName: 'Admin One',
      );
      Future<void> pump(bool canEdit) => tester.pumpWidget(
        _host(
          DssEvidenceCard(
            entries: [entry],
            canEdit: canEdit,
            busy: false,
            onAdd: () {},
            onRemove: (_) {},
          ),
        ),
      );
      await pump(true);
      expect(find.text('Memo to the dean'), findsOneWidget);
      expect(find.textContaining('Document / memo'), findsOneWidget);
      expect(find.text('Add'), findsOneWidget);
      expect(find.byTooltip('Remove'), findsOneWidget);
      await pump(false);
      expect(find.text('Add'), findsNothing);
      expect(find.byTooltip('Remove'), findsNothing);
    });

    testWidgets('due chip: overdue, due soon, closed', (tester) async {
      Future<void> pump(DssFlag f) =>
          tester.pumpWidget(_host(DssDueChip(flag: f)));
      await pump(_flag(due: dssDateValue(_day(-2))));
      expect(find.text('Overdue 2d'), findsOneWidget);
      await pump(_flag(due: dssDateValue(_day(0))));
      expect(find.text('Due today'), findsOneWidget);
      await pump(_flag(due: dssDateValue(_day(3))));
      expect(find.text('Due in 3d'), findsOneWidget);
      await pump(_flag(due: dssDateValue(_day(30))));
      expect(find.byType(DssMetaChip), findsNothing);
      await pump(_flag(status: 'resolved', due: dssDateValue(_day(-2))));
      expect(find.byType(DssMetaChip), findsNothing);
    });
  });
}
