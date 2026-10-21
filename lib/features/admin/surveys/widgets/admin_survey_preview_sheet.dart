import 'package:flutter/material.dart';
import 'package:alumni_system/features/admin/surveys/widgets/admin_survey_ui.dart';
import 'package:alumni_system/features/surveys/ched_gts/ched_gts_form.dart';
import 'package:alumni_system/features/surveys/data/classic_survey_visibility.dart';
import 'package:alumni_system/features/surveys/models/survey_model.dart';
import 'package:alumni_system/features/surveys/presentation/widgets/survey_take_ui.dart';
import 'package:alumni_system/shared/widgets/admin/admin_surface.dart';

/// Read-only survey preview for admins (no submit).
/// Prefer [AdminSurveyPreviewPanel] when embedding beside the editor.
///
/// Desktop opens a centered modal dialog; narrow windows fall back to a
/// bottom sheet.
Future<void> showAdminSurveyPreview({
  required BuildContext context,
  required Survey survey,
  required List<SurveyQuestion> questions,
}) {
  Widget panel(BuildContext ctx) => AdminSurveyPreviewPanel(
        survey: survey,
        questions: questions,
        onClose: () => Navigator.pop(ctx),
      );

  if (adminIsWideSurface(context)) {
    return showAdminDialogSurface<void>(
      context: context,
      maxWidth: 720,
      backgroundColor: AdminSurveyTheme.surface,
      child: Builder(builder: panel),
    );
  }

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AdminSurveyTheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      final height = MediaQuery.sizeOf(ctx).height * 0.92;
      return SizedBox(
        height: height,
        child: panel(ctx),
      );
    },
  );
}

/// Preview chrome used beside the editor workspace (and optional overlays).
class AdminSurveyPreviewPanel extends StatelessWidget {
  const AdminSurveyPreviewPanel({
    super.key,
    required this.survey,
    required this.questions,
    this.onClose,
    this.showCloseControls = true,
  });

  final Survey survey;
  final List<SurveyQuestion> questions;
  final VoidCallback? onClose;

  /// When false, hides the header X and bottom “Close preview” button
  /// (used for the always-visible editor preview pane).
  final bool showCloseControls;

  @override
  Widget build(BuildContext context) {
    final canClose = showCloseControls && onClose != null;
    return Material(
      color: AdminSurveyTheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(16, 12, canClose ? 8 : 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Preview',
                        style: TextStyle(
                          fontSize: showCloseControls ? 18 : 14,
                          fontWeight: FontWeight.w700,
                          color: AdminSurveyTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        showCloseControls
                            ? (survey.title.trim().isEmpty
                                  ? 'Untitled survey'
                                  : survey.title)
                            : (survey.isChedGtsBuiltin
                                  ? 'Official CHED form · read-only'
                                  : 'As alumni see it · answer to test '
                                        'visibility rules'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: showCloseControls ? 13 : 12,
                          color: AdminSurveyTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (canClose)
                  IconButton(
                    tooltip: 'Close preview',
                    onPressed: onClose,
                    icon: const Icon(Icons.close),
                  ),
              ],
            ),
          ),
          const Divider(height: 1, color: AdminSurveyTheme.border),
          Expanded(
            child: survey.isChedGtsBuiltin
                ? ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      ChedGtsForm(
                        answers: const {},
                        onChanged: (_) {},
                        readOnly: true,
                        showIntro: false,
                      ),
                    ],
                  )
                : _ClassicSurveyPreviewBody(
                    survey: survey,
                    questions: questions,
                  ),
          ),
          if (canClose) ...[
            const Divider(height: 1, color: AdminSurveyTheme.border),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              child: OutlinedButton(
                onPressed: onClose,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AdminSurveyTheme.textPrimary,
                  side: const BorderSide(color: AdminSurveyTheme.border),
                  minimumSize: const Size(0, AdminSurveyTheme.buttonHeight),
                ),
                child: const Text('Close preview'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ClassicSurveyPreviewBody extends StatefulWidget {
  const _ClassicSurveyPreviewBody({
    required this.survey,
    required this.questions,
  });

  final Survey survey;
  final List<SurveyQuestion> questions;

  @override
  State<_ClassicSurveyPreviewBody> createState() =>
      _ClassicSurveyPreviewBodyState();
}

class _ClassicSurveyPreviewBodyState extends State<_ClassicSurveyPreviewBody> {
  final Map<String, dynamic> _answers = {};

  List<SurveyQuestion> get _visible {
    final rules = widget.survey.visibilityRules;
    if (rules.isEmpty) return widget.questions;
    return ClassicSurveyVisibility.visibleQuestions(
      questions: widget.questions,
      answers: _answers,
      rules: rules,
    );
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visible;
    final answered = visible
        .where((q) => surveyTakeAnswerFilled(_answers[q.id]))
        .length;

    // Mirrors the respondent take page so admins preview the real experience.
    return Container(
      color: SurveyTakeTheme.background,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: SurveyTakeHeaderCard(
              title: widget.survey.title,
              description: '',
              totalQuestions: visible.length,
              answeredCount: answered,
            ),
          ),
          const SizedBox(height: 12),
          if (visible.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: Text(
                  'No questions to preview yet.',
                  style: TextStyle(color: SurveyTakeTheme.textSecondary),
                ),
              ),
            )
          else
            for (var i = 0; i < visible.length; i++) ...[
              if (surveyTakeShowsSectionHeader(visible, i))
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: SurveySectionBanner(label: visible[i].sectionLabel),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: SurveyQuestionCard(
                  question: visible[i],
                  number: i + 1,
                  answer: _answers[visible[i].id],
                  onAnswerChanged: (v) =>
                      setState(() => _answers[visible[i].id] = v),
                ),
              ),
            ],
        ],
      ),
    );
  }
}
