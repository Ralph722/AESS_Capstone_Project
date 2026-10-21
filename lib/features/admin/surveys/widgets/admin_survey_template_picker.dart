import 'package:flutter/material.dart';
import 'package:alumni_system/features/admin/surveys/widgets/admin_survey_ui.dart';
import 'package:alumni_system/features/surveys/ched_gts/ched_gts_schema.dart';
import 'package:alumni_system/shared/widgets/admin/admin_theme.dart';

/// Result of the new-survey dialog.
sealed class NewSurveyChoice {}

class NewSurveyBlank extends NewSurveyChoice {}

/// Locked official CHED GTS (built-in schema with skip logic).
class NewSurveyChedBuiltin extends NewSurveyChoice {}

/// Lets admin publish built-in CHED GTS or start a blank custom survey.
Future<NewSurveyChoice?> showAdminNewSurveyPicker(BuildContext context) {
  return showDialog<NewSurveyChoice>(
    context: context,
    barrierColor: const Color(0xFF0F172A).withValues(alpha: 0.45),
    builder: (ctx) => const _AdminSurveyTemplatePickerDialog(),
  );
}

class _AdminSurveyTemplatePickerDialog extends StatelessWidget {
  const _AdminSurveyTemplatePickerDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 12,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AdminColors.border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Create survey',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AdminSurveyTheme.textPrimary,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Choose the Official CHED GTS for tracer waves, '
                          'or start blank for a custom form.',
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.45,
                            color: AdminSurveyTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.close,
                      color: AdminSurveyTheme.textMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _ChoiceCard(
                recommended: true,
                badge: 'Official · v${ChedGtsBuiltin.schemaVersion}',
                badgeTone: _BadgeTone.official,
                title: ChedGtsBuiltin.defaultTitle,
                body:
                    'Locked form (sections A–D) with employment skip logic. '
                    'Alumni answer it inline on Tracer after you publish.',
                chips: const ['Sections A–D', 'Skip logic', 'Inline on Tracer'],
                icon: Icons.lock_outline,
                onTap: () => Navigator.pop(context, NewSurveyChedBuiltin()),
              ),
              const SizedBox(height: 12),
              _ChoiceCard(
                recommended: false,
                badge: 'Custom',
                badgeTone: _BadgeTone.custom,
                title: 'Blank survey',
                body:
                    'Build your own questions, types, sections, and '
                    'conditional visibility. Best for non-CHED forms.',
                chips: const ['Editable', 'Preview', 'Visibility rules'],
                icon: Icons.edit_note_outlined,
                onTap: () => Navigator.pop(context, NewSurveyBlank()),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    foregroundColor: AdminSurveyTheme.textSecondary,
                  ),
                  child: const Text('Cancel'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _BadgeTone { official, custom }

class _ChoiceCard extends StatefulWidget {
  const _ChoiceCard({
    required this.recommended,
    required this.badge,
    required this.badgeTone,
    required this.title,
    required this.body,
    required this.chips,
    required this.icon,
    required this.onTap,
  });

  final bool recommended;
  final String badge;
  final _BadgeTone badgeTone;
  final String title;
  final String body;
  final List<String> chips;
  final IconData icon;
  final VoidCallback onTap;

  @override
  State<_ChoiceCard> createState() => _ChoiceCardState();
}

class _ChoiceCardState extends State<_ChoiceCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final borderColor = _hovered
        ? AdminSurveyTheme.primary.withValues(alpha: 0.45)
        : AdminSurveyTheme.border;
    final bg = _hovered ? AdminColors.rowHover : Colors.white;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AdminSurveyTheme.radiusMd),
          border: Border.all(color: borderColor, width: 1),
          boxShadow: _hovered
              ? [
                  BoxShadow(
                    color: AdminSurveyTheme.primary.withValues(alpha: 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(AdminSurveyTheme.radiusMd),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: widget.recommended
                              ? AdminColors.accent.withValues(alpha: 0.16)
                              : AdminColors.primaryTint,
                          borderRadius: BorderRadius.circular(
                            AdminSurveyTheme.radiusSm,
                          ),
                          border: Border.all(color: AdminSurveyTheme.border),
                        ),
                        child: Icon(
                          widget.icon,
                          size: 18,
                          color: AdminSurveyTheme.primary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            _Badge(
                              label: widget.badge,
                              tone: widget.badgeTone,
                            ),
                            if (widget.recommended)
                              const Text(
                                'Recommended',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AdminSurveyTheme.primary,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 14,
                        color: AdminSurveyTheme.textMuted
                            .withValues(alpha: _hovered ? 1 : 0.7),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      height: 1.3,
                      color: AdminSurveyTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.body,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.45,
                      color: AdminSurveyTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final c in widget.chips) _FeatureChip(label: c),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.tone});

  final String label;
  final _BadgeTone tone;

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color fg;
    switch (tone) {
      case _BadgeTone.official:
        bg = AdminSurveyTheme.infoBg;
        fg = AdminSurveyTheme.primary;
      case _BadgeTone.custom:
        bg = AdminSurveyTheme.surface;
        fg = AdminSurveyTheme.textSecondary;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: tone == _BadgeTone.custom
            ? Border.all(color: AdminSurveyTheme.border)
            : null,
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }
}

class _FeatureChip extends StatelessWidget {
  const _FeatureChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AdminSurveyTheme.card,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AdminSurveyTheme.border),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AdminSurveyTheme.textSecondary,
        ),
      ),
    );
  }
}
