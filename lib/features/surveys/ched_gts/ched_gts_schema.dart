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
    'Others, please specify',
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
      helpText: 'Write your full name: Last name, First name, Middle name.',
      required: true,
      prefillKey: 'profile.displayName',
    ),
    ChedGtsItem(
      id: 'ched_2',
      chedNumber: '2',
      section: ChedGtsSection.a,
      type: ChedGtsFieldType.text,
      prompt: 'Permanent Address',
      helpText:
          'House no. or street, barangay, city or municipality, and '
          'province.',
      required: true,
      prefillKey: 'profile.address',
    ),
    ChedGtsItem(
      id: 'ched_3',
      chedNumber: '3',
      section: ChedGtsSection.a,
      type: ChedGtsFieldType.text,
      prompt: 'E-mail Address',
      helpText: 'Use an email address you check regularly.',
      required: true,
      prefillKey: 'profile.email',
    ),
    ChedGtsItem(
      id: 'ched_4',
      chedNumber: '4',
      section: ChedGtsSection.a,
      type: ChedGtsFieldType.text,
      prompt: 'Telephone or Contact Number(s)',
      helpText:
          'A landline or another number where you can be reached. If you '
          'only have a mobile number, you can write it here too.',
      required: true,
      prefillKey: 'profile.telephoneNumber',
    ),
    ChedGtsItem(
      id: 'ched_5',
      chedNumber: '5',
      section: ChedGtsSection.a,
      type: ChedGtsFieldType.text,
      prompt: 'Mobile Number',
      helpText: 'Your active mobile number, e.g. 0917 123 4567.',
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
      helpText:
          'The region of your home province, e.g. Region 10 for Misamis '
          'Oriental or Bukidnon.',
      required: true,
      prefillKey: 'profile.regionOfOrigin',
    ),
    ChedGtsItem(
      id: 'ched_10',
      chedNumber: '10',
      section: ChedGtsSection.a,
      type: ChedGtsFieldType.text,
      prompt: 'Province',
      helpText:
          'The province of your permanent address, e.g. Misamis Oriental.',
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
      helpText:
          'Choose City if you live in a city, or Municipality if you live'
          ' in a town.',
      required: true,
      prefillKey: 'profile.locationOfResidence',
    ),

    // —— B ——
    ChedGtsItem(
      id: 'ched_12',
      chedNumber: '12',
      section: ChedGtsSection.b,
      type: ChedGtsFieldType.tableRows,
      prompt: 'Educational Attainment (Baccalaureate Degree only)',
      tableColumns: const [
        'Degree(s) & Specialization(s)',
        'College or University',
        'Year Graduated',
        'Honor(s) or Award(s) Received',
      ],
      helpText:
          'Your bachelor\'s degree (e.g. BS Information Technology), '
          'school, year graduated, and honors such as Cum Laude. Add a '
          'row for each degree.',
      required: true,
      prefillKey: 'profile.educationRow',
    ),
    ChedGtsItem(
      id: 'ched_13',
      chedNumber: '13',
      section: ChedGtsSection.b,
      type: ChedGtsFieldType.tableRows,
      prompt: 'Professional Examination(s) Passed',
      tableColumns: const ['Name of Examination', 'Date Taken', 'Rating'],
      helpText:
          'Licensure or civil service exams you passed, e.g. LET or Civil'
          ' Service Professional. Leave blank if none.',
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
      matrixColumns: const ['Undergraduate/AB/BS', 'Graduate/MS/MA/PhD'],
      helpText:
          'Tick every reason that applies. Use the Undergraduate column '
          'for your bachelor\'s degree, and the Graduate column only if '
          'you took a master\'s or PhD.',
      required: false,
      othersSpecifyId: 'ched_14_other',
    ),
    ChedGtsItem(
      id: 'ched_14_other',
      chedNumber: '14',
      section: ChedGtsSection.b,
      type: ChedGtsFieldType.text,
      prompt: 'Others, please specify (reasons for taking the course)',
      required: true,
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
      helpText:
          'Seminars, certifications, short courses or graduate studies '
          'after college, e.g. "CCNA Certification, 40 hours, Cisco '
          'Networking Academy". Leave blank if none.',
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
      helpText:
          'Answer only if you took advance studies such as a master\'s '
          'degree. Otherwise, skip it.',
      required: false,
      othersSpecifyId: 'ched_15b_other',
    ),
    ChedGtsItem(
      id: 'ched_15b_other',
      chedNumber: '15b',
      section: ChedGtsSection.c,
      type: ChedGtsFieldType.text,
      prompt: 'Others, please specify (advance studies)',
      required: true,
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
      helpText:
          'Yes if you have paid work now, including part-time or '
          'self-employment. No if you worked before but not now. Never '
          'Employed if you have never had a job.',
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
      helpText:
          'Tick every reason that explains why you are not working right '
          'now.',
      required: true,
      othersSpecifyId: 'ched_17_other',
    ),
    ChedGtsItem(
      id: 'ched_17_other',
      chedNumber: '17',
      section: ChedGtsSection.d,
      type: ChedGtsFieldType.text,
      prompt: 'Other reason(s), please specify (not employed)',
      required: true,
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
      helpText:
          'Regular or Permanent: a permanent position, usually after '
          'probation. Temporary: a short-term post, such as a substitute '
          'role. Casual: paid per day or only when needed. Contractual: a'
          ' fixed-term or project-based contract. Self-employed: you run '
          'your own business or freelance.',
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
      helpText:
          'For example: programming, bookkeeping, customer service or '
          'marketing skills you use in your business.',
      required: false,
    ),
    ChedGtsItem(
      id: 'ched_19',
      chedNumber: '19',
      section: ChedGtsSection.d,
      type: ChedGtsFieldType.text,
      prompt:
          'Present occupation (Ex. Grade School Teacher, Electrical Engineer, Self-employed)',
      helpText:
          'Write your job title, e.g. Web Developer, Sales Associate or '
          'Delivery Driver. If you run your own business, write '
          'Self-employed and what you do.',
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
      helpText:
          'Not sure where your company fits? IT, software, BPO and consulting '
          'firms fall under Real Estate, Renting and Business Activities; '
          'telecommunications falls under Transport Storage and Communication. '
          'If none fits, choose Others, please specify.',
      required: true,
      prefillKey: 'employment.industry',
      othersSpecifyId: 'ched_20_other',
    ),
    ChedGtsItem(
      id: 'ched_20_other',
      chedNumber: '20',
      section: ChedGtsSection.d,
      type: ChedGtsFieldType.text,
      prompt: 'Others, please specify (line of business)',
      required: true,
      isOthersSpecify: true,
    ),
    ChedGtsItem(
      id: 'ched_21',
      chedNumber: '21',
      section: ChedGtsSection.d,
      type: ChedGtsFieldType.single,
      prompt: 'Place of work',
      options: const ['Local', 'Abroad'],
      helpText:
          'Local if your workplace is in the Philippines, Abroad if it is'
          ' in another country.',
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
      helpText:
          'Yes if this is the first job you had after graduating. No if '
          'you worked somewhere else before this job.',
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
      helpText: 'Tick every reason that keeps you in your current job.',
      required: true,
      othersSpecifyId: 'ched_23_other',
    ),
    ChedGtsItem(
      id: 'ched_23_other',
      chedNumber: '23',
      section: ChedGtsSection.d,
      type: ChedGtsFieldType.text,
      prompt: 'Other reason(s), please specify (staying on the job)',
      required: true,
      isOthersSpecify: true,
    ),
    ChedGtsItem(
      id: 'ched_24a',
      chedNumber: '24',
      section: ChedGtsSection.d,
      type: ChedGtsFieldType.single,
      prompt: 'Is your first job related to the course you took up in college?',
      options: const [yes, no],
      helpText:
          'Yes if your first job after college used the knowledge or '
          'skills from your course.',
      required: true,
    ),
    ChedGtsItem(
      id: 'ched_24b',
      chedNumber: '25',
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
      helpText:
          'Think about why you accepted your first job offer. Tick all '
          'that apply.',
      required: true,
      othersSpecifyId: 'ched_24b_other',
    ),
    ChedGtsItem(
      id: 'ched_24b_other',
      chedNumber: '25',
      section: ChedGtsSection.d,
      type: ChedGtsFieldType.text,
      prompt: 'Other reason(s), please specify (accepting the job)',
      required: true,
      isOthersSpecify: true,
    ),
    ChedGtsItem(
      id: 'ched_25',
      chedNumber: '26',
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
      helpText:
          'Answer if you have changed jobs since your first job. Tick '
          'every reason you moved.',
      required: true,
      othersSpecifyId: 'ched_25_other',
    ),
    ChedGtsItem(
      id: 'ched_25_other',
      chedNumber: '26',
      section: ChedGtsSection.d,
      type: ChedGtsFieldType.text,
      prompt: 'Other reason(s), please specify (changing job)',
      required: true,
      isOthersSpecify: true,
    ),
    ChedGtsItem(
      id: 'ched_27',
      chedNumber: '27',
      section: ChedGtsSection.d,
      type: ChedGtsFieldType.single,
      prompt: 'How long did you stay in your first job?',
      options: _durationOptions,
      helpText:
          'Count from your first day to your last day in your first job. '
          'If you are still there, count up to today.',
      required: true,
      othersSpecifyId: 'ched_27_other',
    ),
    ChedGtsItem(
      id: 'ched_27_other',
      chedNumber: '27',
      section: ChedGtsSection.d,
      type: ChedGtsFieldType.text,
      prompt: 'Others, please specify (length of stay in first job)',
      required: true,
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
      helpText:
          'Advertisement: you applied to a job post (online, print or '
          'social media). Walk-in: you applied in person without a '
          'posting. Recommended: someone referred or endorsed you. '
          'Friends: friends told you about the opening.',
      required: true,
      othersSpecifyId: 'ched_28_other',
    ),
    ChedGtsItem(
      id: 'ched_28_other',
      chedNumber: '28',
      section: ChedGtsSection.d,
      type: ChedGtsFieldType.text,
      prompt: 'Others, please specify (how you found first job)',
      required: true,
      isOthersSpecify: true,
    ),
    ChedGtsItem(
      id: 'ched_29',
      chedNumber: '29',
      section: ChedGtsSection.d,
      type: ChedGtsFieldType.single,
      prompt: 'How long did it take you to land your first job?',
      options: _durationOptions,
      helpText:
          'Count from your graduation to the day you started your first '
          'job.',
      required: true,
      othersSpecifyId: 'ched_29_other',
    ),
    ChedGtsItem(
      id: 'ched_29_other',
      chedNumber: '29',
      section: ChedGtsSection.d,
      type: ChedGtsFieldType.text,
      prompt: 'Others, please specify (time to land first job)',
      required: true,
      isOthersSpecify: true,
    ),
    ChedGtsItem(
      id: 'ched_30',
      chedNumber: '30',
      section: ChedGtsSection.d,
      type: ChedGtsFieldType.matrix,
      prompt: 'Job Level Position',
      matrixRows: _jobLevels,
      matrixColumns: const ['30.1. First Job', '30.2. Current or Present Job'],
      helpText:
          'Tick one level for your first job and one for your current '
          'job. Rank or Clerical: staff or support roles, e.g. clerk, '
          'cashier, encoder. Professional, Technical or Supervisory: '
          'specialist or team-lead roles, e.g. engineer, teacher, '
          'programmer, supervisor. Managerial or Executive: you head a '
          'department or company. Self-employed: you run your own '
          'business.',
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
      helpText:
          'Your monthly pay before deductions (tax, SSS, PhilHealth, '
          'Pag-IBIG) when you started your first job.',
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
      helpText:
          'Yes if what you studied in college was useful in your first '
          'job.',
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
      helpText:
          'Answer only if you said Yes to question 32. Tick every skill '
          'from college that helped you.',
      required: true,
      othersSpecifyId: 'ched_33_other',
    ),
    ChedGtsItem(
      id: 'ched_33_other',
      chedNumber: '33',
      section: ChedGtsSection.d,
      type: ChedGtsFieldType.text,
      prompt: 'Other skills, please specify',
      required: true,
      isOthersSpecify: true,
    ),
    ChedGtsItem(
      id: 'ched_34',
      chedNumber: '34',
      section: ChedGtsSection.d,
      type: ChedGtsFieldType.longText,
      prompt: 'List down suggestions to further improve your course curriculum',
      helpText:
          'Optional. Share subjects, skills or tools you wish your course'
          ' had covered, e.g. more hands-on projects or industry tools.',
      required: false,
    ),
  ];
}

enum ChedGtsSection { a, b, c, d }

enum ChedGtsFieldType { text, longText, single, multi, date, matrix, tableRows }

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
    this.helpText,
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

  /// Short guidance shown under the prompt (not part of the official wording).
  final String? helpText;
  final bool required;
  final String? prefillKey;
  final String? othersSpecifyId;
  final bool isOthersSpecify;

  String get sectionTitle => switch (section) {
    ChedGtsSection.a => 'A. GENERAL INFORMATION',
    ChedGtsSection.b => 'B. EDUCATIONAL BACKGROUND',
    ChedGtsSection.c => 'C. TRAINING(S)/ADVANCE STUDIES ATTENDED AFTER COLLEGE',
    ChedGtsSection.d => 'D. EMPLOYMENT DATA',
  };
}
