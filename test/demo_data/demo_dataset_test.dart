import 'dart:convert';

import 'package:alumni_system/core/constants/gts_constants.dart';
import 'package:alumni_system/features/admin/dss/application/dss_metrics.dart';
import 'package:alumni_system/features/surveys/ched_gts/ched_gts_schema.dart';
import 'package:alumni_system/features/surveys/ched_gts/ched_gts_visibility.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../tool/demo_data/demo_dataset.dart';
import '../../tool/demo_data/demo_scenarios.dart';

String _fingerprint(DemoDataset d) => jsonEncode({
  'members': [
    for (final m in d.members)
      [
        m.key,
        m.studentId,
        m.fullName,
        m.course,
        m.batch,
        m.email,
        m.canLogIn,
        m.registeredAt?.toIso8601String(),
      ],
  ],
  'responses': [
    for (final r in d.responses)
      [
        r.memberKey,
        r.waveKey,
        r.submittedAt.toIso8601String(),
        r.answers,
        r.device.category,
        r.device.platform,
        r.device.browser,
      ],
  ],
});

void main() {
  final dataset = DemoDataset.build();

  test('build is deterministic', () {
    expect(_fingerprint(DemoDataset.build()), _fingerprint(dataset));
  });

  test('totals match docs/demo-data-plan.md', () {
    expect(demoWaves, hasLength(3));
    expect(dataset.rosterMembers, hasLength(238));
    expect(dataset.accounts, hasLength(195));
    expect(dataset.responses, hasLength(224));
    expect(dataset.hostedAccounts, hasLength(192));
    expect(dataset.hostedResponses, hasLength(221));
  });

  test('the hosted demo leaves out respondents off the roster', () {
    expect(dataset.hostedAccounts.every((m) => m.onRoster), isTrue);
    expect(
      dataset.hostedResponses.any((r) => r.cohortKey == 'off-roster'),
      isFalse,
    );
    expect(
      dataset.hostedAssignments.every((a) => dataset.isHosted(a.memberKey)),
      isTrue,
    );
    expect(dataset.registrationOrder, hasLength(192));
  });

  test('registered alumni: every respondent plus a quarter of the roster', () {
    for (final cohort in demoCohorts.where((c) => c.onRoster)) {
      final registered = dataset.accounts
          .where((m) => m.cohortKey == cohort.key)
          .length;
      expect(registered, cohort.registered, reason: cohort.key);
      expect(registered, greaterThanOrEqualTo(cohort.respondentsMax));
      expect(registered, lessThanOrEqualTo(cohort.roster));
    }
  });

  group('timeline follows the app flow', () {
    test('registration after the roster import and graduation', () {
      for (final m in dataset.accounts) {
        final at = m.registeredAt!;
        expect(at.isAfter(demoRosterImportedAt), isTrue, reason: m.key);
        expect(at.isBefore(demoSnapshot), isTrue, reason: m.key);
        if (m.batch != null) {
          final graduated = DateTime.utc(int.parse(m.batch!), 6);
          expect(at.isAfter(graduated), isTrue, reason: m.key);
        }
        expect(m.onboardedAt.isAfter(at), isTrue, reason: m.key);
      }
    });

    test('respondents register at least a week before their first answer', () {
      for (final m in dataset.accounts) {
        final first = dataset.responsesOf(m).firstOrNull;
        if (first == null) continue;
        expect(
          first.submittedAt.difference(m.registeredAt!).inDays,
          greaterThanOrEqualTo(7),
          reason: m.key,
        );
      }
    });

    test('responses and their events happen inside the wave, in order', () {
      for (final r in dataset.responses) {
        final wave = dataset.waveByKey(r.waveKey);
        expect(r.openedAt.isAfter(wave.openAt), isTrue);
        expect(r.submittedAt.isBefore(wave.closeAt), isTrue);
        expect(r.submittedAt.isBefore(demoSnapshot), isTrue);
        expect(r.events.map((e) => e.type), [
          'opened',
          'draft_saved',
          'submitted',
        ]);
        for (var i = 1; i < r.events.length; i++) {
          expect(r.events[i].at.isAfter(r.events[i - 1].at), isTrue);
        }
      }
    });

    test('activity logs come from registration, onboarding and logins', () {
      final byAction = <String, int>{};
      for (final a in dataset.activities) {
        byAction[a.action] = (byAction[a.action] ?? 0) + 1;
        expect(a.at.isBefore(demoSnapshot), isTrue);
      }
      expect(byAction, {
        'REGISTER': dataset.accounts.length,
        'COMPLETE_ONBOARDING': dataset.accounts.length,
        'LOGIN': dataset.responses.length,
      });
    });
  });

  group('assignments', () {
    final assignments = dataset.assignments;

    test('hosted counts per wave', () {
      ({int assigned, int completed}) wave(String key) {
        final rows = dataset.hostedAssignments
            .where((a) => a.waveKey == key)
            .toList();
        return (
          assigned: rows.length,
          completed: rows.where((a) => a.completed).length,
        );
      }

      expect(wave('w2024'), (assigned: 33, completed: 25));
      expect(wave('w2025'), (assigned: 173, completed: 146));
      expect(wave('w2026'), (assigned: 192, completed: 50));
    });

    test('a wave goes to everyone registered before it closes', () {
      final keys = {for (final a in assignments) '${a.memberKey}|${a.waveKey}'};
      expect(keys, hasLength(assignments.length));
      for (final m in dataset.accounts) {
        for (final w in demoWaves) {
          expect(
            keys.contains('${m.key}|${w.key}'),
            m.registeredAt!.isBefore(w.closeAt),
            reason: '${m.key} ${w.key}',
          );
        }
      }
      for (final a in assignments) {
        final m = dataset.memberByKey(a.memberKey);
        final w = dataset.waveByKey(a.waveKey);
        final expected = m.registeredAt!.isAfter(w.openAt)
            ? m.registeredAt!
            : w.openAt;
        expect(a.assignedAt, expected);
      }
    });

    test('the open wave is assigned to every registered alumnus', () {
      final open = demoWaves.singleWhere((w) => w.status == 'published');
      final assigned = {
        for (final a in dataset.hostedAssignments)
          if (a.waveKey == open.key) a.memberKey,
      };
      expect(assigned, {for (final m in dataset.hostedAccounts) m.key});
    });

    test('completed exactly when the wave was answered', () {
      final answered = {
        for (final r in dataset.responses) '${r.memberKey}|${r.waveKey}',
      };
      final completed = {
        for (final a in assignments)
          if (a.completed) '${a.memberKey}|${a.waveKey}',
      };
      expect(completed, answered);
    });

    test('respondents never had the wave before their first answer', () {
      for (final m in dataset.accounts) {
        final first = dataset.responsesOf(m).firstOrNull;
        if (first == null) continue;
        final firstOpen = dataset.waveByKey(first.waveKey).openAt;
        final earlier = assignments.where(
          (a) =>
              a.memberKey == m.key &&
              dataset.waveByKey(a.waveKey).openAt.isBefore(firstOpen),
        );
        expect(earlier, isEmpty, reason: m.key);
      }
    });
  });

  group('profiles match onboarding and the latest tracer', () {
    test('every hosted profile is complete', () {
      for (final m in dataset.hostedAccounts) {
        final row = dataset.profileFor(m, uid: 'u').toSupabaseRow();
        expect(row['tracer_profile_complete'], isTrue, reason: m.key);
        expect(row['tracer_profile_completion'], 100, reason: m.key);
      }
    });

    test('Section A, education and employment equal the latest answers', () {
      for (final m in dataset.hostedAccounts) {
        final latest = dataset.latestResponseOf(m);
        if (latest == null) continue;
        final a = latest.answers;
        final row = dataset.profileFor(m, uid: 'u').toSupabaseRow();
        final edu = (a['ched_12'] as List).first as Map;
        expect(row['display_name'], a['ched_1'], reason: m.key);
        expect(row['address'], a['ched_2'], reason: m.key);
        expect(row['email'], a['ched_3'], reason: m.key);
        expect(row['telephone_number'], a['ched_4'], reason: m.key);
        expect(row['mobile_number'], a['ched_5'], reason: m.key);
        expect(row['civil_status'], a['ched_6'], reason: m.key);
        expect(row['gender'], a['ched_7'], reason: m.key);
        expect(row['birth_date'], a['ched_8'], reason: m.key);
        expect(row['region_of_origin'], a['ched_9'], reason: m.key);
        expect(row['province'], a['ched_10'], reason: m.key);
        expect(row['location_of_residence'], a['ched_11'], reason: m.key);
        expect(row['college_university'], edu['College or University']);
        expect(row['year_graduated'], edu['Year Graduated']);
        expect(row['honors_awards'], edu['Honor(s) or Award(s) Received']);
        expect(
          row['employment_status'],
          GtsConstants.fromChedPresentlyEmployed(a['ched_16'] as String),
          reason: m.key,
        );
        expect(row['program'], m.course);
        expect(row['student_id'], m.studentId);
      }
    });

    test('the college is the one onboarding pre-fills', () {
      for (final m in dataset.hostedAccounts) {
        expect(
          dataset.profileFor(m).collegeUniversity,
          GtsConstants.defaultCollegeUniversity,
        );
      }
    });

    test('members without a batch type one at onboarding', () {
      for (final m in dataset.hostedAccounts.where(
        (m) => m.cohortKey == 'bsit-nobatch',
      )) {
        expect(m.batch, isNull);
        expect(dataset.profileFor(m).yearGraduated, demoTypedBatch);
      }
    });
  });

  group('retention rules mirror the nightly jobs', () {
    final now = DateTime.utc(2026, 10, 10, 12);

    test('activity logs: 90 days for logins, a year for the rest', () {
      final day91 = now.subtract(const Duration(days: 91));
      final day89 = now.subtract(const Duration(days: 89));
      expect(DemoDataset.keptByAuditRetention('LOGIN', day91, now), isFalse);
      expect(DemoDataset.keptByAuditRetention('LOGIN', day89, now), isTrue);
      expect(DemoDataset.keptByAuditRetention('REGISTER', day91, now), isTrue);
      expect(
        DemoDataset.keptByAuditRetention(
          'REGISTER',
          DateTime.utc(2025, 10, 10, 11),
          now,
        ),
        isFalse,
      );
    });

    test('notifications: read after 90 days or any after 180 days go', () {
      final day100 = now.subtract(const Duration(days: 100));
      final day200 = now.subtract(const Duration(days: 200));
      expect(
        DemoDataset.keptByNotificationCleanup(day100, read: true, now: now),
        isFalse,
      );
      expect(
        DemoDataset.keptByNotificationCleanup(day100, read: false, now: now),
        isTrue,
      );
      expect(
        DemoDataset.keptByNotificationCleanup(day200, read: false, now: now),
        isFalse,
      );
    });

    test('notifications are read when acted on, or once a month old', () {
      final recent = demoSnapshot.subtract(const Duration(days: 3));
      final old = demoSnapshot.subtract(const Duration(days: 40));
      final acted = recent.add(const Duration(hours: 1));
      expect(DemoDataset.notificationReadAt(recent), isNull);
      expect(DemoDataset.notificationReadAt(recent, actedAt: acted), acted);
      expect(
        DemoDataset.notificationReadAt(old),
        old.add(const Duration(hours: 2)),
      );
    });
  });

  group('scenario definitions', () {
    for (final cohort in demoCohorts) {
      for (final spec in cohort.waves) {
        test('${cohort.key} ${spec.wave} is consistent', () {
          expect(spec.reasons.total, spec.notEmployed);
          expect(spec.neverEmployed, lessThanOrEqualTo(spec.notEmployed));
          for (final n in [
            spec.mismatch,
            spec.clerical,
            spec.longWait + spec.q29Others,
            spec.lowSalary,
            spec.abroad,
            spec.suggestions,
          ]) {
            expect(n, lessThanOrEqualTo(spec.employed));
          }
          if (cohort.onRoster) {
            expect(spec.respondents, lessThanOrEqualTo(cohort.roster));
          }
          expect(demoWaves.map((w) => w.key), contains(spec.wave));
        });
      }
    }
  });

  group('responses look like real submissions', () {
    test('no missing required items and no hidden answers', () {
      for (final r in dataset.responses) {
        expect(
          ChedGtsVisibility.missingRequired(r.answers),
          isEmpty,
          reason: '${r.memberKey} ${r.waveKey}',
        );
        expect(
          ChedGtsVisibility.pruneHiddenAnswers(r.answers).keys.toSet(),
          r.answers.keys.toSet(),
          reason: '${r.memberKey} ${r.waveKey}',
        );
      }
    });

    test('every choice is an official CHED option', () {
      for (final r in dataset.responses) {
        for (final entry in r.answers.entries) {
          final item = ChedGtsBuiltin.byId(entry.key);
          expect(item, isNotNull, reason: entry.key);
          final value = entry.value;
          switch (item!.type) {
            case ChedGtsFieldType.single:
              expect(item.options, contains(value), reason: entry.key);
            case ChedGtsFieldType.multi:
              for (final v in value as List) {
                expect(item.options, contains(v), reason: entry.key);
              }
            case ChedGtsFieldType.matrix:
              for (final row in (value as Map).entries) {
                expect(item.matrixRows, contains(row.key), reason: entry.key);
                for (final col in (row.value as Map).keys) {
                  expect(item.matrixColumns, contains(col), reason: entry.key);
                }
              }
            case ChedGtsFieldType.tableRows:
              for (final row in value as List) {
                for (final col in (row as Map).keys) {
                  expect(item.tableColumns, contains(col), reason: entry.key);
                }
              }
            case ChedGtsFieldType.date:
              expect(DateTime.tryParse(value as String), isNotNull);
            case ChedGtsFieldType.text:
            case ChedGtsFieldType.longText:
              expect((value as String).trim(), isNotEmpty, reason: entry.key);
          }
        }
      }
    });

    test('one response per alumnus per wave', () {
      final seen = <String>{};
      for (final r in dataset.responses) {
        expect(seen.add('${r.memberKey}|${r.waveKey}'), isTrue);
      }
    });
  });

  group('demo markers', () {
    test('every account uses the demo email domain', () {
      final emails = dataset.accounts.map((m) => m.email!).toList();
      expect(emails.toSet(), hasLength(emails.length));
      for (final e in emails) {
        expect(e.endsWith('@$demoEmailDomain'), isTrue, reason: e);
      }
      expect(demoAdminEmail.endsWith('@$demoEmailDomain'), isTrue);
    });

    test('roster rows use demo student IDs and real program codes', () {
      final ids = dataset.rosterMembers.map((m) => m.studentId).toList();
      expect(ids.toSet(), hasLength(ids.length));
      for (final m in dataset.rosterMembers) {
        expect(m.studentId.startsWith(demoStudentIdPrefix), isTrue);
        expect(demoProgramNames.keys, contains(m.course));
      }
    });

    test('three demo alumni can log in', () {
      final logins = dataset.members.where((m) => m.canLogIn).toList();
      expect(logins.map((m) => m.email), [
        'alumni1@$demoEmailDomain',
        'alumni2@$demoEmailDomain',
        'alumni3@$demoEmailDomain',
      ]);
    });

    test('wave IDs are fixed and titled as demo', () {
      for (final w in demoWaves) {
        expect(w.title.startsWith('[DEMO]'), isTrue);
        expect(
          RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-'
            r'[0-9a-f]{12}$',
          ).hasMatch(w.id),
          isTrue,
        );
      }
    });
  });

  group('group mapping cases', () {
    test('batch not recorded stays on the roster with a course', () {
      final m = dataset.members.where((m) => m.cohortKey == 'bsit-nobatch');
      expect(m, isNotEmpty);
      for (final member in m) {
        expect(member.onRoster, isTrue);
        expect(member.course, 'BSIT');
        expect(member.batch, isNull);
      }
    });

    test('respondents off the roster have no course, batch or roster row', () {
      final m = dataset.members.where((m) => m.cohortKey == 'off-roster');
      expect(m, hasLength(3));
      for (final member in m) {
        expect(member.onRoster, isFalse);
        expect(member.course, isEmpty);
        expect(member.batch, isNull);
        expect(member.studentId, isEmpty);
        expect(member.hasAccount, isTrue);
      }
    });

    test('BFPT 2024 has a roster but no responses', () {
      expect(
        dataset.members.where((m) => m.cohortKey == 'bfpt-2024'),
        hasLength(15),
      );
      expect(
        dataset.responses.where((r) => r.cohortKey == 'bfpt-2024'),
        isEmpty,
      );
    });
  });

  test('each wave matches its scenario counts', () {
    for (final cohort in demoCohorts) {
      for (final spec in cohort.waves) {
        final answers = dataset.answersFor(cohort.key, spec.wave);
        expect(answers, hasLength(spec.respondents), reason: cohort.key);
        final share = DssMetrics.unemployment(answers)!;
        expect(share.hits, spec.notEmployed, reason: cohort.key);
        expect(share.total, spec.respondents, reason: cohort.key);
        final never = answers
            .where((a) => a['ched_16'] == ChedGtsBuiltin.neverEmployed)
            .length;
        expect(never, spec.neverEmployed, reason: cohort.key);
      }
    }
  });
}
