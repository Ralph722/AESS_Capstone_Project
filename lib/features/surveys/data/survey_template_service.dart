import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:alumni_system/features/surveys/data/ched_survey_template_seed.dart';
import 'package:alumni_system/features/surveys/models/survey_template_model.dart';

/// Loads CHED preset packs from Supabase (`survey_templates` /
/// `survey_template_questions`).
class SurveyTemplateService {
  SurveyTemplateService({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  /// Seeds packs and upgrades when app seed version is newer.
  Future<void> ensureTemplatesSeeded() async {
    for (final pack in ChedSurveyTemplateSeed.allPacks()) {
      final existing = await _findByTemplateKey(pack.template.templateKey);
      if (existing == null) {
        await _upsertPack(pack, existingId: null);
        continue;
      }
      final currentVersion = existing['version'] as String? ?? '0.0.0';
      if (ChedSurveyTemplateSeed.isVersionNewer(
        pack.template.version,
        currentVersion,
      )) {
        await _upsertPack(pack, existingId: existing['id'] as String);
      }
    }

    for (final retiredKey in ChedSurveyTemplateSeed.retiredTemplateIds) {
      final existing = await _findByTemplateKey(retiredKey);
      if (existing == null) continue;
      final data = Map<String, dynamic>.from(
        existing['data'] as Map<String, dynamic>? ?? {},
      );
      data['isActive'] = false;
      await _supabase.from('survey_templates').update({
        'data': data,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', existing['id']);
    }
  }

  Future<Map<String, dynamic>?> _findByTemplateKey(String templateKey) async {
    try {
      final rows = await _supabase
          .from('survey_templates')
          .select()
          .filter('data->>templateKey', 'eq', templateKey);
      if (rows.isEmpty) return null;
      return rows.first;
    } catch (_) {
      return null;
    }
  }

  Future<void> _upsertPack(
    ({SurveyTemplate template, List<SurveyTemplateQuestion> questions}) pack, {
    required String? existingId,
  }) async {
    String templateId;
    if (existingId != null) {
      await _supabase
          .from('survey_templates')
          .update(pack.template.toSupabaseRow())
          .eq('id', existingId);
      templateId = existingId;
    } else {
      final row = await _supabase
          .from('survey_templates')
          .insert(pack.template.toSupabaseRow())
          .select()
          .single();
      templateId = row['id'] as String;
    }

    await _supabase
        .from('survey_template_questions')
        .delete()
        .eq('template_id', templateId);

    if (pack.questions.isEmpty) return;

    final rows = pack.questions
        .map((q) => {...q.toSupabaseRow(), 'template_id': templateId})
        .toList();
    await _supabase.from('survey_template_questions').insert(rows);
  }

  Future<List<SurveyTemplate>> listActiveTemplates() async {
    await ensureTemplatesSeeded();
    final rows = await _supabase.from('survey_templates').select();
    final list = rows
        .map(SurveyTemplate.fromSupabaseRow)
        .where((t) => t.isActive)
        .toList();
    list.sort((a, b) => a.title.compareTo(b.title));
    return list;
  }

  Future<SurveyTemplate?> getTemplate(String templateId) async {
    await ensureTemplatesSeeded();
    final row = await _supabase
        .from('survey_templates')
        .select()
        .eq('id', templateId)
        .maybeSingle();
    if (row == null) return null;
    return SurveyTemplate.fromSupabaseRow(row);
  }

  Future<List<SurveyTemplateQuestion>> getTemplateQuestions(
    String templateId,
  ) async {
    await ensureTemplatesSeeded();
    final rows = await _supabase
        .from('survey_template_questions')
        .select()
        .eq('template_id', templateId)
        .order('order', ascending: true);
    return rows.map(SurveyTemplateQuestion.fromSupabaseRow).toList();
  }
}
