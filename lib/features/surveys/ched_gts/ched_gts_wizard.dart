import 'package:flutter/material.dart';
import 'package:alumni_system/features/surveys/ched_gts/ched_gts_form.dart';
import 'package:alumni_system/features/surveys/ched_gts/ched_gts_schema.dart';
import 'package:alumni_system/features/surveys/ched_gts/ched_gts_visibility.dart';
import 'package:alumni_system/shared/widgets/user/portal_menu.dart';
import 'package:alumni_system/shared/widgets/user/portal_theme.dart';

/// Friendly section names (the schema titles are the paper form's caps).
String chedSectionLabel(ChedGtsSection section) => switch (section) {
  ChedGtsSection.a => 'General information',
  ChedGtsSection.b => 'Educational background',
  ChedGtsSection.c => 'Training & advanced studies',
  ChedGtsSection.d => 'Employment data',
};

/// Full-screen, distraction-free section wizard: A → B → C → D → Review.
///
/// Required items are validated per section; missing ones are listed in a
/// dialog and can be shown on their own ("focus on missing" mode).
class ChedGtsWizard extends StatefulWidget {
  const ChedGtsWizard({
    super.key,
    required this.answers,
    required this.onChanged,
    required this.onSubmit,
    required this.onClose,
    this.saving = false,
    this.helpSurveyId,
  });

  final Map<String, dynamic> answers;
  final ChedGtsAnswersChanged onChanged;
  final Future<void> Function() onSubmit;

  /// Back arrow / system back on the first step (exit flow).
  final VoidCallback onClose;
  final bool saving;

  /// See [ChedGtsForm.helpSurveyId].
  final String? helpSurveyId;

  @override
  State<ChedGtsWizard> createState() => _ChedGtsWizardState();
}

class _ChedGtsWizardState extends State<ChedGtsWizard> {
  static const _sections = ChedGtsSection.values;

  final _scroll = ScrollController();

  /// 0–3 = sections, 4 = review.
  int _step = 0;

  /// Items shown in "focus on missing" mode. Only ever grows while active so
  /// answered items don't vanish mid-edit; newly revealed required follow-ups
  /// are added.
  Set<String>? _focusIds;

  /// Outline unanswered required items after a failed Next.
  bool _highlight = false;

  bool get _isReview => _step >= _sections.length;
  ChedGtsSection? get _section => _isReview ? null : _sections[_step];
  int get _totalSteps => _sections.length + 1;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  int get _overallRequiredPercent {
    final visible = ChedGtsVisibility.visibleItemIds(widget.answers);
    final requiredCount = ChedGtsBuiltin.items
        .where((i) => i.required && visible.contains(i.id))
        .length;
    if (requiredCount == 0) return 0;
    final missing = ChedGtsVisibility.missingRequired(widget.answers).length;
    return (((requiredCount - missing) / requiredCount) * 100).round().clamp(
      0,
      100,
    );
  }

  void _setStep(int step) {
    setState(() {
      _step = step;
      _focusIds = null;
      _highlight = false;
    });
    _scrollToTop();
  }

  void _scrollToTop() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      _scroll.animateTo(
        0,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Future<void> _goNext() async {
    final section = _section;
    if (section == null) return;
    final missing = ChedGtsVisibility.missingRequiredInSection(
      widget.answers,
      section,
    );
    if (missing.isEmpty) {
      _setStep(_step + 1);
      return;
    }
    final showMissing = await _showMissingDialog(missing);
    if (!mounted) return;
    setState(() {
      _highlight = true;
      if (showMissing) _focusIds = missing.toSet();
    });
    if (showMissing) _scrollToTop();
  }

  void _goBack() {
    if (_step > 0) _setStep(_step - 1);
  }

  Future<void> _submit() async {
    final missing = ChedGtsVisibility.missingRequired(widget.answers);
    if (missing.isEmpty) {
      await widget.onSubmit();
      return;
    }
    final showMissing = await _showMissingDialog(missing);
    if (!mounted || !showMissing) return;
    final firstSection = ChedGtsBuiltin.byId(missing.first)?.section;
    if (firstSection == null) return;
    final sectionMissing = ChedGtsVisibility.missingRequiredInSection(
      widget.answers,
      firstSection,
    );
    setState(() {
      _step = _sections.indexOf(firstSection);
      _highlight = true;
      _focusIds = sectionMissing.toSet();
    });
    _scrollToTop();
  }

  /// Returns true when the user chose "Show missing questions".
  Future<bool> _showMissingDialog(List<String> missingIds) async {
    const maxListed = 5;
    final items = missingIds
        .map(ChedGtsBuiltin.byId)
        .whereType<ChedGtsItem>()
        .toList();
    final extra = items.length - maxListed;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Some answers are missing'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                items.length == 1
                    ? 'Please answer this required question before continuing:'
                    : 'Please answer these ${items.length} required questions '
                          'before continuing:',
                style: PortalTheme.bodySecondary,
              ),
              const SizedBox(height: 14),
              for (final item in items.take(maxListed))
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: PortalTheme.danger.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'Q${item.chedNumber}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: PortalTheme.danger,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          item.prompt,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: PortalTheme.body.copyWith(fontSize: 13.5),
                        ),
                      ),
                    ],
                  ),
                ),
              if (extra > 0)
                Text(
                  '+ $extra more',
                  style: PortalTheme.meta.copyWith(fontWeight: FontWeight.w700),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: PortalTheme.ghostButton(dense: true),
            child: const Text('Close'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: PortalTheme.primaryButton(dense: true),
            child: const Text('Show missing questions'),
          ),
        ],
      ),
    );
    return result == true;
  }

  void _onAnswersChanged(Map<String, dynamic> answers) {
    final section = _section;
    final focus = _focusIds;
    if (focus != null && section != null) {
      setState(() {
        _focusIds = {
          ...focus,
          ...ChedGtsVisibility.missingRequiredInSection(answers, section),
        };
      });
    }
    widget.onChanged(answers);
  }

  @override
  Widget build(BuildContext context) {
    final section = _section;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_step > 0) {
          _goBack();
        } else {
          widget.onClose();
        }
      },
      child: Scaffold(
        backgroundColor: PortalTheme.pageBg,
        appBar: _WizardTopBar(
          title: section == null
              ? 'Review & submit'
              : chedSectionLabel(section),
          subtitle:
              'Step ${_step + 1} of $_totalSteps · '
              '$_overallRequiredPercent% complete',
          step: _step,
          totalSteps: _totalSteps,
          saving: widget.saving,
          onClose: widget.onClose,
        ),
        body: ListView(
          controller: _scroll,
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            24 + MediaQuery.paddingOf(context).bottom,
          ),
          children: [
            if (_focusIds != null && section != null) ...[
              _FocusBanner(
                remaining: _focusIds!
                    .intersection(
                      ChedGtsVisibility.missingRequiredInSection(
                        widget.answers,
                        section,
                      ).toSet(),
                    )
                    .length,
                onShowAll: () => setState(() => _focusIds = null),
              ),
              const SizedBox(height: 14),
            ],
            if (section == null)
              _ReviewStep(
                answers: widget.answers,
                onJumpToSection: (s) => _setStep(_sections.indexOf(s)),
              )
            else
              ChedGtsForm(
                key: ValueKey('ched-section-$_step'),
                answers: widget.answers,
                onChanged: _onAnswersChanged,
                showIntro: false,
                sectionFilter: section,
                showSectionHeaders: false,
                onlyItemIds: _focusIds,
                highlightMissing: _highlight,
                helpSurveyId: widget.helpSurveyId,
              ),
            const SizedBox(height: 12),
            _WizardActions(
              isReview: _isReview,
              saving: widget.saving,
              onBack: _step == 0 ? null : _goBack,
              onNext: _isReview ? _submit : _goNext,
            ),
          ],
        ),
      ),
    );
  }
}

class _WizardTopBar extends StatelessWidget implements PreferredSizeWidget {
  const _WizardTopBar({
    required this.title,
    required this.subtitle,
    required this.step,
    required this.totalSteps,
    required this.saving,
    required this.onClose,
  });

  final String title;
  final String subtitle;
  final int step;
  final int totalSteps;
  final bool saving;
  final VoidCallback onClose;

  static const double _height = 84;

  @override
  Size get preferredSize => const Size.fromHeight(_height);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: PortalTheme.card,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: _height,
          child: Column(
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  alignment: Alignment.center,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 56),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: PortalTheme.pageTitle,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: PortalTheme.meta,
                          ),
                        ],
                      ),
                    ),
                    Positioned.fill(
                      left: 4,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton(
                          icon: const Icon(Icons.close_rounded),
                          color: PortalTheme.navy,
                          tooltip: 'Exit tracer',
                          onPressed: saving ? null : onClose,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: Row(
                  children: List.generate(totalSteps, (i) {
                    return Expanded(
                      child: AnimatedContainer(
                        duration: PortalTheme.normal,
                        margin: EdgeInsets.only(
                          right: i == totalSteps - 1 ? 0 : 4,
                        ),
                        height: 4,
                        decoration: BoxDecoration(
                          color: i <= step
                              ? PortalTheme.gold
                              : PortalTheme.border,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WizardActions extends StatelessWidget {
  const _WizardActions({
    required this.isReview,
    required this.saving,
    required this.onBack,
    required this.onNext,
  });

  final bool isReview;
  final bool saving;
  final VoidCallback? onBack;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (onBack != null) ...[
          Expanded(
            child: OutlinedButton(
              onPressed: saving ? null : onBack,
              style: PortalTheme.secondaryButton(),
              child: const Text('Back'),
            ),
          ),
          const SizedBox(width: 10),
        ],
        Expanded(
          flex: 2,
          child: FilledButton(
            onPressed: saving ? null : onNext,
            style: PortalTheme.primaryButton(),
            child: saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(isReview ? 'Submit CHED GTS' : 'Next'),
          ),
        ),
      ],
    );
  }
}

class _FocusBanner extends StatelessWidget {
  const _FocusBanner({required this.remaining, required this.onShowAll});

  final int remaining;
  final VoidCallback onShowAll;

  @override
  Widget build(BuildContext context) {
    final done = remaining == 0;
    final color = done ? PortalTheme.success : PortalTheme.danger;
    return AnimatedContainer(
      duration: PortalTheme.fast,
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(PortalTheme.radiusLg),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(
            done ? Icons.check_circle_rounded : Icons.filter_list_rounded,
            size: 20,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              done
                  ? 'All set! Tap Next to continue.'
                  : remaining == 1
                  ? 'Showing unanswered questions · 1 left'
                  : 'Showing unanswered questions · $remaining left',
              style: PortalTheme.body.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: done ? PortalTheme.success : PortalTheme.textPrimary,
              ),
            ),
          ),
          TextButton(
            onPressed: onShowAll,
            style: PortalTheme.ghostButton(dense: true),
            child: const Text('Show all'),
          ),
        ],
      ),
    );
  }
}

class _ReviewStep extends StatelessWidget {
  const _ReviewStep({required this.answers, required this.onJumpToSection});

  final Map<String, dynamic> answers;
  final ValueChanged<ChedGtsSection> onJumpToSection;

  @override
  Widget build(BuildContext context) {
    final visible = ChedGtsVisibility.visibleItemIds(answers);
    final missing = ChedGtsVisibility.missingRequired(answers);
    final color = missing.isEmpty ? PortalTheme.success : PortalTheme.warning;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(PortalTheme.space3),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(PortalTheme.radiusXl),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                missing.isEmpty
                    ? Icons.check_circle_rounded
                    : Icons.info_outline_rounded,
                color: color,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  missing.isEmpty
                      ? 'All required questions are answered. Review your '
                            'sections below, then submit.'
                      : '${missing.length} required '
                            '${missing.length == 1 ? 'question is' : 'questions are'} '
                            'still unanswered. Tap a section to finish it.',
                  style: PortalTheme.body.copyWith(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: missing.isEmpty
                        ? PortalTheme.success
                        : PortalTheme.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        for (final section in ChedGtsSection.values) ...[
          _SectionReviewCard(
            section: section,
            answers: answers,
            visible: visible,
            onEdit: () => onJumpToSection(section),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _SectionReviewCard extends StatelessWidget {
  const _SectionReviewCard({
    required this.section,
    required this.answers,
    required this.visible,
    required this.onEdit,
  });

  final ChedGtsSection section;
  final Map<String, dynamic> answers;
  final Set<String> visible;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final count = ChedGtsBuiltin.items
        .where((i) => i.section == section && visible.contains(i.id))
        .length;
    final missing = ChedGtsVisibility.missingRequiredInSection(
      answers,
      section,
    );
    final ready = missing.isEmpty;

    return Material(
      color: PortalTheme.card,
      shape: PortalMenu.menuShape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
          child: Row(
            children: [
              Icon(
                ready
                    ? Icons.check_circle_rounded
                    : Icons.error_outline_rounded,
                color: ready ? PortalTheme.success : PortalTheme.danger,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      chedSectionLabel(section),
                      style: PortalTheme.cardTitle.copyWith(fontSize: 14),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      ready
                          ? '$count ${count == 1 ? 'question' : 'questions'} · ready'
                          : '${missing.length} required '
                                '${missing.length == 1 ? 'question' : 'questions'} '
                                'unanswered',
                      style: PortalTheme.meta.copyWith(
                        color: ready
                            ? PortalTheme.textSecondary
                            : PortalTheme.danger,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: onEdit,
                style: PortalTheme.ghostButton(dense: true),
                child: const Text('Edit'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
