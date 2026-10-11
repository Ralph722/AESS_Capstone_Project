// Demo CHED GTS scenarios for the DSS. See docs/demo-data-plan.md.
//
// Counts are exact, not random, so tests and the demo project always show
// the same numbers.
import 'package:alumni_system/core/constants/gts_constants.dart';

/// Every demo account email ends with this domain.
const demoEmailDomain = 'demo.aess.test';

/// Every demo roster row has a student ID starting with this prefix.
const demoStudentIdPrefix = 'DEMO-';

/// The live project. Demo tooling refuses to run against it.
const liveProjectRef = 'lhukeauszbnsyybazauy';

const demoAdminEmail = 'admin@$demoEmailDomain';

/// The college onboarding pre-fills, so the tracer shows the same name.
const demoInstitution = GtsConstants.defaultCollegeUniversity;

/// The demo history ends here: nothing is registered, submitted or logged on
/// or after this date.
final demoSnapshot = DateTime.utc(2026, 10, 1);

/// The alumni office imported the roster at 08:30 Manila time. Nobody can
/// register before their roster row exists.
final demoRosterImportedAt = DateTime.utc(2024, 1, 15, 0, 30);

/// The demo admin account predates the roster import.
final demoAdminCreatedAt = DateTime.utc(2024, 1, 8, 1);

/// Graduation year typed at onboarding by alumni whose roster row has none.
/// Onboarding requires a year, and the database copies it into the roster.
const demoTypedBatch = '2021';

/// Program names as seeded by `20261005120000_phase3_architecture.sql`.
const demoProgramNames = {
  'BSIT': 'Bachelor of Science in Information Technology',
  'BFPT': 'Bachelor in Food Processing Technology',
  'BTLED-IA':
      'Bachelor of Technology and Livelihood Education major in Industrial Arts',
  'BTLED-ICT':
      'Bachelor of Technology and Livelihood Education major in Information and Communication Technology',
  'BTLED-HE':
      'Bachelor of Technology and Livelihood Education major in Home Economics',
};

class DemoWave {
  const DemoWave({
    required this.key,
    required this.id,
    required this.title,
    required this.status,
    required this.openAt,
    required this.closeAt,
  });

  final String key;
  final String id;
  final String title;

  /// `closed` or `published`.
  final String status;
  final DateTime openAt;
  final DateTime closeAt;
}

final demoWaves = [
  DemoWave(
    key: 'w2024',
    id: 'de3a0000-0000-4000-8000-000000002024',
    title: '[DEMO] CHED GTS 2024',
    status: 'closed',
    openAt: DateTime.utc(2024, 6, 1),
    closeAt: DateTime.utc(2024, 8, 31),
  ),
  DemoWave(
    key: 'w2025',
    id: 'de3a0000-0000-4000-8000-000000002025',
    title: '[DEMO] CHED GTS 2025',
    status: 'closed',
    openAt: DateTime.utc(2025, 6, 1),
    closeAt: DateTime.utc(2025, 8, 31),
  ),
  DemoWave(
    key: 'w2026',
    id: 'de3a0000-0000-4000-8000-000000002026',
    title: '[DEMO] CHED GTS 2026',
    status: 'published',
    openAt: DateTime.utc(2026, 6, 1),
    closeAt: DateTime.utc(2026, 12, 15),
  ),
];

/// Q17 reasons given by respondents who are not employed, as counts.
class DemoReasons {
  const DemoReasons({
    this.seeking = 0,
    this.furtherStudy = 0,
    this.family = 0,
    this.health = 0,
    this.didNotLook = 0,
    this.other = 0,
  });

  /// "No job opportunity" or "Lack of work experience" (alternating).
  final int seeking;
  final int furtherStudy;
  final int family;
  final int health;
  final int didNotLook;
  final int other;

  int get total =>
      seeking + furtherStudy + family + health + didNotLook + other;
}

/// What one cohort's respondents answered in one wave.
///
/// Respondents are the cohort's first [respondents] members, so a later wave
/// re-surveys the same alumni. The first [notEmployed] respondents are not
/// employed; the rest are employed. Counts for employed patterns apply to the
/// employed respondents only.
class DemoWaveSpec {
  const DemoWaveSpec({
    required this.wave,
    required this.respondents,
    this.notEmployed = 0,
    this.neverEmployed = 0,
    this.reasons = const DemoReasons(),
    this.mismatch = 0,
    this.clerical = 0,
    this.longWait = 0,
    this.q29Others = 0,
    this.lowSalary = 0,
    this.abroad = 0,
    this.suggestions = 0,
  });

  final String wave;
  final int respondents;

  /// Q16 "No" or "Never Employed".
  final int notEmployed;

  /// How many of [notEmployed] answer "Never Employed".
  final int neverEmployed;

  /// Must add up to [notEmployed].
  final DemoReasons reasons;

  /// Employed with Q24a = No and Q32 = No.
  final int mismatch;

  /// Employed with Q30 current job = Rank or Clerical.
  final int clerical;

  /// Employed with Q29 one year or longer.
  final int longWait;

  /// Employed with Q29 = "Others, please specify".
  final int q29Others;

  /// Employed with Q31 below P10,000.
  final int lowSalary;
  final int abroad;

  /// Employed respondents (starting with the mismatched ones) who write a
  /// Q34 curriculum suggestion.
  final int suggestions;

  int get employed => respondents - notEmployed;
}

class DemoCohort {
  const DemoCohort({
    required this.key,
    required this.course,
    required this.batch,
    required this.roster,
    required this.waves,
    required this.purpose,
    this.onRoster = true,
  });

  final String key;

  /// Program code; empty for respondents who are not on the roster.
  final String course;

  /// Graduation year; null when the roster has no batch recorded.
  final String? batch;

  /// Roster rows, including members who never respond.
  final int roster;
  final List<DemoWaveSpec> waves;
  final String purpose;
  final bool onRoster;

  int get respondentsMax =>
      waves.fold(0, (max, w) => w.respondents > max ? w.respondents : max);

  /// Members with an account: every respondent, plus a quarter of the roster
  /// (rounded up) who registered but never answered.
  int get registered {
    if (!onRoster) return respondentsMax;
    final total = respondentsMax + (roster + 3) ~/ 4;
    return total < roster ? total : roster;
  }
}

const demoCohorts = [
  DemoCohort(
    key: 'bsit-2022',
    course: 'BSIT',
    batch: '2022',
    roster: 30,
    purpose: 'Trend: not employed rises from 12% to 32% between waves.',
    waves: [
      DemoWaveSpec(
        wave: 'w2024',
        respondents: 25,
        notEmployed: 3,
        neverEmployed: 1,
        reasons: DemoReasons(seeking: 3),
        mismatch: 3,
        clerical: 3,
        longWait: 3,
        lowSalary: 2,
        abroad: 2,
      ),
      DemoWaveSpec(
        wave: 'w2025',
        respondents: 25,
        notEmployed: 8,
        neverEmployed: 2,
        reasons: DemoReasons(seeking: 7, family: 1),
        mismatch: 3,
        clerical: 3,
        longWait: 3,
        lowSalary: 2,
        abroad: 2,
      ),
    ],
  ),
  DemoCohort(
    key: 'bsit-2023',
    course: 'BSIT',
    batch: '2023',
    roster: 45,
    purpose:
        'Strong unemployment finding (mostly job-seeking) that improves in '
        'the next wave; high relatedness; Q29 "Others".',
    waves: [
      DemoWaveSpec(
        wave: 'w2025',
        respondents: 40,
        notEmployed: 14,
        neverEmployed: 6,
        reasons: DemoReasons(seeking: 10, furtherStudy: 2, family: 1, other: 1),
        mismatch: 2,
        clerical: 4,
        longWait: 4,
        q29Others: 2,
        lowSalary: 3,
        abroad: 1,
        suggestions: 3,
      ),
      DemoWaveSpec(
        wave: 'w2026',
        respondents: 35,
        notEmployed: 5,
        neverEmployed: 1,
        reasons: DemoReasons(seeking: 3, furtherStudy: 2),
        mismatch: 2,
        clerical: 4,
        longWait: 4,
        q29Others: 1,
        lowSalary: 3,
        abroad: 2,
        suggestions: 2,
      ),
    ],
  ),
  DemoCohort(
    key: 'bsit-2024',
    course: 'BSIT',
    batch: '2024',
    roster: 60,
    purpose: 'Low response rate: 12 of 60 on the roster responded.',
    waves: [
      DemoWaveSpec(
        wave: 'w2025',
        respondents: 12,
        notEmployed: 2,
        neverEmployed: 2,
        reasons: DemoReasons(seeking: 2),
        mismatch: 1,
        clerical: 2,
        longWait: 1,
        lowSalary: 2,
      ),
    ],
  ),
  DemoCohort(
    key: 'btled-ict-2023',
    course: 'BTLED-ICT',
    batch: '2023',
    roster: 24,
    purpose:
        'Not employed mostly because of further study (no job-seeking '
        'advice); next wave has only 3 respondents.',
    waves: [
      DemoWaveSpec(
        wave: 'w2025',
        respondents: 20,
        notEmployed: 8,
        neverEmployed: 5,
        reasons: DemoReasons(furtherStudy: 6, family: 1, health: 1),
        mismatch: 2,
        clerical: 2,
        longWait: 2,
        lowSalary: 2,
        suggestions: 1,
      ),
      DemoWaveSpec(
        wave: 'w2026',
        respondents: 3,
        notEmployed: 1,
        reasons: DemoReasons(furtherStudy: 1),
        lowSalary: 1,
      ),
    ],
  ),
  DemoCohort(
    key: 'btled-ict-2024',
    course: 'BTLED-ICT',
    batch: '2024',
    roster: 22,
    purpose:
        'Only 3 of 20 respondents are employed, so Q29 has 3 valid answers.',
    waves: [
      DemoWaveSpec(
        wave: 'w2025',
        respondents: 20,
        notEmployed: 17,
        neverEmployed: 15,
        reasons: DemoReasons(seeking: 13, didNotLook: 4),
        longWait: 2,
        lowSalary: 1,
      ),
    ],
  ),
  DemoCohort(
    key: 'btled-he-2024',
    course: 'BTLED-HE',
    batch: '2024',
    roster: 15,
    purpose:
        'Limited evidence (12 answers): course mismatch, clerical jobs, low '
        'pay and long waits that stay the same in the next wave.',
    waves: [
      DemoWaveSpec(
        wave: 'w2025',
        respondents: 12,
        notEmployed: 2,
        neverEmployed: 1,
        reasons: DemoReasons(seeking: 2),
        mismatch: 6,
        clerical: 6,
        longWait: 4,
        q29Others: 1,
        lowSalary: 7,
        suggestions: 5,
      ),
      DemoWaveSpec(
        wave: 'w2026',
        respondents: 12,
        notEmployed: 2,
        neverEmployed: 1,
        reasons: DemoReasons(seeking: 2),
        mismatch: 6,
        clerical: 6,
        longWait: 4,
        q29Others: 1,
        lowSalary: 7,
        suggestions: 4,
      ),
    ],
  ),
  DemoCohort(
    key: 'btled-ia-2024',
    course: 'BTLED-IA',
    batch: '2024',
    roster: 10,
    purpose: 'Watch: 7 valid answers.',
    waves: [
      DemoWaveSpec(
        wave: 'w2025',
        respondents: 7,
        notEmployed: 4,
        neverEmployed: 2,
        reasons: DemoReasons(seeking: 3, didNotLook: 1),
        clerical: 1,
        longWait: 1,
        lowSalary: 1,
      ),
    ],
  ),
  DemoCohort(
    key: 'bfpt-2022',
    course: 'BFPT',
    batch: '2022',
    roster: 6,
    purpose: 'Not enough data: 4 valid answers.',
    waves: [
      DemoWaveSpec(
        wave: 'w2025',
        respondents: 4,
        notEmployed: 2,
        neverEmployed: 1,
        reasons: DemoReasons(seeking: 1, family: 1),
        clerical: 1,
      ),
    ],
  ),
  DemoCohort(
    key: 'bfpt-2023',
    course: 'BFPT',
    batch: '2023',
    roster: 5,
    purpose: 'Privacy: a single respondent.',
    waves: [
      DemoWaveSpec(
        wave: 'w2025',
        respondents: 1,
        notEmployed: 1,
        reasons: DemoReasons(seeking: 1),
      ),
    ],
  ),
  DemoCohort(
    key: 'bfpt-2024',
    course: 'BFPT',
    batch: '2024',
    roster: 15,
    purpose: 'Data quality with zero responses.',
    waves: [],
  ),
  DemoCohort(
    key: 'bsit-nobatch',
    course: 'BSIT',
    batch: null,
    roster: 6,
    purpose:
        'Batch not recorded: counts for BSIT course level only, never for a '
        'batch finding. Offline only: in the hosted demo they type '
        '$demoTypedBatch at onboarding, which fills their roster batch.',
    waves: [
      DemoWaveSpec(
        wave: 'w2025',
        respondents: 5,
        notEmployed: 2,
        neverEmployed: 1,
        reasons: DemoReasons(seeking: 1, furtherStudy: 1),
        mismatch: 1,
        clerical: 1,
        longWait: 1,
        lowSalary: 1,
      ),
    ],
  ),
  DemoCohort(
    key: 'off-roster',
    course: '',
    batch: null,
    roster: 0,
    onRoster: false,
    purpose:
        'Respondents not on the roster: never assigned to a course or batch.',
    waves: [
      DemoWaveSpec(
        wave: 'w2025',
        respondents: 3,
        notEmployed: 1,
        neverEmployed: 1,
        reasons: DemoReasons(seeking: 1),
        mismatch: 1,
        lowSalary: 1,
      ),
    ],
  ),
];

/// Demo alumni who can log in, as (cohort key, member number). They get the
/// emails alumni1@, alumni2@ and alumni3@ the demo domain.
const demoLoginMembers = [
  ('bsit-2023', 1),
  ('btled-ict-2024', 1),
  ('btled-he-2024', 1),
];
