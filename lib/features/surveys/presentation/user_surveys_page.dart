import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:alumni_system/features/surveys/models/survey_model.dart';
import 'package:alumni_system/core/services/app_session.dart';
import 'package:alumni_system/features/surveys/data/survey_service.dart';
import 'package:alumni_system/features/surveys/presentation/user_survey_take_page.dart';
import 'package:alumni_system/shared/widgets/user/portal_breakpoints.dart';
import 'package:alumni_system/shared/widgets/user/portal_headers.dart';
import 'package:alumni_system/shared/widgets/user/portal_skeletons.dart';
import 'package:alumni_system/shared/widgets/user/portal_states.dart';
import 'package:alumni_system/shared/widgets/user/portal_theme.dart';

/// Assigned surveys list (separate from CHED Tracer).
class UserSurveysScreen extends StatefulWidget {
  const UserSurveysScreen({super.key});

  @override
  State<UserSurveysScreen> createState() => _UserSurveysScreenState();
}

class _UserSurveysScreenState extends State<UserSurveysScreen> {
  final _surveyService = SurveyService();
  int _streamGeneration = 0;
  final Map<String, Survey> _surveyById = {};
  String? _detailsFingerprint;
  bool _loadingDetails = false;

  Future<void> _ensureSurveyDetails(List<SurveyAssignment> assignments) async {
    final fingerprint = assignments
        .map((a) => '${a.id}:${a.surveyId}:${a.status.name}')
        .join('|');
    final ids = assignments.map((a) => a.surveyId).toSet().toList();
    final missing = ids.where((id) => !_surveyById.containsKey(id)).toList();
    final listChanged = _detailsFingerprint != fingerprint;

    // Reload all related surveys when the assignment list changes so admin
    // title/description edits appear (not only first-time missing IDs).
    if (!listChanged && missing.isEmpty) return;
    if (_loadingDetails) return;
    _loadingDetails = true;

    final toLoad = listChanged ? ids : missing;
    final loaded = await _surveyService.getSurveysByIds(toLoad);
    if (!mounted) return;
    setState(() {
      _surveyById.addAll(loaded);
      _detailsFingerprint = fingerprint;
      _loadingDetails = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final uid = AppSession.userId;
    if (uid == null) {
      return const Scaffold(body: Center(child: Text('Please log in')));
    }

    final width = PortalBreakpoints.widthOf(context);
    final padding = PortalBreakpoints.pagePadding(
      width,
    ).copyWith(left: 16, right: 16);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const PortalAppBar(title: 'My Surveys'),
      body: PortalContentFrame(
        child: StreamBuilder<List<SurveyAssignment>>(
          key: ValueKey(_streamGeneration),
          stream: _surveyService.watchUserAssignments(uid),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SurveyListSkeleton();
            }
            if (snapshot.hasError) {
              return PortalErrorState(
                error: snapshot.error,
                onRetry: () => setState(() {
                  _surveyById.clear();
                  _detailsFingerprint = null;
                  _streamGeneration++;
                }),
              );
            }

            final raw = snapshot.data ?? [];
            final fingerprint = raw
                .map((a) => '${a.id}:${a.surveyId}:${a.status.name}')
                .join('|');
            final detailsReady =
                raw.isEmpty ||
                (raw.every((a) => _surveyById.containsKey(a.surveyId)) &&
                    _detailsFingerprint == fingerprint);

            if (!detailsReady) {
              // Start the batch fetch immediately (do not wait a frame).
              unawaited(_ensureSurveyDetails(raw));
              return const SurveyListSkeleton();
            }

            final assignments = raw.where((a) {
              final s = _surveyById[a.surveyId];
              // CHED GTS is handled on the Tracer tab.
              if (s?.isChedGtsBuiltin == true) return false;
              return true;
            }).toList();

            if (assignments.isEmpty) {
              return const PortalEmptyState(
                icon: Icons.poll_outlined,
                title: 'No assigned surveys',
                subtitle:
                    'When the office assigns a survey to you, it will appear here. '
                    'CHED Graduate Tracer lives under the Tracer tab.',
              );
            }

            final actionable = assignments.where((a) {
              if (a.status == SurveyAssignmentStatus.completed) return false;
              final s = _surveyById[a.surveyId];
              // Until survey details load, keep incomplete items visible.
              if (s == null) return true;
              return s.acceptsResponses;
            }).toList();

            final scheduled = assignments.where((a) {
              if (a.status == SurveyAssignmentStatus.completed) return false;
              final s = _surveyById[a.surveyId];
              return s?.isNotYetOpen == true;
            }).toList();

            final closedIncomplete = assignments.where((a) {
              if (a.status == SurveyAssignmentStatus.completed) return false;
              final s = _surveyById[a.surveyId];
              return s != null && s.isPastClose;
            }).toList();

            final notStarted = actionable
                .where((a) => a.status == SurveyAssignmentStatus.notStarted)
                .toList();
            final inProgress = actionable
                .where((a) => a.status == SurveyAssignmentStatus.inProgress)
                .toList();
            final completed = assignments
                .where((a) => a.status == SurveyAssignmentStatus.completed)
                .toList();

            final needsActionCount = notStarted.length + inProgress.length;

            return RefreshIndicator(
              onRefresh: () async {
                setState(() {
                  _streamGeneration++;
                  _surveyById.clear();
                });
              },
              color: PortalTheme.navy,
              child: ListView(
                padding: padding.copyWith(bottom: 40),
                children: [
                  if (needsActionCount > 0)
                    PortalHighlightPanel(
                      margin: const EdgeInsets.only(bottom: PortalTheme.space4),
                      variant: PortalHighlightVariant.attention,
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: PortalTheme.gold.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(
                                PortalTheme.radiusSm,
                              ),
                            ),
                            child: const Icon(
                              Icons.notifications_active_outlined,
                              color: PortalTheme.navy,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: PortalTheme.space2),
                          Expanded(
                            child: Text(
                              needsActionCount == 1
                                  ? '1 survey needs your response'
                                  : '$needsActionCount surveys need your response',
                              style: PortalTheme.cardTitle.copyWith(
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (notStarted.isNotEmpty) ...[
                    PortalSectionHeader(
                      title: 'Needs action',
                      subtitle: 'Not started yet',
                      padding: const EdgeInsets.only(
                        bottom: PortalTheme.space2,
                      ),
                    ),
                    ...notStarted.map(
                      (a) => _SurveyRowCard(
                        assignment: a,
                        survey: _surveyById[a.surveyId],
                      ),
                    ),
                    const SizedBox(height: PortalTheme.space4),
                  ],
                  if (inProgress.isNotEmpty) ...[
                    PortalSectionHeader(
                      title: 'In progress',
                      subtitle: 'Pick up where you left off',
                      padding: const EdgeInsets.only(
                        bottom: PortalTheme.space2,
                      ),
                    ),
                    ...inProgress.map(
                      (a) => _SurveyRowCard(
                        assignment: a,
                        survey: _surveyById[a.surveyId],
                      ),
                    ),
                    const SizedBox(height: PortalTheme.space4),
                  ],
                  if (scheduled.isNotEmpty) ...[
                    PortalSectionHeader(
                      title: 'Scheduled',
                      subtitle: 'Assigned, but not open yet',
                      padding: const EdgeInsets.only(
                        bottom: PortalTheme.space2,
                      ),
                    ),
                    ...scheduled.map(
                      (a) => _SurveyRowCard(
                        assignment: a,
                        survey: _surveyById[a.surveyId],
                      ),
                    ),
                    const SizedBox(height: PortalTheme.space4),
                  ],
                  if (closedIncomplete.isNotEmpty) ...[
                    PortalSectionHeader(
                      title: 'Closed',
                      subtitle: 'No longer accepting responses',
                      padding: const EdgeInsets.only(
                        bottom: PortalTheme.space2,
                      ),
                    ),
                    ...closedIncomplete.map(
                      (a) => _SurveyRowCard(
                        assignment: a,
                        survey: _surveyById[a.surveyId],
                      ),
                    ),
                    const SizedBox(height: PortalTheme.space4),
                  ],
                  if (completed.isNotEmpty) ...[
                    PortalSectionHeader(
                      title: 'Completed',
                      subtitle: 'View your submitted responses',
                      padding: const EdgeInsets.only(
                        bottom: PortalTheme.space2,
                      ),
                    ),
                    ...completed.map(
                      (a) => _SurveyRowCard(
                        assignment: a,
                        survey: _surveyById[a.surveyId],
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SurveyRowCard extends StatelessWidget {
  const _SurveyRowCard({required this.assignment, this.survey});

  final SurveyAssignment assignment;
  final Survey? survey;

  @override
  Widget build(BuildContext context) {
    final status = assignment.status;
    final notYetOpen = survey?.isNotYetOpen == true;
    final pastClose =
        survey?.isPastClose == true &&
        status != SurveyAssignmentStatus.completed;
    final canTake =
        status != SurveyAssignmentStatus.completed &&
        survey?.acceptsResponses == true;

    final (
      PortalChipTone tone,
      String label,
      IconData icon,
      String cta,
    ) = notYetOpen
        ? (
            PortalChipTone.brand,
            'Scheduled',
            Icons.schedule_rounded,
            'Not open yet',
          )
        : pastClose
        ? (PortalChipTone.danger, 'Closed', Icons.lock_outline, 'Closed')
        : switch (status) {
            SurveyAssignmentStatus.notStarted => (
              PortalChipTone.warning,
              'Not started',
              Icons.assignment_outlined,
              'Start',
            ),
            SurveyAssignmentStatus.inProgress => (
              PortalChipTone.brand,
              'In progress',
              Icons.edit_note_outlined,
              'Continue',
            ),
            SurveyAssignmentStatus.completed => (
              PortalChipTone.success,
              'Completed',
              Icons.check_circle_outline,
              'View',
            ),
          };

    final description = survey?.description.trim() ?? '';
    final liveTitle = survey?.title.trim() ?? '';
    final title =
        liveTitle.isNotEmpty ? liveTitle : assignment.surveyTitle;
    final openAt = survey?.openAt;
    final closeAt = survey?.closeAt;
    final assignedAt = assignment.assignedAt;

    return Container(
      margin: const EdgeInsets.only(bottom: PortalTheme.space2),
      decoration: BoxDecoration(
        color: PortalTheme.card,
        borderRadius: BorderRadius.circular(PortalTheme.radius2xl),
        border: Border.all(color: PortalTheme.borderStrong),
        boxShadow: PortalTheme.softShadow,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(PortalTheme.radius2xl),
        child: InkWell(
          borderRadius: BorderRadius.circular(PortalTheme.radius2xl),
          onTap: () => _openSurvey(
            context,
            canTake: canTake,
            viewOnly: status == SurveyAssignmentStatus.completed,
          ),
          child: Padding(
            padding: const EdgeInsets.all(PortalTheme.space3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PortalChip(label: label, icon: icon, tone: tone),
                    const Spacer(),
                    if (notYetOpen && openAt != null)
                      PortalChip(
                        label:
                            'Opens ${DateFormat.MMMd().add_jm().format(openAt)}',
                        icon: Icons.lock_clock_outlined,
                        tone: PortalChipTone.warning,
                      )
                    else if (closeAt != null)
                      PortalChip(
                        label: 'Due ${DateFormat.MMMd().format(closeAt)}',
                        icon: Icons.event_outlined,
                        tone: closeAt.isBefore(DateTime.now())
                            ? PortalChipTone.danger
                            : PortalChipTone.neutral,
                      ),
                  ],
                ),
                const SizedBox(height: PortalTheme.space2),
                Text(title, style: PortalTheme.cardTitle),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: PortalTheme.bodySecondary,
                  ),
                ],
                const SizedBox(height: 6),
                Text(
                  'Assigned ${DateFormat.yMMMd().format(assignedAt)}',
                  style: PortalTheme.caption,
                ),
                const SizedBox(height: PortalTheme.space3),
                Align(
                  alignment: Alignment.centerRight,
                  child: status == SurveyAssignmentStatus.completed
                      ? OutlinedButton.icon(
                          onPressed: () => _openSurvey(
                            context,
                            canTake: false,
                            viewOnly: true,
                          ),
                          style: PortalTheme.secondaryButton(dense: true),
                          icon: const Icon(Icons.visibility_outlined, size: 16),
                          label: const Text('View'),
                        )
                      : canTake
                      ? FilledButton.icon(
                          onPressed: () => _openSurvey(
                            context,
                            canTake: true,
                            viewOnly: false,
                          ),
                          style: PortalTheme.primaryButton(dense: true),
                          icon: const Icon(
                            Icons.arrow_forward_rounded,
                            size: 16,
                          ),
                          label: Text(cta),
                        )
                      : OutlinedButton.icon(
                          onPressed: null,
                          style: PortalTheme.secondaryButton(dense: true),
                          icon: Icon(
                            notYetOpen
                                ? Icons.lock_clock_outlined
                                : Icons.lock_outline,
                            size: 16,
                          ),
                          label: Text(cta),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openSurvey(
    BuildContext context, {
    required bool canTake,
    required bool viewOnly,
  }) async {
    if (!viewOnly && !canTake) {
      final openAt = survey?.openAt;
      final message = survey?.isNotYetOpen == true && openAt != null
          ? 'This survey opens on ${DateFormat.yMMMd().add_jm().format(openAt)}.'
          : survey?.isPastClose == true
          ? 'This survey is closed and no longer accepts responses.'
          : 'This survey is not available yet.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            UserSurveyTakeScreen(surveyId: assignment.surveyId),
      ),
    );
  }
}
