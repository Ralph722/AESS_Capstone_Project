import 'package:flutter/material.dart';
import 'package:alumni_system/features/admin/surveys/widgets/admin_survey_ui.dart';
import 'package:alumni_system/features/surveys/models/survey_model.dart';
import 'package:alumni_system/shared/widgets/admin/admin_density.dart';

String surveyQuestionTypeLabel(SurveyQuestionType t) {
  switch (t) {
    case SurveyQuestionType.text:
      return 'Short text';
    case SurveyQuestionType.longText:
      return 'Long text';
    case SurveyQuestionType.singleChoice:
      return 'Single choice';
    case SurveyQuestionType.multipleChoice:
      return 'Multiple choice';
    case SurveyQuestionType.scale:
      return 'Scale';
    case SurveyQuestionType.date:
      return 'Date';
  }
}

/// Editable options list for single/multiple choice questions.
class SurveyOptionsEditor extends StatefulWidget {
  const SurveyOptionsEditor({
    super.key,
    required this.options,
    required this.onChanged,
  });

  final List<String> options;
  final ValueChanged<List<String>> onChanged;

  @override
  State<SurveyOptionsEditor> createState() => _SurveyOptionsEditorState();
}

class _SurveyOptionsEditorState extends State<SurveyOptionsEditor> {
  late List<TextEditingController> _controllers;

  @override
  void initState() {
    super.initState();
    _controllers = widget.options
        .map((o) => TextEditingController(text: o))
        .toList();
    if (_controllers.isEmpty) {
      _controllers = [
        TextEditingController(),
        TextEditingController(),
      ];
    }
  }

  @override
  void didUpdateWidget(covariant SurveyOptionsEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.options.length != widget.options.length) {
      _resyncControllers(widget.options);
    }
  }

  void _resyncControllers(List<String> options) {
    for (final c in _controllers) {
      c.dispose();
    }
    _controllers = options.map((o) => TextEditingController(text: o)).toList();
    if (_controllers.isEmpty) {
      _controllers = [
        TextEditingController(),
        TextEditingController(),
      ];
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _emit() {
    widget.onChanged(_controllers.map((c) => c.text).toList());
  }

  void _add() {
    setState(() {
      _controllers.add(TextEditingController());
    });
    _emit();
  }

  void _removeAt(int index) {
    if (_controllers.length <= 1) return;
    setState(() {
      _controllers[index].dispose();
      _controllers.removeAt(index);
    });
    _emit();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Options',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AdminSurveyTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        for (var i = 0; i < _controllers.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controllers[i],
                  onChanged: (_) => _emit(),
                  decoration: AdminSurveyTheme.fieldDecoration(
                    label: 'Option ${i + 1}',
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Remove option',
                onPressed:
                    _controllers.length <= 1 ? null : () => _removeAt(i),
                icon: const Icon(
                  Icons.close,
                  color: AdminSurveyTheme.textMuted,
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _add,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add option'),
            style: TextButton.styleFrom(
              foregroundColor: AdminSurveyTheme.primary,
            ),
          ),
        ),
      ],
    );
  }
}

/// Expandable inline question editor for classic / legacy surveys.
class SurveyQuestionEditorCard extends StatefulWidget {
  const SurveyQuestionEditorCard({
    super.key,
    required this.question,
    required this.index,
    required this.expanded,
    required this.isSaving,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onToggleExpand,
    required this.onChanged,
    required this.onDuplicate,
    required this.onDelete,
    required this.onMoveUp,
    required this.onMoveDown,
    this.dragHandle,
    this.allQuestions = const [],
    this.visibilityRule,
    this.onVisibilityRuleChanged,
    this.onDuplicateSection,
  });

  final SurveyQuestion question;
  final int index;
  final bool expanded;
  final bool isSaving;
  final bool canMoveUp;
  final bool canMoveDown;
  final VoidCallback onToggleExpand;
  final ValueChanged<SurveyQuestion> onChanged;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final Widget? dragHandle;

  /// Prior + other questions for "show when" source picker.
  final List<SurveyQuestion> allQuestions;
  final SurveyVisibilityRule? visibilityRule;
  final ValueChanged<SurveyVisibilityRule?>? onVisibilityRuleChanged;
  final VoidCallback? onDuplicateSection;

  @override
  State<SurveyQuestionEditorCard> createState() =>
      _SurveyQuestionEditorCardState();
}

class _SurveyQuestionEditorCardState extends State<SurveyQuestionEditorCard> {
  late TextEditingController _promptController;
  late TextEditingController _sectionController;

  @override
  void initState() {
    super.initState();
    _promptController = TextEditingController(text: widget.question.prompt);
    _sectionController =
        TextEditingController(text: widget.question.section ?? '');
  }

  @override
  void didUpdateWidget(covariant SurveyQuestionEditorCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.question.id != widget.question.id) {
      _promptController.text = widget.question.prompt;
      _sectionController.text = widget.question.section ?? '';
    } else {
      if (_promptController.text != widget.question.prompt &&
          !widget.expanded) {
        _promptController.text = widget.question.prompt;
      }
      if ((_sectionController.text) != (widget.question.section ?? '') &&
          !widget.expanded) {
        _sectionController.text = widget.question.section ?? '';
      }
    }
  }

  @override
  void dispose() {
    _promptController.dispose();
    _sectionController.dispose();
    super.dispose();
  }

  String? get _validationHint {
    final q = widget.question;
    if (q.prompt.trim().isEmpty) return 'Add question text';
    if (q.type == SurveyQuestionType.singleChoice ||
        q.type == SurveyQuestionType.multipleChoice) {
      final filled =
          q.options.map((e) => e.trim()).where((e) => e.isNotEmpty).length;
      if (filled < 2) return 'Add at least 2 options';
    }
    return null;
  }

  void _emit(SurveyQuestion next) => widget.onChanged(next);

  @override
  Widget build(BuildContext context) {
    final q = widget.question;
    final hint = _validationHint;

    return Container(
      margin: const EdgeInsets.only(bottom: AdminDensity.listItemGap),
      decoration: BoxDecoration(
        color: AdminSurveyTheme.card,
        borderRadius: BorderRadius.circular(AdminSurveyTheme.radiusMd),
        border: Border.all(
          color: widget.expanded
              ? AdminSurveyTheme.primary.withValues(alpha: 0.35)
              : AdminSurveyTheme.border,
        ),
        boxShadow: AdminSurveyTheme.surfaceCard().boxShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: widget.onToggleExpand,
            borderRadius: BorderRadius.circular(AdminSurveyTheme.radiusMd),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.dragHandle != null) ...[
                    widget.dragHandle!,
                    const SizedBox(width: 4),
                  ],
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AdminSurveyTheme.infoBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${widget.index + 1}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: AdminSurveyTheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          q.prompt.trim().isEmpty
                              ? 'Untitled question'
                              : q.prompt,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: q.prompt.trim().isEmpty
                                ? AdminSurveyTheme.textMuted
                                : AdminSurveyTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            _MiniChip(
                              label: surveyQuestionTypeLabel(q.type),
                            ),
                            if (q.required)
                              const _MiniChip(
                                label: 'Required',
                                emphasize: true,
                              ),
                            if (q.isStandardItem)
                              const _MiniChip(
                                label: 'CHED standard',
                                warning: true,
                              ),
                            if (widget.visibilityRule != null)
                              const _MiniChip(
                                label: 'Conditional',
                                emphasize: true,
                              ),
                            if (hint != null)
                              _MiniChip(label: hint, warning: true),
                            if (widget.isSaving)
                              const _MiniChip(label: 'Saving…'),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    widget.expanded
                        ? Icons.expand_less
                        : Icons.expand_more,
                    color: AdminSurveyTheme.textMuted,
                  ),
                ],
              ),
            ),
          ),
          if (widget.expanded) ...[
            const Divider(height: 1, color: AdminSurveyTheme.border),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _promptController,
                    maxLines: 3,
                    onChanged: (v) => _emit(q.copyWith(prompt: v)),
                    decoration: AdminSurveyTheme.fieldDecoration(
                      label: 'Question',
                      error: q.prompt.trim().isEmpty
                          ? 'Question text is required'
                          : null,
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<SurveyQuestionType>(
                    key: ValueKey('type-${q.id}-${q.type.name}'),
                    initialValue: q.type,
                    decoration: AdminSurveyTheme.fieldDecoration(
                      label: 'Type',
                    ),
                    items: SurveyQuestionType.values
                        .map(
                          (t) => DropdownMenuItem(
                            value: t,
                            child: Text(surveyQuestionTypeLabel(t)),
                          ),
                        )
                        .toList(),
                    onChanged: (t) {
                      if (t == null) return;
                      var next = q.copyWith(type: t);
                      if (t == SurveyQuestionType.scale) {
                        next = next.copyWith(
                          scaleMin: q.scaleMin ?? 1,
                          scaleMax: q.scaleMax ?? 5,
                          options: const [],
                        );
                      } else if (t == SurveyQuestionType.singleChoice ||
                          t == SurveyQuestionType.multipleChoice) {
                        next = next.copyWith(
                          options: q.options.isEmpty
                              ? ['Option 1', 'Option 2']
                              : q.options,
                          clearScale: true,
                        );
                      } else {
                        next = next.copyWith(
                          options: const [],
                          clearScale: true,
                        );
                      }
                      _emit(next);
                    },
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Required',
                      style: TextStyle(fontSize: 14),
                    ),
                    subtitle: const Text(
                      'Alumni must answer before submitting',
                      style: TextStyle(fontSize: 12),
                    ),
                    value: q.required,
                    activeThumbColor: AdminSurveyTheme.primary,
                    onChanged: (v) => _emit(q.copyWith(required: v)),
                  ),
                  if (q.type == SurveyQuestionType.singleChoice ||
                      q.type == SurveyQuestionType.multipleChoice) ...[
                    const SizedBox(height: 8),
                    SurveyOptionsEditor(
                      key: ValueKey('opts-${q.id}-${q.type.name}'),
                      options: q.options.isEmpty ? ['', ''] : q.options,
                      onChanged: (opts) => _emit(q.copyWith(options: opts)),
                    ),
                    if ((q.options
                            .map((e) => e.trim())
                            .where((e) => e.isNotEmpty)
                            .length) <
                        2)
                      const Padding(
                        padding: EdgeInsets.only(top: 6),
                        child: Text(
                          'Add at least 2 non-empty options.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AdminSurveyTheme.warning,
                          ),
                        ),
                      ),
                  ],
                  if (q.type == SurveyQuestionType.scale) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            key: ValueKey('scale-min-${q.id}-${q.scaleMin}'),
                            initialValue: q.scaleMin ?? 1,
                            decoration: AdminSurveyTheme.fieldDecoration(
                              label: 'Scale min',
                            ),
                            items: List.generate(
                              10,
                              (i) => DropdownMenuItem(
                                value: i + 1,
                                child: Text('${i + 1}'),
                              ),
                            ),
                            onChanged: (v) {
                              if (v != null) _emit(q.copyWith(scaleMin: v));
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            key: ValueKey('scale-max-${q.id}-${q.scaleMax}'),
                            initialValue: q.scaleMax ?? 5,
                            decoration: AdminSurveyTheme.fieldDecoration(
                              label: 'Scale max',
                            ),
                            items: List.generate(
                              10,
                              (i) => DropdownMenuItem(
                                value: i + 1,
                                child: Text('${i + 1}'),
                              ),
                            ),
                            onChanged: (v) {
                              if (v != null) _emit(q.copyWith(scaleMax: v));
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextField(
                    controller: _sectionController,
                    onChanged: (v) {
                      final trimmed = v.trim();
                      _emit(
                        trimmed.isEmpty
                            ? q.copyWith(clearSection: true)
                            : q.copyWith(section: trimmed),
                      );
                    },
                    decoration: AdminSurveyTheme.fieldDecoration(
                      label: 'Section (optional)',
                      hint: 'e.g. C or Employment',
                      helper: 'Groups questions under a section heading',
                    ),
                  ),
                  if (widget.onVisibilityRuleChanged != null) ...[
                    const SizedBox(height: 16),
                    _VisibilityRuleEditor(
                      question: q,
                      allQuestions: widget.allQuestions,
                      rule: widget.visibilityRule,
                      onChanged: widget.onVisibilityRuleChanged!,
                    ),
                  ],
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      IconButton(
                        tooltip: 'Move up',
                        onPressed: widget.canMoveUp ? widget.onMoveUp : null,
                        icon: const Icon(Icons.arrow_upward, size: 20),
                        style: AdminDensity.iconButtonStyle(),
                      ),
                      IconButton(
                        tooltip: 'Move down',
                        onPressed:
                            widget.canMoveDown ? widget.onMoveDown : null,
                        icon: const Icon(Icons.arrow_downward, size: 20),
                        style: AdminDensity.iconButtonStyle(),
                      ),
                      IconButton(
                        tooltip: 'Duplicate',
                        onPressed: widget.onDuplicate,
                        icon: const Icon(Icons.copy_outlined, size: 20),
                        style: AdminDensity.iconButtonStyle(),
                      ),
                      if (widget.onDuplicateSection != null)
                        IconButton(
                          tooltip: 'Duplicate section',
                          onPressed: widget.onDuplicateSection,
                          icon: const Icon(Icons.library_add_outlined, size: 20),
                          style: AdminDensity.iconButtonStyle(),
                        ),
                      IconButton(
                        tooltip: 'Delete',
                        onPressed: widget.onDelete,
                        icon: const Icon(
                          Icons.delete_outline,
                          color: AdminSurveyTheme.danger,
                          size: 20,
                        ),
                        style: AdminDensity.iconButtonStyle(
                          foregroundColor: AdminSurveyTheme.danger,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _VisibilityRuleEditor extends StatelessWidget {
  const _VisibilityRuleEditor({
    required this.question,
    required this.allQuestions,
    required this.rule,
    required this.onChanged,
  });

  final SurveyQuestion question;
  final List<SurveyQuestion> allQuestions;
  final SurveyVisibilityRule? rule;
  final ValueChanged<SurveyVisibilityRule?> onChanged;

  List<SurveyQuestion> get _priorSources {
    return allQuestions
        .where((q) => q.id != question.id && q.order < question.order)
        .toList();
  }

  List<String> _valueSuggestions(String? sourceId) {
    if (sourceId == null || sourceId.isEmpty) return const [];
    SurveyQuestion? source;
    for (final q in allQuestions) {
      if (q.id == sourceId) {
        source = q;
        break;
      }
    }
    if (source == null) return const [];
    if (source.type == SurveyQuestionType.singleChoice ||
        source.type == SurveyQuestionType.multipleChoice) {
      return source.options
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    return const [];
  }

  @override
  Widget build(BuildContext context) {
    final enabled = rule != null;
    final sources = _priorSources;
    final sourceId = rule?.sourceQuestionId;
    final suggestions = _valueSuggestions(sourceId);
    final sourceMissing = sourceId != null &&
        sourceId.isNotEmpty &&
        !allQuestions.any((q) => q.id == sourceId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text(
            'Show only when…',
            style: TextStyle(fontSize: 14),
          ),
          subtitle: const Text(
            'Hide this question unless a prior answer matches',
            style: TextStyle(fontSize: 12),
          ),
          value: enabled,
          activeThumbColor: AdminSurveyTheme.primary,
          onChanged: sources.isEmpty
              ? null
              : (v) {
                  if (!v) {
                    onChanged(null);
                    return;
                  }
                  final first = sources.first;
                  final opts = _valueSuggestions(first.id);
                  onChanged(
                    SurveyVisibilityRule(
                      sourceQuestionId: first.id,
                      operator: SurveyVisibilityOperator.equals,
                      value: opts.isNotEmpty ? opts.first : '',
                    ),
                  );
                },
        ),
        if (sources.isEmpty)
          const Padding(
            padding: EdgeInsets.only(bottom: 4),
            child: Text(
              'Add a prior question to use conditional visibility.',
              style: TextStyle(
                fontSize: 12,
                color: AdminSurveyTheme.textMuted,
              ),
            ),
          ),
        if (enabled) ...[
          DropdownButtonFormField<String>(
            key: ValueKey('vis-src-${question.id}-$sourceId'),
            initialValue: sourceMissing ? null : sourceId,
            decoration: AdminSurveyTheme.fieldDecoration(
              label: 'When this question',
              error: sourceMissing ? 'Source question was removed' : null,
            ),
            items: sources
                .map(
                  (s) => DropdownMenuItem(
                    value: s.id,
                    child: Text(
                      s.prompt.trim().isEmpty
                          ? 'Untitled (Q${s.order + 1})'
                          : s.prompt,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: (id) {
              if (id == null || rule == null) return;
              final opts = _valueSuggestions(id);
              onChanged(
                rule!.copyWith(
                  sourceQuestionId: id,
                  value: opts.isNotEmpty ? opts.first : rule!.value,
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<SurveyVisibilityOperator>(
            key: ValueKey('vis-op-${question.id}-${rule?.operator.name}'),
            initialValue: rule?.operator ?? SurveyVisibilityOperator.equals,
            decoration: AdminSurveyTheme.fieldDecoration(label: 'Operator'),
            items: const [
              DropdownMenuItem(
                value: SurveyVisibilityOperator.equals,
                child: Text('Equals'),
              ),
              DropdownMenuItem(
                value: SurveyVisibilityOperator.notEquals,
                child: Text('Does not equal'),
              ),
            ],
            onChanged: (op) {
              if (op == null || rule == null) return;
              onChanged(rule!.copyWith(operator: op));
            },
          ),
          const SizedBox(height: 10),
          if (suggestions.isNotEmpty)
            DropdownButtonFormField<String>(
              key: ValueKey('vis-val-${question.id}-${rule?.value}'),
              initialValue: suggestions.contains(rule?.value)
                  ? rule!.value
                  : suggestions.first,
              decoration: AdminSurveyTheme.fieldDecoration(label: 'Value'),
              items: suggestions
                  .map(
                    (v) => DropdownMenuItem(value: v, child: Text(v)),
                  )
                  .toList(),
              onChanged: (v) {
                if (v == null || rule == null) return;
                onChanged(rule!.copyWith(value: v));
              },
            )
          else
            TextFormField(
              key: ValueKey('vis-val-text-${question.id}'),
              initialValue: rule?.value ?? '',
              decoration: AdminSurveyTheme.fieldDecoration(
                label: 'Value',
                hint: 'Exact answer text',
              ),
              onChanged: (v) {
                if (rule == null) return;
                onChanged(rule!.copyWith(value: v));
              },
            ),
        ],
      ],
    );
  }
}

class _MiniChip extends StatelessWidget {
  const _MiniChip({
    required this.label,
    this.emphasize = false,
    this.warning = false,
  });

  final String label;
  final bool emphasize;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color fg;
    if (warning) {
      bg = AdminSurveyTheme.warningBg;
      fg = AdminSurveyTheme.warning;
    } else if (emphasize) {
      bg = AdminSurveyTheme.infoBg;
      fg = AdminSurveyTheme.primary;
    } else {
      bg = AdminSurveyTheme.surface;
      fg = AdminSurveyTheme.textSecondary;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }
}
