import 'package:flutter/material.dart';
import 'package:alumni_system/features/surveys/ched_gts/ched_gts_form.dart';
import 'package:alumni_system/features/surveys/ched_gts/ched_gts_schema.dart';
import 'package:alumni_system/features/surveys/ched_gts/ched_gts_visibility.dart';
import 'package:alumni_system/shared/widgets/onboarding/onboarding_ui.dart';
import 'package:alumni_system/shared/widgets/user/portal_headers.dart';
import 'package:alumni_system/shared/widgets/user/portal_theme.dart';

/// Section wizard: A → B → C → D → Review / Submit.
class ChedGtsWizard extends StatefulWidget {
  const ChedGtsWizard({
    super.key,
    required this.answers,
    required this.onChanged,
    required this.onSaveDraft,
    required this.onSubmit,
    this.title,
    this.saving = false,
    this.scrollController,
  });

  final Map<String, dynamic> answers;
  final ChedGtsAnswersChanged onChanged;
  final Future<void> Function() onSaveDraft;
  final Future<void> Function() onSubmit;
  final String? title;
  final bool saving;
  /// Parent list scroll controller (so Next/Back can jump to top).
  final ScrollController? scrollController;

  @override
  State<ChedGtsWizard> createState() => _ChedGtsWizardState();
}

class _ChedGtsWizardState extends State<ChedGtsWizard> {
  static const _sections = [
    ChedGtsSection.a,
    ChedGtsSection.b,
    ChedGtsSection.c,
    ChedGtsSection.d,
  ];

  /// 0–3 = sections, 4 = review.
  int _step = 0;
  String? _sectionError;

  bool get _isReview => _step >= _sections.length;

  ChedGtsSection? get _currentSection =>
      _isReview ? null : _sections[_step];

  int get _totalSteps => _sections.length + 1; // + review

  double get _stepProgress => (_step + 1) / _totalSteps;

  int get _overallRequiredPercent {
    final visible = ChedGtsVisibility.visibleItemIds(widget.answers);
    final requiredIds = ChedGtsBuiltin.items
        .where((i) => i.required && visible.contains(i.id))
        .map((i) => i.id)
        .toList();
    if (requiredIds.isEmpty) return 0;
    final missing = ChedGtsVisibility.missingRequired(widget.answers);
    final done = requiredIds.length - missing.length;
    return ((done / requiredIds.length) * 100).round().clamp(0, 100);
  }

  Future<void> _goNext() async {
    if (_isReview) return;
    final section = _currentSection!;
    final missing =
        ChedGtsVisibility.missingRequiredInSection(widget.answers, section);
    if (missing.isNotEmpty) {
      final first = ChedGtsBuiltin.byId(missing.first);
      setState(() {
        _sectionError =
            'Please complete required item ${first?.chedNumber ?? missing.first}'
            '${first != null ? ": ${first.prompt}" : ""}';
      });
      return;
    }
    setState(() {
      _sectionError = null;
      _step += 1;
    });
    _scrollToTop();
  }

  void _goBack() {
    if (_step == 0) return;
    setState(() {
      _sectionError = null;
      _step -= 1;
    });
    _scrollToTop();
  }

  void _scrollToTop() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final explicit = widget.scrollController;
      if (explicit != null && explicit.hasClients) {
        explicit.animateTo(
          0,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
        );
        return;
      }

      // Fallback: nearest enclosing scrollable (e.g. Tracer ListView).
      final position = Scrollable.maybeOf(context)?.position;
      if (position != null && position.hasPixels) {
        position.animateTo(
          0,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  String _stepLabel() {
    if (_isReview) return 'Review & submit';
    return _currentSectionTitle();
  }

  String _currentSectionTitle() {
    final section = _currentSection;
    if (section == null) return 'Review';
    return ChedGtsBuiltin.items
        .firstWhere((i) => i.section == section)
        .sectionTitle;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _WizardHeader(
          title: widget.title ?? ChedGtsBuiltin.defaultTitle,
          step: _step,
          totalSteps: _totalSteps,
          stepProgress: _stepProgress,
          overallPercent: _overallRequiredPercent,
          stepLabel: _stepLabel(),
          isReview: _isReview,
        ),
        const SizedBox(height: 14),
        if (_sectionError != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFECACA)),
            ),
            child: Text(
              _sectionError!,
              style: const TextStyle(
                color: Color(0xFFB91C1C),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (_isReview)
          _ReviewStep(
            answers: widget.answers,
            onJumpToSection: (section) {
              final index = _sections.indexOf(section);
              if (index >= 0) {
                setState(() {
                  _step = index;
                  _sectionError = null;
                });
                _scrollToTop();
              }
            },
          )
        else
          ChedGtsForm(
            key: ValueKey('ched-section-$_step'),
            answers: widget.answers,
            onChanged: (a) {
              setState(() => _sectionError = null);
              widget.onChanged(a);
            },
            showIntro: _step == 0,
            sectionFilter: _currentSection,
            showSectionHeaders: false,
          ),
        const SizedBox(height: 20),
        _WizardActions(
          step: _step,
          isReview: _isReview,
          saving: widget.saving,
          onBack: _step == 0 ? null : _goBack,
          onNext: _goNext,
          onSaveDraft: widget.onSaveDraft,
          onSubmit: widget.onSubmit,
        ),
      ],
    );
  }
}

class _WizardHeader extends StatelessWidget {
  const _WizardHeader({
    required this.title,
    required this.step,
    required this.totalSteps,
    required this.stepProgress,
    required this.overallPercent,
    required this.stepLabel,
    required this.isReview,
  });

  final String title;
  final int step;
  final int totalSteps;
  final double stepProgress;
  final int overallPercent;
  final String stepLabel;
  final bool isReview;

  @override
  Widget build(BuildContext context) {
    return PortalHighlightPanel(
      variant: PortalHighlightVariant.soft,
      padding: const EdgeInsets.all(PortalTheme.space3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: PortalTheme.cardTitle,
                ),
              ),
              PortalChip(
                label: isReview ? 'Review' : 'Step ${step + 1}/$totalSteps',
                tone: PortalChipTone.brand,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            isReview
                ? 'Almost done — review your answers, then submit'
                : stepLabel,
            style: PortalTheme.bodySecondary,
          ),
          const SizedBox(height: PortalTheme.space3),
          Row(
            children: List.generate(totalSteps, (i) {
              final done = i < step;
              final current = i == step;
              return Expanded(
                child: Container(
                  margin: EdgeInsets.only(right: i == totalSteps - 1 ? 0 : 6),
                  height: 6,
                  decoration: BoxDecoration(
                    color: done || current
                        ? PortalTheme.gold
                        : PortalTheme.border,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: overallPercent / 100,
              minHeight: 5,
              backgroundColor: PortalTheme.surfaceMuted,
              color: PortalTheme.navy,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$overallPercent% of required items answered',
            style: PortalTheme.caption,
          ),
        ],
      ),
    );
  }
}

class _WizardActions extends StatelessWidget {
  const _WizardActions({
    required this.step,
    required this.isReview,
    required this.saving,
    required this.onBack,
    required this.onNext,
    required this.onSaveDraft,
    required this.onSubmit,
  });

  final int step;
  final bool isReview;
  final bool saving;
  final VoidCallback? onBack;
  final VoidCallback onNext;
  final Future<void> Function() onSaveDraft;
  final Future<void> Function() onSubmit;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            if (onBack != null)
              Expanded(
                child: OutlinedButton(
                  onPressed: saving ? null : onBack,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: OnboardingTheme.navy,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Back'),
                ),
              ),
            if (onBack != null) const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: FilledButton(
                onPressed: saving
                    ? null
                    : () {
                        if (isReview) {
                          onSubmit();
                        } else {
                          onNext();
                        }
                      },
                style: FilledButton.styleFrom(
                  backgroundColor: OnboardingTheme.navy,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
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
        ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: saving ? null : () => onSaveDraft(),
          child: const Text('Save draft & continue later'),
        ),
      ],
    );
  }
}

class _ReviewStep extends StatelessWidget {
  const _ReviewStep({
    required this.answers,
    required this.onJumpToSection,
  });

  final Map<String, dynamic> answers;
  final ValueChanged<ChedGtsSection> onJumpToSection;

  @override
  Widget build(BuildContext context) {
    final visible = ChedGtsVisibility.visibleItemIds(answers);
    final missing = ChedGtsVisibility.missingRequired(answers);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: OnboardingTheme.border),
          ),
          child: Text(
            missing.isEmpty
                ? 'All required items look complete. You can still jump back to edit a section, then submit.'
                : 'Some required items are still missing (${missing.length}). Jump to a section below to finish them.',
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: missing.isEmpty
                  ? const Color(0xFF047857)
                  : const Color(0xFFB45309),
              fontWeight: FontWeight.w600,
            ),
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
    final items = ChedGtsBuiltin.items
        .where((i) => i.section == section && visible.contains(i.id))
        .toList();
    final missing =
        ChedGtsVisibility.missingRequiredInSection(answers, section);
    final title = items.isNotEmpty
        ? items.first.sectionTitle
        : section.name.toUpperCase();

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: OnboardingTheme.border),
          ),
          child: Row(
            children: [
              Icon(
                missing.isEmpty ? Icons.check_circle : Icons.edit_note,
                color: missing.isEmpty
                    ? const Color(0xFF047857)
                    : OnboardingTheme.navy,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: OnboardingTheme.navy,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      missing.isEmpty
                          ? '${items.length} visible items · ready'
                          : '${missing.length} required item(s) still needed',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: onEdit,
                child: const Text('Edit'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
