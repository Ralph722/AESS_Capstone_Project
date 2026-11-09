import 'package:alumni_system/features/admin/reports/application/ched_wave_comparison.dart';
import 'package:alumni_system/features/surveys/ched_gts/ched_gts_schema.dart';

/// Downloads preset ids that use the institutional CHED outcomes generator.
///
/// Audience packs (T1–T5) replace the older theme-sliced institutional cards.
abstract final class InstitutionalChedTemplates {
  static const employmentEmployability = 'employment_employability';
  static const curriculumCompetency = 'curriculum_competency';
  static const industryPlacement = 'industry_placement';
  static const careerMobility = 'career_mobility';
  static const chedComplianceMaster = 'ched_compliance_master';
  static const gtsParticipationQuality = 'gts_participation_quality';

  static const outcomePresetIds = <String>{
    employmentEmployability,
    curriculumCompetency,
    industryPlacement,
    careerMobility,
    chedComplianceMaster,
  };

  static const allPresetIds = <String>{
    ...outcomePresetIds,
    gtsParticipationQuality,
  };

  static bool isOutcomePreset(String presetId) =>
      outcomePresetIds.contains(presetId);

  static bool isInstitutionalChedPreset(String presetId) =>
      allPresetIds.contains(presetId);

  static String reportTitle(String presetId) => switch (presetId) {
        employmentEmployability =>
          'Institutional Employment & Employability Overview',
        curriculumCompetency =>
          'Program-Level Curriculum & Competency Audit',
        industryPlacement => 'Industry Linkages & Economic Placement',
        careerMobility => 'Career Mobility & Diagnostic',
        chedComplianceMaster =>
          'CHED Compliance & Accreditation Master Summary',
        gtsParticipationQuality => 'GTS Participation and Data Quality',
        _ => 'Institutional CHED Report',
      };

  static String sectionTwoTitle(String presetId) => switch (presetId) {
        employmentEmployability => 'Employment and employability indicators',
        curriculumCompetency => 'Curriculum and competency indicators',
        industryPlacement => 'Industry placement and earnings indicators',
        careerMobility => 'Mobility and retention diagnostics',
        chedComplianceMaster => 'Itemized CHED choice summaries (Q6–Q33)',
        _ => 'Indicator distributions',
      };

  static String fileStem(String presetId) => switch (presetId) {
        employmentEmployability => 'AESS_Employment_Employability_Overview',
        curriculumCompetency => 'AESS_Curriculum_Competency_Audit',
        industryPlacement => 'AESS_Industry_Economic_Placement',
        careerMobility => 'AESS_Career_Mobility_Diagnostic',
        chedComplianceMaster => 'AESS_CHED_Compliance_Master_Summary',
        gtsParticipationQuality => 'AESS_GTS_Participation_Data_Quality',
        _ => 'AESS_Institutional_CHED_Report',
      };

  static List<ChedWaveComparisonFieldSpec> fieldsFor(String presetId) =>
      switch (presetId) {
        employmentEmployability => employmentEmployabilityFields,
        curriculumCompetency => curriculumCompetencyFields,
        industryPlacement => industryPlacementFields,
        careerMobility => careerMobilityFields,
        chedComplianceMaster => complianceMasterFields,
        _ => employmentEmployabilityFields,
      };

  /// T1 — Board / President / VPAA: strategic employment performance.
  ///
  /// Program grouping uses roster course/batch filters (Q12 tableRows are not
  /// aggregated by the choice engine).
  static const employmentEmployabilityFields = <ChedWaveComparisonFieldSpec>[
    ChedWaveComparisonFieldSpec(
      questionId: 'ched_16',
      shortLabel: 'Presently employed',
      highlightOption: ChedGtsBuiltin.yes,
    ),
    ChedWaveComparisonFieldSpec(
      questionId: 'ched_18',
      shortLabel: 'Present employment status',
    ),
    ChedWaveComparisonFieldSpec(
      questionId: 'ched_21',
      shortLabel: 'Place of work',
    ),
    ChedWaveComparisonFieldSpec(
      questionId: 'ched_22',
      shortLabel: 'First job after college',
      highlightOption: ChedGtsBuiltin.yes,
    ),
    ChedWaveComparisonFieldSpec(
      questionId: 'ched_24a',
      shortLabel: 'First job related to course',
      highlightOption: ChedGtsBuiltin.yes,
    ),
    ChedWaveComparisonFieldSpec(
      questionId: 'ched_29',
      shortLabel: 'Time to land first job',
    ),
  ];

  /// T2 — Deans / curriculum committees.
  ///
  /// Q14 (matrix) and Q34 (open text) are not choice-aggregated yet.
  static const curriculumCompetencyFields = <ChedWaveComparisonFieldSpec>[
    ChedWaveComparisonFieldSpec(
      questionId: 'ched_15b',
      shortLabel: 'Reason for advance studies',
    ),
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

  /// T3 — Career center / placement.
  ///
  /// Q30 job-level matrix is not charted in this version.
  static const industryPlacementFields = <ChedWaveComparisonFieldSpec>[
    ChedWaveComparisonFieldSpec(
      questionId: 'ched_20',
      shortLabel: 'Line of business',
    ),
    ChedWaveComparisonFieldSpec(
      questionId: 'ched_21',
      shortLabel: 'Place of work',
    ),
    ChedWaveComparisonFieldSpec(
      questionId: 'ched_28',
      shortLabel: 'How first job was found',
    ),
    ChedWaveComparisonFieldSpec(
      questionId: 'ched_31',
      shortLabel: 'Initial monthly earning',
    ),
  ];

  /// T4 — Guidance / alumni office / student affairs.
  static const careerMobilityFields = <ChedWaveComparisonFieldSpec>[
    ChedWaveComparisonFieldSpec(
      questionId: 'ched_17',
      shortLabel: 'Reasons not employed',
    ),
    ChedWaveComparisonFieldSpec(
      questionId: 'ched_23',
      shortLabel: 'Reasons for staying on the job',
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
  ];

  /// T5 — Accreditation / QA: aggregatable choice items across Parts B–D.
  ///
  /// Personal items (Q1–Q5, Q8), tableRows (Q12, Q13, Q15a), matrices
  /// (Q14, Q30), free text (Q19), and open suggestions (Q34) are excluded
  /// from this rollup; use single-survey Excel/PDF packs for those.
  static const complianceMasterFields = <ChedWaveComparisonFieldSpec>[
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
    ChedWaveComparisonFieldSpec(
      questionId: 'ched_15b',
      shortLabel: 'Reason for advance studies',
    ),
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
    ChedWaveComparisonFieldSpec(
      questionId: 'ched_22',
      shortLabel: 'First job after college',
      highlightOption: ChedGtsBuiltin.yes,
    ),
    ChedWaveComparisonFieldSpec(
      questionId: 'ched_23',
      shortLabel: 'Reasons for staying on the job',
    ),
    ChedWaveComparisonFieldSpec(
      questionId: 'ched_24a',
      shortLabel: 'First job related to course',
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
}
