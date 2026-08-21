import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:alumni_system/features/surveys/models/survey_model.dart';
import 'package:alumni_system/shared/widgets/user/portal_headers.dart';
import 'package:alumni_system/shared/widgets/user/portal_theme.dart';

/// Visual palette shared by the respondent take page and the admin preview,
/// aliasing [PortalTheme] so alumni see consistent USTP branding.
class SurveyTakeTheme {
  static const navy = PortalTheme.navy;
  static const navyLight = PortalTheme.navyMid;
  static const accent = PortalTheme.sky;
  static const accentSoft = Color(0xFFE8F4FD);
  static const background = PortalTheme.pageBg;
  static const surface = PortalTheme.card;
  static const border = PortalTheme.border;
  static const textPrimary = PortalTheme.textPrimary;
  static const textSecondary = PortalTheme.textSecondary;
  static const success = PortalTheme.success;
  static const successSoft = Color(0xFFECFDF5);
  static const danger = PortalTheme.danger;
}

/// Whether an answer counts as filled for progress/checkmark purposes.
bool surveyTakeAnswerFilled(dynamic a) {
  if (a == null) return false;
  if (a is String && a.trim().isEmpty) return false;
  if (a is List && a.isEmpty) return false;
  return true;
}

/// True when a section banner should render above question [index].
bool surveyTakeShowsSectionHeader(List<SurveyQuestion> visible, int index) {
  final section = visible[index].section?.trim() ?? '';
  if (section.isEmpty) return false;
  if (index == 0) return true;
  return (visible[index - 1].section?.trim() ?? '') != section;
}

/// Gradient hero card with survey title, description, meta chips + progress.
class SurveyTakeHeaderCard extends StatelessWidget {
  const SurveyTakeHeaderCard({
    super.key,
    required this.title,
    required this.description,
    required this.totalQuestions,
    required this.answeredCount,
    this.showProgress = true,
  });

  final String title;
  final String description;
  final int totalQuestions;
  final int answeredCount;
  final bool showProgress;

  @override
  Widget build(BuildContext context) {
    final desc = description.trim();
    final progress =
        totalQuestions == 0 ? 0.0 : answeredCount / totalQuestions;
    final estMinutes = math.max(1, (totalQuestions * 0.4).ceil());

    return PortalHighlightPanel(
      variant: PortalHighlightVariant.soft,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.trim().isEmpty ? 'Untitled survey' : title,
            style: PortalTheme.sectionTitle.copyWith(
              color: PortalTheme.navy,
              fontSize: 20,
            ),
          ),
          if (desc.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              desc,
              style: PortalTheme.bodySecondary.copyWith(fontSize: 13.5),
            ),
          ],
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _chip(Icons.help_outline, '$totalQuestions questions'),
              _chip(Icons.schedule, '~$estMinutes min'),
              if (showProgress)
                _chip(
                  Icons.check_circle_outline,
                  '$answeredCount of $totalQuestions answered',
                ),
            ],
          ),
          if (showProgress) ...[
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 7,
                backgroundColor: PortalTheme.surfaceMuted,
                valueColor:
                    const AlwaysStoppedAnimation<Color>(PortalTheme.navy),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _chip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: PortalTheme.navy.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: PortalTheme.border.withValues(alpha: 0.9)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: PortalTheme.navy),
          const SizedBox(width: 6),
          Text(
            label,
            style: PortalTheme.caption.copyWith(
              color: PortalTheme.navy,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Highlighted banner shown when a new section starts.
class SurveySectionBanner extends StatelessWidget {
  const SurveySectionBanner({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: PortalTheme.navy.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(PortalTheme.radiusXl),
        border: Border.all(
          color: PortalTheme.border.withValues(alpha: 0.8),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.bookmark_outline,
            size: 18,
            color: SurveyTakeTheme.accent,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: SurveyTakeTheme.navy,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One question rendered as a card with a numbered badge and styled input.
/// Used both by the respondent take page and the admin preview panel.
class SurveyQuestionCard extends StatelessWidget {
  const SurveyQuestionCard({
    super.key,
    required this.question,
    required this.number,
    required this.answer,
    required this.onAnswerChanged,
    this.textController,
    this.textValidator,
  });

  final SurveyQuestion question;
  final int number;
  final dynamic answer;
  final ValueChanged<dynamic> onAnswerChanged;

  /// Optional controller for text questions (take page keeps its own).
  final TextEditingController? textController;
  final String? Function(String?)? textValidator;

  bool get _answered => surveyTakeAnswerFilled(answer);

  @override
  Widget build(BuildContext context) {
    final answered = _answered;
    return AnimatedContainer(
      duration: PortalTheme.normal,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: SurveyTakeTheme.surface,
        borderRadius: BorderRadius.circular(PortalTheme.radius2xl),
        border: Border.all(
          color: answered
              ? SurveyTakeTheme.success.withValues(alpha: 0.45)
              : SurveyTakeTheme.border.withValues(alpha: 0.75),
        ),
        boxShadow: PortalTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: answered
                      ? SurveyTakeTheme.successSoft
                      : SurveyTakeTheme.accentSoft,
                  borderRadius: BorderRadius.circular(PortalTheme.radiusSm),
                ),
                child: answered
                    ? const Icon(
                        Icons.check,
                        size: 15,
                        color: SurveyTakeTheme.success,
                      )
                    : Text(
                        '$number',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: SurveyTakeTheme.accent,
                        ),
                      ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text.rich(
                    TextSpan(
                      text: question.prompt.trim().isEmpty
                          ? 'Untitled question'
                          : question.prompt,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: SurveyTakeTheme.textPrimary,
                        height: 1.35,
                      ),
                      children: [
                        if (question.required)
                          const TextSpan(
                            text: ' *',
                            style: TextStyle(
                              color: SurveyTakeTheme.danger,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildAnswerField(context),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration({String? hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        color: SurveyTakeTheme.textSecondary,
        fontSize: 13.5,
      ),
      filled: true,
      fillColor: SurveyTakeTheme.background,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(PortalTheme.radiusMd),
        borderSide: const BorderSide(color: SurveyTakeTheme.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(PortalTheme.radiusMd),
        borderSide: const BorderSide(color: SurveyTakeTheme.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(PortalTheme.radiusMd),
        borderSide: const BorderSide(color: SurveyTakeTheme.accent, width: 1.6),
      ),
    );
  }

  Widget _buildAnswerField(BuildContext context) {
    final q = question;
    switch (q.type) {
      case SurveyQuestionType.text:
        return TextFormField(
          controller: textController,
          initialValue: textController == null
              ? (answer?.toString() ?? '')
              : null,
          decoration: _inputDecoration(hint: 'Type your answer…'),
          maxLines: 3,
          minLines: 1,
          validator: textValidator,
          onChanged: onAnswerChanged,
        );
      case SurveyQuestionType.longText:
        return TextFormField(
          controller: textController,
          initialValue: textController == null
              ? (answer?.toString() ?? '')
              : null,
          decoration: _inputDecoration(hint: 'Type your answer…'),
          maxLines: 6,
          minLines: 4,
          validator: textValidator,
          onChanged: onAnswerChanged,
        );
      case SurveyQuestionType.singleChoice:
        final current = answer as String?;
        return Column(
          children: [
            for (final opt in q.options) ...[
              _OptionTile(
                label: opt,
                selected: current == opt,
                multi: false,
                onTap: () => onAnswerChanged(opt),
              ),
              if (opt != q.options.last) const SizedBox(height: 8),
            ],
          ],
        );
      case SurveyQuestionType.multipleChoice:
        final selected = (answer as List?)?.cast<String>() ?? <String>[];
        return Column(
          children: [
            for (final opt in q.options) ...[
              _OptionTile(
                label: opt,
                selected: selected.contains(opt),
                multi: true,
                onTap: () {
                  final list = List<String>.from(selected);
                  if (list.contains(opt)) {
                    list.remove(opt);
                  } else {
                    list.add(opt);
                  }
                  onAnswerChanged(list);
                },
              ),
              if (opt != q.options.last) const SizedBox(height: 8),
            ],
          ],
        );
      case SurveyQuestionType.scale:
        final min = q.scaleMin ?? 1;
        final max = q.scaleMax ?? 5;
        final current = answer as int? ?? min;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '$min',
                  style: const TextStyle(
                    fontSize: 12,
                    color: SurveyTakeTheme.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: SurveyTakeTheme.accent,
                      thumbColor: SurveyTakeTheme.accent,
                      inactiveTrackColor: SurveyTakeTheme.border,
                      overlayColor:
                          SurveyTakeTheme.accent.withValues(alpha: 0.12),
                    ),
                    child: Slider(
                      min: min.toDouble(),
                      max: max.toDouble(),
                      divisions: max - min,
                      label: current.toString(),
                      value: current.toDouble().clamp(
                            min.toDouble(),
                            max.toDouble(),
                          ),
                      onChanged: (v) => onAnswerChanged(v.round()),
                    ),
                  ),
                ),
                Text(
                  '$max',
                  style: const TextStyle(
                    fontSize: 12,
                    color: SurveyTakeTheme.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            Align(
              alignment: Alignment.center,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: SurveyTakeTheme.accentSoft,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Selected: $current',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: SurveyTakeTheme.accent,
                  ),
                ),
              ),
            ),
          ],
        );
      case SurveyQuestionType.date:
        final raw = answer as String?;
        final hasValue = raw != null && raw.isNotEmpty;
        return InkWell(
          borderRadius: BorderRadius.circular(PortalTheme.radiusMd),
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: DateTime.now(),
              firstDate: DateTime(1950),
              lastDate: DateTime.now(),
            );
            if (picked != null) {
              onAnswerChanged(picked.toIso8601String());
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              color: SurveyTakeTheme.background,
              borderRadius: BorderRadius.circular(PortalTheme.radiusMd),
              border: Border.all(
                color:
                    hasValue ? SurveyTakeTheme.accent : SurveyTakeTheme.border,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today_outlined,
                  size: 18,
                  color: hasValue
                      ? SurveyTakeTheme.accent
                      : SurveyTakeTheme.textSecondary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    hasValue
                        ? DateFormat.yMMMd().format(DateTime.parse(raw))
                        : 'Tap to select date',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: hasValue ? FontWeight.w600 : FontWeight.w400,
                      color: hasValue
                          ? SurveyTakeTheme.textPrimary
                          : SurveyTakeTheme.textSecondary,
                    ),
                  ),
                ),
                const Icon(
                  Icons.expand_more,
                  size: 18,
                  color: SurveyTakeTheme.textSecondary,
                ),
              ],
            ),
          ),
        );
    }
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.label,
    required this.selected,
    required this.multi,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool multi;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(PortalTheme.radiusMd),
      onTap: onTap,
      child: AnimatedContainer(
        duration: PortalTheme.fast,
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? SurveyTakeTheme.accentSoft
              : SurveyTakeTheme.background,
          borderRadius: BorderRadius.circular(PortalTheme.radiusMd),
          border: Border.all(
            color: selected ? SurveyTakeTheme.accent : SurveyTakeTheme.border,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              multi
                  ? (selected
                      ? Icons.check_box
                      : Icons.check_box_outline_blank)
                  : (selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off),
              size: 20,
              color: selected
                  ? SurveyTakeTheme.accent
                  : SurveyTakeTheme.textSecondary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected
                      ? SurveyTakeTheme.navy
                      : SurveyTakeTheme.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
