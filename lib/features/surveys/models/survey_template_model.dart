import 'package:alumni_system/features/surveys/models/survey_model.dart';

/// Read-only CHED / GTS questionnaire pack stored in Supabase
/// (`survey_templates` / `survey_template_questions`).
class SurveyTemplate {
  const SurveyTemplate({
    required this.id,
    required this.templateKey,
    required this.title,
    required this.description,
    required this.version,
    required this.disclaimer,
    required this.sections,
    required this.questionCount,
    this.isActive = true,
    this.coversTracerSections = const ['A', 'B'],
    this.surveySections = const ['C', 'D'],
  });

  /// Supabase row id (`survey_templates.id`, uuid). Empty until persisted.
  final String id;

  /// Stable seed identifier used to match/upgrade packs across app versions.
  final String templateKey;

  final String title;
  final String description;
  final String version;
  final String disclaimer;
  final List<String> sections;
  final int questionCount;
  final bool isActive;

  /// CHED sections already collected in Alumni Tracer (not duplicated in pack).
  final List<String> coversTracerSections;

  /// Sections included in this survey pack.
  final List<String> surveySections;

  Map<String, dynamic> toSupabaseRow() {
    return {
      'title': title,
      'description': description,
      'version': version,
      'data': {
        'templateKey': templateKey,
        'disclaimer': disclaimer,
        'sections': sections,
        'questionCount': questionCount,
        'isActive': isActive,
        'coversTracerSections': coversTracerSections,
        'surveySections': surveySections,
      },
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
  }

  factory SurveyTemplate.fromSupabaseRow(Map<String, dynamic> row) {
    final data = row['data'] as Map<String, dynamic>? ?? {};
    return SurveyTemplate(
      id: row['id']?.toString() ?? '',
      templateKey: data['templateKey'] as String? ?? '',
      title: row['title'] as String? ?? '',
      description: row['description'] as String? ?? '',
      version: row['version'] as String? ?? '1.0.0',
      disclaimer: data['disclaimer'] as String? ?? '',
      sections: List<String>.from(data['sections'] ?? []),
      questionCount: data['questionCount'] as int? ?? 0,
      isActive: data['isActive'] as bool? ?? true,
      coversTracerSections:
          List<String>.from(data['coversTracerSections'] ?? []),
      surveySections: List<String>.from(data['surveySections'] ?? []),
    );
  }

  SurveyTemplate copyWith({String? id, bool? isActive}) {
    return SurveyTemplate(
      id: id ?? this.id,
      templateKey: templateKey,
      title: title,
      description: description,
      version: version,
      disclaimer: disclaimer,
      sections: sections,
      questionCount: questionCount,
      isActive: isActive ?? this.isActive,
      coversTracerSections: coversTracerSections,
      surveySections: surveySections,
    );
  }
}

/// Question blueprint inside a template (cloned into a live survey on create).
class SurveyTemplateQuestion {
  const SurveyTemplateQuestion({
    required this.id,
    required this.templateId,
    required this.order,
    required this.section,
    required this.type,
    required this.prompt,
    this.chedItemNumber,
    this.prefillKey,
    this.isStandardItem = false,
    this.required = true,
    this.options = const [],
    this.scaleMin,
    this.scaleMax,
  });

  final String id;
  final String templateId;
  final int order;
  final String section;
  final SurveyQuestionType type;
  final String prompt;
  final String? chedItemNumber;
  final String? prefillKey;
  final bool isStandardItem;
  final bool required;
  final List<String> options;
  final int? scaleMin;
  final int? scaleMax;

  Map<String, dynamic> toSupabaseRow() {
    return {
      'template_id': templateId,
      'order': order,
      'section': section,
      'type': type.name,
      'prompt': prompt,
      'ched_item_number': chedItemNumber,
      'prefill_key': prefillKey,
      'is_standard_item': isStandardItem,
      'required': required,
      'options': options,
      'scale_min': scaleMin,
      'scale_max': scaleMax,
    };
  }

  factory SurveyTemplateQuestion.fromSupabaseRow(Map<String, dynamic> row) {
    return SurveyTemplateQuestion(
      id: row['id']?.toString() ?? '',
      templateId: row['template_id']?.toString() ?? '',
      order: row['order'] as int? ?? 0,
      section: row['section'] as String? ?? '',
      type: SurveyQuestionType.values.firstWhere(
        (e) => e.name == row['type'],
        orElse: () => SurveyQuestionType.text,
      ),
      prompt: row['prompt'] as String? ?? '',
      chedItemNumber: row['ched_item_number'] as String?,
      prefillKey: row['prefill_key'] as String?,
      isStandardItem: row['is_standard_item'] as bool? ?? false,
      required: row['required'] as bool? ?? true,
      options: List<String>.from(row['options'] ?? []),
      scaleMin: row['scale_min'] as int?,
      scaleMax: row['scale_max'] as int?,
    );
  }

  SurveyQuestion toSurveyQuestion({
    required String surveyId,
    required String newQuestionId,
  }) {
    return SurveyQuestion(
      id: newQuestionId,
      surveyId: surveyId,
      order: order,
      type: type,
      prompt: prompt,
      required: required,
      options: options,
      scaleMin: scaleMin,
      scaleMax: scaleMax,
      section: section,
      chedItemNumber: chedItemNumber,
      prefillKey: prefillKey,
      isStandardItem: isStandardItem,
    );
  }
}
