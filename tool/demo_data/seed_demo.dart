// Seeds or resets the separate demo Supabase project. See
// docs/demo-data-plan.md.
//
//   dart run tool/demo_data/seed_demo.dart --dry-run
//   dart run tool/demo_data/seed_demo.dart --seed --confirm-demo
//   dart run tool/demo_data/seed_demo.dart --reset --confirm-demo
//   dart run tool/demo_data/seed_demo.dart --admin-password --confirm-demo
//
// Reads only supabase/.env.demo. Refuses to touch the live project or any
// database that holds accounts outside the demo email domain. --seed replays
// the history from the roster import, so it needs a project without demo
// data: run --reset first.
import 'dart:io';

import 'package:alumni_system/features/auth/data/password_policy.dart';
import 'package:alumni_system/features/surveys/ched_gts/ched_gts_schema.dart';
import 'package:supabase/supabase.dart';

import 'demo_dataset.dart';
import 'demo_guards.dart';
import 'demo_scenarios.dart';

const _envPath = 'supabase/.env.demo';

/// PostgREST returns at most this many rows per request.
const _maxRows = 1000;

Future<void> main(List<String> args) async {
  try {
    await _run(args);
  } on DemoGuardException catch (e) {
    _fail(e.message);
  } on PostgrestException catch (e) {
    _fail('Stopped on a database error: ${e.message}');
  } on AuthException catch (e) {
    _fail('Stopped on an Auth error: ${e.message}');
  }
}

Future<void> _run(List<String> args) async {
  final dryRun = args.contains('--dry-run');
  final seed = args.contains('--seed');
  final reset = args.contains('--reset');
  final adminPassword = args.contains('--admin-password');
  if ([dryRun, seed, reset, adminPassword].where((m) => m).length != 1) {
    _fail(
      'Choose exactly one of --dry-run, --seed, --reset or --admin-password.',
    );
  }

  final dataset = DemoDataset.build();
  _printPlan(dataset);
  final envFile = File(_envPath);
  if (!envFile.existsSync()) {
    if (dryRun) {
      stdout.writeln('No $_envPath yet. Dry run: nothing was written.');
      return;
    }
    _fail('Missing $_envPath. Copy $_envPath.example and fill it in.');
  }
  final target = demoTargetFromEnv(parseEnvFile(envFile.readAsStringSync()));
  stdout.writeln('Target demo project: ${target.projectRef} (${target.url})');
  if (dryRun) {
    stdout.writeln('Dry run: nothing was written.');
    return;
  }

  if (!args.contains('--confirm-demo')) {
    _fail('Add --confirm-demo to write to the demo project.');
  }
  _confirmProjectRef(target.projectRef, args);

  final client = SupabaseClient(
    target.url,
    target.serviceRoleKey,
    authOptions: const AuthClientOptions(autoRefreshToken: false),
  );
  try {
    final users = await _listAllUsers(client);
    requireDemoOnlyAccounts(users.map((u) => u.email));
    if (seed) {
      await _seed(client, dataset, users);
    } else if (adminPassword) {
      await _setAdminPassword(client, users);
    } else {
      await _reset(client, dataset, users, target.projectRef);
    }
  } finally {
    await client.dispose();
  }
}

void _confirmProjectRef(String ref, List<String> args) {
  final flag = args.firstWhere(
    (a) => a.startsWith('--confirm-ref='),
    orElse: () => '',
  );
  String typed;
  if (flag.isNotEmpty) {
    typed = flag.substring('--confirm-ref='.length);
  } else {
    if (!stdin.hasTerminal) {
      _fail('Run in a terminal, or pass --confirm-ref=<demo project ref>.');
    }
    stdout.write('Type the demo project ref to continue: ');
    typed = stdin.readLineSync()?.trim() ?? '';
  }
  if (typed != ref) _fail('Project ref did not match. Nothing was written.');
}

Future<List<User>> _listAllUsers(SupabaseClient client) async {
  final all = <User>[];
  for (var page = 1; ; page++) {
    final batch = await client.auth.admin.listUsers(page: page, perPage: 500);
    all.addAll(batch);
    if (batch.length < 500) return all;
  }
}

Future<List<Map<String, dynamic>>> _demoWaveRows(SupabaseClient client) =>
    client.from('surveys').select('id, title').inFilter('id', [
      for (final w in demoWaves) w.id,
    ]);

/// Replays the app's flow from the roster import onward: roster, waves,
/// registration (account, then roster link, which lets the database
/// auto-assign the open wave), onboarding, publish history, survey activity,
/// then back-dates what the triggers stamped with the current time.
Future<void> _seed(
  SupabaseClient client,
  DemoDataset dataset,
  List<User> existing,
) async {
  final byEmail = {for (final u in existing) u.email!.toLowerCase(): u};

  final programs = await client.from('programs').select('code');
  final codes = programs.map((p) => p['code'] as String).toSet();
  final missing = demoProgramNames.keys.where((c) => !codes.contains(c));
  if (missing.isNotEmpty) {
    _fail('Programs missing in the demo project: ${missing.join(', ')}.');
  }
  final nonDemoRoster = await client
      .from('alumni_members')
      .select('id')
      .not('student_id', 'like', '$demoStudentIdPrefix%')
      .limit(1);
  final demoRoster = await client
      .from('alumni_members')
      .select('id')
      .like('student_id', '$demoStudentIdPrefix%')
      .limit(1);
  final waveRows = await _demoWaveRows(client);
  final blockers = seedBlockers(
    waveRows: waveRows,
    hasNonDemoRosterRows: nonDemoRoster.isNotEmpty,
    hasDemoData:
        demoRoster.isNotEmpty ||
        waveRows.isNotEmpty ||
        dataset.accounts.any((m) => byEmail.containsKey(m.email)),
  );
  if (blockers.isNotEmpty) {
    _fail('Nothing was written.\n${blockers.join('\n')}');
  }

  final adminPassword = _askPassword(
    'Password for $demoAdminEmail',
    required: !byEmail.containsKey(demoAdminEmail),
  );
  final alumniPassword = _askPassword(
    'Password for the 3 demo alumni logins',
    required: true,
  );
  final now = DateTime.now().toUtc();
  final order = dataset.registrationOrder;
  final waveIds = {for (final w in dataset.waves) w.key: w.id};
  final openWave = dataset.waves.singleWhere((w) => w.status == 'published');
  final responseByKey = {
    for (final r in dataset.hostedResponses) '${r.memberKey}|${r.waveKey}': r,
  };

  stdout.writeln('1/9 Demo admin...');
  final adminId = await _ensureAccount(
    client,
    byEmail,
    email: demoAdminEmail,
    displayName: 'Demo Admin',
    password: adminPassword,
  );
  await client.from('users').upsert({
    'id': adminId,
    'email': demoAdminEmail,
    'display_name': 'Demo Admin',
    'role': 'admin',
    'onboarding_complete': true,
    'created_at': _iso(demoAdminCreatedAt),
  }, onConflict: 'id');

  stdout.writeln(
    '2/9 Importing the roster (${_iso(demoRosterImportedAt)}), unlinked...',
  );
  final rosterIds = <String, String>{};
  final rosterRows = [
    for (final m in dataset.rosterMembers)
      {
        'full_name': m.fullName,
        'course': m.course,
        'student_id': m.studentId,
        'year_graduated': m.batch,
        'created_at': _iso(demoRosterImportedAt),
        'updated_at': _iso(demoRosterImportedAt),
      },
  ];
  for (final chunk in _rowChunks(rosterRows, 100)) {
    final inserted = await client
        .from('alumni_members')
        .insert(chunk)
        .select('id, student_id');
    for (final r in inserted) {
      rosterIds[r['student_id'] as String] = r['id'] as String;
    }
  }

  stdout.writeln('3/9 Creating the waves...');
  await client.from('surveys').insert([
    for (final w in dataset.waves)
      {
        'id': w.id,
        'title': w.title,
        'description': ChedGtsBuiltin.defaultDescription,
        'status': w.status,
        'open_at': _iso(w.openAt),
        'close_at': _iso(w.closeAt),
        'created_by': adminId,
        'target_programs': <String>[],
        'target_batch_years': <String>[],
        'created_at': _iso(w.openAt.subtract(const Duration(days: 10))),
        'updated_at': _iso(w.status == 'closed' ? w.closeAt : w.openAt),
        'data': {
          'kind': ChedGtsBuiltin.kind,
          'template_key': ChedGtsBuiltin.templateKey,
          'schema_version': ChedGtsBuiltin.schemaVersion,
          'publishedAt': _iso(w.openAt),
          'visibility_rules': <String, dynamic>{},
          'archived': false,
          'autoAssignNewAlumni': true,
          'aiHelpEnabled': true,
        },
      },
  ]);

  stdout.writeln(
    '4/9 Registering ${order.length} alumni (confirmed account, then roster '
    'link)...',
  );
  final userIds = <String, String>{};
  for (var i = 0; i < order.length; i++) {
    final m = order[i];
    userIds[m.key] = await _ensureAccount(
      client,
      byEmail,
      email: m.email!,
      displayName: m.fullName,
      password: m.canLogIn ? alumniPassword : null,
    );
    if ((i + 1) % 25 == 0) stdout.writeln('    ${i + 1}/${order.length}');
  }
  // Same columns link_alumni_registration writes. The database then copies
  // course, ID and batch to the profile and assigns the open wave.
  await _inParallel(order, (m) async {
    await client
        .from('alumni_members')
        .update({
          'is_registered_user': true,
          'auth_uid': userIds[m.key],
          'registered_email': m.email!.toLowerCase(),
        })
        .eq('id', rosterIds[m.studentId]!);
  });

  stdout.writeln('5/9 Onboarding (profile, roster contact details)...');
  final profileRows = {
    for (final m in order)
      m.key: {
        ...dataset.profileFor(m, uid: userIds[m.key]!).toSupabaseRow(),
        'role': 'user',
        'onboarding_complete': true,
        'created_at': _iso(m.registeredAt!),
        'last_active_at': _iso(dataset.lastActiveAt(m)),
      },
  };
  for (final chunk in _rowChunks(profileRows.values.toList(), 100)) {
    await client.from('users').upsert(chunk, onConflict: 'id');
  }
  // Same columns syncRosterFromTracerProfile and
  // flagProfileUpdatedForAuthUid write; older changes were already viewed.
  await _inParallel(order, (m) async {
    final row = profileRows[m.key]!;
    final viewed = dataset.adminViewedAt(m);
    await client
        .from('alumni_members')
        .update({
          'contact_number': row['mobile_number'],
          'email_address': row['email'],
          'address': row['address'],
          'gender': row['gender'],
          'civil_status': row['civil_status'],
          'birth_date': row['birth_date'],
          'tracer_profile_complete': row['tracer_profile_complete'],
          'has_profile_updates': viewed == null,
          'admin_viewed_at': viewed == null ? null : _iso(viewed),
          'last_active_at': _iso(dataset.lastActiveAt(m)),
        })
        .eq('id', rosterIds[m.studentId]!);
  });

  stdout.writeln('6/9 Publish history: assigning the closed waves...');
  final closedRows = [
    for (final a in dataset.hostedAssignments)
      if (dataset.waveByKey(a.waveKey).status == 'closed')
        {
          'survey_id': waveIds[a.waveKey],
          'user_id': userIds[a.memberKey],
          'survey_title': dataset.waveByKey(a.waveKey).title,
          'status': a.completed ? 'completed' : 'notStarted',
          'assigned_at': _iso(a.assignedAt),
          'created_at': _iso(a.assignedAt),
          'updated_at': _iso(
            a.completed
                ? responseByKey['${a.memberKey}|${a.waveKey}']!.submittedAt
                : a.assignedAt,
          ),
        },
  ];
  for (final chunk in _rowChunks(closedRows, 100)) {
    await client.from('survey_assignments').insert(chunk);
  }

  stdout.writeln('7/9 Survey activity: responses and their events...');
  final responses = dataset.hostedResponses.toList();
  final responseIds = <String, String>{};
  for (final chunk in _rowChunks(responses, 50)) {
    final inserted = await client
        .from('survey_responses')
        .insert([
          for (final r in chunk)
            {
              'survey_id': waveIds[r.waveKey],
              'user_id': userIds[r.memberKey],
              'status': 'submitted',
              'answers': r.answers,
              'opened_at': _iso(r.openedAt),
              'first_draft_at': _iso(r.firstDraftAt),
              'submitted_at': _iso(r.submittedAt),
              'device_category': r.device.category,
              'platform_family': r.device.platform,
              'browser_family': r.device.browser,
              'created_at': _iso(r.openedAt),
              'updated_at': _iso(r.submittedAt),
            },
        ])
        .select('id, survey_id, user_id');
    for (final row in inserted) {
      responseIds['${row['survey_id']}|${row['user_id']}'] =
          row['id'] as String;
    }
  }
  final eventRows = [
    for (final r in responses)
      for (final e in r.events)
        {
          'survey_id': waveIds[r.waveKey],
          'user_id': userIds[r.memberKey],
          // Only record_survey_opened links the response; saveResponse does not.
          'response_id': e.type == 'opened'
              ? responseIds['${waveIds[r.waveKey]}|${userIds[r.memberKey]}']
              : null,
          'event_type': e.type,
          'device_category': r.device.category,
          'platform_family': r.device.platform,
          'browser_family': r.device.browser,
          'created_at': _iso(e.at),
        },
  ];
  for (final chunk in _rowChunks(eventRows, 200)) {
    await client.from('survey_response_events').insert(chunk);
  }

  stdout.writeln('8/9 Back-dating the open wave and notifications...');
  final openAssigned = {
    for (final row in _checkedRows(
      await client
          .from('survey_assignments')
          .select('id, user_id')
          .eq('survey_id', openWave.id),
      'survey_assignments',
    ))
      row['user_id'] as String: row['id'] as String,
  };
  final openAssignments = [
    for (final a in dataset.hostedAssignments)
      if (a.waveKey == openWave.key) a,
  ];
  final notAutoAssigned = [
    for (final a in openAssignments)
      if (!openAssigned.containsKey(userIds[a.memberKey])) a,
  ];
  await _inParallel(openAssignments, (a) async {
    final id = openAssigned[userIds[a.memberKey]];
    final row = {
      'assigned_at': _iso(a.assignedAt),
      'created_at': _iso(a.assignedAt),
      'status': a.completed ? 'completed' : 'notStarted',
    };
    if (id == null) {
      await client.from('survey_assignments').insert({
        ...row,
        'survey_id': openWave.id,
        'user_id': userIds[a.memberKey],
        'survey_title': openWave.title,
      });
    } else {
      await client.from('survey_assignments').update(row).eq('id', id);
    }
  });

  final noticeTimes = <String, ({DateTime created, DateTime? acted})>{};
  for (final m in order) {
    noticeTimes['$adminId|${registrationNoticeKey(userIds[m.key]!)}'] = (
      created: m.registeredAt!,
      acted: null,
    );
  }
  for (final a in openAssignments) {
    final r = responseByKey['${a.memberKey}|${a.waveKey}'];
    noticeTimes['${userIds[a.memberKey]}|survey:${openWave.id}:assigned'] = (
      created: a.assignedAt,
      acted: r?.openedAt.subtract(const Duration(minutes: 1)),
    );
  }
  for (final r in responses) {
    noticeTimes['${userIds[r.memberKey]}|survey:${waveIds[r.waveKey]}:submitted'] =
        (created: r.submittedAt, acted: null);
  }
  final notices = await _selectIn(
    client,
    'user_notifications',
    'id, user_id, dedupe_key',
    'user_id',
    [adminId, ...userIds.values],
  );
  final toRead = <String>[];
  final toRemove = <String>[];
  final backDates = <(String, Map<String, dynamic>)>[];
  var otherNotices = 0;
  for (final n in notices) {
    final times = noticeTimes['${n['user_id']}|${n['dedupe_key']}'];
    if (times == null) {
      otherNotices++;
      continue;
    }
    final readAt = DemoDataset.notificationReadAt(
      times.created,
      actedAt: times.acted,
    );
    final id = n['id'] as String;
    if (!DemoDataset.keptByNotificationCleanup(
      times.created,
      read: readAt != null,
      now: now,
    )) {
      toRemove.add(id);
      continue;
    }
    if (readAt != null) toRead.add(id);
    backDates.add((
      id,
      {
        'created_at': _iso(times.created),
        if (readAt != null) 'read_at': _iso(readAt),
      },
    ));
  }
  for (final chunk in _chunks(toRead)) {
    await client
        .from('user_notifications')
        .update({'is_read': true})
        .inFilter('id', chunk);
  }
  // is_read is left out so the read-tracking trigger keeps these times.
  await _inParallel(backDates, (b) async {
    await client.from('user_notifications').update(b.$2).eq('id', b.$1);
  });
  await _deleteIds(client, 'user_notifications', toRemove);

  stdout.writeln('9/9 Activity logs still inside the retention window...');
  final members = {for (final m in order) m.key: m};
  final kept = [
    for (final a in dataset.hostedActivities)
      if (DemoDataset.keptByAuditRetention(a.action, a.at, now)) a,
  ];
  // The insert trigger stamps the current time, so each row is back-dated
  // right after it is written.
  await _inParallel(kept, (a) async {
    final m = members[a.memberKey]!;
    final uid = userIds[m.key]!;
    final inserted = await client
        .from('audit_logs')
        .insert(_auditRow(a, m, uid))
        .select('id')
        .single();
    await client
        .from('audit_logs')
        .update({'created_at': _iso(a.at)})
        .eq('id', inserted['id'] as String);
  });

  await _printSeedSummary(
    client,
    dataset,
    userIds: userIds,
    notAutoAssigned: notAutoAssigned.length,
    noticesBackDated: backDates.length,
    noticesRemoved: toRemove.length,
    otherNotices: otherNotices,
    logs: kept.length,
  );
}

Map<String, dynamic> _auditRow(DemoActivity a, DemoMember m, String uid) => {
  'user_id': uid,
  'action': a.action,
  'entity_type': 'User',
  'entity_id': uid,
  'details': {
    'userName': m.fullName,
    'userEmail': m.email,
    'description': switch (a.action) {
      'REGISTER' => 'Alumni registered: ${m.email} (${m.studentId})',
      'COMPLETE_ONBOARDING' => 'Alumni completed mandatory onboarding',
      _ => 'User logged in: ${m.email}',
    },
    'status': 'SUCCESS',
    'userRole': 'user',
  },
};

/// Reads the result back so the counts come from the database, not the
/// dataset.
Future<void> _printSeedSummary(
  SupabaseClient client,
  DemoDataset dataset, {
  required Map<String, String> userIds,
  required int notAutoAssigned,
  required int noticesBackDated,
  required int noticesRemoved,
  required int otherNotices,
  required int logs,
}) async {
  stdout.writeln('Done. Read back from the demo project:');
  for (final w in dataset.waves) {
    final rows = _checkedRows(
      await client
          .from('survey_assignments')
          .select('status')
          .eq('survey_id', w.id),
      'survey_assignments',
    );
    final done = rows.where((r) => r['status'] == 'completed').length;
    stdout.writeln(
      '  ${w.title}: ${rows.length} assigned, $done submitted, '
      '${rows.length - done} pending',
    );
  }
  final incomplete = await _selectIn(
    client,
    'users',
    'id, tracer_profile_complete, onboarding_complete',
    'id',
    userIds.values.toList(),
  );
  final notComplete = incomplete
      .where(
        (r) =>
            r['tracer_profile_complete'] != true ||
            r['onboarding_complete'] != true,
      )
      .length;
  stdout.writeln(
    '  ${userIds.length} registered alumni, $notComplete with an incomplete '
    'profile or onboarding',
  );
  stdout.writeln(
    '  Notifications: $noticesBackDated back-dated, $noticesRemoved removed '
    '(the nightly cleanup would have), $otherNotices left as created',
  );
  stdout.writeln('  Activity logs: $logs');
  if (notAutoAssigned > 0) {
    stdout.writeln(
      '  Warning: $notAutoAssigned open-wave assignment(s) were not created '
      'by the database auto-assign and were added by the seed.',
    );
  }
}

String _iso(DateTime d) => d.toUtc().toIso8601String();

Iterable<List<T>> _rowChunks<T>(List<T> rows, int size) sync* {
  for (var i = 0; i < rows.length; i += size) {
    yield rows.sublist(i, i + size < rows.length ? i + size : rows.length);
  }
}

/// Runs [action] for every item, a few requests at a time.
Future<void> _inParallel<T>(
  List<T> items,
  Future<void> Function(T item) action, {
  int width = 8,
}) async {
  for (final chunk in _rowChunks(items, width)) {
    await Future.wait(chunk.map(action));
  }
}

Future<String> _ensureAccount(
  SupabaseClient client,
  Map<String, User> byEmail, {
  required String email,
  required String displayName,
  String? password,
}) async {
  final found = byEmail[email.toLowerCase()];
  if (found != null) {
    if (password != null) {
      await client.auth.admin.updateUserById(
        found.id,
        attributes: AdminUserAttributes(password: password),
      );
    }
    return found.id;
  }
  final created = await client.auth.admin.createUser(
    AdminUserAttributes(
      email: email,
      password: password,
      emailConfirm: true,
      userMetadata: {'display_name': displayName},
    ),
  );
  final user = created.user;
  if (user == null) _fail('Could not create $email.');
  byEmail[email.toLowerCase()] = user;
  return user.id;
}

/// Sets a new password for the demo admin only. Nothing else is changed.
Future<void> _setAdminPassword(SupabaseClient client, List<User> users) async {
  final admin = users
      .where((u) => u.email?.toLowerCase() == demoAdminEmail)
      .firstOrNull;
  if (admin == null) {
    _fail('$demoAdminEmail does not exist yet. Run --seed to create it.');
  }
  final password = _askPassword(
    'New password for $demoAdminEmail',
    required: true,
  );
  await client.auth.admin.updateUserById(
    admin.id,
    attributes: AdminUserAttributes(password: password),
  );
  stdout.writeln('Password updated for $demoAdminEmail. Nothing else changed.');
}

/// Reads a password without echoing it. Empty input keeps the current one.
String? _askPassword(String label, {required bool required}) {
  if (!stdin.hasTerminal) {
    _fail('Run this in a terminal so passwords can be typed.');
  }
  while (true) {
    stdout.write(
      required ? '$label: ' : '$label (Enter to keep the current one): ',
    );
    String value;
    stdin.echoMode = false;
    try {
      value = stdin.readLineSync() ?? '';
    } finally {
      stdin.echoMode = true;
    }
    stdout.writeln();
    if (value.isEmpty && !required) return null;
    final problem = PasswordPolicy.validate(value);
    if (problem == null) return value;
    stdout.writeln(problem);
  }
}

Future<void> _reset(
  SupabaseClient client,
  DemoDataset dataset,
  List<User> users,
  String projectRef,
) async {
  final waveIds = [for (final w in demoWaves) w.id];
  final ownedEmails = {
    for (final m in dataset.accounts) m.email!.toLowerCase(),
  };
  final ownedIds = [
    for (final u in users)
      if (ownedEmails.contains(u.email!.toLowerCase())) u.id,
  ];

  final responses = {
    for (final r in [
      ...await _selectIn(
        client,
        'survey_responses',
        'id, survey_id, user_id',
        'survey_id',
        waveIds,
      ),
      ...await _selectIn(
        client,
        'survey_responses',
        'id, survey_id, user_id',
        'user_id',
        ownedIds,
      ),
    ])
      r['id'] as String: r,
  };
  final plan = DemoResetPlan.build(
    dataset: dataset,
    accounts: [for (final u in users) (id: u.id, email: u.email)],
    waveRows: await _demoWaveRows(client),
    flagRows: await _selectIn(
      client,
      'dss_flags',
      'id, survey_id',
      'survey_id',
      waveIds,
    ),
    responseRows: responses.values.toList(),
    assignmentRows: await _selectIn(
      client,
      'survey_assignments',
      'id, user_id',
      'user_id',
      ownedIds,
    ),
    eventRows: await _selectIn(
      client,
      'survey_response_events',
      'id, user_id',
      'user_id',
      ownedIds,
    ),
    auditRows: await _selectIn(
      client,
      'audit_logs',
      'id, user_id',
      'user_id',
      ownedIds,
    ),
    noticeRows: await _selectIn(
      client,
      'user_notifications',
      'id, dedupe_key',
      'dedupe_key',
      [for (final id in ownedIds) registrationNoticeKey(id)],
    ),
    demoRosterRows: _checkedRows(
      await client
          .from('alumni_members')
          .select('id, student_id')
          .like('student_id', '$demoStudentIdPrefix%'),
      'alumni_members',
    ),
  );

  stdout.writeln('Reset would delete:');
  for (final line in plan.preview()) {
    stdout.writeln('  $line');
  }
  if (plan.blockers.isNotEmpty) {
    _fail('Nothing was deleted.\n${plan.blockers.join('\n')}');
  }
  if (plan.isEmpty) {
    stdout.writeln('Nothing to delete.');
    return;
  }

  final phrase = resetConfirmationPhrase(projectRef);
  if (!stdin.hasTerminal) {
    _fail('Run --reset in a terminal so the deletion can be confirmed.');
  }
  stdout.write('Type "$phrase" to delete exactly the rows above: ');
  if ((stdin.readLineSync() ?? '').trim() != phrase) {
    _fail('Confirmation did not match. Nothing was deleted.');
  }

  Future<void> step(String label, Future<void> Function() action) async {
    stdout.writeln(label);
    try {
      await action();
    } on Exception catch (e) {
      final detail = e is PostgrestException
          ? e.message
          : e is AuthException
          ? e.message
          : e.runtimeType.toString();
      _fail(
        'Reset stopped at "$label": $detail\n'
        'Only rows listed above were touched. Run --reset again to finish.',
      );
    }
  }

  await step('Removing DSS findings on demo waves...', () {
    return _deleteIds(client, 'dss_flags', plan.flagIds);
  });
  await step('Removing survey responses of demo accounts...', () {
    return _deleteIds(client, 'survey_responses', plan.responseIds);
  });
  await step('Removing survey assignments of demo accounts...', () {
    return _deleteIds(client, 'survey_assignments', plan.assignmentIds);
  });
  await step('Removing response events of demo accounts...', () {
    return _deleteIds(client, 'survey_response_events', plan.eventIds);
  });
  await step('Removing activity logs of demo accounts...', () {
    return _deleteIds(client, 'audit_logs', plan.auditLogIds);
  });
  await step('Removing "new registration" notices about demo accounts...', () {
    return _deleteIds(client, 'user_notifications', plan.noticeIds);
  });
  await step('Removing demo waves...', () {
    return _deleteIds(client, 'surveys', plan.waveIds);
  });
  await step('Removing demo roster rows...', () {
    return _deleteIds(client, 'alumni_members', plan.rosterIds);
  });
  await step('Removing demo alumni accounts...', () async {
    for (final id in plan.accountIds) {
      await client.auth.admin.deleteUser(id);
    }
  });
  stdout.writeln('Reset done. The demo admin account was kept.');
}

Iterable<List<String>> _chunks(List<String> values) => _rowChunks(values, 100);

Future<List<Map<String, dynamic>>> _selectIn(
  SupabaseClient client,
  String table,
  String columns,
  String column,
  List<String> values,
) async {
  final rows = <Map<String, dynamic>>[];
  for (final chunk in _chunks(values)) {
    rows.addAll(
      _checkedRows(
        await client.from(table).select(columns).inFilter(column, chunk),
        table,
      ),
    );
  }
  return rows;
}

/// A full page may mean rows were cut off, so the preview would be wrong.
List<Map<String, dynamic>> _checkedRows(
  List<Map<String, dynamic>> rows,
  String table,
) {
  if (rows.length >= _maxRows) {
    throw DemoGuardException(
      'Stopped: $table returned $_maxRows rows, more than the demo dataset '
      'can own. Check the demo project by hand.',
    );
  }
  return rows;
}

Future<void> _deleteIds(
  SupabaseClient client,
  String table,
  List<String> ids,
) async {
  for (final chunk in _chunks(ids)) {
    await client.from(table).delete().inFilter('id', chunk);
  }
}

void _printPlan(DemoDataset dataset) {
  stdout.writeln(
    'Demo dataset (hosted): ${dataset.waves.length} waves, '
    '${dataset.rosterMembers.length} roster rows, '
    '${dataset.hostedAccounts.length} registered alumni '
    '(${dataset.hostedAccounts.where((m) => m.canLogIn).length} can log in), '
    '${dataset.hostedResponses.length} submitted responses.',
  );
  for (final w in dataset.waves) {
    final assigned = dataset.hostedAssignments
        .where((a) => a.waveKey == w.key)
        .toList();
    final done = assigned.where((a) => a.completed).length;
    stdout.writeln(
      '  ${w.title}: ${assigned.length} assigned, $done submitted, '
      '${assigned.length - done} pending',
    );
  }
}

Never _fail(String message) {
  stderr.writeln(message);
  exit(1);
}
