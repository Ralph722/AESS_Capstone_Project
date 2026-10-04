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
    constraints: const BoxConstraints(maxWidth: 560),
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

  bool _loading = false;
  String? _error;
  ChedGtsHelpSuggestion? _result;
  int? _remaining;
  bool _usedOccupation = false;
  bool _usedLine = false;

  @override
  void dispose() {
    _controller.dispose();
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
  }

  void _useLine(ChedGtsHelpSuggestion r) {
    widget.onApply(chedGtsLineOfBusinessUpdates(r), r);
    setState(() => _usedLine = true);
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
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: PortalTheme.borderStrong,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: PortalTheme.gold.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(PortalTheme.radiusMd),
                    ),
                    child: const Icon(
                      Icons.auto_awesome_rounded,
                      size: 20,
                      color: PortalTheme.navy,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Find your occupation and line of business',
                      style: PortalTheme.sectionTitle,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Text(
                'Describe what you do and what your company does. We\'ll '
                'suggest answers for questions 19 and 20.',
                style: PortalTheme.bodySecondary,
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _controller,
                enabled: !_loading,
                minLines: 2,
                maxLines: 4,
                maxLength: ChedGtsHelpService.maxInput,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _ask(),
                decoration: InputDecoration(
                  hintText:
                      'e.g. I drive a delivery truck for a logistics company',
                  filled: true,
                  fillColor: PortalTheme.surfaceMuted,
                  contentPadding: const EdgeInsets.all(14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(PortalTheme.radiusLg),
                    borderSide: const BorderSide(color: PortalTheme.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(PortalTheme.radiusLg),
                    borderSide: const BorderSide(color: PortalTheme.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(PortalTheme.radiusLg),
                    borderSide: const BorderSide(
                      color: PortalTheme.navy,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.lock_outline_rounded,
                    size: 14,
                    color: PortalTheme.textMuted,
                  ),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Your description is sent to Google Gemini to generate '
                      "help and isn't saved. Don't include your name or "
                      'contact details.',
                      style: PortalTheme.caption,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: _loading ? null : _ask,
                style: PortalTheme.primaryButton(),
                icon: _loading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.auto_awesome_rounded, size: 18),
                label: Text(
                  _loading
                      ? 'Thinking…'
                      : (result == null ? 'Get suggestions' : 'Try again'),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                _Notice(
                  icon: Icons.info_outline_rounded,
                  color: PortalTheme.danger,
                  text: _error!,
                ),
              ],
              if (result != null && result.unclear) ...[
                const SizedBox(height: 12),
                const _Notice(
                  icon: Icons.help_outline_rounded,
                  color: PortalTheme.warning,
                  text:
                      "We couldn't tell your job from that. Try saying what "
                      'you do and what your company does, e.g. "I answer '
                      'customer calls for a BPO company".',
                ),
              ],
              if (result != null && !result.unclear) ...[
                const SizedBox(height: 16),
                if (result.occupation.isNotEmpty)
                  _SuggestionCard(
                    label: 'Q19 · Present occupation',
                    value: result.occupation,
                    used: _usedOccupation,
                    onUse: () => _useOccupation(result),
                  ),
                if (result.lineOfBusiness != null) ...[
                  const SizedBox(height: 10),
                  _SuggestionCard(
                    label: 'Q20 · Major line of business',
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
                const Text(
                  'Suggestion only. You choose the final answer and can '
                  'change it anytime.',
                  style: PortalTheme.caption,
                ),
              ],
              if (_remaining != null) ...[
                const SizedBox(height: 6),
                Text(
                  '$_remaining of ${ChedGtsHelpService.dailyLimit} helps left '
                  'today',
                  style: PortalTheme.caption,
                ),
              ],
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: PortalTheme.secondaryButton(),
                child: Text(_usedOccupation || _usedLine ? 'Done' : 'Close'),
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
    required this.label,
    required this.value,
    required this.used,
    required this.onUse,
    this.reason,
  });

  final String label;
  final String value;
  final String? reason;
  final bool used;
  final VoidCallback onUse;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(PortalTheme.radiusLg),
        border: Border.all(
          color: used
              ? PortalTheme.success.withValues(alpha: 0.5)
              : PortalTheme.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: PortalTheme.meta),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  value,
                  style: PortalTheme.cardTitle.copyWith(height: 1.3),
                ),
              ),
              const SizedBox(width: 10),
              used
                  ? const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_rounded,
                            size: 16,
                            color: PortalTheme.success,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Added',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: PortalTheme.success,
                            ),
                          ),
                        ],
                      ),
                    )
                  : TextButton(
                      onPressed: onUse,
                      style: PortalTheme.ghostButton(dense: true).copyWith(
                        foregroundColor: const WidgetStatePropertyAll(
                          PortalTheme.navy,
                        ),
                      ),
                      child: const Text('Use this'),
                    ),
            ],
          ),
          if (reason != null && reason!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(reason!, style: PortalTheme.bodySecondary),
          ],
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.color, required this.text});

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(PortalTheme.radiusMd),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: PortalTheme.body.copyWith(fontSize: 13, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
