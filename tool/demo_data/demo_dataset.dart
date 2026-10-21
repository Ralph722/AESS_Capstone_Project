// Deterministic demo dataset built from demo_scenarios.dart.
//
// Every answer is taken from the built-in CHED GTS options and follows
// ChedGtsVisibility, so responses look exactly like real submissions. The
// history (registration, onboarding, assignments, survey activity, logs)
// follows the app's own flow; see "V. Flow-faithful reseed" in
// docs/demo-data-plan.md.
import 'package:alumni_system/core/constants/gts_constants.dart';
import 'package:alumni_system/features/alumni/tracer/models/tracer_profile_model.dart';
import 'package:alumni_system/features/surveys/ched_gts/ched_gts_prefill.dart';
import 'package:alumni_system/features/surveys/ched_gts/ched_gts_schema.dart';

import 'demo_scenarios.dart';

/// Coarse device info, as `SurveyClientContext` records it.
typedef DemoDevice = ({String category, String platform, String browser});

class DemoMember {
  const DemoMember({
    required this.key,
    required this.cohortKey,
    required this.number,
    required this.studentId,
    required this.fullName,
    required this.course,
    required this.batch,
    required this.onRoster,
    required this.email,
    required this.canLogIn,
    required this.registeredAt,
  });

  /// e.g. `bsit-2023-001`.
  final String key;
  final String cohortKey;

  /// 1-based position within the cohort.
  final int number;

  /// Empty for respondents who are not on the roster.
  final String studentId;
  final String fullName;
  final String course;
  final String? batch;
  final bool onRoster;

  /// Null for roster members without an account.
  final String? email;
  final bool canLogIn;

  /// When the email was confirmed and the account linked to the roster row
  /// (the app's registration step). Null without an account.
  final DateTime? registeredAt;

  bool get hasAccount => email != null;

  /// Year on the profile: the roster batch, or the one typed at onboarding
  /// when the roster has none.
  String get profileYear => batch ?? (onRoster ? demoTypedBatch : '');

  /// Onboarding is finished in the same session as registration.
  DateTime get onboardedAt =>
      registeredAt!.add(Duration(minutes: 12 + number % 25));
}

class DemoResponse {
  const DemoResponse({
    required this.memberKey,
    required this.cohortKey,
    required this.waveKey,
    required this.submittedAt,
    required this.answers,
    required this.device,
  });

  final String memberKey;
  final String cohortKey;
  final String waveKey;
  final DateTime submittedAt;
  final Map<String, dynamic> answers;
  final DemoDevice device;

  DateTime get openedAt => submittedAt.subtract(const Duration(minutes: 25));

  DateTime get firstDraftAt =>
      submittedAt.subtract(const Duration(minutes: 20));

  /// What the app records while the alumnus fills in the survey.
  List<({String type, DateTime at})> get events => [
    (type: 'opened', at: openedAt),
    (type: 'draft_saved', at: firstDraftAt),
    (type: 'submitted', at: submittedAt),
  ];
}

class DemoAssignment {
  const DemoAssignment({
    required this.memberKey,
    required this.waveKey,
    required this.assignedAt,
    required this.completed,
  });

  final String memberKey;
  final String waveKey;
  final DateTime assignedAt;

  /// False while the member has not submitted that wave (pending).
  final bool completed;
}

/// An activity log row the app writes (`REGISTER`, `COMPLETE_ONBOARDING`,
/// `LOGIN`).
class DemoActivity {
  const DemoActivity({
    required this.memberKey,
    required this.action,
    required this.at,
  });

  final String memberKey;
  final String action;
  final DateTime at;
}

class DemoDataset {
  DemoDataset._(this.members, this.responses)
    : _byKey = {for (final m in members) m.key: m},
      _responsesByMember = _groupResponses(responses);

  final List<DemoMember> members;
  final List<DemoResponse> responses;
  final Map<String, DemoMember> _byKey;
  final Map<String, List<DemoResponse>> _responsesByMember;

  List<DemoWave> get waves => demoWaves;

  Iterable<DemoMember> get rosterMembers => members.where((m) => m.onRoster);

  Iterable<DemoMember> get accounts => members.where((m) => m.hasAccount);

  DemoWave waveByKey(String key) => demoWaves.firstWhere((w) => w.key == key);

  DemoMember memberByKey(String key) => _byKey[key]!;

  /// Respondents off the roster cannot register through the app, so the
  /// hosted demo holds only roster members. The offline dataset keeps them
  /// for the DSS group-mapping tests.
  bool isHosted(String memberKey) => _byKey[memberKey]!.onRoster;

  Iterable<DemoMember> get hostedAccounts =>
      accounts.where((m) => isHosted(m.key));

  Iterable<DemoResponse> get hostedResponses =>
      responses.where((r) => isHosted(r.memberKey));

  Iterable<DemoAssignment> get hostedAssignments =>
      assignments.where((a) => isHosted(a.memberKey));

  Iterable<DemoActivity> get hostedActivities =>
      activities.where((a) => isHosted(a.memberKey));

  /// Hosted accounts in the order they registered.
  List<DemoMember> get registrationOrder =>
      hostedAccounts.toList()
        ..sort((a, b) => a.registeredAt!.compareTo(b.registeredAt!));

  /// A member's responses, oldest first.
  List<DemoResponse> responsesOf(DemoMember member) =>
      _responsesByMember[member.key] ?? const [];

  DemoResponse? latestResponseOf(DemoMember member) {
    final list = responsesOf(member);
    return list.isEmpty ? null : list.last;
  }

  /// A wave is assigned to everyone registered before it closes: at publish
  /// time for those already registered, otherwise when their registration
  /// links the roster row (the database's auto-assign). Those without a
  /// response in that wave are pending.
  List<DemoAssignment> get assignments {
    final answered = {for (final r in responses) '${r.memberKey}|${r.waveKey}'};
    return [
      for (final m in accounts)
        for (final w in demoWaves)
          if (m.registeredAt!.isBefore(w.closeAt))
            DemoAssignment(
              memberKey: m.key,
              waveKey: w.key,
              assignedAt: m.registeredAt!.isAfter(w.openAt)
                  ? m.registeredAt!
                  : w.openAt,
              completed: answered.contains('${m.key}|${w.key}'),
            ),
    ];
  }

  /// Activity log rows, as the app writes them: registration, onboarding in
  /// the same session, and a login before each survey.
  List<DemoActivity> get activities => [
    for (final m in accounts) ...[
      DemoActivity(memberKey: m.key, action: 'REGISTER', at: m.registeredAt!),
      DemoActivity(
        memberKey: m.key,
        action: 'COMPLETE_ONBOARDING',
        at: m.onboardedAt,
      ),
    ],
    for (final r in responses)
      DemoActivity(
        memberKey: r.memberKey,
        action: 'LOGIN',
        at: r.openedAt.subtract(const Duration(minutes: 2)),
      ),
  ];

  /// The member's live profile: what onboarding saved, then synced from the
  /// latest tracer the way the app syncs it on submit. The submit sync
  /// leaves the mobile number alone (it is saved after verification), so the
  /// demo profile starts with the number from the answers.
  TracerProfile profileFor(DemoMember member, {String uid = ''}) {
    final latest = latestResponseOf(member);
    final answers =
        latest?.answers ??
        {..._sectionA(member), 'ched_16': _onboardingEmployment(member)};
    return ChedGtsPrefill.mergeIntoProfile(
      current: TracerProfile(
        uid: uid,
        email: member.email ?? '',
        displayName: member.fullName,
        studentId: member.studentId,
        program: member.course,
        batchYear: member.profileYear,
        yearGraduated: member.profileYear,
        mobileNumber: (answers['ched_5'] ?? '').toString().trim(),
      ),
      answers: answers,
    );
  }

  /// Last time the member did something: onboarding or their latest survey.
  DateTime lastActiveAt(DemoMember member) =>
      latestResponseOf(member)?.submittedAt ?? member.onboardedAt;

  /// The admin opened the member's record two days after a profile change,
  /// except for changes in the last two weeks, which are still flagged.
  DateTime? adminViewedAt(DemoMember member) {
    final changed = lastActiveAt(member);
    return changed.isBefore(demoSnapshot.subtract(const Duration(days: 14)))
        ? changed.add(const Duration(days: 2))
        : null;
  }

  /// When a notification was read: when the alumnus acted on it, otherwise
  /// two hours after it arrived once it is a month old.
  static DateTime? notificationReadAt(DateTime createdAt, {DateTime? actedAt}) {
    if (actedAt != null) return actedAt;
    if (createdAt.isBefore(demoSnapshot.subtract(const Duration(days: 30)))) {
      return createdAt.add(const Duration(hours: 2));
    }
    return null;
  }

  /// Mirrors `run_notification_cleanup`: read notices older than 90 days and
  /// any notice older than 180 days are removed nightly.
  static bool keptByNotificationCleanup(
    DateTime createdAt, {
    required bool read,
    required DateTime now,
  }) {
    if (createdAt.isBefore(now.subtract(const Duration(days: 180)))) {
      return false;
    }
    return !(read && createdAt.isBefore(now.subtract(const Duration(days: 90))));
  }

  /// Mirrors `purge_expired_audit_logs`: logins and logouts are kept for 90
  /// days, everything else for a year.
  static bool keptByAuditRetention(String action, DateTime at, DateTime now) {
    final session = action == 'LOGIN' || action == 'LOGOUT';
    final cutoff = session
        ? now.subtract(const Duration(days: 90))
        : DateTime.utc(
            now.year - 1,
            now.month,
            now.day,
            now.hour,
            now.minute,
            now.second,
          );
    return at.isAfter(cutoff);
  }

  /// Answers of one cohort in one wave.
  List<Map<String, dynamic>> answersFor(String cohortKey, String waveKey) => [
    for (final r in responses)
      if (r.cohortKey == cohortKey && r.waveKey == waveKey) r.answers,
  ];

  static DemoDataset build() {
    final members = <DemoMember>[];
    final responses = <DemoResponse>[];
    for (final cohort in demoCohorts) {
      final size = cohort.onRoster ? cohort.roster : cohort.respondentsMax;
      final cohortMembers = [
        for (var n = 1; n <= size; n++) _member(cohort, n),
      ];
      members.addAll(cohortMembers);
      for (final spec in cohort.waves) {
        final wave = demoWaves.firstWhere((w) => w.key == spec.wave);
        for (var i = 0; i < spec.respondents; i++) {
          final member = cohortMembers[i];
          responses.add(
            DemoResponse(
              memberKey: member.key,
              cohortKey: cohort.key,
              waveKey: wave.key,
              submittedAt: _submittedAt(wave, member.key),
              answers: _answers(cohort, spec, member, i),
              device: _devices[_hash('device|${member.key}') % _devices.length],
            ),
          );
        }
      }
    }
    return DemoDataset._(
      List.unmodifiable(members),
      List.unmodifiable(responses),
    );
  }

  static Map<String, List<DemoResponse>> _groupResponses(
    List<DemoResponse> responses,
  ) {
    final byMember = <String, List<DemoResponse>>{};
    for (final r in responses) {
      byMember.putIfAbsent(r.memberKey, () => []).add(r);
    }
    for (final list in byMember.values) {
      list.sort((a, b) => a.submittedAt.compareTo(b.submittedAt));
    }
    return byMember;
  }

  static DemoMember _member(DemoCohort cohort, int n) {
    final key = '${cohort.key}-${n.toString().padLeft(3, '0')}';
    final loginIndex = demoLoginMembers.indexWhere(
      (m) => m.$1 == cohort.key && m.$2 == n,
    );
    final canLogIn = loginIndex >= 0;
    final hasAccount = n <= cohort.registered;
    final email = !hasAccount
        ? null
        : canLogIn
        ? 'alumni${loginIndex + 1}@$demoEmailDomain'
        : '$key@$demoEmailDomain';
    final h = _hash(key);
    return DemoMember(
      key: key,
      cohortKey: cohort.key,
      number: n,
      studentId: cohort.onRoster
          ? '$demoStudentIdPrefix${cohort.key.toUpperCase()}-'
                '${n.toString().padLeft(3, '0')}'
          : '',
      fullName:
          '${_firstNames[h % _firstNames.length]} '
          '${_lastNames[(h ~/ 7) % _lastNames.length]}',
      course: cohort.course,
      batch: cohort.batch,
      onRoster: cohort.onRoster,
      email: email,
      canLogIn: canLogIn,
      registeredAt: hasAccount ? _registeredAt(cohort, n, key) : null,
    );
  }

  /// Registration happens after the roster import and graduation. A
  /// respondent registers after the wave before their first answered wave
  /// closed (so they were never assigned it) and at least a week before
  /// their first submission. Others register any time until the snapshot.
  static DateTime _registeredAt(DemoCohort cohort, int n, String key) {
    final answered = [
      for (final w in demoWaves)
        if (cohort.waves.any((s) => s.wave == w.key && n <= s.respondents)) w,
    ];
    var from = demoRosterImportedAt;
    if (cohort.batch != null) {
      final graduated = DateTime.utc(int.parse(cohort.batch!), 6);
      if (graduated.isAfter(from)) from = graduated;
    }
    var until = demoSnapshot;
    if (answered.isNotEmpty) {
      final first = answered.first;
      final index = demoWaves.indexOf(first);
      if (index > 0 && demoWaves[index - 1].closeAt.isAfter(from)) {
        from = demoWaves[index - 1].closeAt;
      }
      until = _submittedAt(first, key).subtract(const Duration(days: 7));
    }
    final start = DateTime.utc(from.year, from.month, from.day + 1);
    final days = until.difference(start).inDays;
    if (days < 1) throw StateError('No registration window for $key.');
    final h = _hash('registered|$key');
    // Hours 0-13 UTC are 08:00-21:59 in Manila.
    return start.add(
      Duration(days: h % days, hours: h ~/ 7 % 14, minutes: h ~/ 11 % 60),
    );
  }

  /// Inside the wave window, and before the snapshot for an open wave.
  static DateTime _submittedAt(DemoWave wave, String memberKey) {
    final end = wave.closeAt.isBefore(demoSnapshot)
        ? wave.closeAt
        : demoSnapshot;
    final days = end.difference(wave.openAt).inDays;
    final h = _hash('${wave.key}|$memberKey');
    return wave.openAt.add(
      Duration(days: 1 + h % (days - 2), hours: h % 14, minutes: h % 60),
    );
  }

  /// Section A and B item 12: what onboarding saved and the tracer
  /// pre-fills, identical in every wave.
  static Map<String, dynamic> _sectionA(DemoMember member) {
    final h = _hash(member.key);
    final program =
        demoProgramNames[member.course] ?? demoProgramNames['BSIT']!;
    return {
      'ched_1': member.fullName,
      'ched_2':
          'Purok ${1 + h % 9}, ${_barangays[h % _barangays.length]}, '
          'Oroquieta City, Misamis Occidental',
      'ched_3': member.email,
      'ched_4': '088-531-${1000 + h % 9000}',
      'ched_5':
          '${_mobilePrefixes[h % _mobilePrefixes.length]}'
          '${1000000 + h ~/ 3 % 9000000}',
      'ched_6': GtsConstants.civilStatuses[h % 5 == 0 ? 1 : 0],
      'ched_7': GtsConstants.sexOptions[h % 2],
      'ched_8': _birthDate(member.profileYear, h),
      'ched_9': _region10,
      'ched_10': 'Misamis Occidental',
      'ched_11': GtsConstants.locationOfResidenceOptions[h % 3 == 0 ? 1 : 0],
      'ched_12': [
        {
          'Degree(s) & Specialization(s)': program,
          'College or University': demoInstitution,
          'Year Graduated': member.profileYear,
          'Honor(s) or Award(s) Received': h % 6 == 0 ? 'Cum Laude' : 'None',
        },
      ],
    };
  }

  /// Q16 chosen at onboarding by members who never answered a tracer.
  static String _onboardingEmployment(DemoMember member) {
    final h = _hash('employment|${member.key}');
    return h % 10 < 7
        ? ChedGtsBuiltin.yes
        : h % 10 < 9
        ? ChedGtsBuiltin.no
        : ChedGtsBuiltin.neverEmployed;
  }

  static Map<String, dynamic> _answers(
    DemoCohort cohort,
    DemoWaveSpec spec,
    DemoMember member,
    int i,
  ) {
    final h = _hash(member.key);
    final a = <String, dynamic>{
      ..._sectionA(member),
      'ched_14': {
        _reasonRows[h % _reasonRows.length]: {_undergradCol: true},
      },
    };

    if (i < spec.notEmployed) {
      a['ched_16'] = i < spec.neverEmployed
          ? ChedGtsBuiltin.neverEmployed
          : ChedGtsBuiltin.no;
      final reason = _reasonAt(spec.reasons, i);
      a['ched_17'] = [reason];
      if (reason == ChedGtsBuiltin.otherReasonsSpecify) {
        a['ched_17_other'] = 'Caring for a newborn child';
      }
      if (reason == _furtherStudy) {
        a['ched_15a'] = [
          {
            'Title of Training or Advance Study': 'Master of Arts in Education',
            'Duration and Credits Earned': 'Ongoing, 12 units',
            'Name of Training Institution/College/University': demoInstitution,
          },
        ];
        a['ched_15b'] = 'For professional development';
      }
    } else {
      _employedAnswers(a, cohort, spec, i - spec.notEmployed, h);
    }
    return a;
  }

  static void _employedAnswers(
    Map<String, dynamic> a,
    DemoCohort cohort,
    DemoWaveSpec spec,
    int e,
    int h,
  ) {
    final employed = spec.employed;
    final mismatch = e < spec.mismatch;
    final clerical = e >= employed - spec.clerical;
    final selfEmployed = !clerical && !mismatch && e % 9 == 8;
    final lowSalary = e >= employed - spec.lowSalary;
    final firstJob = mismatch || e % 5 != 4;

    a['ched_16'] = ChedGtsBuiltin.yes;
    a['ched_18'] = selfEmployed
        ? ChedGtsBuiltin.selfEmployed
        : _statuses[e % _statuses.length];
    if (selfEmployed) {
      a['ched_18_skills'] = 'Programming and bookkeeping';
    }
    a['ched_19'] = selfEmployed
        ? 'Self-employed, small online business'
        : clerical
        ? _clericalJobs[e % _clericalJobs.length]
        : (_courseJobs[cohort.course] ?? _courseJobs['BSIT']!)[e % 3];
    a['ched_20'] = mismatch || clerical
        ? _retail
        : _courseIndustry[cohort.course] ?? _courseIndustry['BSIT']!;
    a['ched_21'] = e < spec.abroad ? 'Abroad' : 'Local';
    a['ched_22'] = firstJob ? ChedGtsBuiltin.yes : ChedGtsBuiltin.no;
    if (firstJob) {
      a['ched_23'] = mismatch
          ? ['Salaries and benefits', 'Proximity to residence']
          : ['Salaries and benefits', 'Related to course or program of study'];
      a['ched_24a'] = mismatch ? ChedGtsBuiltin.no : ChedGtsBuiltin.yes;
      if (mismatch) {
        a['ched_25'] = ['Salaries & benefits', 'Career challenge'];
      } else {
        a['ched_24b'] = ['Salaries & benefits', 'Related to special skills'];
      }
    } else {
      a['ched_25'] = ['Career challenge'];
    }
    a['ched_27'] = _stays[e % _stays.length];
    a['ched_28'] = _foundVia[(e + h) % _foundVia.length];

    if (e < spec.longWait) {
      a['ched_29'] = _longWaits[e % _longWaits.length];
    } else if (e < spec.longWait + spec.q29Others) {
      a['ched_29'] = ChedGtsBuiltin.othersSpecify;
      a['ched_29_other'] = 'Started freelancing before graduation';
    } else {
      a['ched_29'] = _shortWaits[e % _shortWaits.length];
    }

    final level = selfEmployed
        ? ChedGtsBuiltin.selfEmployed
        : clerical
        ? _clericalLevel
        : _professionalLevel;
    a['ched_30'] = {
      level: {_firstJobCol: true, _currentJobCol: true},
    };
    a['ched_31'] = lowSalary
        ? _salaries[e % 2]
        : _salaries[2 + (e + h) % (_salaries.length - 2)];
    a['ched_32'] = mismatch ? ChedGtsBuiltin.no : ChedGtsBuiltin.yes;
    if (!mismatch) {
      a['ched_33'] = _courseSkills[cohort.course] ?? _courseSkills['BSIT']!;
    }
    if (e < spec.suggestions) {
      a['ched_34'] =
          (_suggestions[cohort.course] ?? _suggestions['BSIT']!)[e % 3];
    }
  }

  static String _reasonAt(DemoReasons r, int i) {
    final ordered = [
      for (var k = 0; k < r.seeking; k++)
        k.isEven ? 'No job opportunity' : 'Lack of work experience',
      for (var k = 0; k < r.furtherStudy; k++) _furtherStudy,
      for (var k = 0; k < r.family; k++)
        'Family concern and decided not to find a job',
      for (var k = 0; k < r.health; k++) 'Health-related reason(s)',
      for (var k = 0; k < r.didNotLook; k++) 'Did not look for a job',
      for (var k = 0; k < r.other; k++) ChedGtsBuiltin.otherReasonsSpecify,
    ];
    return ordered[i];
  }

  static String _birthDate(String? batch, int h) {
    final year = (int.tryParse(batch ?? '') ?? 2023) - 22;
    final month = 1 + h % 12;
    final day = 1 + h % 28;
    return '$year-${month.toString().padLeft(2, '0')}-'
        '${day.toString().padLeft(2, '0')}';
  }

  /// FNV-1a, so values never depend on the Dart SDK's Random.
  static int _hash(String s) {
    var h = 0x811c9dc5;
    for (final c in s.codeUnits) {
      h ^= c;
      h = (h * 0x01000193) & 0x7fffffff;
    }
    return h;
  }

  static final _region10 = GtsConstants.regionsOfOrigin.firstWhere(
    (r) => r.contains('10'),
  );

  static final _reasonRows = ChedGtsBuiltin.byId(
    'ched_14',
  )!.matrixRows.where((r) => r != ChedGtsBuiltin.othersSpecify).toList();
  static final _undergradCol = ChedGtsBuiltin.byId('ched_14')!.matrixColumns[0];
  static final _firstJobCol = ChedGtsBuiltin.byId('ched_30')!.matrixColumns[0];
  static final _currentJobCol = ChedGtsBuiltin.byId(
    'ched_30',
  )!.matrixColumns[1];
  static final _clericalLevel = ChedGtsBuiltin.byId('ched_30')!.matrixRows[0];
  static final _professionalLevel = ChedGtsBuiltin.byId(
    'ched_30',
  )!.matrixRows[1];
  static final _salaries = ChedGtsBuiltin.byId('ched_31')!.options;
  static final _durations = ChedGtsBuiltin.byId('ched_29')!.options;
  static final _shortWaits = _durations.sublist(0, 3);
  static final _longWaits = _durations.sublist(3, 6);
  static final _stays = [_durations[1], _durations[2], _durations[3]];
  static final _foundVia = ChedGtsBuiltin.byId(
    'ched_28',
  )!.options.where((o) => o != ChedGtsBuiltin.othersSpecify).toList();
  static final _statuses = ChedGtsBuiltin.byId(
    'ched_18',
  )!.options.where((o) => o != ChedGtsBuiltin.selfEmployed).toList();
  static final _retail = ChedGtsBuiltin.byId('ched_20')!.options[6];

  static const _furtherStudy = 'Advance or further study';

  static const _courseIndustry = {
    'BSIT': 'Real Estate, Renting and Business Activities',
    'BTLED-ICT': 'Education',
    'BTLED-HE': 'Hotels and Restaurants',
    'BTLED-IA': 'Construction',
    'BFPT': 'Manufacturing',
  };

  static const _courseJobs = {
    'BSIT': ['Web Developer', 'IT Support Specialist', 'Software Tester'],
    'BTLED-ICT': ['ICT Teacher', 'Computer Laboratory Technician', 'Trainer'],
    'BTLED-HE': ['TLE Teacher', 'Food Service Supervisor', 'Pastry Chef'],
    'BTLED-IA': ['Industrial Arts Teacher', 'Electrician', 'Draftsman'],
    'BFPT': [
      'Quality Control Analyst',
      'Production Supervisor',
      'Food Technologist',
    ],
  };

  static const _clericalJobs = [
    'Office Clerk',
    'Data Encoder',
    'Cashier',
    'Sales Associate',
  ];

  static const _courseSkills = {
    'BSIT': ['Information Technology skills', 'Problem-solving skills'],
    'BTLED-ICT': ['Communication skills', 'Information Technology skills'],
    'BTLED-HE': ['Human Relations skills', 'Entrepreneurial skills'],
    'BTLED-IA': ['Problem-solving skills', 'Critical Thinking skills'],
    'BFPT': ['Critical Thinking skills', 'Problem-solving skills'],
  };

  static const _suggestions = {
    'BSIT': [
      'More hands-on projects with current web frameworks.',
      'Add cloud computing and DevOps tools to the curriculum.',
      'Longer internship with partner companies.',
    ],
    'BTLED-ICT': [
      'More practice teaching with actual ICT classes.',
      'Include networking certification preparation.',
      'Update the computer laboratory equipment.',
    ],
    'BTLED-HE': [
      'More industry immersion in hotels and restaurants.',
      'Add food business management and costing subjects.',
      'Partner with employers for on-the-job training placements.',
    ],
    'BTLED-IA': [
      'More shop hours with modern power tools.',
      'Include electrical licensure exam review.',
      'Add CAD drafting software training.',
    ],
    'BFPT': [
      'More plant visits to food manufacturers.',
      'Add food safety certification such as HACCP.',
      'Update the food laboratory equipment.',
    ],
  };

  /// Barangays of Oroquieta City.
  static const _barangays = [
    'Poblacion I',
    'Poblacion II',
    'Lower Langcangan',
    'Upper Langcangan',
    'Villaflor',
    'Taboc Norte',
    'Mobod',
    'Talairon',
    'Canubay',
    'Layawan',
  ];

  static const _mobilePrefixes = [
    '0917',
    '0927',
    '0935',
    '0945',
    '0956',
    '0966',
    '0977',
    '0995',
  ];

  /// Weighted towards the Android app and Chrome.
  static const List<DemoDevice> _devices = [
    (category: 'mobile', platform: 'android', browser: 'native'),
    (category: 'mobile', platform: 'android', browser: 'native'),
    (category: 'mobile', platform: 'android', browser: 'native'),
    (category: 'mobile', platform: 'ios', browser: 'native'),
    (category: 'mobile', platform: 'web', browser: 'chrome'),
    (category: 'mobile', platform: 'web', browser: 'safari'),
    (category: 'desktop', platform: 'web', browser: 'chrome'),
    (category: 'desktop', platform: 'web', browser: 'chrome'),
    (category: 'desktop', platform: 'web', browser: 'edge'),
    (category: 'tablet', platform: 'web', browser: 'safari'),
  ];

  static const _firstNames = [
    'Juan',
    'Maria',
    'Jose',
    'Ana',
    'Mark',
    'Kristine',
    'John Paul',
    'Angelica',
    'Carlo',
    'Jasmine',
    'Miguel',
    'Patricia',
    'Rafael',
    'Camille',
    'Joshua',
    'Nicole',
  ];

  static const _lastNames = [
    'Dela Cruz',
    'Santos',
    'Reyes',
    'Garcia',
    'Mendoza',
    'Bautista',
    'Villanueva',
    'Ramos',
    'Castillo',
    'Fernandez',
    'Lim',
    'Pacana',
    'Emano',
    'Neri',
  ];
}
