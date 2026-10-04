import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:alumni_system/features/surveys/ched_gts/ched_gts_help_service.dart';
import 'package:alumni_system/features/surveys/ched_gts/ched_gts_help_sheet.dart';
import 'package:alumni_system/features/surveys/ched_gts/ched_gts_schema.dart';
import 'package:alumni_system/features/surveys/ched_gts/ched_gts_visibility.dart';
import 'package:alumni_system/shared/widgets/user/portal_theme.dart';

typedef ChedGtsAnswersChanged = void Function(Map<String, dynamic> answers);

InputDecoration _portalFieldDecoration({
  required String label,
  String? hint,
  IconData? icon,
  bool readOnly = false,
}) {
  final radius = BorderRadius.circular(PortalTheme.radiusMd);
  return InputDecoration(
    labelText: label,
    hintText: hint,
    prefixIcon: icon != null
        ? Icon(icon, color: PortalTheme.navy, size: 20)
        : null,
    filled: true,
    fillColor: readOnly ? PortalTheme.surfaceMuted : PortalTheme.card,
    labelStyle: PortalTheme.meta.copyWith(color: PortalTheme.textSecondary),
    hintStyle: PortalTheme.meta.copyWith(color: PortalTheme.textMuted),
    border: OutlineInputBorder(
      borderRadius: radius,
      borderSide: const BorderSide(color: PortalTheme.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: radius,
      borderSide: const BorderSide(color: PortalTheme.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: radius,
      borderSide: const BorderSide(color: PortalTheme.navy, width: 1.6),
    ),
  );
}

/// Digitized official CHED GTS form with paper-accurate skip logic.
class ChedGtsForm extends StatefulWidget {
  const ChedGtsForm({
    super.key,
    required this.answers,
    required this.onChanged,
    this.readOnly = false,
    this.showIntro = true,
    this.sectionFilter,
    this.showSectionHeaders = true,
    this.onlyItemIds,
    this.highlightMissing = false,
    this.helpSurveyId,
  });

  final Map<String, dynamic> answers;
  final ChedGtsAnswersChanged onChanged;
  final bool readOnly;
  final bool showIntro;

  /// When set, only items in this section are rendered.
  final ChedGtsSection? sectionFilter;
  final bool showSectionHeaders;

  /// When set, only these (visible) items are rendered.
  final Set<String>? onlyItemIds;

  /// Outlines required items that are still unanswered.
  final bool highlightMissing;

  /// When set (and not [readOnly]), Q19/Q20 show "Help me answer" backed by
  /// the `tracer-help` Edge Function for this survey.
  final String? helpSurveyId;

  @override
  State<ChedGtsForm> createState() => _ChedGtsFormState();
}

class _ChedGtsFormState extends State<ChedGtsForm> {
  late Map<String, dynamic> _answers;
  final Map<String, TextEditingController> _textControllers = {};

  @override
  void initState() {
    super.initState();
    _answers = Map<String, dynamic>.from(widget.answers);
    _syncTextControllers();
  }

  @override
  void didUpdateWidget(covariant ChedGtsForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.answers, widget.answers)) {
      _answers = Map<String, dynamic>.from(widget.answers);
      _syncTextControllers();
    }
  }

  @override
  void dispose() {
    for (final c in _textControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _syncTextControllers() {
    for (final item in ChedGtsBuiltin.items) {
      if (item.type != ChedGtsFieldType.text &&
          item.type != ChedGtsFieldType.longText) {
        continue;
      }
      final text = _answers[item.id]?.toString() ?? '';
      final existing = _textControllers[item.id];
      if (existing == null) {
        _textControllers[item.id] = TextEditingController(text: text);
      } else if (existing.text != text) {
        existing.text = text;
      }
    }
  }

  Set<String> get _visible => ChedGtsVisibility.visibleItemIds(_answers);

  void _set(String id, dynamic value) => _setMany({id: value});

  void _setMany(Map<String, dynamic> updates) {
    if (widget.readOnly || updates.isEmpty) return;
    setState(() {
      _answers.addAll(updates);
      _answers = ChedGtsVisibility.pruneHiddenAnswers(_answers);
      _syncTextControllers();
    });
    widget.onChanged(Map<String, dynamic>.from(_answers));
  }

  /// Answer keys filled from a helper suggestion, and the latest suggestion,
  /// per survey for this app session. Static because the wizard rebuilds this
  /// form per section.
  static final Map<String, Set<String>> _helpAppliedKeys = {};
  static final Map<String, ChedGtsHelpSuggestion> _helpSuggestions = {};

  bool get _helpAvailable => widget.helpSurveyId != null && !widget.readOnly;

  Set<String> get _applied =>
      _helpAppliedKeys[widget.helpSurveyId] ?? const <String>{};

  /// The button lives on Q19 only; it reads "Ask again" after use.
  VoidCallback? _helpFor(ChedGtsItem item) {
    final surveyId = widget.helpSurveyId;
    if (!_helpAvailable || item.id != 'ched_19') return null;
    return () => showChedGtsHelpSheet(
      context,
      surveyId: surveyId!,
      onApply: (updates, source) {
        _helpAppliedKeys.putIfAbsent(surveyId, () => {}).addAll(updates.keys);
        _helpSuggestions[surveyId] = source;
        if (mounted) _setMany(updates);
      },
    );
  }

  /// Q20 recommendation after only the Q19 suggestion was used. Hidden once
  /// Q19 no longer matches the suggested title, or Q20 already has that answer.
  ChedGtsHelpSuggestion? _q20Recommendation() {
    if (!_helpAvailable) return null;
    final s = _helpSuggestions[widget.helpSurveyId];
    if (s == null || s.unclear || s.lineOfBusiness == null) return null;
    if (_applied.contains('ched_20')) return null;
    final q19 = _answers['ched_19']?.toString().trim() ?? '';
    if (q19 != s.occupation.trim()) return null;
    if (_answers['ched_20'] == s.lineOfBusiness) return null;
    return s;
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visible;
    final missing = widget.highlightMissing
        ? ChedGtsVisibility.missingRequired(_answers).toSet()
        : const <String>{};
    ChedGtsSection? lastSection;

    final children = <Widget>[];
    if (widget.showIntro) {
      children.add(_IntroBanner());
      children.add(const SizedBox(height: 16));
    }

    final q20Recommendation = _q20Recommendation();

    for (final item in ChedGtsBuiltin.items) {
      if (!visible.contains(item.id)) continue;
      if (widget.sectionFilter != null &&
          item.section != widget.sectionFilter) {
        continue;
      }
      final only = widget.onlyItemIds;
      if (only != null && !only.contains(item.id)) continue;
      if (widget.showSectionHeaders && item.section != lastSection) {
        lastSection = item.section;
        children.add(_SectionHeader(title: item.sectionTitle));
        children.add(const SizedBox(height: 12));
      }
      children.add(
        _ItemCard(
          item: item,
          value: _answers[item.id],
          textController: _textControllers[item.id],
          readOnly: widget.readOnly,
          missing: missing.contains(item.id),
          onChanged: (v) => _set(item.id, v),
          onHelp: _helpFor(item),
          helpUsed: _applied.isNotEmpty,
          recommendation: item.id == 'ched_20' && q20Recommendation != null
              ? _Q20Recommendation(
                  suggestion: q20Recommendation,
                  onUse: () {
                    _helpAppliedKeys
                        .putIfAbsent(widget.helpSurveyId!, () => {})
                        .add('ched_20');
                    _setMany(chedGtsLineOfBusinessUpdates(q20Recommendation));
                  },
                )
              : null,
          helpPointer:
              item.id == 'ched_20' &&
              _helpAvailable &&
              q20Recommendation == null &&
              !_applied.contains('ched_20'),
        ),
      );
      children.add(const SizedBox(height: 12));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }
}

class _IntroBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PortalTheme.navy.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(PortalTheme.radiusXl),
        border: Border.all(color: PortalTheme.border.withValues(alpha: 0.8)),
      ),
      child: Text(
        'Complete this GTS questionnaire as accurately as you can. '
        'Answers are confidential and used to assess graduate outcomes. '
        'Optional items may be skipped (for example, leave professional exams blank if none).',
        style: PortalTheme.bodySecondary.copyWith(fontSize: 13, height: 1.4),
      ),
    );
  }
}

class _RequiredBadge extends StatelessWidget {
  const _RequiredBadge({required this.required});

  final bool required;

  @override
  Widget build(BuildContext context) {
    final bg = required ? const Color(0xFFFEF3C7) : const Color(0xFFECFDF5);
    final fg = required ? const Color(0xFF92400E) : const Color(0xFF047857);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        required ? 'Required' : 'Optional',
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: PortalTheme.navy.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(PortalTheme.radiusXl),
        border: Border.all(color: PortalTheme.border.withValues(alpha: 0.8)),
      ),
      child: Text(title, style: PortalTheme.cardTitle.copyWith(fontSize: 13)),
    );
  }
}

/// Guidance note under the question; long notes collapse to two lines.
class _HelpNote extends StatefulWidget {
  const _HelpNote({required this.text});

  final String text;

  @override
  State<_HelpNote> createState() => _HelpNoteState();
}

class _HelpNoteState extends State<_HelpNote> {
  static const _collapsedLines = 2;
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final style = PortalTheme.meta.copyWith(
      height: 1.4,
      color: PortalTheme.textSecondary,
    );
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: PortalTheme.navy.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(PortalTheme.radiusLg),
        border: Border.all(color: PortalTheme.navy.withValues(alpha: 0.08)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(
              Icons.lightbulb_outline_rounded,
              size: 16,
              color: Color(0xFFD99A00),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final painter = TextPainter(
                  text: TextSpan(text: widget.text, style: style),
                  maxLines: _collapsedLines,
                  textDirection: Directionality.of(context),
                  textScaler: MediaQuery.textScalerOf(context),
                )..layout(maxWidth: constraints.maxWidth);
                final overflows = painter.didExceedMaxLines;
                painter.dispose();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedSize(
                      duration: PortalTheme.fast,
                      alignment: Alignment.topCenter,
                      child: Text(
                        widget.text,
                        style: style,
                        maxLines: _expanded || !overflows
                            ? null
                            : _collapsedLines,
                        overflow: _expanded || !overflows
                            ? TextOverflow.visible
                            : TextOverflow.ellipsis,
                      ),
                    ),
                    if (overflows)
                      InkWell(
                        onTap: () => setState(() => _expanded = !_expanded),
                        borderRadius: BorderRadius.circular(6),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Text(
                            _expanded ? 'Less' : 'More',
                            style: style.copyWith(
                              color: PortalTheme.navy,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// "Based on your job…" Q20 recommendation from the Q19 AI suggestion.
class _Q20Recommendation extends StatelessWidget {
  const _Q20Recommendation({required this.suggestion, required this.onUse});

  final ChedGtsHelpSuggestion suggestion;
  final VoidCallback onUse;

  @override
  Widget build(BuildContext context) {
    final line = suggestion.lineOfBusiness!;
    final value =
        line == ChedGtsBuiltin.othersSpecify &&
            suggestion.specifyText.isNotEmpty
        ? 'Others: ${suggestion.specifyText}'
        : line;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      decoration: BoxDecoration(
        color: PortalTheme.gold.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(PortalTheme.radiusLg),
        border: Border.all(color: PortalTheme.gold.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 1),
                child: Icon(
                  Icons.auto_awesome_rounded,
                  size: 16,
                  color: PortalTheme.navy,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Based on your job, your line of business may be:',
                      style: PortalTheme.meta.copyWith(
                        color: PortalTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      value,
                      style: PortalTheme.cardTitle.copyWith(
                        fontSize: 14,
                        height: 1.3,
                      ),
                    ),
                    if (suggestion.reason.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        suggestion.reason,
                        style: PortalTheme.meta.copyWith(height: 1.35),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      'This is only a suggestion and might be wrong. Choose '
                      'the option that matches what your company does.',
                      style: PortalTheme.meta.copyWith(
                        height: 1.35,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onUse,
              style: TextButton.styleFrom(
                foregroundColor: PortalTheme.navy,
                minimumSize: const Size(0, 36),
                textStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: const Text('Use this'),
            ),
          ),
        ],
      ),
    );
  }
}

class _HelpMeAnswerPill extends StatelessWidget {
  const _HelpMeAnswerPill({required this.onPressed, required this.label});

  final VoidCallback onPressed;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: StadiumBorder(
        side: BorderSide(color: PortalTheme.navy.withValues(alpha: 0.18)),
      ),
      child: InkWell(
        onTap: onPressed,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.auto_awesome_rounded,
                size: 15,
                color: PortalTheme.navy,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: PortalTheme.navy,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({
    required this.item,
    required this.value,
    required this.onChanged,
    required this.readOnly,
    this.textController,
    this.missing = false,
    this.onHelp,
    this.helpUsed = false,
    this.recommendation,
    this.helpPointer = false,
  });

  final ChedGtsItem item;
  final dynamic value;
  final ValueChanged<dynamic> onChanged;
  final bool readOnly;
  final TextEditingController? textController;
  final bool missing;
  final VoidCallback? onHelp;
  final bool helpUsed;

  /// Replaces the written note (Q20 after a Q19 AI suggestion).
  final Widget? recommendation;

  /// Adds "Not sure? Tap Help me answer on question 19." under the note.
  final bool helpPointer;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: PortalTheme.fast,
      decoration: BoxDecoration(
        color: PortalTheme.card,
        borderRadius: BorderRadius.circular(PortalTheme.radius2xl),
        border: Border.all(
          color: missing
              ? PortalTheme.danger.withValues(alpha: 0.6)
              : PortalTheme.border.withValues(alpha: 0.75),
          width: missing ? 1.5 : 1,
        ),
        boxShadow: PortalTheme.softShadow,
      ),
      padding: const EdgeInsets.all(PortalTheme.space3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  '${item.chedNumber}. ${item.prompt}',
                  style: PortalTheme.cardTitle.copyWith(
                    fontSize: 14,
                    height: 1.35,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _RequiredBadge(required: item.required),
            ],
          ),
          if (missing) ...[
            const SizedBox(height: 6),
            const Row(
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  size: 15,
                  color: PortalTheme.danger,
                ),
                SizedBox(width: 6),
                Text(
                  'This question needs an answer',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: PortalTheme.danger,
                  ),
                ),
              ],
            ),
          ],
          if (recommendation != null) ...[
            const SizedBox(height: 10),
            recommendation!,
          ] else if (item.helpText != null) ...[
            const SizedBox(height: 8),
            _HelpNote(text: item.helpText!),
          ],
          if (helpPointer) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(
                  Icons.auto_awesome_rounded,
                  size: 14,
                  color: PortalTheme.navy,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        const TextSpan(text: 'Not sure? Tap '),
                        TextSpan(
                          text: 'Help me answer',
                          style: PortalTheme.meta.copyWith(
                            color: PortalTheme.navy,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const TextSpan(text: ' on question 19.'),
                      ],
                    ),
                    style: PortalTheme.meta.copyWith(height: 1.35),
                  ),
                ),
              ],
            ),
          ],
          if (!item.required && !item.isOthersSpecify) ...[
            const SizedBox(height: 6),
            Text(
              'Optional — you may skip this item or write None / N/A if it does not apply.',
              style: PortalTheme.meta.copyWith(
                height: 1.35,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          if (onHelp != null) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: _HelpMeAnswerPill(
                onPressed: onHelp!,
                label: helpUsed ? 'Ask again' : 'Help me answer',
              ),
            ),
          ],
          const SizedBox(height: 14),
          _buildField(),
        ],
      ),
    );
  }

  Widget _buildField() {
    switch (item.type) {
      case ChedGtsFieldType.text:
      case ChedGtsFieldType.longText:
        return TextField(
          controller: textController,
          readOnly: readOnly,
          maxLines: item.type == ChedGtsFieldType.longText ? 4 : 1,
          onChanged: onChanged,
          decoration: _portalFieldDecoration(
            label: item.required ? 'Your answer *' : 'Optional — skip if N/A',
            hint: item.required ? null : 'None / N/A or leave blank',
            readOnly: readOnly,
          ),
        );
      case ChedGtsFieldType.date:
        return _DateField(
          value: value?.toString(),
          readOnly: readOnly,
          onChanged: onChanged,
        );
      case ChedGtsFieldType.single:
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: item.options.map((opt) {
            final selected = value?.toString() == opt;
            return ChoiceChip(
              label: Text(opt),
              selected: selected,
              onSelected: readOnly ? null : (_) => onChanged(opt),
              selectedColor: PortalTheme.navy.withValues(alpha: 0.12),
              backgroundColor: PortalTheme.surfaceMuted,
              side: BorderSide(
                color: selected
                    ? PortalTheme.navy.withValues(alpha: 0.35)
                    : PortalTheme.border,
              ),
              labelStyle: TextStyle(
                fontWeight: FontWeight.w600,
                color: selected ? PortalTheme.navy : PortalTheme.textSecondary,
                fontSize: 12,
              ),
            );
          }).toList(),
        );
      case ChedGtsFieldType.multi:
        final selected = value is List
            ? value!.map((e) => e.toString()).toSet()
            : <String>{};
        return Column(
          children: item.options.map((opt) {
            final checked = selected.contains(opt);
            return CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              activeColor: PortalTheme.navy,
              title: Text(opt, style: PortalTheme.body.copyWith(fontSize: 13)),
              value: checked,
              onChanged: readOnly
                  ? null
                  : (v) {
                      final next = Set<String>.from(selected);
                      if (v == true) {
                        next.add(opt);
                      } else {
                        next.remove(opt);
                      }
                      onChanged(next.toList());
                    },
            );
          }).toList(),
        );
      case ChedGtsFieldType.matrix:
        return _MatrixField(
          item: item,
          value: value is Map
              ? Map<String, dynamic>.from(value as Map)
              : <String, dynamic>{},
          readOnly: readOnly,
          onChanged: onChanged,
        );
      case ChedGtsFieldType.tableRows:
        return _TableRowsField(
          item: item,
          value: value is List
              ? List<Map<String, dynamic>>.from(
                  (value as List).map(
                    (e) => e is Map
                        ? Map<String, dynamic>.from(e)
                        : <String, dynamic>{},
                  ),
                )
              : <Map<String, dynamic>>[{}],
          readOnly: readOnly,
          onChanged: onChanged,
        );
    }
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.value,
    required this.onChanged,
    required this.readOnly,
  });

  final String? value;
  final ValueChanged<String> onChanged;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    DateTime? parsed;
    if (value != null && value!.isNotEmpty) {
      parsed = DateTime.tryParse(value!);
    }
    final label = parsed != null
        ? DateFormat.yMMMd().format(parsed)
        : 'Tap to select date';

    return InkWell(
      onTap: readOnly
          ? null
          : () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: parsed ?? DateTime(2000, 1, 1),
                firstDate: DateTime(1950),
                lastDate: DateTime.now(),
              );
              if (picked != null) {
                onChanged(DateFormat('yyyy-MM-dd').format(picked));
              }
            },
      borderRadius: BorderRadius.circular(PortalTheme.radiusMd),
      child: InputDecorator(
        decoration: _portalFieldDecoration(
          label: 'Birthday',
          icon: Icons.calendar_today_outlined,
          readOnly: readOnly,
        ),
        child: Text(label, style: PortalTheme.body),
      ),
    );
  }
}

/// Horizontal scroll with an always-visible scrollbar (shown only on overflow).
class _VisibleHorizontalScroll extends StatefulWidget {
  const _VisibleHorizontalScroll({required this.child});

  final Widget child;

  @override
  State<_VisibleHorizontalScroll> createState() =>
      _VisibleHorizontalScrollState();
}

class _VisibleHorizontalScrollState extends State<_VisibleHorizontalScroll> {
  final _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScrollbarTheme(
      data: ScrollbarThemeData(
        thickness: const WidgetStatePropertyAll(6),
        radius: const Radius.circular(999),
        thumbColor: const WidgetStatePropertyAll(PortalTheme.navy),
        trackColor: WidgetStatePropertyAll(
          PortalTheme.navy.withValues(alpha: 0.06),
        ),
        trackBorderColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      child: Scrollbar(
        controller: _controller,
        thumbVisibility: true,
        trackVisibility: true,
        child: ScrollConfiguration(
          // Avoids a second, hover-only scrollbar on desktop/web.
          behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
          child: SingleChildScrollView(
            controller: _controller,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(bottom: 14),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

class _MatrixField extends StatelessWidget {
  const _MatrixField({
    required this.item,
    required this.value,
    required this.onChanged,
    required this.readOnly,
  });

  final ChedGtsItem item;
  final Map<String, dynamic> value;
  final ValueChanged<Map<String, dynamic>> onChanged;
  final bool readOnly;

  static const _minLabelWidth = 160.0;
  static const _minCheckWidth = 120.0;
  static const _margin = 12.0;
  static const _spacing = 16.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Fill the card: spare width is split between the label column and
        // the checkbox columns; below the minimum it scrolls instead.
        final cols = item.matrixColumns.length;
        final chrome = _margin * 2 + _spacing * cols + 1;
        final extra =
            constraints.maxWidth -
            chrome -
            _minLabelWidth -
            cols * _minCheckWidth;
        final spare = extra > 0 ? extra : 0.0;
        final labelWidth = _minLabelWidth + spare / 2;
        final checkWidth = _minCheckWidth + (cols == 0 ? 0 : spare / 2 / cols);
        return _buildTable(labelWidth, checkWidth);
      },
    );
  }

  Widget _buildTable(double labelWidth, double checkWidth) {
    return _VisibleHorizontalScroll(
      child: DataTable(
        headingRowHeight: 40,
        dataRowMinHeight: 40,
        dataRowMaxHeight: 56,
        horizontalMargin: _margin,
        columnSpacing: _spacing,
        columns: [
          DataColumn(label: SizedBox(width: labelWidth)),
          ...item.matrixColumns.map(
            (c) => DataColumn(
              label: SizedBox(
                width: checkWidth,
                child: Text(
                  c,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 11),
                ),
              ),
            ),
          ),
        ],
        rows: item.matrixRows.map((row) {
          final rowMap = value[row] is Map
              ? Map<String, dynamic>.from(value[row] as Map)
              : <String, dynamic>{};
          return DataRow(
            cells: [
              DataCell(
                SizedBox(
                  width: labelWidth,
                  child: Text(row, style: const TextStyle(fontSize: 12)),
                ),
              ),
              ...item.matrixColumns.map((col) {
                final checked = rowMap[col] == true;
                return DataCell(
                  SizedBox(
                    width: checkWidth,
                    child: Center(
                      child: Checkbox(
                        value: checked,
                        activeColor: PortalTheme.navy,
                        side: BorderSide(
                          color: PortalTheme.navy.withValues(alpha: 0.6),
                          width: 1.5,
                        ),
                        onChanged: readOnly
                            ? null
                            : (v) {
                                final next = Map<String, dynamic>.from(value);
                                final nextRow = Map<String, dynamic>.from(
                                  rowMap,
                                );
                                // Single select per column for job level (item 30).
                                if (item.id == 'ched_30' && v == true) {
                                  for (final r in item.matrixRows) {
                                    final other = next[r] is Map
                                        ? Map<String, dynamic>.from(
                                            next[r] as Map,
                                          )
                                        : <String, dynamic>{};
                                    other[col] = false;
                                    next[r] = other;
                                  }
                                }
                                nextRow[col] = v == true;
                                next[row] = nextRow;
                                onChanged(next);
                              },
                      ),
                    ),
                  ),
                );
              }),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _TableRowsField extends StatelessWidget {
  const _TableRowsField({
    required this.item,
    required this.value,
    required this.onChanged,
    required this.readOnly,
  });

  final ChedGtsItem item;
  final List<Map<String, dynamic>> value;
  final ValueChanged<List<Map<String, dynamic>>> onChanged;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final rows = value.isEmpty ? [<String, dynamic>{}] : value;

    return Column(
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const Divider(height: 20),
          ...item.tableColumns.map((col) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: TextFormField(
                initialValue: rows[i][col]?.toString() ?? '',
                readOnly: readOnly,
                onChanged: (text) {
                  final next = rows
                      .map((r) => Map<String, dynamic>.from(r))
                      .toList();
                  next[i][col] = text;
                  onChanged(next);
                },
                decoration: _portalFieldDecoration(
                  label: item.required ? col : '$col (optional)',
                  hint: item.required ? null : 'Leave blank or None / N/A',
                  readOnly: readOnly,
                ),
              ),
            );
          }),
        ],
        if (!readOnly)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              style: PortalTheme.ghostButton(dense: true),
              onPressed: () {
                onChanged([
                  ...rows.map((r) => Map<String, dynamic>.from(r)),
                  <String, dynamic>{},
                ]);
              },
              icon: const Icon(Icons.add, size: 18),
              label: Text(item.required ? 'Add row' : 'Add row (optional)'),
            ),
          ),
      ],
    );
  }
}

/// Formats a builtin answer for history / admin display.
String formatChedGtsAnswer(ChedGtsItem item, dynamic value) {
  if (value == null) return '—';
  switch (item.type) {
    case ChedGtsFieldType.multi:
      if (value is List) return value.join(', ');
      return value.toString();
    case ChedGtsFieldType.matrix:
      if (value is! Map) return value.toString();
      final parts = <String>[];
      value.forEach((row, cols) {
        if (cols is Map) {
          final checked = cols.entries
              .where((e) => e.value == true)
              .map((e) => e.key.toString())
              .toList();
          if (checked.isNotEmpty) {
            parts.add('$row: ${checked.join(", ")}');
          }
        }
      });
      return parts.isEmpty ? '—' : parts.join(' · ');
    case ChedGtsFieldType.tableRows:
      if (value is! List) return value.toString();
      return value
          .whereType<Map>()
          .map(
            (row) =>
                row.values.where((v) => '$v'.trim().isNotEmpty).join(' | '),
          )
          .where((s) => s.isNotEmpty)
          .join('\n');
    default:
      return value.toString();
  }
}
