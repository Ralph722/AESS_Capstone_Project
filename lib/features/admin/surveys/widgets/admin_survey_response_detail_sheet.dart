import 'package:flutter/material.dart';
import 'package:alumni_system/features/admin/surveys/widgets/admin_survey_ui.dart';
import 'package:alumni_system/features/surveys/ched_gts/ched_gts_form.dart';
import 'package:alumni_system/features/surveys/ched_gts/ched_gts_schema.dart';
import 'package:alumni_system/features/surveys/ched_gts/ched_gts_visibility.dart';
import 'package:alumni_system/features/surveys/data/classic_survey_visibility.dart';
import 'package:alumni_system/features/surveys/data/survey_answer_display.dart';
import 'package:alumni_system/features/surveys/models/survey_model.dart';
import 'package:alumni_system/shared/widgets/admin/admin_surface.dart';
import 'package:alumni_system/shared/widgets/admin/admin_theme.dart';

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
  String? subtitle,
  Map<String, SurveyVisibilityRule> visibilityRules = const {},
  VoidCallback? onViewTimeline,
}) {
  Widget workspace(BuildContext ctx) => _ResponseDetailWorkspace(
        alumniName: alumniName,
        subtitle: subtitle,
        response: response,
        isChedBuiltin: isChedBuiltin,
        questions: questions,
        visibilityRules: visibilityRules,
        onClose: () => Navigator.pop(ctx),
        onViewTimeline: onViewTimeline,
      );

  if (adminIsWideSurface(context)) {
    return showAdminSidePanel<void>(
      context: context,
      width: 580,
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
    required this.subtitle,
    required this.response,
    required this.isChedBuiltin,
    required this.questions,
    required this.visibilityRules,
    required this.onClose,
    this.onViewTimeline,
  });

  final String alumniName;
  final String? subtitle;
  final SurveyResponse response;
  final bool isChedBuiltin;
  final List<SurveyQuestion> questions;
  final Map<String, SurveyVisibilityRule> visibilityRules;
  final VoidCallback onClose;
  final VoidCallback? onViewTimeline;

  @override
  State<_ResponseDetailWorkspace> createState() =>
      _ResponseDetailWorkspaceState();
}

class _ResponseDetailWorkspaceState extends State<_ResponseDetailWorkspace> {
  late String _activeSectionId;
  bool _showOfficialForm = false;

  /// Questions this alumnus actually saw (show-when rules applied).
  List<SurveyQuestion> get _visibleQuestions =>
      ClassicSurveyVisibility.visibleQuestions(
        questions: widget.questions,
        answers: widget.response.answers,
        rules: widget.visibilityRules,
      );

  List<SurveyQuestion> _questionsInActiveSection(List<SurveyQuestion> source) {
    return source.where((q) {
      if (_activeSectionId == '__general__') {
        return q.section == null || q.section!.trim().isEmpty;
      }
      return (q.section ?? '').trim() == _activeSectionId;
    }).toList()
      ..sort((a, b) => a.order.compareTo(b.order));
  }

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
            shortLabel: _chedSectionShort(s),
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
              : _displaySectionTitle(
                  q.sectionLabel.isEmpty ? key : q.sectionLabel,
                ),
          shortLabel: key == '__general__'
              ? 'General'
              : _shortSectionLabel(
                  q.sectionLabel.isEmpty ? key : q.sectionLabel,
                ),
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

  static String _chedSectionTitle(ChedGtsSection s) => switch (s) {
        ChedGtsSection.a => 'General Information',
        ChedGtsSection.b => 'Educational Background',
        ChedGtsSection.c => 'Training / Advance Studies',
        ChedGtsSection.d => 'Employment Data',
      };

  static String _chedSectionShort(ChedGtsSection s) => switch (s) {
        ChedGtsSection.a => 'General',
        ChedGtsSection.b => 'Education',
        ChedGtsSection.c => 'Training',
        ChedGtsSection.d => 'Employment',
      };

  /// Strip CHED-style "A. " prefixes and soften ALL-CAPS titles.
  static String _displaySectionTitle(String title) {
    var t = title.trim().replaceFirst(RegExp(r'^[A-D]\.\s*'), '').trim();
    if (t.isEmpty) return title.trim();
    if (t == t.toUpperCase() && RegExp(r'[A-Z]').hasMatch(t)) {
      t = t
          .toLowerCase()
          .split(RegExp(r'\s+'))
          .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
          .join(' ');
    }
    return t;
  }

  static String _shortSectionLabel(String title) {
    final t = _displaySectionTitle(title);
    if (t.length <= 16) return t;
    final words = t.split(RegExp(r'\s+'));
    if (words.isNotEmpty && words.first.length <= 16) return words.first;
    return '${t.substring(0, 14)}…';
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

    return [
      for (final q in _questionsInActiveSection(_visibleQuestions))
        if (_isAnswerEmpty(answers[q.id])) q.prompt,
    ];
  }

  int _answeredCountForActive() {
    if (widget.isChedBuiltin) {
      final section = ChedGtsSection.values.firstWhere(
        (s) => s.name == _activeSectionId,
        orElse: () => ChedGtsSection.a,
      );
      final answers = widget.response.answers;
      final visible = ChedGtsVisibility.visibleItemIds(answers);
      var answered = 0;
      for (final item in ChedGtsBuiltin.items) {
        if (item.section != section) continue;
        if (!visible.contains(item.id)) continue;
        if (item.isOthersSpecify) continue;
        if (!_isAnswerEmpty(answers[item.id])) answered++;
      }
      return answered;
    }
    final qs = _questionsInActiveSection(_visibleQuestions);
    final answers = widget.response.answers;
    return qs.where((q) => !_isAnswerEmpty(answers[q.id])).length;
  }

  int _visibleCountForActive() {
    if (widget.isChedBuiltin) {
      final section = ChedGtsSection.values.firstWhere(
        (s) => s.name == _activeSectionId,
        orElse: () => ChedGtsSection.a,
      );
      final answers = widget.response.answers;
      final visible = ChedGtsVisibility.visibleItemIds(answers);
      return ChedGtsBuiltin.items
          .where(
            (i) =>
                i.section == section &&
                visible.contains(i.id) &&
                !i.isOthersSpecify,
          )
          .length;
    }
    if (_activeSectionId == '__answers__') {
      return widget.response.answers.length;
    }
    return _questionsInActiveSection(_visibleQuestions).length;
  }

  @override
  Widget build(BuildContext context) {
    final sections = _sections;
    if (sections.isNotEmpty &&
        !sections.any((s) => s.id == _activeSectionId)) {
      _activeSectionId = sections.first.id;
    }
    final unanswered = _unansweredLabelsForActive();
    final activeTitle = sections
        .firstWhere(
          (s) => s.id == _activeSectionId,
          orElse: () => sections.isEmpty
              ? const _DetailSection(
                  id: '',
                  title: 'Responses',
                  shortLabel: 'All',
                )
              : sections.first,
        )
        .title;
    final visibleCount = _visibleCountForActive();
    final answeredCount = _answeredCountForActive();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DetailHeader(
          alumniName: widget.alumniName,
          subtitle: widget.subtitle,
          isChed: widget.isChedBuiltin,
          onClose: widget.onClose,
          onViewTimeline: widget.onViewTimeline,
        ),
        Material(
          color: AdminSurveyTheme.card,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: AdminSurveyTheme.border),
              ),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (var i = 0; i < sections.length; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
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
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      activeTitle,
                      style: AdminText.sectionTitle.copyWith(fontSize: 15),
                    ),
                  ),
                  if (visibleCount > 0)
                    _SectionStatusChip(
                      answered: answeredCount,
                      total: visibleCount,
                      complete: unanswered.isEmpty,
                    ),
                ],
              ),
              if (unanswered.isNotEmpty) ...[
                const SizedBox(height: 10),
                _UnansweredStrip(
                  key: ValueKey('unanswered-$_activeSectionId'),
                  prompts: unanswered,
                ),
              ],
              const SizedBox(height: 12),
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
        _AnswerGroup(
          children: [
            for (final item in items)
              _AnswerRow(
                prompt: item.prompt,
                value: _formatValue(answers[item.id]),
                unanswered: _isAnswerEmpty(answers[item.id]),
                requiredField: item.required,
              ),
          ],
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () =>
                setState(() => _showOfficialForm = !_showOfficialForm),
            icon: Icon(
              _showOfficialForm
                  ? Icons.expand_less
                  : Icons.description_outlined,
              size: 18,
            ),
            label: Text(
              _showOfficialForm ? 'Hide official form' : 'Show official form',
            ),
            style: TextButton.styleFrom(
              foregroundColor: AdminSurveyTheme.textSecondary,
              visualDensity: VisualDensity.compact,
            ),
          ),
        ),
        if (_showOfficialForm) ...[
          const SizedBox(height: 4),
          ChedGtsForm(
            answers: answers,
            onChanged: (_) {},
            readOnly: true,
            showIntro: false,
            showSectionHeaders: false,
            sectionFilter: section,
          ),
        ],
      ],
    );
  }

  Widget _buildClassicSectionBody() {
    final answers = widget.response.answers;
    if (_activeSectionId == '__answers__') {
      return _AnswerGroup(
        children: [
          for (final e in answers.entries)
            _AnswerRow(
              prompt: e.key,
              value: _formatValue(e.value),
              unanswered: _isAnswerEmpty(e.value),
            ),
        ],
      );
    }

    final qs = _questionsInActiveSection(_visibleQuestions);

    if (qs.isEmpty) {
      final hadQuestions =
          _questionsInActiveSection(widget.questions).isNotEmpty;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Text(
          hadQuestions
              ? 'No questions in this section were shown to this alumnus.'
              : 'No questions in this section.',
          style: AdminText.caption,
          textAlign: TextAlign.center,
        ),
      );
    }

    return _AnswerGroup(
      children: [
        for (final q in qs)
          _AnswerRow(
            prompt: q.prompt,
            value: _formatValue(answers[q.id]),
            unanswered: _isAnswerEmpty(answers[q.id]),
            requiredField: q.required,
          ),
      ],
    );
  }

  String _formatValue(dynamic value) {
    final text = formatSurveyAnswerValue(value);
    return text.isEmpty ? 'No answer' : text;
  }
}

class _DetailHeader extends StatelessWidget {
  const _DetailHeader({
    required this.alumniName,
    required this.subtitle,
    required this.isChed,
    required this.onClose,
    this.onViewTimeline,
  });

  final String alumniName;
  final String? subtitle;
  final bool isChed;
  final VoidCallback onClose;
  final VoidCallback? onViewTimeline;

  @override
  Widget build(BuildContext context) {
    final name =
        alumniName.trim().isEmpty ? 'Alumni response' : alumniName.trim();
    final sub = (subtitle?.trim().isNotEmpty ?? false)
        ? subtitle!.trim()
        : 'Response details';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 8, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AdminText.sectionTitle.copyWith(fontSize: 17),
                ),
                const SizedBox(height: 4),
                Text(
                  sub,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AdminText.caption.copyWith(height: 1.35),
                ),
                if (isChed) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7ED),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFFDBA74)),
                    ),
                    child: const Text(
                      'Official CHED GTS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFC2410C),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (onViewTimeline != null)
            IconButton(
              tooltip: 'View timeline',
              onPressed: onViewTimeline,
              icon: const Icon(
                Icons.timeline_outlined,
                color: AdminSurveyTheme.textSecondary,
              ),
            ),
          IconButton(
            tooltip: 'Close',
            onPressed: onClose,
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }
}

class _SectionStatusChip extends StatelessWidget {
  const _SectionStatusChip({
    required this.answered,
    required this.total,
    required this.complete,
  });

  final int answered;
  final int total;
  final bool complete;

  @override
  Widget build(BuildContext context) {
    final color =
        complete ? AdminColors.success : AdminSurveyTheme.textSecondary;
    final bg = complete
        ? AdminColors.success.withValues(alpha: 0.1)
        : AdminSurveyTheme.surface;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: complete
              ? AdminColors.success.withValues(alpha: 0.25)
              : AdminSurveyTheme.border,
        ),
      ),
      child: Text(
        complete ? 'Complete · $total' : '$answered of $total answered',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

/// Compact warning strip; [SurveyCallout] is left to the Editor.
class _UnansweredStrip extends StatefulWidget {
  const _UnansweredStrip({super.key, required this.prompts});

  final List<String> prompts;

  @override
  State<_UnansweredStrip> createState() => _UnansweredStripState();
}

class _UnansweredStripState extends State<_UnansweredStrip> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final count = widget.prompts.length;
    return Container(
      decoration: BoxDecoration(
        color: AdminColors.warningBg,
        borderRadius: BorderRadius.circular(AdminSurfaces.radiusSm),
        border: Border.all(
          color: AdminColors.warning.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(AdminSurfaces.radiusSm),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber_outlined,
                    size: 16,
                    color: AdminColors.warning,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '$count unanswered in this section',
                      style: AdminText.body.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AdminColors.warning,
                      ),
                    ),
                  ),
                  Text(
                    _expanded ? 'Hide' : 'Show',
                    style: AdminText.caption.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AdminColors.warning,
                    ),
                  ),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    size: 18,
                    color: AdminColors.warning,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(34, 0, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final prompt in widget.prompts)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '• $prompt',
                        style: AdminText.caption.copyWith(
                          color: AdminColors.textPrimary,
                          height: 1.35,
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
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
          borderRadius: BorderRadius.circular(AdminSurfaces.radiusSm),
          hoverColor: AdminSurveyTheme.infoBg.withValues(alpha: 0.7),
          focusColor: AdminSurveyTheme.infoBg,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: selected
                  ? AdminSurveyTheme.infoBg
                  : AdminSurveyTheme.surface,
              borderRadius: BorderRadius.circular(AdminSurfaces.radiusSm),
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

class _AnswerGroup extends StatelessWidget {
  const _AnswerGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) {
      return const SizedBox.shrink();
    }
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AdminSurveyTheme.card,
        borderRadius: BorderRadius.circular(AdminSurveyTheme.radiusMd),
        border: Border.all(color: AdminSurveyTheme.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0)
              const Divider(
                height: 1,
                thickness: 1,
                color: AdminSurveyTheme.border,
              ),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _AnswerRow extends StatelessWidget {
  const _AnswerRow({
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
    return ColoredBox(
      color: unanswered
          ? AdminSurveyTheme.warningBg.withValues(alpha: 0.45)
          : AdminSurveyTheme.card,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
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
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AdminSurveyTheme.textMuted,
                      height: 1.3,
                    ),
                  ),
                ),
                if (unanswered && requiredField)
                  const Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: Text(
                      'Required',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AdminSurveyTheme.warning,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                fontWeight: unanswered ? FontWeight.w500 : FontWeight.w600,
                fontStyle: unanswered ? FontStyle.italic : FontStyle.normal,
                color: unanswered
                    ? AdminSurveyTheme.warning
                    : AdminSurveyTheme.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
