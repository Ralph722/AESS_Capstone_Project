// Safety checks used by seed_demo.dart. No I/O here, so every guard is
// covered by test/demo_data/demo_guards_test.dart without a network.
import 'dart:convert';

import 'demo_dataset.dart';
import 'demo_scenarios.dart';

class DemoGuardException implements Exception {
  const DemoGuardException(this.message);

  final String message;

  @override
  String toString() => message;
}

class DemoTarget {
  const DemoTarget(this.projectRef, this.url, this.serviceRoleKey);

  final String projectRef;
  final String url;
  final String serviceRoleKey;
}

final _projectRefPattern = RegExp(r'^[a-z]{20}$');

Map<String, String> parseEnvFile(String contents) {
  final env = <String, String>{};
  for (final raw in const LineSplitter().convert(contents)) {
    final line = raw.trim();
    if (line.isEmpty || line.startsWith('#') || !line.contains('=')) continue;
    final i = line.indexOf('=');
    env[line.substring(0, i).trim()] = line
        .substring(i + 1)
        .trim()
        .replaceAll(RegExp(r'''^["']|["']$'''), '');
  }
  return env;
}

/// Validates `supabase/.env.demo`. Error messages never include the key.
DemoTarget demoTargetFromEnv(Map<String, String> env) {
  final ref = env['DEMO_PROJECT_REF'] ?? '';
  final url = env['DEMO_SUPABASE_URL'] ?? '';
  final key = env['DEMO_SERVICE_ROLE_KEY'] ?? '';
  if (ref.isEmpty || url.isEmpty || key.isEmpty) {
    throw const DemoGuardException(
      'supabase/.env.demo needs DEMO_PROJECT_REF, DEMO_SUPABASE_URL and '
      'DEMO_SERVICE_ROLE_KEY.',
    );
  }
  final claims = jwtClaims(key);
  if (ref == liveProjectRef ||
      url.contains(liveProjectRef) ||
      claims['ref'] == liveProjectRef) {
    throw const DemoGuardException(
      'Refusing to run: this points at the live project.',
    );
  }
  if (!_projectRefPattern.hasMatch(ref)) {
    throw const DemoGuardException(
      'DEMO_PROJECT_REF is not a Supabase project ref (20 lowercase letters).',
    );
  }
  final uri = Uri.tryParse(url);
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.host != '$ref.supabase.co' ||
      (uri.path.isNotEmpty && uri.path != '/') ||
      uri.hasQuery) {
    throw DemoGuardException(
      'DEMO_SUPABASE_URL must be https://$ref.supabase.co',
    );
  }
  if (claims['role'] != 'service_role' || claims['ref'] != ref) {
    throw DemoGuardException(
      'DEMO_SERVICE_ROLE_KEY is not the legacy service_role key of project '
      '$ref.',
    );
  }
  return DemoTarget(ref, 'https://$ref.supabase.co', key);
}

Map<String, dynamic> jwtClaims(String jwt) {
  final parts = jwt.split('.');
  if (parts.length != 3) return const {};
  try {
    final payload = utf8.decode(
      base64Url.decode(base64Url.normalize(parts[1])),
    );
    final decoded = jsonDecode(payload);
    return decoded is Map<String, dynamic> ? decoded : const {};
  } on FormatException {
    return const {};
  }
}

bool isDemoEmail(String? email) =>
    (email ?? '').trim().toLowerCase().endsWith('@$demoEmailDomain');

/// Stops when the target holds any account outside the demo domain. Such
/// accounts are never changed; the script simply refuses to run.
void requireDemoOnlyAccounts(Iterable<String?> emails) {
  final others = emails.where((e) => !isDemoEmail(e)).length;
  if (others > 0) {
    throw DemoGuardException(
      'Refusing to run: the target has $others account(s) outside '
      '@$demoEmailDomain, so it is not a demo-only project.',
    );
  }
}

/// Typed before `--reset` deletes anything.
String resetConfirmationPhrase(String projectRef) =>
    'DELETE DEMO DATA $projectRef';

/// Rows that already use a demo wave ID must be demo waves.
List<String> waveIdConflicts(List<Map<String, dynamic>> waveRows) {
  final titles = {for (final w in demoWaves) w.id: w.title};
  return [
    for (final row in waveRows)
      if (titles.containsKey(row['id']) && row['title'] != titles[row['id']])
        'Survey ${row['id']} uses a demo wave ID but is titled '
            '"${row['title']}". It was not created by the seed script.',
  ];
}

/// Reasons `--seed` must stop before writing anything. The seed replays the
/// history from the roster import onward, so it needs a project without
/// demo data.
List<String> seedBlockers({
  required List<Map<String, dynamic>> waveRows,
  required bool hasNonDemoRosterRows,
  required bool hasDemoData,
}) => [
  ...waveIdConflicts(waveRows),
  if (hasNonDemoRosterRows)
    'The roster has rows whose student ID does not start with '
        '"$demoStudentIdPrefix". The demo project must not hold real alumni '
        'records.',
  if (hasDemoData)
    'The demo project already holds demo data (roster rows, waves or '
        'alumni accounts). Run --reset first; the seed rebuilds the history '
        'from the start.',
];

/// Dedupe key of the admin's "New alumni registration" notice, as
/// `notify_admins_new_registration` writes it.
String registrationNoticeKey(String userId) => 'user:$userId:registered';

/// Exactly what `--reset` would delete. Ownership is proven by the dataset:
/// account emails, roster student IDs and the fixed wave IDs. Anything else
/// is left alone, and foreign data on demo waves stops the reset.
class DemoResetPlan {
  DemoResetPlan._({
    required this.flagIds,
    required this.responseIds,
    required this.assignmentIds,
    required this.eventIds,
    required this.auditLogIds,
    required this.noticeIds,
    required this.waveIds,
    required this.rosterIds,
    required this.accountIds,
    required this.responsesOnOtherSurveys,
    required this.untouchedRosterRows,
    required this.untouchedAccounts,
    required this.blockers,
  });

  factory DemoResetPlan.build({
    required DemoDataset dataset,
    required List<({String id, String? email})> accounts,
    required List<Map<String, dynamic>> waveRows,
    required List<Map<String, dynamic>> flagRows,
    required List<Map<String, dynamic>> responseRows,
    required List<Map<String, dynamic>> assignmentRows,
    required List<Map<String, dynamic>> eventRows,
    required List<Map<String, dynamic>> auditRows,
    required List<Map<String, dynamic>> noticeRows,
    required List<Map<String, dynamic>> demoRosterRows,
  }) {
    final ownedEmails = {
      for (final m in dataset.accounts) m.email!.toLowerCase(),
    };
    final ownedAccounts = {
      for (final a in accounts)
        if (ownedEmails.contains((a.email ?? '').trim().toLowerCase())) a.id,
    };
    final demoWaveIds = {for (final w in demoWaves) w.id};
    final ownedStudentIds = {
      for (final m in dataset.rosterMembers) m.studentId,
    };

    final blockers = waveIdConflicts(waveRows);
    final responseIds = <String>{};
    var otherSurveys = 0;
    var foreign = 0;
    for (final r in responseRows) {
      final onDemoWave = demoWaveIds.contains(r['survey_id']);
      if (ownedAccounts.contains(r['user_id'])) {
        if (responseIds.add(r['id'] as String) && !onDemoWave) otherSurveys++;
      } else if (onDemoWave) {
        foreign++;
      }
    }
    if (foreign > 0) {
      blockers.add(
        '$foreign response(s) on demo waves belong to accounts outside the '
        'demo dataset. Remove them by hand first; reset will not.',
      );
    }

    final rosterIds = <String>[];
    var untouchedRoster = 0;
    for (final r in demoRosterRows) {
      if (ownedStudentIds.contains(r['student_id'])) {
        rosterIds.add(r['id'] as String);
      } else {
        untouchedRoster++;
      }
    }

    final noticeKeys = {for (final id in ownedAccounts) registrationNoticeKey(id)};

    List<String> ownedRows(List<Map<String, dynamic>> rows) => [
      for (final r in rows)
        if (ownedAccounts.contains(r['user_id'])) r['id'] as String,
    ];

    return DemoResetPlan._(
      flagIds: [
        for (final f in flagRows)
          if (demoWaveIds.contains(f['survey_id'])) f['id'] as String,
      ],
      responseIds: responseIds.toList(),
      assignmentIds: ownedRows(assignmentRows),
      eventIds: ownedRows(eventRows),
      auditLogIds: ownedRows(auditRows),
      noticeIds: [
        for (final n in noticeRows)
          if (noticeKeys.contains(n['dedupe_key'])) n['id'] as String,
      ],
      waveIds: [
        for (final w in waveRows)
          if (demoWaveIds.contains(w['id']) && waveIdConflicts([w]).isEmpty)
            w['id'] as String,
      ],
      rosterIds: rosterIds,
      accountIds: ownedAccounts.toList(),
      responsesOnOtherSurveys: otherSurveys,
      untouchedRosterRows: untouchedRoster,
      untouchedAccounts: accounts.length - ownedAccounts.length,
      blockers: blockers,
    );
  }

  final List<String> flagIds;
  final List<String> responseIds;
  final List<String> assignmentIds;
  final List<String> eventIds;

  /// Activity logs of demo accounts. Deleting an account would keep them
  /// with an empty owner, so they go first.
  final List<String> auditLogIds;

  /// The admin's "New alumni registration" notices about demo accounts.
  final List<String> noticeIds;
  final List<String> waveIds;
  final List<String> rosterIds;
  final List<String> accountIds;
  final int responsesOnOtherSurveys;
  final int untouchedRosterRows;
  final int untouchedAccounts;
  final List<String> blockers;

  bool get isEmpty =>
      flagIds.isEmpty &&
      responseIds.isEmpty &&
      assignmentIds.isEmpty &&
      eventIds.isEmpty &&
      auditLogIds.isEmpty &&
      noticeIds.isEmpty &&
      waveIds.isEmpty &&
      rosterIds.isEmpty &&
      accountIds.isEmpty;

  List<String> preview() => [
    'DSS findings on demo waves: ${flagIds.length}',
    'Survey responses by demo accounts: ${responseIds.length} '
        '($responsesOnOtherSurveys on non-demo surveys)',
    'Survey assignments of demo accounts: ${assignmentIds.length}',
    'Response events of demo accounts: ${eventIds.length}',
    'Activity logs of demo accounts: ${auditLogIds.length}',
    'Admin "new registration" notices about demo accounts: '
        '${noticeIds.length}',
    'Demo waves: ${waveIds.length}',
    'Demo roster rows: ${rosterIds.length}',
    'Demo alumni accounts: ${accountIds.length}',
    'Left untouched: $untouchedAccounts other account(s) (including the demo '
        'admin), $untouchedRosterRows "$demoStudentIdPrefix" roster row(s) '
        'not in the dataset.',
  ];
}
