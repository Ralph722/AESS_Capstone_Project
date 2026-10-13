import 'package:flutter_test/flutter_test.dart';
import 'package:alumni_system/features/admin/dss/application/dss_metrics.dart';
import 'package:alumni_system/features/admin/dss/application/dss_policy.dart';
import 'package:alumni_system/features/admin/reports/application/gts_alumni_list.dart';
import 'package:alumni_system/features/admin/reports/application/tracer_coverage.dart';
import 'package:alumni_system/features/admin/reports/application/tracer_tab_stats.dart';
import 'package:alumni_system/features/admin/reports/models/gts_list_config.dart';
import 'package:alumni_system/features/admin/reports/models/gts_report_config.dart';
import 'package:alumni_system/features/admin/reports/models/gts_respondent.dart';
import 'package:alumni_system/features/admin/reports/models/reports_dashboard_filters.dart';
import 'package:alumni_system/features/admin/roster/models/alumni_member_model.dart';

AlumniMember _member(
  String name, {
  required String course,
  String batch = '',
  String? uid,
  bool registered = true,
  bool deactivated = false,
}) => AlumniMember(
  id: 'm-$name',
  fullName: name,
  course: course,
  studentId: 'S-$name',
  authUid: uid,
  isRegisteredUser: registered,
  isDeactivated: deactivated,
  batchYear: batch,
  createdAt: DateTime(2020),
);

GtsListResponse _answer(
  String uid,
  String wave,
  Object? item16, {
  required DateTime at,
  Map<String, dynamic> extra = const {},
}) => GtsListResponse(
  userId: uid,
  surveyId: wave,
  responseId: '$uid-$wave-${at.millisecondsSinceEpoch}',
  submittedAt: at,
  answers: {'ched_16': ?item16, ...extra},
);

final _w1 = DateTime(2025, 6);
final _w2 = DateTime(2026, 6);

final roster = [
  _member('Juan Dela Cruz', course: 'BSIT', batch: '2023', uid: 'u1'),
  _member('Maria Santos', course: 'BSIT', batch: '2023', uid: 'u2'),
  _member('Pedro Reyes', course: 'BSCS', batch: '2024', uid: 'u3'),
  _member('Ana Lopez', course: 'BSCS', batch: '2024', uid: 'u4'),
  _member('Jose Rizal', course: 'BSIT', batch: '2024', registered: false),
  _member('Liza Cruz', course: 'BSCS', uid: 'u6'),
  _member(
    'Dan Inactive',
    course: 'BSIT',
    batch: '2023',
    uid: 'u7',
    deactivated: true,
  ),
  _member('Rico Blanco', course: 'BSIT', batch: '2023', uid: 'u8'),
];

final responses = [
  _answer('u1', 'w1', 'No', at: _w1),
  _answer('u1', 'w2', 'Yes', at: _w2),
  _answer('u2', 'w2', 'No', at: _w2),
  _answer('u3', 'w2', 'Never Employed', at: _w2),
  _answer('u4', 'w1', 'Yes', at: _w1),
  _answer('u6', 'w2', 'No', at: _w2),
  _answer('u6', 'w2', ['Yes'], at: _w2.add(const Duration(days: 3))),
  _answer('u7', 'w2', 'Yes', at: _w2, extra: {'ched_1': 'Dan Inactive'}),
  _answer('u8', 'w2', null, at: _w2),
  _answer('u9', 'w2', 'Yes', at: _w2, extra: {'ched_1': 'Off Roster Person'}),
  _answer('u5', 'not-a-tracer', 'Yes', at: _w2),
];

GtsAlumniListResult _build([
  GtsListConfig config = const GtsListConfig(surveyId: 'w2'),
]) => GtsAlumniList.build(
  config,
  roster: roster,
  responses: responses,
  waveIds: const ['w2', 'w1'],
);

List<String> _names(Iterable<GtsListRow> rows) => [
  for (final r in rows) r.name,
];

void main() {
  group('statuses', () {
    test('every active roster alumnus is listed with a tracer status', () {
      final result = _build();
      final byName = {for (final r in result.rows) r.name: r.status};
      expect(byName, {
        'Juan Dela Cruz': GtsTracerStatus.employed,
        'Maria Santos': GtsTracerStatus.notEmployed,
        'Rico Blanco': GtsTracerStatus.statusNotGiven,
        'Ana Lopez': GtsTracerStatus.untrackedRegistered,
        'Jose Rizal': GtsTracerStatus.untrackedNotRegistered,
        'Pedro Reyes': GtsTracerStatus.neverEmployed,
        'Liza Cruz': GtsTracerStatus.employed,
        'Dan Inactive': GtsTracerStatus.offRoster,
        'Off Roster Person': GtsTracerStatus.offRoster,
      });
    });

    test('the latest submission to the wave is used', () {
      final liza = _build().rows.firstWhere((r) => r.name == 'Liza Cruz');
      expect(liza.response!.answers['ched_16'], ['Yes']);
    });

    test('item 16 is read as the DSS reads it', () {
      expect(
        GtsAlumniList.statusOf({'ched_16': ' Yes '}),
        GtsTracerStatus.employed,
      );
      expect(
        GtsAlumniList.statusOf({
          'ched_16': ['Never Employed'],
        }),
        GtsTracerStatus.neverEmployed,
      );
      expect(GtsAlumniList.statusOf({}), GtsTracerStatus.statusNotGiven);
    });

    test('latest answer from any wave', () {
      final result = _build(const GtsListConfig());
      final byName = {for (final r in result.rows) r.name: r};
      expect(byName['Ana Lopez']!.status, GtsTracerStatus.employed);
      expect(byName['Ana Lopez']!.response!.surveyId, 'w1');
      expect(byName['Juan Dela Cruz']!.status, GtsTracerStatus.employed);
      expect(byName['Juan Dela Cruz']!.response!.surveyId, 'w2');
      expect(
        byName['Jose Rizal']!.status,
        GtsTracerStatus.untrackedNotRegistered,
      );
    });

    test('roster cells come from the roster', () {
      final rows = _build().rows;
      final liza = rows.firstWhere((r) => r.name == 'Liza Cruz');
      expect(liza.batch, DssPolicy.batchNotRecorded);
      expect(liza.course, 'BSCS');
      final off = rows.firstWhere((r) => r.name == 'Off Roster Person');
      expect(off.batch, '');
      expect(off.course, '');
      expect(off.respondent!.onActiveRoster, isFalse);
    });
  });

  group('tally', () {
    test('counts, shares and rates', () {
      final t = _build().tally;
      expect(t.total, 7);
      expect(t.answered, 5);
      expect(t.answeredItem16, 4);
      expect(t.count(GtsTracerStatus.employed), 2);
      expect(t.count(GtsTracerStatus.offRoster), 2);
      expect(t.share(GtsTracerStatus.employed), 2 / 7);
      expect(t.share(GtsTracerStatus.offRoster), isNull);
      expect(t.responseRate, 5 / 7);
      expect(t.employmentRate, 0.5);
      expect(t.lines, GtsTracerStatus.values);
    });

    test('optional lines appear only when used', () {
      final t = _build(
        const GtsListConfig(surveyId: 'w2', batches: ['2024']),
      ).tally;
      expect(t.lines, [
        GtsTracerStatus.employed,
        GtsTracerStatus.notEmployed,
        GtsTracerStatus.neverEmployed,
        GtsTracerStatus.untrackedRegistered,
        GtsTracerStatus.untrackedNotRegistered,
      ]);
    });

    test('an empty list has no rates', () {
      final t = GtsListTally(const []);
      expect(t.total, 0);
      expect(t.responseRate, isNull);
      expect(t.employmentRate, isNull);
      expect(t.share(GtsTracerStatus.employed), isNull);
    });

    test('matches the Tracer tab coverage funnel', () {
      final t = _build().tally;
      final coverage = buildTracerCoverage(
        members: roster,
        tracerSubmitterUserIds: {
          for (final r in responses)
            if (r.surveyId == 'w2') r.userId,
        },
        filters: ReportsDashboardFilters.empty,
        surveys: const [],
      );
      expect(t.total, coverage.rosterTotal);
      expect(
        t.count(GtsTracerStatus.untrackedNotRegistered),
        coverage.notRegistered,
      );
      expect(
        t.count(GtsTracerStatus.untrackedRegistered),
        coverage.registeredNoTracer,
      );
      expect(t.answered, coverage.tookTracer);
      expect(t.responseRate, coverage.tracerTakeRateAmongRoster);
    });

    test('matches the Tracer tab employment rate and the DSS', () {
      final result = _build();
      final t = result.tally;
      final memberByAuth = {
        for (final m in roster)
          if (!m.isDeactivated && m.authUid != null) m.authUid!: m,
      };
      final latest = <String, GtsListResponse>{};
      for (final r in responses.where((r) => r.surveyId == 'w2')) {
        final prev = latest[r.userId];
        if (prev == null || r.isLaterThan(prev)) latest[r.userId] = r;
      }
      final stats = TracerTabStats(
        waves: [
          (
            surveyId: 'w2',
            respondents: [
              for (final r in latest.values)
                GtsRespondent(
                  userId: r.userId,
                  surveyId: r.surveyId,
                  answers: r.answers,
                  course: memberByAuth[r.userId]?.course ?? '',
                  yearGraduated: memberByAuth[r.userId]?.batchYear ?? '',
                  onActiveRoster: memberByAuth.containsKey(r.userId),
                ),
            ],
          ),
        ],
        surveyId: 'w2',
      );
      final employment = stats.employment;
      expect(t.count(GtsTracerStatus.employed), TracerTabStats.yes(employment));
      expect(t.answeredItem16, employment.answered);

      final dss = DssMetrics.unemployment([
        for (final r in result.rows)
          if (r.status.onRoster && r.response != null) r.response!.answers,
      ])!;
      expect(t.answeredItem16, dss.total);
      expect(t.employmentRate, 1 - dss.hits / dss.total);
    });
  });

  group('filters and order', () {
    test('default order is batch, then name; off-roster last', () {
      expect(_names(_build().rows), [
        'Juan Dela Cruz',
        'Maria Santos',
        'Rico Blanco',
        'Ana Lopez',
        'Jose Rizal',
        'Pedro Reyes',
        'Liza Cruz',
        'Dan Inactive',
        'Off Roster Person',
      ]);
    });

    test('sort by name, descending', () {
      final rows = _build(
        const GtsListConfig(
          surveyId: 'w2',
          sortBy: GtsListConfig.nameColumn,
          sortDescending: true,
        ),
      ).rows;
      expect(_names(rows).take(3), [
        'Rico Blanco',
        'Pedro Reyes',
        'Maria Santos',
      ]);
      expect(rows.last.status, GtsTracerStatus.offRoster);
    });

    test('course and batch filters ignore case and spaces', () {
      final result = _build(
        const GtsListConfig(
          surveyId: 'w2',
          courses: [' bsit'],
          batches: ['2024'],
        ),
      );
      expect(_names(result.rows), ['Jose Rizal']);
      expect(result.tally.total, 1);
    });

    test('status filter lists the untracked for follow-up', () {
      final rows = _build(
        const GtsListConfig(
          surveyId: 'w2',
          statuses: [
            GtsTracerStatus.untrackedRegistered,
            GtsTracerStatus.untrackedNotRegistered,
          ],
        ),
      ).rows;
      expect(_names(rows), ['Ana Lopez', 'Jose Rizal']);
    });

    test('answer filters keep only graduates who gave that answer', () {
      final rows = _build(
        const GtsListConfig(
          surveyId: 'w2',
          answerFilters: [
            GtsReportFilter(field: 'ched_16', values: ['Yes']),
          ],
        ),
      ).rows;
      expect(_names(rows), [
        'Juan Dela Cruz',
        'Liza Cruz',
        'Dan Inactive',
        'Off Roster Person',
      ]);
    });
  });

  group('subtotals', () {
    test('by batch: one tally per batch, off-roster in none', () {
      final result = _build(
        const GtsListConfig(surveyId: 'w2', subtotalBy: GtsListSubtotal.batch),
      );
      expect(
        [for (final g in result.groups) g.label],
        ['2023', '2024', DssPolicy.batchNotRecorded],
      );
      expect([for (final g in result.groups) g.tally.total], [3, 3, 1]);
      expect(
        result.groups.fold<int>(0, (s, g) => s + g.tally.total),
        result.tally.total,
      );
      final b2024 = result.groups[1].tally;
      expect(b2024.count(GtsTracerStatus.untrackedRegistered), 1);
      expect(b2024.count(GtsTracerStatus.untrackedNotRegistered), 1);
      expect(b2024.count(GtsTracerStatus.neverEmployed), 1);
    });

    test('by course', () {
      final result = _build(
        const GtsListConfig(surveyId: 'w2', subtotalBy: GtsListSubtotal.course),
      );
      expect([for (final g in result.groups) g.label], ['BSCS', 'BSIT']);
      expect([for (final g in result.groups) g.tally.total], [3, 4]);
    });

    test('none by default', () {
      expect(_build().groups, isEmpty);
    });
  });

  group('settings', () {
    test('round-trip as JSON with the list mode', () {
      const config = GtsListConfig(
        surveyId: 'w2',
        columns: ['year_graduated', 'name', 'ched_16', 'ched_19'],
        courses: ['BSIT'],
        batches: ['2023'],
        statuses: [GtsTracerStatus.employed],
        answerFilters: [
          GtsReportFilter(field: 'ched_18', values: ['Contractual']),
        ],
        subtotalBy: GtsListSubtotal.course,
        sortBy: 'name',
        sortDescending: true,
        title: 'Employed IT graduates',
      );
      final json = config.toJson();
      expect(json['mode'], 'list');
      expect(GtsListConfig.isList(json), isTrue);
      expect(GtsListConfig.fromJson(json).toJson(), json);
    });

    test('latest from any wave stores no wave', () {
      final json = const GtsListConfig().toJson();
      expect(json.containsKey('surveyId'), isFalse);
      final back = GtsListConfig.fromJson(json);
      expect(back.latestFromAnyWave, isTrue);
      expect(back.columns, GtsListConfig.defaultColumns);
    });

    test('new lists include the tracer status column', () {
      expect(
        const GtsListConfig().columns,
        contains(GtsListConfig.statusColumn),
      );
    });

    test('summary settings and newer versions are refused', () {
      final summary = const GtsReportConfig(
        surveyIds: ['w2'],
        measure: 'ched_16',
      ).toJson();
      expect(GtsListConfig.isList(summary), isFalse);
      expect(() => GtsListConfig.fromJson(summary), throwsFormatException);
      expect(
        () => GtsListConfig.fromJson({
          ...const GtsListConfig().toJson(),
          'version': GtsListConfig.currentVersion + 1,
        }),
        throwsFormatException,
      );
    });

    test('unknown statuses in saved settings are skipped', () {
      final back = GtsListConfig.fromJson({
        ...const GtsListConfig().toJson(),
        'statuses': ['employed', 'retired'],
      });
      expect(back.statuses, [GtsTracerStatus.employed]);
    });
  });
}
