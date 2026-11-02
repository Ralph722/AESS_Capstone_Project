import 'package:alumni_system/features/admin/reports/application/ched_wave_comparison.dart';
import 'package:alumni_system/features/surveys/ched_gts/ched_gts_schema.dart';
import 'package:alumni_system/features/surveys/data/survey_ched_outcomes_summary_service.dart';

/// Downloads preset ids that use the institutional CHED outcomes generator.
abstract final class InstitutionalChedTemplates {
  static const institutionalSummary = 'institutional_gts';
  static const graduateEmployment = 'graduate_employment';
  static const curriculumRelevance = 'curriculum_relevance';
  static const firstJobSalary = 'first_job_salary';
  static const educationalBackground = 'educational_background';
  static const alumniDemographics = 'alumni_demographics';
  static const programCohortComparison = 'program_cohort_comparison';
  static const gtsParticipationQuality = 'gts_participation_quality';

  static const outcomePresetIds = <String>{
    institutionalSummary,
    graduateEmployment,
    curriculumRelevance,
    firstJobSalary,
    educationalBackground,
    alumniDemographics,
  };

  static const allPresetIds = <String>{
    ...outcomePresetIds,
    programCohortComparison,
    gtsParticipationQuality,
  };

  static bool isOutcomePreset(String presetId) =>
      outcomePresetIds.contains(presetId);

  static bool isInstitutionalChedPreset(String presetId) =>
      allPresetIds.contains(presetId);

  static String reportTitle(String presetId) => switch (presetId) {
        institutionalSummary => 'CHED GTS Institutional Summary',
        graduateEmployment => 'Graduate Employment Report',
        curriculumRelevance => 'Curriculum Relevance Report',
        firstJobSalary => 'First-Job and Salary Report',
        educationalBackground => 'Educational Background Report',
        alumniDemographics => 'Alumni Demographics Report',
        programCohortComparison => 'Program and Cohort Comparison',
        gtsParticipationQuality => 'GTS Participation and Data Quality',
        _ => 'Institutional CHED Report',
      };

  static String fileStem(String presetId) => switch (presetId) {
        institutionalSummary => 'AESS_Institutional_GTS_Summary',
        graduateEmployment => 'AESS_Graduate_Employment_Report',
        curriculumRelevance => 'AESS_Curriculum_Relevance_Report',
        firstJobSalary => 'AESS_First_Job_Salary_Report',
        educationalBackground => 'AESS_Educational_Background_Report',
        alumniDemographics => 'AESS_Alumni_Demographics_Report',
        programCohortComparison => 'AESS_Program_Cohort_Comparison',
        gtsParticipationQuality => 'AESS_GTS_Participation_Data_Quality',
        _ => 'AESS_Institutional_CHED_Report',
      };

  static List<ChedWaveComparisonFieldSpec> fieldsFor(String presetId) =>
      switch (presetId) {
        institutionalSummary => ChedOutcomesSummary.outcomeFields,
        graduateEmployment => employmentFields,
        curriculumRelevance => curriculumFields,
        firstJobSalary => firstJobFields,
        educationalBackground => educationFields,
        alumniDemographics => demographicsFields,
        _ => ChedOutcomesSummary.outcomeFields,
      };

  static const employmentFields = <ChedWaveComparisonFieldSpec>[
    ChedWaveComparisonFieldSpec(
      questionId: 'ched_16',
      shortLabel: 'Presently employed',
      highlightOption: ChedGtsBuiltin.yes,
    ),
    ChedWaveComparisonFieldSpec(
      questionId: 'ched_17',
      shortLabel: 'Reasons not employed',
    ),
    ChedWaveComparisonFieldSpec(
      questionId: 'ched_18',
      shortLabel: 'Present employment status',
    ),
    ChedWaveComparisonFieldSpec(
      questionId: 'ched_20',
      shortLabel: 'Line of business',
    ),
    ChedWaveComparisonFieldSpec(
      questionId: 'ched_21',
      shortLabel: 'Place of work',
    ),
  ];

  static const curriculumFields = <ChedWaveComparisonFieldSpec>[
    ChedWaveComparisonFieldSpec(
      questionId: 'ched_24a',
      shortLabel: 'First job related to course',
      highlightOption: ChedGtsBuiltin.yes,
    ),
    ChedWaveComparisonFieldSpec(
      questionId: 'ched_32',
      shortLabel: 'Curriculum relevant to first job',
      highlightOption: ChedGtsBuiltin.yes,
    ),
    ChedWaveComparisonFieldSpec(
      questionId: 'ched_33',
      shortLabel: 'Useful competencies from college',
    ),
  ];

  static const firstJobFields = <ChedWaveComparisonFieldSpec>[
    ChedWaveComparisonFieldSpec(
      questionId: 'ched_22',
      shortLabel: 'First job after college',
      highlightOption: ChedGtsBuiltin.yes,
    ),
    ChedWaveComparisonFieldSpec(
      questionId: 'ched_24b',
      shortLabel: 'Reasons for accepting the job',
    ),
    ChedWaveComparisonFieldSpec(
      questionId: 'ched_25',
      shortLabel: 'Reasons for changing job',
    ),
    ChedWaveComparisonFieldSpec(
      questionId: 'ched_27',
      shortLabel: 'Length of stay in first job',
    ),
    ChedWaveComparisonFieldSpec(
      questionId: 'ched_28',
      shortLabel: 'How first job was found',
    ),
    ChedWaveComparisonFieldSpec(
      questionId: 'ched_29',
      shortLabel: 'Time to land first job',
    ),
    ChedWaveComparisonFieldSpec(
      questionId: 'ched_31',
      shortLabel: 'Initial monthly earning',
    ),
  ];

  /// Choice-type education items only (matrix/table items need later work).
  static const educationFields = <ChedWaveComparisonFieldSpec>[
    ChedWaveComparisonFieldSpec(
      questionId: 'ched_15b',
      shortLabel: 'Reason for advance studies',
    ),
  ];

  static const demographicsFields = <ChedWaveComparisonFieldSpec>[
    ChedWaveComparisonFieldSpec(
      questionId: 'ched_6',
      shortLabel: 'Civil status',
    ),
    ChedWaveComparisonFieldSpec(
      questionId: 'ched_7',
      shortLabel: 'Sex',
    ),
    ChedWaveComparisonFieldSpec(
      questionId: 'ched_9',
      shortLabel: 'Region of origin',
    ),
    ChedWaveComparisonFieldSpec(
      questionId: 'ched_10',
      shortLabel: 'Province',
    ),
    ChedWaveComparisonFieldSpec(
      questionId: 'ched_11',
      shortLabel: 'Location of residence',
    ),
  ];
}
