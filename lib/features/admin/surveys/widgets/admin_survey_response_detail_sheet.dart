import 'package:flutter/material.dart';
import 'package:alumni_system/features/admin/surveys/widgets/admin_survey_ui.dart';
import 'package:alumni_system/features/surveys/ched_gts/ched_gts_form.dart';
import 'package:alumni_system/features/surveys/ched_gts/ched_gts_schema.dart';
import 'package:alumni_system/features/surveys/ched_gts/ched_gts_visibility.dart';
import 'package:alumni_system/features/surveys/data/survey_answer_display.dart';
import 'package:alumni_system/features/surveys/models/survey_model.dart';
import 'package:alumni_system/shared/widgets/admin/admin_surface.dart';

/// Sectioned response detail view — UI only; does not alter CHED schema.
///
/// On desktop this opens as a right-docked side panel so the responses list
/// stays visible; on narrow windows it falls back to a bottom sheet.
Future<void> showAdminSurveyResponseDetailSheet({
  required BuildContext context,
  required String alumniName,
  required SurveyResponse response,
  required bool isChedBuiltin,
  required List<SurveyQuestion> questions,
  VoidCallback? onViewTimeline,
}) {
  Widget workspace(BuildContext ctx) => _ResponseDetailWorkspace(
        alumniName: alumniName,
        response: response,
        isChedBuiltin: isChedBuiltin,
        questions: questions,
        onClose: () => Navigator.pop(ctx),
        onViewTimeline: onViewTimeline,
      );

  if (adminIsWideSurface(context)) {
    return showAdminSidePanel<void>(
      context: context,
      width: 560,
      backgroundColor: AdminSurveyTheme.background,
      child: Builder(builder: workspace),
    );
  }

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: AdminSurveyTheme.background,
    builder: (ctx) {
      final height = MediaQuery.sizeOf(ctx).height * 0.92;
      return SizedBox(
        height: height,
        child: workspace(ctx),
      );
    },
  );
}

class _ResponseDetailWorkspace extends StatefulWidget {
  const _ResponseDetailWorkspace({
    required this.alumniName,
    required this.response,
    required this.isChedBuiltin,
    required this.questions,
    required this.onClose,
    this.onViewTimeline,
  });

  final String alumniName;
  final SurveyResponse response;
  final bool isChedBuiltin;
  final List<SurveyQuestion> questions;
  final VoidCallback onClose;
  final VoidCallback? onViewTimeline;

  @override
  State<_ResponseDetailWorkspace> createState() =>
      _ResponseDetailWorkspaceState();
}

class _ResponseDetailWorkspaceState extends State<_ResponseDetailWorkspace> {
  late String _activeSectionId;

  @override
  void initState() {
    super.initState();
    final sections = _sections;
    _activeSectionId = sections.isEmpty ? '' : sections.first.id;
  }

  List<_DetailSection> get _sections {
    if (widget.isChedBuiltin) {
      return [
        for (final s in ChedGtsSection.values)
          _DetailSection(
            id: s.name,
            title: _chedSectionTitle(s),
            shortLabel: s.name.toUpperCase(),
          ),
      ];
    }
    final ordered = List<SurveyQuestion>.from(widget.questions)
      ..sort((a, b) => a.order.compareTo(b.order));
    final map = <String, _DetailSection>{};
    for (final q in ordered) {
      final key = (q.section == null || q.section!.trim().isEmpty)
          ? '__general__'
          : q.section!.trim();
      map.putIfAbsent(
        key,
        () => _DetailSection(
          id: key,
          title: key == '__general__'
              ? 'General information'
              : (q.sectionLabel.isEmpty ? key : q.sectionLabel),
          shortLabel: key == '__general__'
              ? 'General'
              : _shortSectionLabel(q.sectionLabel.isEmpty ? key : q.sectionLabel),
        ),
      );
    }
    if (map.isEmpty) {
      // Answers without matching question rows (e.g. orphan keys).
      return [
        const _DetailSection(
          id: '__answers__',
          title: 'Responses',
          shortLabel: 'All',
        ),
      ];
    }
    return map.values.toList();
  }

  static String _chedSectionTitle(ChedGtsSection s) {
    final item = ChedGtsBuiltin.items.firstWhere((i) => i.section == s);
    return item.sectionTitle;
  }

  static String _shortSectionLabel(String title) {
    final t = title.trim();
    if (t.length <= 18) return t;
    final letter = RegExp(r'^([A-D])\.').firstMatch(t);
    if (letter != null) return letter.group(1)!;
    return '${t.substring(0, 16)}…';
  }

  bool _isAnswerEmpty(dynamic value) => isSurveyAnswerEmpty(value);

  List<String> _unansweredLabelsForActive() {
    final answers = widget.response.answers;
    if (widget.isChedBuiltin) {
      final section = ChedGtsSection.values.firstWhere(
        (s) => s.name == _activeSectionId,
        orElse: () => ChedGtsSection.a,
      );
      final visible = ChedGtsVisibility.visibleItemIds(answers);
      final missing = <String>[];
      for (final item in ChedGtsBuiltin.items) {
        if (item.section != section) continue;
        if (!visible.contains(item.id)) continue;
        if (item.isOthersSpecify) continue;
        if (_isAnswerEmpty(answers[item.id])) {
          missing.add(item.prompt);
        }
      }
      return missing;
    }

    final qs = widget.questions.where((q) {
      if (_activeSectionId == '__general__') {
        return q.section == null || q.section!.trim().isEmpty;
      }
      return (q.section ?? '').trim() == _activeSectionId;
    }).toList()
      ..sort((a, b) => a.order.compareTo(b.order));

    return [
      for (final q in qs)
        if (_isAnswerEmpty(answers[q.id])) q.prompt,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final sections = _sections;
    if (sections.isNotEmpty &&
        !sections.any((s) => s.id == _activeSectionId)) {
      _activeSectionId = sections.first.id;
    }
    final unanswered = _unansweredLabelsForActive();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 8, 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.alumniName.trim().isEmpty
                          ? 'Alumni response'
                          : widget.alumniName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AdminSurveyTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Response details',
                      style: TextStyle(
                        fontSize: 12,
                        color: AdminSurveyTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.onViewTimeline != null)
                IconButton(
                  tooltip: 'View timeline',
                  onPressed: widget.onViewTimeline,
                  icon: const Icon(
                    Icons.timeline_outlined,
                    color: AdminSurveyTheme.textSecondary,
                  ),
                ),
              IconButton(
                tooltip: 'Close',
                onPressed: widget.onClose,
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ),
        Material(
          color: AdminSurveyTheme.card,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: AdminSurveyTheme.border),
                top: BorderSide(color: AdminSurveyTheme.border),
              ),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (var i = 0; i < sections.length; i++) ...[
                    if (i > 0) const SizedBox(width: 6),
                    _SectionNavChip(
                      label: sections[i].shortLabel,
                      selected: sections[i].id == _activeSectionId,
                      onTap: () => setState(
                        () => _activeSectionId = sections[i].id,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            children: [
              Text(
                sections
                    .firstWhere(
                      (s) => s.id == _activeSectionId,
                      orElse: () => sections.first,
                    )
                    .title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AdminSurveyTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              if (unanswered.isNotEmpty) ...[
                SurveyCallout(
                  tone: SurveyCalloutTone.warning,
                  icon: Icons.warning_amber_outlined,
                  title:
                      '${unanswered.length} unanswered in this section',
                  body: unanswered.take(6).join('\n'),
                ),
                const SizedBox(height: 12),
              ] else
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text(
                    'All visible items in this section have answers.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AdminSurveyTheme.success,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              if (widget.isChedBuiltin)
                _buildChedSectionBody()
              else
                _buildClassicSectionBody(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChedSectionBody() {
    final section = ChedGtsSection.values.firstWhere(
      (s) => s.name == _activeSectionId,
      orElse: () => ChedGtsSection.a,
    );
    final answers = widget.response.answers;
    final visible = ChedGtsVisibility.visibleItemIds(answers);
    final items = ChedGtsBuiltin.items
        .where((i) => i.section == section && visible.contains(i.id))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final item in items) ...[
          _AnswerBlock(
            prompt: item.prompt,
            value: _formatValue(answers[item.id]),
            unanswered: _isAnswerEmpty(answers[item.id]),
            requiredField: item.required,
          ),
          const SizedBox(height: 10),
        ],
        // Full official form for this section (read-only) for fidelity.
        const SizedBox(height: 8),
        const Text(
          'Official form view',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AdminSurveyTheme.textMuted,
          ),
        ),
        const SizedBox(height: 8),
        ChedGtsForm(
          answers: answers,
          onChanged: (_) {},
          readOnly: true,
          showIntro: false,
          showSectionHeaders: false,
          sectionFilter: section,
        ),
      ],
    );
  }

  Widget _buildClassicSectionBody() {
    final answers = widget.response.answers;
    if (_activeSectionId == '__answers__') {
      return Column(
        children: [
          for (final e in answers.entries) ...[
            _AnswerBlock(
              prompt: e.key,
              value: _formatValue(e.value),
              unanswered: _isAnswerEmpty(e.value),
            ),
            const SizedBox(height: 10),
          ],
        ],
      );
    }

    final qs = widget.questions.where((q) {
      if (_activeSectionId == '__general__') {
        return q.section == null || q.section!.trim().isEmpty;
      }
      return (q.section ?? '').trim() == _activeSectionId;
    }).toList()
      ..sort((a, b) => a.order.compareTo(b.order));

    if (qs.isEmpty) {
      return const Text(
        'No questions in this section.',
        style: TextStyle(color: AdminSurveyTheme.textMuted),
      );
    }

    return Column(
      children: [
        for (final q in qs) ...[
          _AnswerBlock(
            prompt: q.prompt,
            value: _formatValue(answers[q.id]),
            unanswered: _isAnswerEmpty(answers[q.id]),
            requiredField: q.required,
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  String _formatValue(dynamic value) {
    final text = formatSurveyAnswerValue(value);
    return text.isEmpty ? 'No answer' : text;
  }
}

class _DetailSection {
  const _DetailSection({
    required this.id,
    required this.title,
    required this.shortLabel,
  });

  final String id;
  final String title;
  final String shortLabel;
}

class _SectionNavChip extends StatelessWidget {
  const _SectionNavChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '$label section',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          hoverColor: AdminSurveyTheme.infoBg.withValues(alpha: 0.7),
          focusColor: AdminSurveyTheme.infoBg,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color:
                  selected ? AdminSurveyTheme.infoBg : AdminSurveyTheme.surface,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: selected
                    ? AdminSurveyTheme.primary.withValues(alpha: 0.35)
                    : AdminSurveyTheme.border,
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected
                    ? AdminSurveyTheme.primary
                    : AdminSurveyTheme.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AnswerBlock extends StatelessWidget {
  const _AnswerBlock({
    required this.prompt,
    required this.value,
    required this.unanswered,
    this.requiredField = false,
  });

  final String prompt;
  final String value;
  final bool unanswered;
  final bool requiredField;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: unanswered
            ? AdminSurveyTheme.warningBg.withValues(alpha: 0.55)
            : AdminSurveyTheme.card,
        borderRadius: BorderRadius.circular(AdminSurveyTheme.radiusMd),
        border: Border.all(
          color: unanswered
              ? AdminSurveyTheme.warning.withValues(alpha: 0.35)
              : AdminSurveyTheme.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  prompt,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AdminSurveyTheme.textPrimary,
                    height: 1.35,
                  ),
                ),
              ),
              if (requiredField)
                const Padding(
                  padding: EdgeInsets.only(left: 6),
                  child: Text(
                    'Required',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AdminSurveyTheme.textMuted,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              fontStyle: unanswered ? FontStyle.italic : FontStyle.normal,
              color: unanswered
                  ? AdminSurveyTheme.warning
                  : AdminSurveyTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
