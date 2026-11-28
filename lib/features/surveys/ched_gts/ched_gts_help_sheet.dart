import 'package:flutter/material.dart';
import 'package:alumni_system/features/surveys/ched_gts/ched_gts_help_service.dart';
import 'package:alumni_system/features/surveys/ched_gts/ched_gts_schema.dart';
import 'package:alumni_system/shared/widgets/user/portal_theme.dart';

/// "Help me answer" for CHED GTS Q19 (occupation) and Q20 (line of business).
///
/// Nothing is filled in until the alumnus taps "Use this"; each tap calls
/// [onApply] with the answer keys to set and the suggestion they came from.
Future<void> showChedGtsHelpSheet(
  BuildContext context, {
  required String surveyId,
  required ChedGtsHelpApply onApply,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    backgroundColor: Colors.white,
    constraints: const BoxConstraints(maxWidth: 580),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(PortalTheme.radius2xl),
      ),
    ),
    builder: (_) => _HelpSheet(surveyId: surveyId, onApply: onApply),
  );
}

/// Q20 answer keys for a suggestion ("Others" also fills the specify field).
Map<String, dynamic> chedGtsLineOfBusinessUpdates(ChedGtsHelpSuggestion r) {
  final line = r.lineOfBusiness!;
  return {
    'ched_20': line,
    if (line == ChedGtsBuiltin.othersSpecify && r.specifyText.isNotEmpty)
      'ched_20_other': r.specifyText,
  };
}

typedef ChedGtsHelpApply =
    void Function(Map<String, dynamic> updates, ChedGtsHelpSuggestion source);

class _HelpSheet extends StatefulWidget {
  const _HelpSheet({required this.surveyId, required this.onApply});

  final String surveyId;
  final ChedGtsHelpApply onApply;

  @override
  State<_HelpSheet> createState() => _HelpSheetState();
}

class _HelpSheetState extends State<_HelpSheet> {
  final _service = ChedGtsHelpService();
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  bool _loading = false;
  String? _error;
  ChedGtsHelpSuggestion? _result;
  int? _remaining;
  bool _usedOccupation = false;
  bool _usedLine = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _ask() async {
    final text = _controller.text.trim();
    if (text.length < 3) {
      setState(() => _error = 'Please describe your job in a few words first.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
      _result = null;
      _usedOccupation = false;
      _usedLine = false;
    });
    try {
      final result = await _service.suggest(
        surveyId: widget.surveyId,
        description: text,
      );
      if (!mounted) return;
      setState(() {
        _result = result;
        _remaining = result.remaining;
      });

      // Smoothly scroll down so the suggestions come into view
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutCubic,
          );
        }
      });
    } on ChedGtsHelpException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _remaining = e.remaining ?? _remaining;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _useOccupation(ChedGtsHelpSuggestion r) {
    widget.onApply({'ched_19': r.occupation}, r);
    setState(() => _usedOccupation = true);
    _showFeedbackToast('Question 19 updated with occupation.');
  }

  void _useLine(ChedGtsHelpSuggestion r) {
    widget.onApply(chedGtsLineOfBusinessUpdates(r), r);
    setState(() => _usedLine = true);
    _showFeedbackToast('Question 20 updated with line of business.');
  }

  void _useBoth(ChedGtsHelpSuggestion r) {
    final updates = <String, dynamic>{
      if (r.occupation.isNotEmpty) 'ched_19': r.occupation,
      if (r.lineOfBusiness != null) ...chedGtsLineOfBusinessUpdates(r),
    };
    widget.onApply(updates, r);
    setState(() {
      if (r.occupation.isNotEmpty) _usedOccupation = true;
      if (r.lineOfBusiness != null) _usedLine = true;
    });
    _showFeedbackToast('Applied both Q19 & Q20 answers to your survey!');
  }

  void _showFeedbackToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.check_circle_rounded,
              color: PortalTheme.gold,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: PortalTheme.navyDeep,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 2200),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PortalTheme.radiusMd),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final result = _result;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top drag pill
              Center(
                child: Container(
                  width: 44,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: PortalTheme.borderStrong.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Header with modern AI badge and close button
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: PortalTheme.navy,
                      borderRadius: BorderRadius.circular(PortalTheme.radiusLg),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.auto_awesome_rounded,
                        size: 20,
                        color: PortalTheme.gold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2.5,
                              ),
                              decoration: BoxDecoration(
                                color: PortalTheme.navy.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(
                                  PortalTheme.radiusSm,
                                ),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.auto_awesome_rounded,
                                    size: 11,
                                    color: PortalTheme.navy,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'AI ASSISTANT',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.6,
                                      color: PortalTheme.navy,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (_remaining != null) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2.5,
                                ),
                                decoration: BoxDecoration(
                                  color: (_remaining! <= 3
                                          ? PortalTheme.warning
                                          : PortalTheme.success)
                                      .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(
                                    PortalTheme.radiusSm,
                                  ),
                                ),
                                child: Text(
                                  '$_remaining helps left',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: _remaining! <= 3
                                        ? PortalTheme.warning
                                        : PortalTheme.success,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Find Occupation & Business',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                            color: PortalTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      color: PortalTheme.textSecondary,
                    ),
                    tooltip: 'Close',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Subtitle instructions
              const Text(
                'Describe what you do and what your company does. We\'ll suggest official CHED classifications for Questions 19 and 20.',
                style: PortalTheme.bodySecondary,
              ),
              const SizedBox(height: 14),

              // Input field with clear button
              TextField(
                controller: _controller,
                enabled: !_loading,
                minLines: 2,
                maxLines: 4,
                maxLength: ChedGtsHelpService.maxInput,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _ask(),
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w500,
                  color: PortalTheme.textPrimary,
                  height: 1.4,
                ),
                decoration: InputDecoration(
                  hintText:
                      'e.g. I drive a delivery truck for a logistics company',
                  hintStyle: const TextStyle(
                    color: PortalTheme.textMuted,
                    fontSize: 14,
                  ),
                  filled: true,
                  fillColor: PortalTheme.surfaceMuted.withValues(alpha: 0.7),
                  contentPadding: const EdgeInsets.all(14),
                  suffixIcon: _controller.text.isNotEmpty && !_loading
                      ? IconButton(
                          icon: const Icon(
                            Icons.cancel_rounded,
                            size: 18,
                            color: PortalTheme.textMuted,
                          ),
                          tooltip: 'Clear',
                          onPressed: () {
                            _controller.clear();
                            setState(() {});
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(PortalTheme.radiusLg),
                    borderSide: const BorderSide(color: PortalTheme.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(PortalTheme.radiusLg),
                    borderSide: BorderSide(
                      color: PortalTheme.border.withValues(alpha: 0.9),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(PortalTheme.radiusLg),
                    borderSide: const BorderSide(
                      color: PortalTheme.navy,
                      width: 1.8,
                    ),
                  ),
                ),
              ),

              // Privacy banner
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: PortalTheme.navy.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(PortalTheme.radiusMd),
                  border: Border.all(
                    color: PortalTheme.navy.withValues(alpha: 0.08),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(
                        Icons.shield_outlined,
                        size: 15,
                        color: PortalTheme.navyMid,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: PortalTheme.caption.copyWith(
                            fontSize: 11.5,
                            height: 1.35,
                            color: PortalTheme.textSecondary,
                          ),
                          children: const [
                            TextSpan(
                              text: 'Private & ephemeral: ',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: PortalTheme.textPrimary,
                              ),
                            ),
                            TextSpan(
                              text:
                                  'Your description is processed securely only to generate suggestions and is never saved. Do not include personal names or contact info.',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Action button (Solid Navy)
              FilledButton.icon(
                onPressed: _loading ? null : _ask,
                style: FilledButton.styleFrom(
                  backgroundColor: PortalTheme.navy,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor:
                      PortalTheme.borderStrong.withValues(alpha: 0.4),
                  disabledForegroundColor: PortalTheme.textMuted,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(PortalTheme.radiusMd),
                  ),
                ),
                icon: _loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(
                        Icons.auto_awesome_rounded,
                        size: 18,
                        color: PortalTheme.gold,
                      ),
                label: Text(
                  _loading
                      ? 'Analyzing suggestions…'
                      : (result == null
                          ? 'Get AI Suggestions'
                          : 'Try Another Description'),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
              ),

              // Loading shimmer indicator
              if (_loading) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: PortalTheme.surfaceMuted.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(PortalTheme.radiusLg),
                    border: Border.all(
                      color: PortalTheme.border.withValues(alpha: 0.9),
                    ),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: PortalTheme.navy,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Consulting official CHED taxonomy…',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: PortalTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Matching your job description to CHED Q19 & Q20 classifications.',
                              style: PortalTheme.caption.copyWith(
                                color: PortalTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Error feedback
              if (_error != null) ...[
                const SizedBox(height: 14),
                _Notice(
                  icon: Icons.error_outline_rounded,
                  color: PortalTheme.danger,
                  title: 'Unable to get suggestions',
                  text: _error!,
                ),
              ],

              // Unclear feedback with helpful guidance
              if (result != null && result.unclear) ...[
                const SizedBox(height: 14),
                _Notice(
                  icon: Icons.psychology_alt_outlined,
                  color: PortalTheme.warning,
                  title: 'Could you provide a little more detail?',
                  text:
                      "We couldn't clearly match your job with official classifications. Try mentioning both your role and the kind of company you work for (e.g., \"I answer customer calls for an IT and BPO company\").",
                ),
              ],

              // Suggestions result section
              if (result != null && !result.unclear) ...[
                const SizedBox(height: 20),

                // One-tap Apply Both Banner (massive UX improvement!)
                if (result.occupation.isNotEmpty &&
                    result.lineOfBusiness != null &&
                    !(_usedOccupation && _usedLine)) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: PortalTheme.surfaceMuted,
                      borderRadius: BorderRadius.circular(PortalTheme.radiusLg),
                      border: Border.all(
                        color: PortalTheme.border,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: PortalTheme.navy,
                            borderRadius: BorderRadius.circular(
                              PortalTheme.radiusMd,
                            ),
                          ),
                          child: const Icon(
                            Icons.done_all_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Ready to apply both?',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: PortalTheme.navyDeep,
                                ),
                              ),
                              Text(
                                'Apply Q19 occupation & Q20 industry at once.',
                                style: PortalTheme.caption.copyWith(
                                  fontSize: 11.5,
                                  color: PortalTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: () => _useBoth(result),
                          style: FilledButton.styleFrom(
                            backgroundColor: PortalTheme.navy,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                PortalTheme.radiusMd,
                              ),
                            ),
                          ),
                          child: const Text(
                            'Apply Both',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Card 1: Question 19 (Occupation)
                if (result.occupation.isNotEmpty) ...[
                  _SuggestionCard(
                    questionBadge: 'QUESTION 19',
                    fieldTitle: 'Present Occupation',
                    icon: Icons.work_outline_rounded,
                    value: result.occupation,
                    used: _usedOccupation,
                    onUse: () => _useOccupation(result),
                  ),
                ],

                // Card 2: Question 20 (Major Line of Business)
                if (result.lineOfBusiness != null) ...[
                  const SizedBox(height: 12),
                  _SuggestionCard(
                    questionBadge: 'QUESTION 20',
                    fieldTitle: 'Major Line of Business',
                    icon: Icons.domain_rounded,
                    value:
                        result.lineOfBusiness == ChedGtsBuiltin.othersSpecify &&
                            result.specifyText.isNotEmpty
                        ? 'Others: ${result.specifyText}'
                        : result.lineOfBusiness!,
                    reason: result.reason,
                    used: _usedLine,
                    onUse: () => _useLine(result),
                  ),
                ],

                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      size: 14,
                      color: PortalTheme.textMuted,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Suggestions are recommendations only. You can adjust your final choices anytime on the survey form.',
                        style: PortalTheme.caption.copyWith(
                          fontSize: 11.5,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ],

              // Footer quota summary
              if (_remaining != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: PortalTheme.surfaceMuted,
                    borderRadius: BorderRadius.circular(PortalTheme.radiusMd),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.bolt_rounded,
                        size: 16,
                        color: _remaining! <= 3
                            ? PortalTheme.warning
                            : PortalTheme.navy,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '$_remaining of ${ChedGtsHelpService.dailyLimit} daily AI requests available today',
                          style: PortalTheme.caption.copyWith(
                            fontWeight: FontWeight.w600,
                            color: PortalTheme.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 16),

              // Close / Done button
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: PortalTheme.secondaryButton().copyWith(
                  minimumSize: const WidgetStatePropertyAll(Size.fromHeight(44)),
                  shape: WidgetStatePropertyAll(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(PortalTheme.radiusMd),
                    ),
                  ),
                ),
                child: Text(
                  _usedOccupation || _usedLine ? 'Done & Return' : 'Close',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({
    required this.questionBadge,
    required this.fieldTitle,
    required this.icon,
    required this.value,
    required this.used,
    required this.onUse,
    this.reason,
  });

  final String questionBadge;
  final String fieldTitle;
  final IconData icon;
  final String value;
  final String? reason;
  final bool used;
  final VoidCallback onUse;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(PortalTheme.radiusLg),
        border: Border.all(
          color: used
              ? PortalTheme.success.withValues(alpha: 0.6)
              : PortalTheme.border.withValues(alpha: 0.9),
          width: used ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Tag + Field Title + Action Button
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: used
                      ? PortalTheme.success.withValues(alpha: 0.12)
                      : PortalTheme.navy.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(PortalTheme.radiusSm),
                ),
                child: Icon(
                  icon,
                  size: 16,
                  color: used ? PortalTheme.success : PortalTheme.navy,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      questionBadge,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: used
                            ? PortalTheme.success
                            : PortalTheme.textSecondary,
                      ),
                    ),
                    Text(
                      fieldTitle,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: PortalTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              if (used)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: PortalTheme.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(PortalTheme.radiusSm),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        size: 14,
                        color: PortalTheme.success,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Applied',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: PortalTheme.success,
                        ),
                      ),
                    ],
                  ),
                )
              else
                FilledButton.tonalIcon(
                  onPressed: onUse,
                  style: FilledButton.styleFrom(
                    backgroundColor: PortalTheme.navy.withValues(alpha: 0.08),
                    foregroundColor: PortalTheme.navy,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    minimumSize: const Size(0, 34),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(PortalTheme.radiusMd),
                    ),
                  ),
                  icon: const Icon(Icons.check_rounded, size: 14),
                  label: const Text(
                    'Use this',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Suggested value highlight
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: used
                  ? PortalTheme.success.withValues(alpha: 0.04)
                  : PortalTheme.surfaceMuted.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(PortalTheme.radiusMd),
            ),
            child: Text(
              value,
              style: PortalTheme.cardTitle.copyWith(
                fontSize: 15.5,
                fontWeight: FontWeight.w700,
                color: PortalTheme.navyDeep,
                height: 1.3,
              ),
            ),
          ),

          // AI Reasoning callout box
          if (reason != null && reason!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: PortalTheme.navy.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(PortalTheme.radiusMd),
                border: Border.all(
                  color: PortalTheme.navy.withValues(alpha: 0.06),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 1.5),
                    child: Icon(
                      Icons.tips_and_updates_outlined,
                      size: 15,
                      color: PortalTheme.navyMid,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      reason!,
                      style: PortalTheme.bodySecondary.copyWith(
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
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

class _Notice extends StatelessWidget {
  const _Notice({
    required this.icon,
    required this.color,
    required this.text,
    this.title,
  });

  final IconData icon;
  final Color color;
  final String text;
  final String? title;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(PortalTheme.radiusLg),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null) ...[
                  Text(
                    title!,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 3),
                ],
                Text(
                  text,
                  style: PortalTheme.body.copyWith(
                    fontSize: 12.5,
                    height: 1.4,
                    color: PortalTheme.textPrimary,
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
