import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:typed_data';
import 'package:alumni_system/core/utils/local_id.dart';
import 'package:alumni_system/features/admin/roster/data/alumni_member_service.dart';
import 'package:alumni_system/features/surveys/models/survey_model.dart';
import 'package:alumni_system/core/constants/audience_targeting.dart';
import 'package:alumni_system/features/alumni/tracer/models/tracer_profile_model.dart';
import 'package:alumni_system/features/notifications/models/notification_model.dart';
import 'package:alumni_system/core/config/email_delivery_config.dart';
import 'package:alumni_system/core/services/app_session.dart';
import 'package:alumni_system/core/services/email_service.dart';
import 'package:alumni_system/features/notifications/data/notification_service.dart';
import 'package:alumni_system/features/surveys/data/survey_template_service.dart';
import 'package:alumni_system/features/surveys/models/survey_template_model.dart';
import 'package:alumni_system/features/alumni/tracer/data/id_tracer_service.dart';
import 'package:alumni_system/features/alumni/tracer/data/profile_survey_sync.dart';
import 'package:alumni_system/features/alumni/tracer/data/survey_prefill_helper.dart';
import 'package:alumni_system/features/alumni/profile/data/user_profile_service.dart';
import 'package:alumni_system/core/services/supabase_user_bridge.dart';
import 'package:alumni_system/features/surveys/application/survey_catalog_refresh.dart';
import 'package:alumni_system/features/surveys/ched_gts/ched_gts_schema.dart';
import 'package:alumni_system/features/surveys/ched_gts/ched_gts_visibility.dart';
import 'package:alumni_system/features/surveys/ched_gts/ched_gts_prefill.dart';
import 'package:alumni_system/features/surveys/data/classic_survey_visibility.dart';
import 'package:alumni_system/features/alumni/profile/data/user_profile_events.dart';
import 'package:alumni_system/core/utils/client_context.dart';

/// Surveys data access — Supabase only.
class SurveyService {
  SurveyService({
    SupabaseClient? supabase,
    SupabaseUserBridge? bridge,
    SurveyTemplateService? templateService,
    IdTracerService? idTracerService,
    UserProfileService? userProfileService,
  }) : _supabase = supabase ?? Supabase.instance.client,
       _bridge = bridge ?? SupabaseUserBridge(client: supabase),
       _templateService = templateService ?? SurveyTemplateService(),
       _idTracerService = idTracerService ?? IdTracerService(),
       _userProfileService = userProfileService ?? UserProfileService();

  final SupabaseClient _supabase;
  final SupabaseUserBridge _bridge;
  final SurveyTemplateService _templateService;
  final IdTracerService _idTracerService;
  final UserProfileService _userProfileService;

  Future<Set<String>> _activeRegisteredUserIds() async {
    return AlumniMemberService(
      supabase: _supabase,
    ).getActiveRegisteredAuthUids();
  }

  Future<List<Survey>> getAllSurveys() async {
    final surveys = await _fetchAllSurveysFromSupabase();
    surveys.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return surveys;
  }

  /// Live submitted counts from `survey_responses` (source of truth).
  Future<Map<String, int>> countSubmittedResponsesBySurvey({
    bool activeRegisteredOnly = false,
  }) async {
    final counts = <String, int>{};

    try {
      Set<String>? activeIds;
      if (activeRegisteredOnly) {
        activeIds = await _activeRegisteredUserIds();
        if (activeIds.isEmpty) return counts;
      }

      var query = _supabase
          .from('survey_responses')
          .select('survey_id')
          .eq('status', SurveyResponseStatus.submitted.name);
      if (activeIds != null) {
        query = query.inFilter('user_id', activeIds.toList());
      }
      final rows = await query;
      for (final row in rows) {
        final surveyId = row['survey_id']?.toString() ?? '';
        if (surveyId.isEmpty) continue;
        counts[surveyId] = (counts[surveyId] ?? 0) + 1;
      }
    } catch (_) {}

    return counts;
  }

  /// Admin list — merges live submission counts into survey models.
  Future<List<Survey>> getAllSurveysForAdmin({
    bool syncDenormalized = true,
  }) async {
    final surveys = await getAllSurveys();
    final liveCounts = await countSubmittedResponsesBySurvey();
    final merged = surveys
        .map(
          (s) => s.copyWith(responseCount: liveCounts[s.id] ?? s.responseCount),
        )
        .toList();

    if (syncDenormalized) {
      unawaited(_syncDenormalizedResponseCounts(surveys, liveCounts));
    }
    return merged;
  }

  Future<void> _syncDenormalizedResponseCounts(
    List<Survey> surveys,
    Map<String, int> liveCounts,
  ) async {
    for (final survey in surveys) {
      final live = liveCounts[survey.id];
      if (live == null || live == survey.responseCount) continue;
      try {
        await setSurveyResponseCount(survey.id, live);
      } catch (_) {}
    }
  }

  Future<Survey?> getSurvey(String surveyId) async {
    try {
      final row = await _supabase
          .from('surveys')
          .select()
          .eq('id', surveyId)
          .maybeSingle();
      if (row != null) {
        var survey = Survey.fromSupabaseRow(row);
        final creatorLabel = await _resolveUserDisplayLabel(survey.createdBy);
        if (creatorLabel != null) {
          survey = survey.copyWith(createdByDisplayName: creatorLabel);
        }
        return survey;
      }
    } catch (_) {}
    return null;
  }

  Future<String?> _resolveUserDisplayLabel(String userId) async {
    if (userId.trim().isEmpty) return null;
    try {
      final row = await _supabase
          .from('users')
          .select('display_name, email')
          .eq('id', userId)
          .maybeSingle();
      if (row == null) return null;
      final display = (row['display_name'] as String?)?.trim();
      if (display != null && display.isNotEmpty) return display;
      final email = (row['email'] as String?)?.trim();
      if (email != null && email.isNotEmpty) return email;
    } catch (_) {}
    return null;
  }

  /// Prefill survey items from live profile, employment record, and prior answers.
  Future<Map<String, dynamic>> buildPrefillAnswersByQuestionId({
    required List<SurveyQuestion> questions,
    required String userId,
    Map<String, dynamic> existingAnswers = const {},
  }) async {
    final values = <String, dynamic>{};

    final profile = await _userProfileService.getTracerProfile(userId);
    if (profile != null) {
      values.addAll(SurveyPrefillHelper.valuesFromProfile(profile));
    }

    final record = await _idTracerService.getEmploymentRecordByUserId(userId);
    if (record != null) {
      values.addAll(SurveyPrefillHelper.valuesFromEmployment(record));
    }

    // Merge most recent submitted answers for unanswered keys.
    final history = await getUserSubmittedResponses(userId);
    for (final response in history) {
      for (final q in questions) {
        if (existingAnswers[q.id] != null &&
            existingAnswers[q.id].toString().trim().isNotEmpty) {
          continue;
        }
        final prior = response.response.answers[q.id];
        if (prior != null && prior.toString().trim().isNotEmpty) {
          values['prior.${q.id}'] = prior;
        }
      }
    }

    final prefill = SurveyPrefillHelper.applyToQuestions(
      questions: questions,
      valuesByPrefillKey: values,
      existing: existingAnswers,
    );

    // Apply prior submission values for still-empty questions.
    for (final q in questions) {
      if (prefill.containsKey(q.id) || existingAnswers.containsKey(q.id)) {
        continue;
      }
      for (final response in history) {
        final prior = response.response.answers[q.id];
        if (prior != null && prior.toString().trim().isNotEmpty) {
          prefill[q.id] = prior;
          break;
        }
      }
    }

    return prefill;
  }

  /// Submitted survey snapshots for a user, newest first.
  Future<List<SurveyResponseWithMeta>> getUserSubmittedResponses(
    String userId,
  ) async {
    try {
      final supabaseUserId = await _resolveTargetSupabaseUserId(userId);
      if (supabaseUserId == null) return [];

      final rows = await _supabase
          .from('survey_responses')
          .select('*, surveys(title)')
          .eq('user_id', supabaseUserId)
          .eq('status', SurveyResponseStatus.submitted.name)
          .order('submitted_at', ascending: false);

      return rows.map((row) {
        final surveyId = row['survey_id']?.toString() ?? '';
        final surveyJoin = row['surveys'];
        final title = surveyJoin is Map
            ? surveyJoin['title'] as String? ?? 'Survey'
            : 'Survey';
        return SurveyResponseWithMeta(
          response: SurveyResponse.fromSupabaseRow(row, surveyId: surveyId),
          surveyTitle: title,
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<SurveyQuestion>> getQuestions(String surveyId) async {
    final merged = <String, SurveyQuestion>{};

    try {
      final rows = await _supabase
          .from('survey_questions')
          .select()
          .eq('survey_id', surveyId)
          .order('order', ascending: true);
      for (final row in rows) {
        final question = SurveyQuestion.fromSupabaseRow(
          row,
          surveyId: surveyId,
        );
        if (question.id.isNotEmpty) merged[question.id] = question;
      }
    } catch (_) {}

    final list = merged.values.toList()
      ..sort((a, b) => a.order.compareTo(b.order));
    return list;
  }

  Future<String> createSurvey({
    required String title,
    required String description,
    List<String> targetPrograms = const [],
    List<String> targetBatchYears = const [],
  }) async {
    final userId = AppSession.requireUserId();

    final survey = Survey(
      id: LocalId.generate(),
      title: title,
      description: description,
      status: SurveyStatus.draft,
      targetPrograms: targetPrograms,
      targetBatchYears: targetBatchYears,
      createdBy: userId,
      createdAt: DateTime.now(),
    );

    await _upsertSurveyToSupabase(survey);
    _notifyCatalogChanged();
    return survey.id;
  }

  /// Creates a draft locked CHED GTS (built-in schema, no editable questions).
  Future<String> createBuiltinChedGtsSurvey({
    String? title,
    String? description,
    List<String> targetPrograms = const [],
    List<String> targetBatchYears = const [],
  }) async {
    final userId = AppSession.requireUserId();
    final surveyId = LocalId.generate();
    final survey = Survey(
      id: surveyId,
      title: (title?.trim().isNotEmpty == true)
          ? title!.trim()
          : ChedGtsBuiltin.defaultTitle,
      description: (description?.trim().isNotEmpty == true)
          ? description!.trim()
          : ChedGtsBuiltin.defaultDescription,
      status: SurveyStatus.draft,
      targetPrograms: targetPrograms,
      targetBatchYears: targetBatchYears,
      createdBy: userId,
      createdAt: DateTime.now(),
      kind: ChedGtsBuiltin.kind,
      templateKey: ChedGtsBuiltin.templateKey,
      schemaVersion: ChedGtsBuiltin.schemaVersion,
      templateVersion: ChedGtsBuiltin.schemaVersion,
    );
    await _upsertSurveyToSupabase(survey);
    _notifyCatalogChanged();
    return surveyId;
  }

  Future<SurveyTemplate?> getSurveyTemplateMeta(String surveyId) async {
    final survey = await getSurvey(surveyId);
    if (survey?.templateId == null) return null;
    return _templateService.getTemplate(survey!.templateId!);
  }

  Future<void> updateSurvey(Survey survey) async {
    await _upsertSurveyToSupabase(survey);
  }

  Future<void> deleteSurvey(String surveyId) async {
    try {
      // survey_questions / survey_assignments / survey_responses cascade-delete.
      await _supabase.from('surveys').delete().eq('id', surveyId);
      _notifyCatalogChanged();
    } catch (e) {
      throw Exception('Error deleting survey: $e');
    }
  }

  Future<void> saveQuestion(SurveyQuestion question) async {
    await _upsertQuestionsToSupabase(question.surveyId, [question]);
  }

  /// Batch upsert (e.g. after reorder). Same persistence path as [saveQuestion].
  Future<void> saveQuestions(List<SurveyQuestion> questions) async {
    if (questions.isEmpty) return;
    final surveyId = questions.first.surveyId;
    await _upsertQuestionsToSupabase(surveyId, questions);
  }

  Future<void> deleteQuestion(String surveyId, String questionId) async {
    try {
      await _supabase.from('survey_questions').delete().eq('id', questionId);
    } catch (e) {
      throw Exception('Error deleting question: $e');
    }
  }

  /// Alumni accounts (non-admin), as raw Supabase `users` rows.
  Future<List<Map<String, dynamic>>> _fetchEligibleAlumni() async {
    final rows = await _supabase.from('users').select();
    return rows.where((row) {
      final role = (row['role'] as String?)?.toLowerCase() ?? 'user';
      return role != 'admin';
    }).toList();
  }

  bool _matchesTarget(Survey survey, TracerProfile profile) {
    return AudienceTargeting.matches(
      targetPrograms: survey.targetPrograms,
      targetBatchYears: survey.targetBatchYears,
      profile: profile,
    );
  }

  Future<int> countAudience({
    required List<String> targetPrograms,
    required List<String> targetBatchYears,
  }) async {
    final rows = await _fetchEligibleAlumni();
    final profiles = rows.map(TracerProfile.fromSupabaseRow).toList();
    return AudienceTargeting.countMatches(
      targetPrograms: targetPrograms,
      targetBatchYears: targetBatchYears,
      profiles: profiles,
    );
  }

  /// Creates or refreshes assignments. Safe to run again on published surveys.
  Future<int> publishSurvey(String surveyId, {bool notify = true}) async {
    final survey = await getSurvey(surveyId);
    if (survey == null) throw Exception('Survey not found');
    if (survey.archived) {
      throw Exception(
        'Unarchive this survey before publishing or re-assigning',
      );
    }

    final questions = await getQuestions(surveyId);
    if (questions.isEmpty && !survey.isChedGtsBuiltin) {
      throw Exception('Add at least one question before publishing');
    }

    final rows = await _fetchEligibleAlumni();
    final existingAssignments = await getSurveyAssignments(surveyId);
    final existingByUser = {for (final a in existingAssignments) a.userId: a};
    final notificationService = NotificationService();
    final now = DateTime.now();
    final matchedUserIds = <String>[];

    for (final row in rows) {
      final profile = TracerProfile.fromSupabaseRow(row);
      if (!_matchesTarget(survey, profile)) continue;

      final userId = row['id'] as String? ?? '';
      if (userId.isEmpty) continue;
      matchedUserIds.add(userId);

      final isNew = !existingByUser.containsKey(userId);
      final assignment = SurveyAssignment(
        id: isNew ? LocalId.generate() : existingByUser[userId]!.id,
        surveyId: surveyId,
        userId: userId,
        surveyTitle: survey.title,
        status: isNew
            ? SurveyAssignmentStatus.notStarted
            : existingByUser[userId]!.status,
        assignedAt: isNew ? now : existingByUser[userId]!.assignedAt,
        lastReminderAt: existingByUser[userId]?.lastReminderAt,
        reminderCount: existingByUser[userId]?.reminderCount ?? 0,
      );

      try {
        await _supabase
            .from('survey_assignments')
            .upsert(
              assignment.toSupabaseRow(
                surveySupabaseId: surveyId,
                userSupabaseId: userId,
              ),
              onConflict: 'survey_id,user_id',
            );
      } catch (e) {
        throw Exception('Error assigning survey: $e');
      }
    }

    if (matchedUserIds.isEmpty) {
      final hasFilters =
          survey.targetPrograms.isNotEmpty ||
          survey.targetBatchYears.isNotEmpty;
      throw Exception(
        hasFilters
            ? 'No alumni in this program/batch range. Check tracer profiles or adjust filters.'
            : 'No alumni accounts found to assign.',
      );
    }

    try {
      await _supabase
          .from('surveys')
          .update({
            'status': SurveyStatus.published.name,
            'assignment_count': matchedUserIds.length,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', surveyId);
    } catch (e) {
      throw Exception('Error publishing survey: $e');
    }

    if (notify) {
      for (final userId in matchedUserIds) {
        if (existingByUser.containsKey(userId)) continue;
        try {
          await notificationService.createNotification(
            userId: userId,
            type: NotificationType.survey,
            title: 'New survey: ${survey.title}',
            message: 'Please complete the graduate tracer survey.',
            relatedId: surveyId,
          );
        } catch (_) {}
      }
    }

    _notifyCatalogChanged();
    return matchedUserIds.length;
  }

  Future<List<SurveyAssignment>> getUserAssignments(String userId) async {
    try {
      final supabaseUserId = await _resolveTargetSupabaseUserId(userId);
      if (supabaseUserId == null) return [];

      final rows = await _supabase
          .from('survey_assignments')
          .select()
          .eq('user_id', supabaseUserId);
      final list = rows.map(SurveyAssignment.fromSupabaseRow).toList()
        ..sort((a, b) => b.assignedAt.compareTo(a.assignedAt));
      return list;
    } catch (_) {
      return [];
    }
  }

  Stream<List<SurveyAssignment>> watchUserAssignments(String userId) {
    final controller = StreamController<List<SurveyAssignment>>();

    Future<void> emit() async {
      try {
        final items = await getUserAssignments(userId);
        if (!controller.isClosed) controller.add(items);
      } catch (_) {
        if (!controller.isClosed) controller.add(const []);
      }
    }

    StreamSubscription<dynamic>? supabaseSub;
    Timer? poller;

    Future<void> startPolling() async {
      await supabaseSub?.cancel();
      supabaseSub = null;
      poller?.cancel();
      poller = Timer.periodic(const Duration(seconds: 20), (_) => emit());
    }

    controller.onListen = () async {
      await emit();
      try {
        final supabaseUserId = await _resolveTargetSupabaseUserId(userId);
        if (supabaseUserId == null) {
          await startPolling();
          return;
        }
        supabaseSub = _supabase
            .from('survey_assignments')
            .stream(primaryKey: ['id'])
            .eq('user_id', supabaseUserId)
            .listen(
              (_) => emit(),
              onError: (_) => startPolling(),
              cancelOnError: true,
            );
      } catch (_) {
        await startPolling();
      }
    };

    controller.onCancel = () async {
      poller?.cancel();
      await supabaseSub?.cancel();
    };

    return controller.stream;
  }

  Future<SurveyResponse?> getResponse(String surveyId, String userId) async {
    try {
      final userSupabaseId = await _resolveTargetSupabaseUserId(userId);
      if (userSupabaseId != null) {
        final row = await _supabase
            .from('survey_responses')
            .select()
            .eq('survey_id', surveyId)
            .eq('user_id', userSupabaseId)
            .maybeSingle();
        if (row != null) {
          return SurveyResponse.fromSupabaseRow(row, surveyId: surveyId);
        }
      }
    } catch (_) {}
    return null;
  }

  Future<void> recordSurveyOpened(
    String surveyId, {
    SurveyClientContext? clientContext,
  }) async {
    final ctx = clientContext ?? SurveyClientContext.capture();
    try {
      await _supabase.rpc(
        'record_survey_opened',
        params: {
          'p_survey_id': surveyId,
          'p_device_category': ctx.deviceCategory,
          'p_platform_family': ctx.platformFamily,
          'p_browser_family': ctx.browserFamily,
        },
      );
    } catch (_) {}
  }

  Future<List<SurveyResponseEvent>> getResponseEvents({
    required String surveyId,
    required String userId,
  }) async {
    try {
      final userSupabaseId = await _resolveTargetSupabaseUserId(userId);
      if (userSupabaseId == null) return [];

      final rows = await _supabase
          .from('survey_response_events')
          .select()
          .eq('survey_id', surveyId)
          .eq('user_id', userSupabaseId)
          .order('created_at', ascending: true);
      return rows
          .map((row) => SurveyResponseEvent.fromSupabaseRow(row))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveResponse({
    required String surveyId,
    required Map<String, dynamic> answers,
    required bool submit,
    SurveyClientContext? clientContext,
  }) async {
    final userId = AppSession.requireUserId();
    final survey = await getSurvey(surveyId);
    final questions = await getQuestions(surveyId);

    if (survey != null && !survey.acceptsResponses) {
      if (survey.isNotYetOpen && survey.openAt != null) {
        throw Exception(
          'This survey is scheduled to open later. '
          'Please come back when it becomes available.',
        );
      }
      if (survey.isPastClose) {
        throw Exception(
          'This survey is closed and no longer accepts responses.',
        );
      }
      throw Exception(
        'This survey is not currently available for responses.',
      );
    }

    var pruned = Map<String, dynamic>.from(answers);
    if (survey?.isChedGtsBuiltin == true) {
      pruned = ChedGtsVisibility.pruneHiddenAnswers(pruned);
      if (submit) {
        final missing = ChedGtsVisibility.missingRequired(pruned);
        if (missing.isNotEmpty) {
          final first = ChedGtsBuiltin.byId(missing.first);
          throw Exception(
            'Please answer: ${first?.chedNumber ?? missing.first}. '
            '${first?.prompt ?? "required item"}',
          );
        }
      }
    } else if (submit) {
      final rules = survey?.visibilityRules ?? const {};
      pruned = ClassicSurveyVisibility.pruneHiddenAnswers(
        questions: questions,
        answers: pruned,
        rules: rules,
      );
      final visible = ClassicSurveyVisibility.visibleQuestions(
        questions: questions,
        answers: pruned,
        rules: rules,
      );
      for (final q in visible) {
        if (!q.required) continue;
        final answer = pruned[q.id];
        if (answer == null || answer.toString().trim().isEmpty) {
          throw Exception('Please answer: ${q.prompt}');
        }
      }
    }

    final now = DateTime.now();
    final ctx = clientContext ?? SurveyClientContext.capture();
    final existing = await getResponse(surveyId, userId);
    final wasSubmitted = existing?.status == SurveyResponseStatus.submitted;
    final response = SurveyResponse(
      surveyId: surveyId,
      userId: userId,
      answers: pruned,
      status: submit
          ? SurveyResponseStatus.submitted
          : SurveyResponseStatus.draft,
      submittedAt: submit ? now : null,
      updatedAt: now,
      openedAt: existing?.openedAt,
      firstDraftAt: existing?.firstDraftAt ?? (!submit ? now : null),
      deviceCategory: existing?.deviceCategory ?? ctx.deviceCategory,
      platformFamily: existing?.platformFamily ?? ctx.platformFamily,
      browserFamily: existing?.browserFamily ?? ctx.browserFamily,
    );

    final status = submit
        ? SurveyAssignmentStatus.completed
        : SurveyAssignmentStatus.inProgress;

    try {
      final userSupabaseId =
          _bridge.currentSupabaseUserId ??
          await _bridge.resolveSupabaseUserId(userId);
      if (userSupabaseId == null) {
        throw Exception('Survey or user not found');
      }

      await _supabase
          .from('survey_responses')
          .upsert(
            response.toSupabaseRow(
              surveySupabaseId: surveyId,
              userSupabaseId: userSupabaseId,
            ),
            onConflict: 'survey_id,user_id',
          );
      await _recordResponseLifecycleEvent(
        surveyId: surveyId,
        userSupabaseId: userSupabaseId,
        submit: submit,
        wasSubmitted: wasSubmitted,
        clientContext: ctx,
        setFirstDraftAt: !submit && existing?.firstDraftAt == null,
      );
      await _supabase
          .from('survey_assignments')
          .update({
            'status': status.name,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('survey_id', surveyId)
          .eq('user_id', userSupabaseId);
      if (submit && !wasSubmitted) {
        final row = await _supabase
            .from('surveys')
            .select('response_count')
            .eq('id', surveyId)
            .maybeSingle();
        final current = row?['response_count'] as int? ?? 0;
        await _supabase
            .from('surveys')
            .update({
              'response_count': current + 1,
              'updated_at': DateTime.now().toUtc().toIso8601String(),
            })
            .eq('id', surveyId);
      }

      if (submit) {
        if (survey?.isChedGtsBuiltin == true) {
          await _syncProfileFromBuiltinChedGts(userId: userId, answers: pruned);
        } else {
          await _syncProfileFromSurveySubmission(
            userId: userId,
            questions: questions,
            answers: pruned,
          );
        }
      }
    } catch (e) {
      throw Exception('Error saving survey response: $e');
    }
  }

  Future<void> _recordResponseLifecycleEvent({
    required String surveyId,
    required String userSupabaseId,
    required bool submit,
    required bool wasSubmitted,
    required SurveyClientContext clientContext,
    required bool setFirstDraftAt,
  }) async {
    try {
      if (setFirstDraftAt) {
        await _supabase
            .from('survey_responses')
            .update({
              'first_draft_at': DateTime.now().toUtc().toIso8601String(),
            })
            .eq('survey_id', surveyId)
            .eq('user_id', userSupabaseId)
            .isFilter('first_draft_at', null);
      }

      if (!submit) {
        await _supabase.from('survey_response_events').insert({
          'survey_id': surveyId,
          'user_id': userSupabaseId,
          'event_type': 'draft_saved',
          'device_category': clientContext.deviceCategory,
          'platform_family': clientContext.platformFamily,
          'browser_family': clientContext.browserFamily,
        });
        return;
      }

      if (!wasSubmitted) {
        await _supabase.from('survey_response_events').insert({
          'survey_id': surveyId,
          'user_id': userSupabaseId,
          'event_type': 'submitted',
          'device_category': clientContext.deviceCategory,
          'platform_family': clientContext.platformFamily,
          'browser_family': clientContext.browserFamily,
        });
      }
    } catch (_) {}
  }

  Future<void> _syncProfileFromBuiltinChedGts({
    required String userId,
    required Map<String, dynamic> answers,
  }) async {
    try {
      final current = await _userProfileService.getTracerProfile(userId);
      if (current == null) return;
      final synced = ChedGtsPrefill.mergeIntoProfile(
        current: current,
        answers: answers,
      );
      await _userProfileService.saveTracerProfile(synced);
      UserProfileEvents.notifyProfileFieldsChanged();
    } catch (_) {}
  }

  Future<void> _syncProfileFromSurveySubmission({
    required String userId,
    required List<SurveyQuestion> questions,
    required Map<String, dynamic> answers,
  }) async {
    try {
      final current = await _userProfileService.getTracerProfile(userId);
      if (current == null) return;
      final updates = ProfileSurveySync.profileUpdatesFromAnswers(
        questions: questions,
        answers: answers,
        current: current,
      );
      if (updates.isEmpty) return;
      final synced = ProfileSurveySync.applyUpdates(current, updates);
      await _userProfileService.saveTracerProfile(synced);
    } catch (_) {}
  }

  Future<List<SurveyResponse>> getSurveyResponses(String surveyId) async {
    try {
      final rows = await _supabase
          .from('survey_responses')
          .select()
          .eq('survey_id', surveyId)
          .eq('status', SurveyResponseStatus.submitted.name);
      final merged = <String, SurveyResponse>{};
      for (final row in rows) {
        final response = SurveyResponse.fromSupabaseRow(
          row,
          surveyId: surveyId,
        );
        if (response.userId.isNotEmpty) {
          merged[response.userId] = response;
        }
      }
      return merged.values.toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<SurveyResponse>> _fetchAllSurveyResponses(String surveyId) async {
    try {
      final rows = await _supabase
          .from('survey_responses')
          .select()
          .eq('survey_id', surveyId);
      return rows
          .map((row) => SurveyResponse.fromSupabaseRow(row, surveyId: surveyId))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Count of submitted responses (source of truth for reporting).
  Future<int> countSubmittedResponses(String surveyId) async {
    final list = await getSurveyResponses(surveyId);
    return list.length;
  }

  Future<Map<String, int>> countAssignmentsBySurvey({
    bool activeRegisteredOnly = false,
  }) async {
    final counts = <String, int>{};
    try {
      Set<String>? activeIds;
      if (activeRegisteredOnly) {
        activeIds = await _activeRegisteredUserIds();
        if (activeIds.isEmpty) return counts;
      }

      var query = _supabase.from('survey_assignments').select('survey_id');
      if (activeIds != null) {
        query = query.inFilter('user_id', activeIds.toList());
      }
      final rows = await query;
      for (final row in rows) {
        final surveyId = row['survey_id']?.toString() ?? '';
        if (surveyId.isEmpty) continue;
        counts[surveyId] = (counts[surveyId] ?? 0) + 1;
      }
    } catch (_) {}
    return counts;
  }

  /// Align denormalized [Survey.responseCount] with live submissions (fixes stale dashboard counts).
  Future<void> setSurveyResponseCount(String surveyId, int count) async {
    try {
      await _supabase
          .from('surveys')
          .update({
            'response_count': count,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', surveyId);
    } catch (e) {
      throw Exception('Error setting survey response count: $e');
    }
  }

  Future<List<SurveyAssignment>> getSurveyAssignments(String surveyId) async {
    try {
      final rows = await _supabase
          .from('survey_assignments')
          .select()
          .eq('survey_id', surveyId);
      final merged = <String, SurveyAssignment>{};
      for (final row in rows) {
        final assignment = SurveyAssignment.fromSupabaseRow(row);
        if (assignment.id.isNotEmpty) merged[assignment.id] = assignment;
      }
      return merged.values.toList();
    } catch (_) {
      return [];
    }
  }

  /// All incomplete assignments (notStarted + inProgress) across surveys.
  Future<int> countPendingSurveyAssignments({
    bool activeRegisteredOnly = false,
  }) async {
    try {
      Set<String>? activeIds;
      if (activeRegisteredOnly) {
        activeIds = await _activeRegisteredUserIds();
        if (activeIds.isEmpty) return 0;
      }

      var query = _supabase
          .from('survey_assignments')
          .select('id')
          .inFilter('status', [
            SurveyAssignmentStatus.notStarted.name,
            SurveyAssignmentStatus.inProgress.name,
          ]);
      if (activeIds != null) {
        query = query.inFilter('user_id', activeIds.toList());
      }
      final rows = await query;
      return rows.length;
    } catch (_) {
      return 0;
    }
  }

  /// Single-query survey stats for admin dashboard (avoids N+1 reads).
  Future<
    ({
      int publishedCount,
      int totalAssignments,
      int totalResponses,
      int unreadResponses,
    })
  >
  getAdminDashboardSurveyStats() async {
    try {
      final surveys = await getAllSurveysForAdmin(syncDenormalized: false);
      final activeAssignments = await countAssignmentsBySurvey(
        activeRegisteredOnly: true,
      );
      final liveCounts = await countSubmittedResponsesBySurvey(
        activeRegisteredOnly: true,
      );
      var published = 0;
      var assignments = 0;
      var responses = 0;
      for (final survey in surveys) {
        if (survey.archived) continue;
        final submitted = liveCounts[survey.id] ?? survey.responseCount;
        final assigned = activeAssignments[survey.id] ?? 0;
        if (survey.status == SurveyStatus.published) published++;
        assignments += assigned;
        responses += submitted;
      }

      // Submitted responses the admin has not yet opened in View responses
      // (NOT pending assignments — publishing must not raise this alert).
      var unread = 0;
      try {
        final rows = await _supabase.from('surveys').select('id, data');
        for (final row in rows) {
          final id = row['id']?.toString() ?? '';
          if (id.isEmpty) continue;
          final data = row['data'] is Map
              ? Map<String, dynamic>.from(row['data'] as Map)
              : <String, dynamic>{};
          if (data['archived'] == true) continue;
          final lastSeen =
              (data['adminLastSeenResponseCount'] as num?)?.toInt() ?? 0;
          final submitted = liveCounts[id] ?? 0;
          if (submitted > lastSeen) unread += submitted - lastSeen;
        }
      } catch (_) {}

      return (
        publishedCount: published,
        totalAssignments: assignments,
        totalResponses: responses,
        unreadResponses: unread,
      );
    } catch (_) {
      return (
        publishedCount: 0,
        totalAssignments: 0,
        totalResponses: 0,
        unreadResponses: 0,
      );
    }
  }

  /// Admin notification count for submitted responses not yet viewed in admin.
  Future<int> countUnreadSurveyResponsesForAdmin() async {
    final stats = await getAdminDashboardSurveyStats();
    return stats.unreadResponses;
  }

  /// Fast unread count (same single-query path as [getAdminDashboardSurveyStats]).
  Future<int> countUnreadSurveyResponsesForAdminFast() async {
    final stats = await getAdminDashboardSurveyStats();
    return stats.unreadResponses;
  }

  /// Marks all current submitted responses as seen by admin for this survey.
  Future<void> markSurveyResponsesSeenByAdmin(String surveyId) async {
    final liveSubmitted = await countSubmittedResponses(surveyId);
    try {
      final row = await _supabase
          .from('surveys')
          .select('data')
          .eq('id', surveyId)
          .maybeSingle();
      final data = Map<String, dynamic>.from(row?['data'] as Map? ?? {});
      data['adminLastSeenResponseCount'] = liveSubmitted;
      data['adminLastSeenAt'] = DateTime.now().toUtc().toIso8601String();
      await _supabase
          .from('surveys')
          .update({
            'data': data,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', surveyId);
    } catch (e) {
      throw Exception('Error marking survey responses seen: $e');
    }
  }

  Future<void> closeSurvey(String surveyId) async {
    try {
      await _supabase
          .from('surveys')
          .update({
            'status': SurveyStatus.closed.name,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', surveyId);
      _notifyCatalogChanged();
    } catch (e) {
      throw Exception('Error closing survey: $e');
    }
  }

  /// Soft-archive via `surveys.data.archived` (keeps status for restore).
  Future<void> setSurveyArchived(
    String surveyId, {
    required bool archived,
  }) async {
    final survey = await getSurvey(surveyId);
    if (survey == null) throw Exception('Survey not found');
    await updateSurvey(survey.copyWith(archived: archived));
    _notifyCatalogChanged();
  }

  /// Clones survey metadata + questions (and remapped visibility rules) as a draft.
  /// Builtin CHED copies keep locked kind/schema with no question rows.
  Future<String> duplicateSurvey(String sourceId) async {
    final source = await getSurvey(sourceId);
    if (source == null) throw Exception('Survey not found');
    final userId = AppSession.requireUserId();
    final newId = LocalId.generate();
    final now = DateTime.now();

    Map<String, SurveyVisibilityRule> remappedRules = const {};
    List<SurveyQuestion> newQuestions = const [];

    if (!source.isChedGtsBuiltin) {
      final questions = await getQuestions(sourceId);
      final idMap = <String, String>{
        for (final q in questions) q.id: LocalId.generate(),
      };
      newQuestions = [
        for (final q in questions)
          SurveyQuestion(
            id: idMap[q.id]!,
            surveyId: newId,
            order: q.order,
            type: q.type,
            prompt: q.prompt,
            required: q.required,
            options: List<String>.from(q.options),
            scaleMin: q.scaleMin,
            scaleMax: q.scaleMax,
            section: q.section,
            chedItemNumber: q.chedItemNumber,
            prefillKey: q.prefillKey,
            isStandardItem: q.isStandardItem,
          ),
      ];
      remappedRules = {
        for (final e in source.visibilityRules.entries)
          if (idMap.containsKey(e.key) &&
              idMap.containsKey(e.value.sourceQuestionId))
            idMap[e.key]!: e.value.copyWith(
              sourceQuestionId: idMap[e.value.sourceQuestionId]!,
            ),
      };
    }

    final copy = Survey(
      id: newId,
      title: source.title.trim().isEmpty
          ? 'Untitled survey (Copy)'
          : '${source.title} (Copy)',
      description: source.description,
      status: SurveyStatus.draft,
      targetPrograms: List<String>.from(source.targetPrograms),
      targetBatchYears: List<String>.from(source.targetBatchYears),
      openAt: null,
      closeAt: null,
      createdBy: userId,
      createdAt: now,
      updatedAt: now,
      assignmentCount: 0,
      responseCount: 0,
      templateId: source.templateId,
      templateVersion: source.templateVersion,
      kind: source.kind,
      templateKey: source.templateKey,
      schemaVersion: source.schemaVersion,
      visibilityRules: remappedRules,
      archived: false,
    );

    await _upsertSurveyToSupabase(copy);
    if (newQuestions.isNotEmpty) {
      await _upsertQuestionsToSupabase(newId, newQuestions);
    }
    _notifyCatalogChanged();
    return newId;
  }

  void _notifyCatalogChanged() {
    SurveyCatalogRefresh.instance.notifyChanged();
  }

  Future<List<SurveyParticipant>> getSurveyParticipants(String surveyId) async {
    final assignments = await getSurveyAssignments(surveyId);
    final responses = await _fetchAllSurveyResponses(surveyId);
    final responseByUser = {for (final r in responses) r.userId: r};

    final userIds = assignments
        .map((a) => a.userId)
        .where((id) => id.isNotEmpty)
        .toSet();
    final userRowsById = <String, Map<String, dynamic>>{};
    if (userIds.isNotEmpty) {
      try {
        final rows = await _supabase
            .from('users')
            .select()
            .inFilter('id', userIds.toList());
        for (final row in rows) {
          final id = row['id']?.toString();
          if (id != null && id.isNotEmpty) {
            userRowsById[id] = Map<String, dynamic>.from(row);
          }
        }
      } catch (_) {}
    }

    final participants = <SurveyParticipant>[];
    for (final assignment in assignments) {
      final row = userRowsById[assignment.userId];
      final profile = row != null ? TracerProfile.fromSupabaseRow(row) : null;
      final studentId = (row?['student_id'] as String?)?.trim();
      final avatar = (row?['profile_image_base64'] as String?)?.trim();
      participants.add(
        SurveyParticipant(
          assignment: assignment,
          displayName: (profile?.displayName.isNotEmpty ?? false)
              ? profile!.displayName
              : (profile?.email ?? ''),
          email: profile?.email ?? '',
          program: profile?.program ?? '',
          batchYear: profile?.batchYear ?? '',
          studentId: studentId != null && studentId.isNotEmpty
              ? studentId
              : null,
          profileImageUrl: avatar != null && avatar.isNotEmpty ? avatar : null,
          response: responseByUser[assignment.userId],
        ),
      );
    }

    participants.sort((a, b) {
      if (a.isPending != b.isPending) return a.isPending ? -1 : 1;
      return b.assignment.assignedAt.compareTo(a.assignment.assignedAt);
    });
    return participants;
  }

  List<SurveyParticipant> pendingParticipants(List<SurveyParticipant> all) =>
      all.where((p) => p.isPending).toList();

  Future<SurveyReminderResult> sendReminders({
    required String surveyId,
    required List<String> userIds,
    bool inApp = true,
    bool email = true,
  }) async {
    if (userIds.isEmpty) {
      return const SurveyReminderResult();
    }

    final survey = await getSurvey(surveyId);
    if (survey == null) throw Exception('Survey not found');

    final notificationService = NotificationService();
    EmailService? emailService;
    if (email && EmailDeliveryConfig.isConfigured) {
      emailService = EmailService();
    }

    var inAppSent = 0;
    var emailSent = 0;
    var emailSkippedNoAddress = 0;
    final emailEnabled = email && EmailDeliveryConfig.isConfigured;
    final emailSkippedNotConfigured = email && !EmailDeliveryConfig.isConfigured
        ? userIds.length
        : 0;
    final failures = <String>[];

    final reminderMessage =
        'Please complete "${survey.title}" in the Alumni System app.';

    for (final userId in userIds) {
      Map<String, dynamic>? row;
      try {
        row = await _supabase
            .from('users')
            .select()
            .eq('id', userId)
            .maybeSingle();
      } catch (_) {}
      final profile = row != null ? TracerProfile.fromSupabaseRow(row) : null;
      final name = (profile?.displayName.isNotEmpty ?? false)
          ? profile!.displayName
          : (row?['email'] as String? ?? 'Alumni');

      if (inApp) {
        try {
          await notificationService.createNotification(
            userId: userId,
            type: NotificationType.survey,
            title: 'Reminder: ${survey.title}',
            message: reminderMessage,
            relatedId: surveyId,
          );
          inAppSent++;
        } catch (e) {
          failures.add('$name (in-app): $e');
        }
      }

      if (emailEnabled) {
        final address = (profile?.email ?? '').trim();
        if (address.isEmpty || !address.contains('@')) {
          emailSkippedNoAddress++;
        } else {
          try {
            await emailService!.sendSurveyReminderEmail(
              toEmail: address,
              userName: name,
              surveyTitle: survey.title,
              message: reminderMessage,
            );
            emailSent++;
          } catch (e) {
            failures.add('$name (email): $e');
          }
        }
      }

      try {
        final assignmentRow = await _supabase
            .from('survey_assignments')
            .select('reminder_count')
            .eq('survey_id', surveyId)
            .eq('user_id', userId)
            .maybeSingle();
        final current = assignmentRow?['reminder_count'] as int? ?? 0;
        await _supabase
            .from('survey_assignments')
            .update({
              'last_reminder_at': DateTime.now().toUtc().toIso8601String(),
              'reminder_count': current + 1,
              'updated_at': DateTime.now().toUtc().toIso8601String(),
            })
            .eq('survey_id', surveyId)
            .eq('user_id', userId);
      } catch (_) {}
    }

    return SurveyReminderResult(
      inAppSent: inAppSent,
      emailSent: emailSent,
      emailSkippedNoAddress: emailSkippedNoAddress,
      emailSkippedNotConfigured: emailSkippedNotConfigured,
      failures: failures,
    );
  }

  String buildResponsesCsv({
    required Survey survey,
    required List<SurveyQuestion> questions,
    required List<SurveyParticipant> participants,
  }) {
    final submitted = participants
        .where((p) => !p.isPending && p.response != null)
        .toList();
    final buffer = StringBuffer();
    final headers = [
      'Name',
      'Email',
      'Program',
      'Batch',
      'Status',
      'Submitted At',
      ...questions.map((q) => _csvEscape(q.prompt)),
    ];
    buffer.writeln(headers.join(','));

    for (final p in submitted) {
      final r = p.response!;
      final row = <String>[
        _csvEscape(p.displayName),
        _csvEscape(p.email),
        _csvEscape(p.program),
        _csvEscape(p.batchYear),
        _csvEscape(p.assignment.status.name),
        _csvEscape(r.submittedAt?.toIso8601String() ?? ''),
        ...questions.map((q) => _csvEscape('${r.answers[q.id] ?? ''}')),
      ];
      buffer.writeln(row.join(','));
    }
    return buffer.toString();
  }

  /// Detailed per-survey export:
  /// - respondent roster
  /// - per-question tally/count summaries
  /// - per-question raw responses by respondent
  String buildDetailedSurveyExportCsv({
    required Survey survey,
    required List<SurveyQuestion> questions,
    required List<SurveyParticipant> participants,
  }) {
    final submitted = participants
        .where((p) => !p.isPending && p.response != null)
        .toList(growable: false);
    final respondentById = {for (final p in submitted) p.assignment.userId: p};
    final buffer = StringBuffer();

    buffer.writeln('Survey,${_csvEscape(survey.title)}');
    buffer.writeln('Description,${_csvEscape(survey.description)}');
    buffer.writeln('Assigned,${participants.length}');
    buffer.writeln('Submitted,${submitted.length}');
    buffer.writeln('');

    buffer.writeln('Respondents');
    buffer.writeln('Name,Email,Program,Batch,Submitted At');
    for (final p in submitted) {
      final r = p.response!;
      buffer.writeln(
        [
          _csvEscape(p.displayName),
          _csvEscape(p.email),
          _csvEscape(p.program),
          _csvEscape(p.batchYear),
          _csvEscape(r.submittedAt?.toIso8601String() ?? ''),
        ].join(','),
      );
    }
    buffer.writeln('');

    for (final q in questions) {
      buffer.writeln('Question,${_csvEscape(q.prompt)}');
      buffer.writeln('Type,${q.type.name}');

      final responses = <(SurveyParticipant, dynamic)>[];
      for (final p in submitted) {
        final r = p.response!;
        if (!r.answers.containsKey(q.id)) continue;
        responses.add((p, r.answers[q.id]));
      }

      switch (q.type) {
        case SurveyQuestionType.singleChoice:
        case SurveyQuestionType.multipleChoice:
        case SurveyQuestionType.scale:
          final tally = <String, int>{};
          for (final (_, value) in responses) {
            if (value is List) {
              for (final v in value) {
                final k = '${v ?? ''}'.trim();
                if (k.isEmpty) continue;
                tally[k] = (tally[k] ?? 0) + 1;
              }
            } else {
              final k = '${value ?? ''}'.trim();
              if (k.isEmpty) continue;
              tally[k] = (tally[k] ?? 0) + 1;
            }
          }
          buffer.writeln('Tally Option,Count');
          final orderedKeys = tally.keys.toList()
            ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
          for (final key in orderedKeys) {
            buffer.writeln('${_csvEscape(key)},${tally[key]}');
          }
          if (tally.isEmpty) {
            buffer.writeln('No response,0');
          }
          break;
        case SurveyQuestionType.text:
        case SurveyQuestionType.longText:
        case SurveyQuestionType.date:
          buffer.writeln('Response Count,${responses.length}');
          break;
      }

      buffer.writeln('Respondent,Response');
      for (final (participant, value) in responses) {
        String responseValue;
        if (value is List) {
          responseValue = value.map((e) => '$e').join(' | ');
        } else {
          responseValue = '${value ?? ''}';
        }
        buffer.writeln(
          '${_csvEscape(participant.displayName)},${_csvEscape(responseValue)}',
        );
      }

      // Include explicit missing responders for auditing completion.
      final answeredIds = responses.map((e) => e.$1.assignment.userId).toSet();
      for (final participant in submitted) {
        if (answeredIds.contains(participant.assignment.userId)) continue;
        final p = respondentById[participant.assignment.userId];
        if (p == null) continue;
        buffer.writeln('${_csvEscape(p.displayName)},${_csvEscape('')}');
      }
      buffer.writeln('');
    }

    return buffer.toString();
  }

  Future<Uint8List> buildDetailedSurveySummaryPdfBytes({
    required Survey survey,
    required List<SurveyQuestion> questions,
    required List<SurveyParticipant> participants,
  }) async {
    final submitted = participants
        .where((p) => !p.isPending && p.response != null)
        .toList(growable: false);

    final doc = pw.Document();

    final byQuestion = <String, List<(SurveyParticipant, dynamic)>>{};
    for (final q in questions) {
      byQuestion[q.id] = <(SurveyParticipant, dynamic)>[];
    }
    for (final p in submitted) {
      final answers = p.response!.answers;
      for (final q in questions) {
        if (!answers.containsKey(q.id)) continue;
        byQuestion[q.id]!.add((p, answers[q.id]));
      }
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  survey.title,
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  DateTime.now().toIso8601String().split('T').first,
                  style: const pw.TextStyle(fontSize: 10),
                ),
              ],
            ),
          ),
          if (survey.description.trim().isNotEmpty)
            pw.Text(
              survey.description,
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
            ),
          pw.SizedBox(height: 10),
          pw.TableHelper.fromTextArray(
            headers: const ['Assigned', 'Submitted', 'Completion'],
            data: [
              [
                '${participants.length}',
                '${submitted.length}',
                '${participants.isEmpty ? 0 : ((submitted.length / participants.length) * 100).toStringAsFixed(0)}%',
              ],
            ],
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blue900),
            cellStyle: const pw.TextStyle(fontSize: 10),
            cellAlignment: pw.Alignment.centerLeft,
          ),
          pw.SizedBox(height: 14),
          pw.Text(
            'Respondents',
            style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          pw.TableHelper.fromTextArray(
            headers: const ['Name', 'Program', 'Batch', 'Submitted At'],
            data: submitted.map((p) {
              final ts = p.response!.submittedAt ?? p.response!.updatedAt;
              return [
                p.displayName,
                p.program,
                p.batchYear,
                ts.toIso8601String(),
              ];
            }).toList(),
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
            headerDecoration: const pw.BoxDecoration(
              color: PdfColors.indigo700,
            ),
            cellStyle: const pw.TextStyle(fontSize: 9),
          ),
          pw.SizedBox(height: 14),
          ...questions.expand((q) {
            final answers =
                byQuestion[q.id] ?? const <(SurveyParticipant, dynamic)>[];
            final tally = <String, int>{};
            for (final (_, v) in answers) {
              if (v is List) {
                for (final item in v) {
                  final k = '$item'.trim();
                  if (k.isEmpty) continue;
                  tally[k] = (tally[k] ?? 0) + 1;
                }
              } else {
                final k = '$v'.trim();
                if (k.isEmpty) continue;
                tally[k] = (tally[k] ?? 0) + 1;
              }
            }
            final maxTally = tally.values.isEmpty
                ? 1
                : tally.values.reduce((a, b) => a > b ? a : b);
            final tallyRows = tally.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value));

            return <pw.Widget>[
              pw.Container(
                margin: const pw.EdgeInsets.only(top: 8, bottom: 6),
                child: pw.Text(
                  'Q${q.order + 1}. ${q.prompt} (${q.type.name})',
                  style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              if (q.type == SurveyQuestionType.singleChoice ||
                  q.type == SurveyQuestionType.multipleChoice ||
                  q.type == SurveyQuestionType.scale)
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: tallyRows.isEmpty
                      ? [
                          pw.Text(
                            'No responses',
                            style: const pw.TextStyle(fontSize: 9),
                          ),
                        ]
                      : tallyRows.map((entry) {
                          final ratio = entry.value / maxTally;
                          return pw.Padding(
                            padding: const pw.EdgeInsets.only(bottom: 4),
                            child: pw.Row(
                              children: [
                                pw.SizedBox(
                                  width: 140,
                                  child: pw.Text(
                                    entry.key,
                                    style: const pw.TextStyle(fontSize: 9),
                                  ),
                                ),
                                pw.Container(
                                  width: 170 * ratio,
                                  height: 8,
                                  decoration: const pw.BoxDecoration(
                                    color: PdfColors.blue400,
                                  ),
                                ),
                                pw.SizedBox(width: 6),
                                pw.Text(
                                  '${entry.value}',
                                  style: const pw.TextStyle(fontSize: 9),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                )
              else
                pw.Text(
                  'Responses: ${answers.length}',
                  style: const pw.TextStyle(fontSize: 9),
                ),
              pw.SizedBox(height: 4),
              pw.TableHelper.fromTextArray(
                headers: const ['Respondent', 'Response'],
                data: answers.map((entry) {
                  final respondent = entry.$1.displayName;
                  final value = entry.$2;
                  final responseText = value is List
                      ? value.map((e) => '$e').join(' | ')
                      : '$value';
                  return [respondent, responseText];
                }).toList(),
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.blueGrey700,
                ),
                cellStyle: const pw.TextStyle(fontSize: 8.5),
              ),
            ];
          }),
        ],
      ),
    );

    return doc.save();
  }

  Future<void> _upsertSurveyToSupabase(Survey survey) async {
    final createdBySupabaseId =
        _bridge.currentSupabaseUserId ??
        await _bridge.resolveSupabaseUserId(survey.createdBy);
    if (createdBySupabaseId == null) {
      throw Exception('Unable to resolve survey creator.');
    }

    try {
      final existing = await _supabase
          .from('surveys')
          .select('data')
          .eq('id', survey.id)
          .maybeSingle();
      final existingData = Map<String, dynamic>.from(
        existing?['data'] as Map? ?? {},
      );
      final row = survey.toSupabaseRow(
        createdBySupabaseId: createdBySupabaseId,
        templateSupabaseId: survey.templateId,
      );
      final newData = Map<String, dynamic>.from(row['data'] as Map? ?? {});
      // Preserve keys like adminLastSeen* while overlaying kind / visibility_rules.
      row['data'] = {...existingData, ...newData};
      await _supabase.from('surveys').upsert(row, onConflict: 'id');
    } catch (e) {
      throw Exception('Error saving survey: $e');
    }
  }

  Future<void> _upsertQuestionsToSupabase(
    String surveyId,
    List<SurveyQuestion> questions,
  ) async {
    if (questions.isEmpty) return;

    try {
      for (final question in questions) {
        await _supabase
            .from('survey_questions')
            .upsert(
              question.toSupabaseRow(surveySupabaseId: surveyId),
              onConflict: 'id',
            );
      }
    } catch (e) {
      throw Exception('Error saving survey question: $e');
    }
  }

  Future<String?> _resolveTargetSupabaseUserId(String userId) {
    if (userId.isEmpty) return Future.value(null);
    return _bridge.resolveSupabaseUserId(userId);
  }

  Future<List<Survey>> _fetchAllSurveysFromSupabase() async {
    try {
      final rows = await _supabase
          .from('surveys')
          .select()
          .order('created_at', ascending: false);
      return rows.map(Survey.fromSupabaseRow).toList();
    } catch (_) {
      return [];
    }
  }

  static String _csvEscape(String value) {
    final v = value.replaceAll('"', '""');
    if (v.contains(',') || v.contains('"') || v.contains('\n')) {
      return '"$v"';
    }
    return v;
  }
}
