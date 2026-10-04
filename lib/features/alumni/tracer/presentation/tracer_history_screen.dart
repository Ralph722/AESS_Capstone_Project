import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:alumni_system/features/alumni/tracer/presentation/ched_response_screen.dart';
import 'package:alumni_system/features/surveys/models/survey_model.dart';
import 'package:alumni_system/shared/widgets/user/portal_breakpoints.dart';
import 'package:alumni_system/shared/widgets/user/portal_headers.dart';
import 'package:alumni_system/shared/widgets/user/portal_states.dart';
import 'package:alumni_system/shared/widgets/user/portal_theme.dart';

/// Past CHED GTS submissions, opened from the Tracer header.
class TracerHistoryScreen extends StatelessWidget {
  const TracerHistoryScreen({super.key, required this.history});

  final List<SurveyResponseWithMeta> history;

  static Future<void> open(
    BuildContext context, {
    required List<SurveyResponseWithMeta> history,
  }) {
    return Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(builder: (_) => TracerHistoryScreen(history: history)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = PortalBreakpoints.widthOf(context);
    final padding = PortalBreakpoints.pagePadding(width);

    return Scaffold(
      backgroundColor: PortalTheme.pageBg,
      appBar: const PortalAppBar(
        title: 'Past responses',
        subtitle: 'CHED Graduate Tracer Study',
        automaticallyImplyLeading: true,
      ),
      body: history.isEmpty
          ? const PortalEmptyState(
              icon: Icons.history_outlined,
              title: 'No CHED history yet',
              subtitle:
                  'Submitted CHED Graduate Tracer responses will appear here '
                  'for your records.',
            )
          : ListView.builder(
              padding: padding.copyWith(
                bottom: 40 + MediaQuery.paddingOf(context).bottom,
              ),
              itemCount: history.length,
              itemBuilder: (context, index) {
                final item = history[index];
                final submitted = item.response.submittedAt;
                return _HistoryResponseCard(
                  title: item.surveyTitle,
                  submittedLabel: submitted != null
                      ? DateFormat.yMMMd().add_jm().format(submitted.toLocal())
                      : null,
                  onTap: () => ChedResponseScreen.open(
                    context,
                    surveyTitle: item.surveyTitle,
                    answers: item.response.answers,
                    submittedAt: submitted,
                  ),
                );
              },
            ),
    );
  }
}

class _HistoryResponseCard extends StatelessWidget {
  const _HistoryResponseCard({
    required this.title,
    required this.submittedLabel,
    required this.onTap,
  });

  final String title;
  final String? submittedLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: PortalTheme.space2),
      child: Material(
        color: PortalTheme.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PortalTheme.radiusLg),
          side: const BorderSide(color: PortalTheme.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          splashColor: PortalTheme.navy.withValues(alpha: 0.06),
          highlightColor: PortalTheme.navy.withValues(alpha: 0.04),
          hoverColor: PortalTheme.navy.withValues(alpha: 0.03),
          child: Padding(
            padding: const EdgeInsets.all(PortalTheme.space3),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: PortalTheme.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(PortalTheme.radiusSm),
                  ),
                  child: const Icon(
                    Icons.verified_outlined,
                    color: PortalTheme.success,
                    size: 20,
                  ),
                ),
                const SizedBox(width: PortalTheme.space2),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: PortalTheme.cardTitle.copyWith(fontSize: 15),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        submittedLabel != null
                            ? 'Submitted $submittedLabel'
                            : 'Submitted',
                        style: PortalTheme.meta,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: PortalTheme.space1),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: PortalTheme.textMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
