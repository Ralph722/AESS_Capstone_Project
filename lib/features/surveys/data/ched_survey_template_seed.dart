import 'package:alumni_system/features/surveys/models/survey_model.dart';
import 'package:alumni_system/features/surveys/models/survey_template_model.dart';

/// CHED Graduate Tracer Study (GTS) preset packs — aligned to the standard
/// CHED GTS questionnaire (sections C & D). Sections A & B live in Alumni Tracer.
class ChedSurveyTemplateSeed {
  ChedSurveyTemplateSeed._();

  /// Current recommended pack (CHED GTS PDF sections C–D).
  static const String officialTemplateId = 'ched_gts_official_v2';

  /// Legacy short pack — deactivated on sync.
  static const String legacyCoreTemplateId = 'ched_gts_core_v1';

  static const List<String> retiredTemplateIds = [legacyCoreTemplateId];

  static const String disclaimer =
      'Based on the CHED Graduate Tracer Study (GTS) questionnaire (sections C & D). '
      'Sections A (General Information) and B (Educational Background) are collected '
      'in Alumni Tracer — ask alumni to update their tracer profile first. '
      'Have your registrar or QA office review before publishing. Salary brackets '
      'and region labels may need updating per current CHED guidance.';

  static const List<String> _industryOptions = [
    'Agriculture, Hunting and Forestry',
    'Fishing',
    'Mining and Quarrying',
    'Manufacturing',
    'Electricity, Gas and Water Supply',
    'Construction',
    'Wholesale and Retail Trade; repair of motor vehicles, motorcycles and personal and household goods',
    'Hotels and Restaurants',
    'Transport, Storage and Communication',
    'Financial Intermediation',
    'Real Estate, Renting and Business Activities',
    'Public Administration and Defense; Compulsory Social Security',
    'Education',
    'Health and Social Work',
    'Other Community, Social and Personal Service Activities',
    'Private Households with Employed Persons',
    'Extra-territorial Organizations and Bodies',
  ];

  static SurveyTemplate officialTemplate() {
    return SurveyTemplate(
      id: '',
      templateKey: officialTemplateId,
      title: 'CHED GTS — Official (B extras, C & D)',
      description:
          'Professional exams, training/advance studies, and employment items from the '
          'standard CHED Graduate Tracer Study form. Sections A and B item 12 live in Profile.',
      version: '2.1.0',
      disclaimer: disclaimer,
      sections: const [
        'B. EDUCATIONAL BACKGROUND (extras)',
        'C. TRAINING(S)/ADVANCE STUDIES ATTENDED AFTER COLLEGE',
        'D. EMPLOYMENT DATA',
      ],
      questionCount: officialQuestions().length,
      coversTracerSections: const ['A', 'B'],
      surveySections: const ['B', 'C', 'D'],
    );
  }

  static List<SurveyTemplateQuestion> officialQuestions() {
    const t = officialTemplateId;
    var order = 0;
    SurveyTemplateQuestion q({
      required String id,
      required String section,
      required String prompt,
      required SurveyQuestionType type,
      String? chedItemNumber,
      String? prefillKey,
      bool required = true,
      bool isStandardItem = true,
      List<String> options = const [],
      int? scaleMin,
      int? scaleMax,
    }) {
      order++;
      return SurveyTemplateQuestion(
        id: id,
        templateId: t,
        order: order,
        section: section,
        chedItemNumber: chedItemNumber,
        prefillKey: prefillKey,
        isStandardItem: isStandardItem,
        required: required,
        type: type,
        prompt: prompt,
        options: options,
        scaleMin: scaleMin,
        scaleMax: scaleMax,
      );
    }

    return [
      // —— B. EDUCATIONAL BACKGROUND (extras) ——
      q(
        id: 'b13_professional_exams',
        section: 'B',
        chedItemNumber: '13',
        required: false,
        type: SurveyQuestionType.text,
        prompt:
            '13. Professional Examination(s) Passed (name of examination, date taken, rating). '
            'You may use extra lines if needed.',
      ),
      q(
        id: 'b14_reasons_for_course',
        section: 'B',
        chedItemNumber: '14',
        required: false,
        type: SurveyQuestionType.multipleChoice,
        prompt:
            '14. Reason(s) for taking the course(s) or pursuing degree(s). '
            'You may check more than one answer (Undergraduate/AB/BS).',
        options: [
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
        ],
      ),
      q(
        id: 'b14_others_specify',
        section: 'B',
        chedItemNumber: '14',
        required: false,
        isStandardItem: false,
        type: SurveyQuestionType.text,
        prompt: '14. Others, please specify',
      ),
      // —— C. TRAINING(S)/ADVANCE STUDIES ——
      q(
        id: 'c15a_training_programs',
        section: 'C',
        chedItemNumber: '15a',
        required: false,
        type: SurveyQuestionType.text,
        prompt:
            '15a. List all professional or work-related training program(s) including '
            'advance studies you attended after college (title, duration/credits, institution). '
            'You may use extra lines if needed.',
      ),
      q(
        id: 'c15b_pursue_studies_reason',
        section: 'C',
        chedItemNumber: '15b',
        required: false,
        type: SurveyQuestionType.singleChoice,
        prompt: '15b. What made you pursue advance studies?',
        options: [
          'For promotion',
          'For professional development',
          'Others (specify in next field)',
        ],
      ),
      q(
        id: 'c15b_others_specify',
        section: 'C',
        chedItemNumber: '15b',
        required: false,
        isStandardItem: false,
        type: SurveyQuestionType.text,
        prompt: '15b. Others, please specify',
      ),
      // —— D. EMPLOYMENT DATA ——
      q(
        id: 'd16_employed',
        section: 'D',
        chedItemNumber: '16',
        prefillKey: 'employment.presentlyEmployed',
        type: SurveyQuestionType.singleChoice,
        prompt: '16. Are you presently employed?',
        options: ['Yes', 'No', 'Never Employed'],
      ),
      q(
        id: 'd17_not_employed_reasons',
        section: 'D',
        chedItemNumber: '17',
        required: false,
        type: SurveyQuestionType.multipleChoice,
        prompt:
            '17. Please state reason(s) why you are not yet employed. '
            'You may check more than one answer.',
        options: [
          'Advance or further study',
          'Family concern and decided not to find a job',
          'Health-related reason(s)',
          'Lack of work experience',
          'No job opportunity',
          'Did not look for a job',
          'Other reason(s), please specify',
        ],
      ),
      q(
        id: 'd17_other_specify',
        section: 'D',
        chedItemNumber: '17',
        required: false,
        isStandardItem: false,
        type: SurveyQuestionType.text,
        prompt: '17. Other reason(s), please specify',
      ),
      q(
        id: 'd18_employment_status',
        section: 'D',
        chedItemNumber: '18',
        required: false,
        prefillKey: 'employment.employmentStatus',
        type: SurveyQuestionType.singleChoice,
        prompt: '18. Present Employment Status',
        options: [
          'Regular or Permanent',
          'Contractual',
          'Temporary',
          'Self-employed',
          'Casual',
        ],
      ),
      q(
        id: 'd18_selfemployed_skills',
        section: 'D',
        chedItemNumber: '18',
        required: false,
        type: SurveyQuestionType.text,
        prompt:
            'If self-employed, what skills acquired in college were you able to apply in your work?',
      ),
      q(
        id: 'd19_occupation',
        section: 'D',
        chedItemNumber: '19',
        required: false,
        prefillKey: 'employment.position',
        type: SurveyQuestionType.text,
        prompt:
            '19. Present occupation (e.g. Grade School Teacher, Electrical Engineer, Self-employed)',
      ),
      q(
        id: 'd20_line_of_business',
        section: 'D',
        chedItemNumber: '20',
        required: false,
        prefillKey: 'employment.industry',
        type: SurveyQuestionType.singleChoice,
        prompt:
            '20. Major line of business of the company you are presently employed in. Check one only.',
        options: _industryOptions,
      ),
      q(
        id: 'd21_place_of_work',
        section: 'D',
        chedItemNumber: '21',
        required: false,
        prefillKey: 'employment.placeOfWork',
        type: SurveyQuestionType.singleChoice,
        prompt: '21. Place of work',
        options: ['Local', 'Abroad'],
      ),
      q(
        id: 'd22_first_job',
        section: 'D',
        chedItemNumber: '22',
        required: false,
        type: SurveyQuestionType.singleChoice,
        prompt: '22. Is this your first job after college?',
        options: ['Yes', 'No'],
      ),
      q(
        id: 'd23_stay_reasons',
        section: 'D',
        chedItemNumber: '23',
        required: false,
        type: SurveyQuestionType.multipleChoice,
        prompt:
            '23. What are your reason(s) for staying on the job? You may check more than one answer.',
        options: [
          'Salaries and benefits',
          'Career challenge',
          'Related to special skill',
          'Related to course or program of study',
          'Proximity to residence',
          'Peer influence',
          'Family influence',
          'Other reason(s), please specify',
        ],
      ),
      q(
        id: 'd23_other_specify',
        section: 'D',
        chedItemNumber: '23',
        required: false,
        isStandardItem: false,
        type: SurveyQuestionType.text,
        prompt: '23. Other reason(s), please specify',
      ),
      q(
        id: 'd24_job_related',
        section: 'D',
        chedItemNumber: '24',
        required: false,
        type: SurveyQuestionType.singleChoice,
        prompt:
            '24. Is your first job related to the course you took up in college?',
        options: ['Yes', 'No'],
      ),
      q(
        id: 'd24_accept_reasons',
        section: 'D',
        chedItemNumber: '24',
        required: false,
        type: SurveyQuestionType.multipleChoice,
        prompt:
            'What were your reasons for accepting the job? You may check more than one answer.',
        options: [
          'Salaries & benefits',
          'Career challenge',
          'Related to special skills',
          'Proximity to residence',
          'Other reason(s), please specify',
        ],
      ),
      q(
        id: 'd25_change_reasons',
        section: 'D',
        chedItemNumber: '25',
        required: false,
        type: SurveyQuestionType.multipleChoice,
        prompt:
            '25. What were your reason(s) for changing job? You may check more than one answer.',
        options: [
          'Salaries & benefits',
          'Career challenge',
          'Related to special skills',
          'Proximity to residence',
          'Other reason(s), please specify',
        ],
      ),
      q(
        id: 'd27_first_job_duration',
        section: 'D',
        chedItemNumber: '27',
        required: false,
        type: SurveyQuestionType.singleChoice,
        prompt: '27. How long did you stay in your first job?',
        options: [
          'Less than a month',
          '1 to 6 months',
          '7 to 11 months',
          '1 year to less than 2 years',
          '2 years to less than 3 years',
          '3 years to less than 4 years',
          'Others, please specify',
        ],
      ),
      q(
        id: 'd28_find_first_job',
        section: 'D',
        chedItemNumber: '28',
        required: false,
        type: SurveyQuestionType.singleChoice,
        prompt: '28. How did you find your first job?',
        options: [
          'Response to an advertisement',
          'As walk-in applicant',
          'Recommended by someone',
          'Information from friends',
          'Arranged by school\'s job placement officer',
          'Family business',
          'Job Fair or Public Employment Service Office (PESO)',
          'Others, please specify',
        ],
      ),
      q(
        id: 'd29_time_to_land_job',
        section: 'D',
        chedItemNumber: '29',
        required: false,
        type: SurveyQuestionType.singleChoice,
        prompt: '29. How long did it take you to land your first job?',
        options: [
          'Less than a month',
          '1 to 6 months',
          '7 to 11 months',
          '1 year to less than 2 years',
          '2 years to less than 3 years',
          '3 years to less than 4 years',
          'Others, please specify',
        ],
      ),
      q(
        id: 'd30_1_first_job_level',
        section: 'D',
        chedItemNumber: '30.1',
        required: false,
        type: SurveyQuestionType.singleChoice,
        prompt: '30.1 Job Level Position — First Job',
        options: [
          'Rank or Clerical',
          'Professional, Technical or Supervisory',
          'Managerial or Executive',
          'Self-employed',
        ],
      ),
      q(
        id: 'd30_2_current_job_level',
        section: 'D',
        chedItemNumber: '30.2',
        required: false,
        type: SurveyQuestionType.singleChoice,
        prompt: '30.2 Job Level Position — Current or Present Job',
        options: [
          'Rank or Clerical',
          'Professional, Technical or Supervisory',
          'Managerial or Executive',
          'Self-employed',
        ],
      ),
      q(
        id: 'd31_first_salary',
        section: 'D',
        chedItemNumber: '31',
        required: false,
        prefillKey: 'employment.salaryRange',
        type: SurveyQuestionType.singleChoice,
        prompt:
            '31. What is your initial gross monthly earning in your first job after college?',
        options: [
          'Below P5,000.00',
          'P5,000.00 to less than P10,000.00',
          'P10,000.00 to less than P15,000.00',
          'P15,000.00 to less than P20,000.00',
          'P20,000.00 to less than P25,000.00',
          'P25,000.00 and above',
        ],
      ),
      q(
        id: 'd32_curriculum_relevant',
        section: 'D',
        chedItemNumber: '32',
        required: false,
        type: SurveyQuestionType.singleChoice,
        prompt:
            '32. Was the curriculum you had in college relevant to your first job?',
        options: ['Yes', 'No'],
      ),
      q(
        id: 'd33_competencies',
        section: 'D',
        chedItemNumber: '33',
        required: false,
        type: SurveyQuestionType.multipleChoice,
        prompt:
            '33. If YES, what competencies learned in college did you find very useful '
            'in your first job? You may check more than one answer.',
        options: [
          'Communication skills',
          'Human Relations skills',
          'Entrepreneurial skills',
          'Information Technology skills',
          'Problem-solving skills',
          'Critical Thinking skills',
          'Other skills, please specify',
        ],
      ),
      q(
        id: 'd33_other_specify',
        section: 'D',
        chedItemNumber: '33',
        required: false,
        isStandardItem: false,
        type: SurveyQuestionType.text,
        prompt: '33. Other skills, please specify',
      ),
      q(
        id: 'd34_suggestions',
        section: 'D',
        chedItemNumber: '34',
        required: false,
        type: SurveyQuestionType.text,
        prompt:
            '34. List down suggestions to further improve your course curriculum',
      ),
    ];
  }

  static List<
    ({SurveyTemplate template, List<SurveyTemplateQuestion> questions})
  >
  allPacks() {
    return [(template: officialTemplate(), questions: officialQuestions())];
  }

  /// Parses `2.0.0` style versions; returns true if [incoming] > [current].
  static bool isVersionNewer(String incoming, String current) {
    List<int> parts(String v) {
      return v.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    }

    final a = parts(incoming);
    final b = parts(current);
    final len = a.length > b.length ? a.length : b.length;
    for (var i = 0; i < len; i++) {
      final av = i < a.length ? a[i] : 0;
      final bv = i < b.length ? b[i] : 0;
      if (av > bv) return true;
      if (av < bv) return false;
    }
    return false;
  }
}
