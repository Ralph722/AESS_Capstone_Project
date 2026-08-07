import 'package:alumni_system/core/constants/gts_constants.dart';

/// Official built-in CHED Graduate Tracer Study (GTS) schema.
///
/// Answer keys are stable (`ched_16`, …) and stored in `survey_responses.answers`.
abstract final class ChedGtsBuiltin {
  static const kind = 'ched_gts_builtin';
  static const templateKey = 'ched_gts_builtin';
  static const schemaVersion = '3.0.0';

  static const defaultTitle = 'CHED Graduate Tracer Survey (GTS)';
  static const defaultDescription =
      'Official Commission on Higher Education Graduate Tracer Study questionnaire. '
      'Your answers are confidential and used to assess graduate employability.';

  static const yes = 'Yes';
  static const no = 'No';
  static const neverEmployed = 'Never Employed';
  static const selfEmployed = 'Self-employed';
  static const othersSpecify = 'Others, please specify';
  static const otherReasonsSpecify = 'Other reason(s), please specify';
  static const otherSkillsSpecify = 'Other skills, please specify';

  static List<ChedGtsItem> get items => _items;

  static ChedGtsItem? byId(String id) {
    for (final item in _items) {
      if (item.id == id) return item;
    }
    return null;
  }

  static const _reasonRows = [
    'High grades in the course or subject area(s) related to the course',
    'Good grades in high school',
    'Influence of parents or relatives',
    'Peer Influence',
    'Inspired by a role model',
    'Strong passion for the profession',
    'Prospect for immediate employment',
    'Status or prestige of the profession',
    'Availability of course offering in chosen institution',
    'Prospect of career advancement',
    'Affordable for the family',
    'Prospect of attractive compensation',
    'Opportunity for employment abroad',
    'No particular choice or no better idea',
    'Others, please specify',
  ];

  static const _lineOfBusiness = [
    'Agriculture, Hunting and Forestry',
    'Fishing',
    'Mining and Quarrying',
    'Manufacturing',
    'Electricity, Gas and Water Supply',
    'Construction',
    'Wholesale and Retail Trade, repair of motor vehicles, motorcycles and personal and household goods',
    'Hotels and Restaurants',
    'Transport Storage and Communication',
    'Financial Intermediation',
    'Real Estate, Renting and Business Activities',
    'Public Administration and Defense; Compulsory Social Security',
    'Education',
    'Health and Social Work',
    'Other Community, Social and Personal Service Activities',
    'Private Households with Employed Persons',
    'Extra-territorial Organizations and Bodies',
  ];

  static const _jobLevels = [
    'Rank or Clerical',
    'Professional, Technical or Supervisory',
    'Managerial or Executive',
    'Self-employed',
  ];

  static const _durationOptions = [
    'Less than a month',
    '1 to 6 months',
    '7 to 11 months',
    '1 year to less than 2 years',
    '2 years to less than 3 years',
    '3 years to less than 4 years',
    'Others, please specify',
  ];

  static final List<ChedGtsItem> _items = [
    // —— A ——
    ChedGtsItem(
      id: 'ched_1',
      chedNumber: '1',
      section: ChedGtsSection.a,
      type: ChedGtsFieldType.text,
      prompt: 'Name',
      required: true,
      prefillKey: 'profile.displayName',
    ),
    ChedGtsItem(
      id: 'ched_2',
      chedNumber: '2',
      section: ChedGtsSection.a,
      type: ChedGtsFieldType.text,
      prompt: 'Permanent Address',
      required: true,
      prefillKey: 'profile.address',
    ),
    ChedGtsItem(
      id: 'ched_3',
      chedNumber: '3',
      section: ChedGtsSection.a,
      type: ChedGtsFieldType.text,
      prompt: 'E-mail Address',
      required: true,
      prefillKey: 'profile.email',
    ),
    ChedGtsItem(
      id: 'ched_4',
      chedNumber: '4',
      section: ChedGtsSection.a,
      type: ChedGtsFieldType.text,
      prompt: 'Telephone or Contact Number(s)',
      required: true,
      prefillKey: 'profile.telephoneNumber',
    ),
    ChedGtsItem(
      id: 'ched_5',
      chedNumber: '5',
      section: ChedGtsSection.a,
      type: ChedGtsFieldType.text,
      prompt: 'Mobile Number',
      required: true,
      prefillKey: 'profile.mobileNumber',
    ),
    ChedGtsItem(
      id: 'ched_6',
      chedNumber: '6',
      section: ChedGtsSection.a,
      type: ChedGtsFieldType.single,
      prompt: 'Civil Status',
      options: GtsConstants.civilStatuses,
      required: true,
      prefillKey: 'profile.civilStatus',
    ),
    ChedGtsItem(
      id: 'ched_7',
      chedNumber: '7',
      section: ChedGtsSection.a,
      type: ChedGtsFieldType.single,
      prompt: 'Sex',
      options: GtsConstants.sexOptions,
      required: true,
      prefillKey: 'profile.gender',
    ),
    ChedGtsItem(
      id: 'ched_8',
      chedNumber: '8',
      section: ChedGtsSection.a,
      type: ChedGtsFieldType.date,
      prompt: 'Birthday',
      required: true,
      prefillKey: 'profile.birthDate',
    ),
    ChedGtsItem(
      id: 'ched_9',
      chedNumber: '9',
      section: ChedGtsSection.a,
      type: ChedGtsFieldType.single,
      prompt: 'Region of Origin',
      options: GtsConstants.regionsOfOrigin,
      required: true,
      prefillKey: 'profile.regionOfOrigin',
    ),
    ChedGtsItem(
      id: 'ched_10',
      chedNumber: '10',
      section: ChedGtsSection.a,
      type: ChedGtsFieldType.text,
      prompt: 'Province',
      required: true,
      prefillKey: 'profile.province',
    ),
    ChedGtsItem(
      id: 'ched_11',
      chedNumber: '11',
      section: ChedGtsSection.a,
      type: ChedGtsFieldType.single,
      prompt: 'Location of Residence',
      options: GtsConstants.locationOfResidenceOptions,
      required: true,
      prefillKey: 'profile.locationOfResidence',
    ),

    // —— B ——
    ChedGtsItem(
      id: 'ched_12',
      chedNumber: '12',
      section: ChedGtsSection.b,
      type: ChedGtsFieldType.tableRows,
      prompt:
          'Educational Attainment (Baccalaureate Degree only)',
      tableColumns: const [
        'Degree(s) & Specialization(s)',
        'College or University',
        'Year Graduated',
        'Honor(s) or Award(s) Received',
      ],
      required: true,
      prefillKey: 'profile.educationRow',
    ),
    ChedGtsItem(
      id: 'ched_13',
      chedNumber: '13',
      section: ChedGtsSection.b,
      type: ChedGtsFieldType.tableRows,
      prompt: 'Professional Examination(s) Passed',
      tableColumns: const [
        'Name of Examination',
        'Date Taken',
        'Rating',
      ],
      required: false,
    ),
    ChedGtsItem(
      id: 'ched_14',
      chedNumber: '14',
      section: ChedGtsSection.b,
      type: ChedGtsFieldType.matrix,
      prompt:
          'Reason(s) for taking the course(s) or pursuing degree(s). You may check more than one answer.',
      matrixRows: _reasonRows,
      matrixColumns: const [
        'Undergraduate/AB/BS',
        'Graduate/MS/MA/PhD',
      ],
      required: false,
      othersSpecifyId: 'ched_14_other',
    ),
    ChedGtsItem(
      id: 'ched_14_other',
      chedNumber: '14',
      section: ChedGtsSection.b,
      type: ChedGtsFieldType.text,
      prompt: 'Others, please specify (reasons for taking the course)',
      required: false,
      isOthersSpecify: true,
    ),

    // —— C ——
    ChedGtsItem(
      id: 'ched_15a',
      chedNumber: '15a',
      section: ChedGtsSection.c,
      type: ChedGtsFieldType.tableRows,
      prompt:
          'Please list down all professional or work-related training program(s) including advance studies you have attended after college.',
      tableColumns: const [
        'Title of Training or Advance Study',
        'Duration and Credits Earned',
        'Name of Training Institution/College/University',
      ],
      required: false,
    ),
    ChedGtsItem(
      id: 'ched_15b',
      chedNumber: '15b',
      section: ChedGtsSection.c,
      type: ChedGtsFieldType.single,
      prompt: 'What made you pursue advance studies?',
      options: const [
        'For promotion',
        'For professional development',
        'Others, please specify',
      ],
      required: false,
      othersSpecifyId: 'ched_15b_other',
    ),
    ChedGtsItem(
      id: 'ched_15b_other',
      chedNumber: '15b',
      section: ChedGtsSection.c,
      type: ChedGtsFieldType.text,
      prompt: 'Others, please specify (advance studies)',
      required: false,
      isOthersSpecify: true,
    ),

    // —— D ——
    ChedGtsItem(
      id: 'ched_16',
      chedNumber: '16',
      section: ChedGtsSection.d,
      type: ChedGtsFieldType.single,
      prompt: 'Are you presently employed?',
      options: const [yes, no, neverEmployed],
      required: true,
      prefillKey: 'employment.presentlyEmployed',
    ),
    ChedGtsItem(
      id: 'ched_17',
      chedNumber: '17',
      section: ChedGtsSection.d,
      type: ChedGtsFieldType.multi,
      prompt:
          'Please state reason(s) why you are not yet employed. You may check more than one answer.',
      options: const [
        'Advance or further study',
        'Family concern and decided not to find a job',
        'Health-related reason(s)',
        'Lack of work experience',
        'No job opportunity',
        'Did not look for a job',
        'Other reason(s), please specify',
      ],
      required: true,
      othersSpecifyId: 'ched_17_other',
    ),
    ChedGtsItem(
      id: 'ched_17_other',
      chedNumber: '17',
      section: ChedGtsSection.d,
      type: ChedGtsFieldType.text,
      prompt: 'Other reason(s), please specify (not employed)',
      required: false,
      isOthersSpecify: true,
    ),
    ChedGtsItem(
      id: 'ched_18',
      chedNumber: '18',
      section: ChedGtsSection.d,
      type: ChedGtsFieldType.single,
      prompt: 'Present Employment Status',
      options: const [
        'Regular or Permanent',
        'Temporary',
        'Casual',
        'Contractual',
        'Self-employed',
      ],
      required: true,
      prefillKey: 'employment.employmentStatus',
    ),
    ChedGtsItem(
      id: 'ched_18_skills',
      chedNumber: '18',
      section: ChedGtsSection.d,
      type: ChedGtsFieldType.text,
      prompt:
          'If self-employed, what skills acquired in college were you able to apply in your work?',
      required: false,
    ),
    ChedGtsItem(
      id: 'ched_19',
      chedNumber: '19',
      section: ChedGtsSection.d,
      type: ChedGtsFieldType.text,
      prompt:
          'Present occupation (Ex. Grade School Teacher, Electrical Engineer, Self-employed)',
      required: true,
      prefillKey: 'employment.position',
    ),
    ChedGtsItem(
      id: 'ched_20',
      chedNumber: '20',
      section: ChedGtsSection.d,
      type: ChedGtsFieldType.single,
      prompt:
          'Major line of business of the company you are presently employed in. Check one only.',
      options: _lineOfBusiness,
      required: true,
      prefillKey: 'employment.industry',
    ),
    ChedGtsItem(
      id: 'ched_21',
      chedNumber: '21',
      section: ChedGtsSection.d,
      type: ChedGtsFieldType.single,
      prompt: 'Place of work',
      options: const ['Local', 'Abroad'],
      required: true,
      prefillKey: 'employment.placeOfWork',
    ),
    ChedGtsItem(
      id: 'ched_22',
      chedNumber: '22',
      section: ChedGtsSection.d,
      type: ChedGtsFieldType.single,
      prompt: 'Is this your first job after college?',
      options: const [yes, no],
      required: true,
    ),
    ChedGtsItem(
      id: 'ched_23',
      chedNumber: '23',
      section: ChedGtsSection.d,
      type: ChedGtsFieldType.multi,
      prompt:
          'What are your reason(s) for staying on the job? You may check more than one answer.',
      options: const [
        'Salaries and benefits',
        'Career challenge',
        'Related to special skill',
        'Related to course or program of study',
        'Proximity to residence',
        'Peer influence',
        'Family influence',
        'Other reason(s), please specify',
      ],
      required: true,
      othersSpecifyId: 'ched_23_other',
    ),
    ChedGtsItem(
      id: 'ched_23_other',
      chedNumber: '23',
      section: ChedGtsSection.d,
      type: ChedGtsFieldType.text,
      prompt: 'Other reason(s), please specify (staying on the job)',
      required: false,
      isOthersSpecify: true,
    ),
    ChedGtsItem(
      id: 'ched_24a',
      chedNumber: '24a',
      section: ChedGtsSection.d,
      type: ChedGtsFieldType.single,
      prompt:
          'Is your first job related to the course you took up in college?',
      options: const [yes, no],
      required: true,
    ),
    ChedGtsItem(
      id: 'ched_24b',
      chedNumber: '24b',
      section: ChedGtsSection.d,
      type: ChedGtsFieldType.multi,
      prompt:
          'What were your reasons for accepting the job? You may check more than one answer.',
      options: const [
        'Salaries & benefits',
        'Career challenge',
        'Related to special skills',
        'Proximity to residence',
        'Other reason(s), please specify',
      ],
      required: true,
      othersSpecifyId: 'ched_24b_other',
    ),
    ChedGtsItem(
      id: 'ched_24b_other',
      chedNumber: '24b',
      section: ChedGtsSection.d,
      type: ChedGtsFieldType.text,
      prompt: 'Other reason(s), please specify (accepting the job)',
      required: false,
      isOthersSpecify: true,
    ),
    ChedGtsItem(
      id: 'ched_25',
      chedNumber: '25',
      section: ChedGtsSection.d,
      type: ChedGtsFieldType.multi,
      prompt:
          'What were your reason(s) for changing job? You may check more than one answer.',
      options: const [
        'Salaries & benefits',
        'Career challenge',
        'Related to special skills',
        'Proximity to residence',
        'Other reason(s), please specify',
      ],
      required: true,
      othersSpecifyId: 'ched_25_other',
    ),
    ChedGtsItem(
      id: 'ched_25_other',
      chedNumber: '25',
      section: ChedGtsSection.d,
      type: ChedGtsFieldType.text,
      prompt: 'Other reason(s), please specify (changing job)',
      required: false,
      isOthersSpecify: true,
    ),
    ChedGtsItem(
      id: 'ched_27',
      chedNumber: '27',
      section: ChedGtsSection.d,
      type: ChedGtsFieldType.single,
      prompt: 'How long did you stay in your first job?',
      options: _durationOptions,
      required: true,
      othersSpecifyId: 'ched_27_other',
    ),
    ChedGtsItem(
      id: 'ched_27_other',
      chedNumber: '27',
      section: ChedGtsSection.d,
      type: ChedGtsFieldType.text,
      prompt: 'Others, please specify (length of stay in first job)',
      required: false,
      isOthersSpecify: true,
    ),
    ChedGtsItem(
      id: 'ched_28',
      chedNumber: '28',
      section: ChedGtsSection.d,
      type: ChedGtsFieldType.single,
      prompt: 'How did you find your first job?',
      options: const [
        'Response to an advertisement',
        'As walk-in applicant',
        'Recommended by someone',
        'Information from friends',
        "Arranged by school's job placement officer",
        'Family business',
        'Job Fair or Public Employment Service Office (PESO)',
        'Others, please specify',
      ],
      required: true,
      othersSpecifyId: 'ched_28_other',
    ),
    ChedGtsItem(
      id: 'ched_28_other',
      chedNumber: '28',
      section: ChedGtsSection.d,
      type: ChedGtsFieldType.text,
      prompt: 'Others, please specify (how you found first job)',
      required: false,
      isOthersSpecify: true,
    ),
    ChedGtsItem(
      id: 'ched_29',
      chedNumber: '29',
      section: ChedGtsSection.d,
      type: ChedGtsFieldType.single,
      prompt: 'How long did it take you to land your first job?',
      options: _durationOptions,
      required: true,
      othersSpecifyId: 'ched_29_other',
    ),
    ChedGtsItem(
      id: 'ched_29_other',
      chedNumber: '29',
      section: ChedGtsSection.d,
      type: ChedGtsFieldType.text,
      prompt: 'Others, please specify (time to land first job)',
      required: false,
      isOthersSpecify: true,
    ),
    ChedGtsItem(
      id: 'ched_30',
      chedNumber: '30',
      section: ChedGtsSection.d,
      type: ChedGtsFieldType.matrix,
      prompt: 'Job Level Position',
      matrixRows: _jobLevels,
      matrixColumns: const [
        '30.1. First Job',
        '30.2. Current or Present Job',
      ],
      required: true,
    ),
    ChedGtsItem(
      id: 'ched_31',
      chedNumber: '31',
      section: ChedGtsSection.d,
      type: ChedGtsFieldType.single,
      prompt:
          'What is your initial gross monthly earning in your first job after college?',
      options: const [
        'Below P5,000.00',
        'P5,000.00 to less than P10,000.00',
        'P10,000.00 to less than P15,000.00',
        'P15,000.00 to less than P20,000.00',
        'P20,000.00 to less than P25,000.00',
        'P25,000.00 and above',
      ],
      required: true,
      prefillKey: 'employment.salaryRange',
    ),
    ChedGtsItem(
      id: 'ched_32',
      chedNumber: '32',
      section: ChedGtsSection.d,
      type: ChedGtsFieldType.single,
      prompt:
          'Was the curriculum you had in college relevant to your first job?',
      options: const [yes, no],
      required: true,
    ),
    ChedGtsItem(
      id: 'ched_33',
      chedNumber: '33',
      section: ChedGtsSection.d,
      type: ChedGtsFieldType.multi,
      prompt:
          'If YES, what competencies learned in college did you find very useful in your first job? You may check more than one answer.',
      options: const [
        'Communication skills',
        'Human Relations skills',
        'Entrepreneurial skills',
        'Information Technology skills',
        'Problem-solving skills',
        'Critical Thinking skills',
        'Other skills, please specify',
      ],
      required: true,
      othersSpecifyId: 'ched_33_other',
    ),
    ChedGtsItem(
      id: 'ched_33_other',
      chedNumber: '33',
      section: ChedGtsSection.d,
      type: ChedGtsFieldType.text,
      prompt: 'Other skills, please specify',
      required: false,
      isOthersSpecify: true,
    ),
    ChedGtsItem(
      id: 'ched_34',
      chedNumber: '34',
      section: ChedGtsSection.d,
      type: ChedGtsFieldType.longText,
      prompt: 'List down suggestions to further improve your course curriculum',
      required: false,
    ),
  ];
}

enum ChedGtsSection { a, b, c, d }

enum ChedGtsFieldType {
  text,
  longText,
  single,
  multi,
  date,
  matrix,
  tableRows,
}

class ChedGtsItem {
  const ChedGtsItem({
    required this.id,
    required this.chedNumber,
    required this.section,
    required this.type,
    required this.prompt,
    this.options = const [],
    this.matrixRows = const [],
    this.matrixColumns = const [],
    this.tableColumns = const [],
    this.required = false,
    this.prefillKey,
    this.othersSpecifyId,
    this.isOthersSpecify = false,
  });

  final String id;
  final String chedNumber;
  final ChedGtsSection section;
  final ChedGtsFieldType type;
  final String prompt;
  final List<String> options;
  final List<String> matrixRows;
  final List<String> matrixColumns;
  final List<String> tableColumns;
  final bool required;
  final String? prefillKey;
  final String? othersSpecifyId;
  final bool isOthersSpecify;

  String get sectionTitle => switch (section) {
        ChedGtsSection.a => 'A. GENERAL INFORMATION',
        ChedGtsSection.b => 'B. EDUCATIONAL BACKGROUND',
        ChedGtsSection.c =>
          'C. TRAINING(S)/ADVANCE STUDIES ATTENDED AFTER COLLEGE',
        ChedGtsSection.d => 'D. EMPLOYMENT DATA',
      };
}
