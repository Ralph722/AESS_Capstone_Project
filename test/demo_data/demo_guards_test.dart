import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/demo_data/demo_dataset.dart';
import '../../tool/demo_data/demo_guards.dart';
import '../../tool/demo_data/demo_scenarios.dart';

const _ref = 'abcdefghijklmnopqrst';

String _jwt(Map<String, Object> claims) =>
    'e30.${base64Url.encode(utf8.encode(jsonEncode(claims))).replaceAll('=', '')}.sig';

Map<String, String> _env({String ref = _ref, String? url, String? key}) => {
  'DEMO_PROJECT_REF': ref,
  'DEMO_SUPABASE_URL': url ?? 'https://$ref.supabase.co',
  'DEMO_SERVICE_ROLE_KEY': key ?? _jwt({'role': 'service_role', 'ref': ref}),
};

Matcher _refused(String text) => throwsA(
  isA<DemoGuardException>().having((e) => e.message, 'message', contains(text)),
);

void main() {
  group('demo target', () {
    test('a complete demo config is accepted', () {
      final target = demoTargetFromEnv(_env());
      expect(target.projectRef, _ref);
      expect(target.url, 'https://$_ref.supabase.co');
    });

    test('missing values fail', () {
      expect(() => demoTargetFromEnv(const {}), _refused('needs'));
      expect(
        () => demoTargetFromEnv({..._env(), 'DEMO_SERVICE_ROLE_KEY': ''}),
        _refused('needs'),
      );
    });

    test('the live project is refused by ref, URL or key', () {
      expect(
        () => demoTargetFromEnv(_env(ref: liveProjectRef)),
        _refused('live project'),
      );
      expect(
        () =>
            demoTargetFromEnv(_env(url: 'https://$liveProjectRef.supabase.co')),
        _refused('live project'),
      );
      expect(
        () => demoTargetFromEnv(
          _env(key: _jwt({'role': 'service_role', 'ref': liveProjectRef})),
        ),
        _refused('live project'),
      );
    });

    test('the URL must be exactly the demo project', () {
      for (final url in [
        'https://other0000000000000000.supabase.co',
        'http://$_ref.supabase.co',
        'https://$_ref.supabase.co.evil.example',
        'https://$_ref.supabase.co/rest/v1',
      ]) {
        expect(() => demoTargetFromEnv(_env(url: url)), _refused('must be'));
      }
      expect(
        demoTargetFromEnv(_env(url: 'https://$_ref.supabase.co/')).url,
        'https://$_ref.supabase.co',
      );
    });

    test('placeholder refs are refused', () {
      expect(
        () => demoTargetFromEnv(_env(ref: 'your-demo-project-ref')),
        _refused('not a Supabase project ref'),
      );
    });

    test('only the matching service-role key is accepted', () {
      for (final key in [
        _jwt({'role': 'anon', 'ref': _ref}),
        _jwt({'role': 'service_role', 'ref': 'zyxwvutsrqponmlkjihg'}),
        'sb_secret_abc',
        'not-a-jwt',
      ]) {
        expect(
          () => demoTargetFromEnv(_env(key: key)),
          _refused('service_role key'),
        );
      }
    });

    test('errors never include the key', () {
      const secret = 'eyJhbGciOiJIUzI1NiJ9.eyJyb2xlIjoiYW5vbiJ9.TOPSECRET';
      try {
        demoTargetFromEnv(_env(key: secret));
        fail('expected a refusal');
      } on DemoGuardException catch (e) {
        expect(e.message, isNot(contains('TOPSECRET')));
      }
    });

    test('the env file parser ignores comments and quotes', () {
      final env = parseEnvFile(
        '# comment\nDEMO_PROJECT_REF="$_ref"\n\nDEMO_SUPABASE_URL=x\n',
      );
      expect(env, {'DEMO_PROJECT_REF': _ref, 'DEMO_SUPABASE_URL': 'x'});
    });
  });

  group('accounts and confirmation', () {
    test('any non-demo account stops the script, case-insensitively', () {
      requireDemoOnlyAccounts(['admin@demo.aess.test', 'A1@DEMO.AESS.TEST']);
      expect(
        () => requireDemoOnlyAccounts(['admin@demo.aess.test', 'x@ustp.edu']),
        _refused('1 account(s) outside'),
      );
      expect(() => requireDemoOnlyAccounts([null]), _refused('outside'));
    });

    test('the reset phrase names the project', () {
      expect(resetConfirmationPhrase(_ref), 'DELETE DEMO DATA $_ref');
    });
  });

  group('seed preflight', () {
    test('a fresh or demo-only project passes', () {
      expect(
        seedBlockers(
          waveRows: [
            {'id': demoWaves.first.id, 'title': demoWaves.first.title},
          ],
          hasNonDemoRosterRows: false,
          hasDemoData: false,
        ),
        isEmpty,
      );
    });

    test('a foreign survey on a demo wave ID or real roster rows stop it', () {
      final blockers = seedBlockers(
        waveRows: [
          {'id': demoWaves.first.id, 'title': 'Real tracer'},
        ],
        hasNonDemoRosterRows: true,
        hasDemoData: false,
      );
      expect(blockers, hasLength(2));
    });

    test('existing demo data stops it until --reset', () {
      final blockers = seedBlockers(
        waveRows: const [],
        hasNonDemoRosterRows: false,
        hasDemoData: true,
      );
      expect(blockers.single, contains('Run --reset first'));
    });
  });

  group('reset plan', () {
    final dataset = DemoDataset.build();
    final owned = dataset.accounts.take(2).toList();
    final wave = demoWaves.first;
    const otherSurvey = '00000000-0000-4000-8000-000000000001';

    DemoResetPlan plan({
      List<Map<String, dynamic>> extraResponses = const [],
      List<Map<String, dynamic>> waveRows = const [],
    }) => DemoResetPlan.build(
      dataset: dataset,
      accounts: [
        (id: 'u-admin', email: demoAdminEmail),
        (id: 'u-1', email: owned[0].email),
        (id: 'u-2', email: owned[1].email!.toUpperCase()),
        (id: 'u-extra', email: 'alumni99@demo.aess.test'),
      ],
      waveRows: waveRows.isEmpty
          ? [
              {'id': wave.id, 'title': wave.title},
            ]
          : waveRows,
      flagRows: [
        {'id': 'f-1', 'survey_id': wave.id},
        {'id': 'f-2', 'survey_id': otherSurvey},
      ],
      responseRows: [
        {'id': 'r-1', 'survey_id': wave.id, 'user_id': 'u-1'},
        {'id': 'r-2', 'survey_id': otherSurvey, 'user_id': 'u-2'},
        {'id': 'r-3', 'survey_id': otherSurvey, 'user_id': 'u-extra'},
        ...extraResponses,
      ],
      assignmentRows: [
        {'id': 'a-1', 'user_id': 'u-1'},
        {'id': 'a-2', 'user_id': 'u-extra'},
      ],
      eventRows: [
        {'id': 'e-1', 'user_id': 'u-2'},
        {'id': 'e-2', 'user_id': 'u-admin'},
      ],
      auditRows: [
        {'id': 'l-1', 'user_id': 'u-1'},
        {'id': 'l-2', 'user_id': 'u-admin'},
        {'id': 'l-3', 'user_id': 'u-extra'},
      ],
      noticeRows: [
        {'id': 'n-1', 'dedupe_key': registrationNoticeKey('u-2')},
        {'id': 'n-2', 'dedupe_key': registrationNoticeKey('u-extra')},
      ],
      demoRosterRows: [
        {'id': 'm-1', 'student_id': dataset.rosterMembers.first.studentId},
        {'id': 'm-2', 'student_id': 'DEMO-HAND-MADE-001'},
      ],
    );

    test('deletes only rows proven to belong to the dataset', () {
      final p = plan();
      expect(p.blockers, isEmpty);
      expect(p.accountIds, unorderedEquals(['u-1', 'u-2']));
      expect(p.responseIds, unorderedEquals(['r-1', 'r-2']));
      expect(p.responsesOnOtherSurveys, 1);
      expect(p.assignmentIds, ['a-1']);
      expect(p.eventIds, ['e-1']);
      expect(p.auditLogIds, ['l-1']);
      expect(p.noticeIds, ['n-1']);
      expect(p.flagIds, ['f-1']);
      expect(p.waveIds, [wave.id]);
      expect(p.rosterIds, ['m-1']);
      expect(p.untouchedAccounts, 2);
      expect(p.untouchedRosterRows, 1);
      expect(p.preview(), hasLength(10));
    });

    test('foreign responses on a demo wave stop the reset', () {
      final p = plan(
        extraResponses: [
          {'id': 'r-9', 'survey_id': wave.id, 'user_id': 'u-extra'},
        ],
      );
      expect(p.blockers.single, contains('outside the demo dataset'));
    });

    test('a non-demo survey using a demo wave ID is kept and stops reset', () {
      final p = plan(
        waveRows: [
          {'id': wave.id, 'title': 'Real tracer'},
        ],
      );
      expect(p.waveIds, isEmpty);
      expect(p.blockers.single, contains('not created by the seed'));
    });
  });
}
