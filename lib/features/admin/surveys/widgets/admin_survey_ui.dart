import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:alumni_system/features/admin/roster/widgets/alumni_directory_ui.dart';
import 'package:alumni_system/features/surveys/models/survey_model.dart';
import 'package:alumni_system/shared/widgets/admin/admin_buttons.dart';
import 'package:alumni_system/shared/widgets/admin/admin_density.dart';
import 'package:alumni_system/shared/widgets/admin/admin_page_header.dart';
import 'package:alumni_system/shared/widgets/admin/admin_theme.dart';
import 'package:alumni_system/shared/widgets/user/skeleton.dart';

/// Visual chrome for admin Surveys — reuses [AdminDirectoryTheme] (no second navy).
abstract final class AdminSurveyTheme {
  static const primary = AdminDirectoryTheme.primary;
  static const background = AdminDirectoryTheme.background;
  static const surface = AdminDirectoryTheme.surface;
  static const card = AdminDirectoryTheme.card;
  static const border = AdminDirectoryTheme.border;
  static const textPrimary = AdminDirectoryTheme.textPrimary;
  static const textSecondary = AdminDirectoryTheme.textSecondary;
  static const textMuted = AdminDirectoryTheme.textMuted;
  static const success = AdminDirectoryTheme.success;
  static const successBg = AdminDirectoryTheme.successBg;
  static const warning = AdminDirectoryTheme.warning;
  static const warningBg = AdminDirectoryTheme.warningBg;
  static const infoBg = AdminDirectoryTheme.infoBg;
  static const danger = AdminDirectoryTheme.danger;
  static const dangerBg = AdminDirectoryTheme.dangerBg;

  static const space1 = AdminDirectoryTheme.space1;
  static const space2 = AdminDirectoryTheme.space2;
  static const space3 = AdminDirectoryTheme.space3;
  static const space4 = AdminDirectoryTheme.space4;
  static const sectionGap = AdminDensity.sectionGap;
  static const cardPadding = AdminDensity.cardPadding;
  static const gridGap = AdminDensity.gridGap;
  static const listItemGap = AdminDensity.listItemGap;
  static const buttonHeight = AdminDirectoryTheme.buttonHeight;
  static const toolbarControlHeight = AdminDirectoryTheme.toolbarControlHeight;
  static const radiusSm = AdminDirectoryTheme.radiusSm;
  static const radiusMd = AdminDirectoryTheme.radiusMd;
  static const radiusLg = AdminDirectoryTheme.radiusLg;
  static const contentMaxWidth = 880.0;

  static BoxDecoration surfaceCard({bool hovered = false}) =>
      AdminDirectoryTheme.surfaceCard(hovered: hovered);

  /// Compact search / toolbar field (matches Alumni Directory).
  static InputDecoration toolbarFieldDecoration({
    String? hint,
    Widget? prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      isDense: true,
      hintText: hint,
      hintStyle: const TextStyle(
        color: textMuted,
        fontSize: 13.5,
      ),
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      prefixIconConstraints: const BoxConstraints(
        minWidth: 40,
        minHeight: toolbarControlHeight,
      ),
      suffixIconConstraints: const BoxConstraints(
        minWidth: 36,
        minHeight: toolbarControlHeight,
      ),
      filled: true,
      fillColor: background,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusSm),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusSm),
        borderSide: const BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusSm),
        borderSide: const BorderSide(color: primary, width: 1.5),
      ),
    );
  }

  static InputDecoration fieldDecoration({
    required String label,
    String? hint,
    String? helper,
    String? error,
    bool dense = true,
  }) {
    return InputDecoration(
      isDense: dense,
      labelText: label,
      hintText: hint,
      helperText: helper,
      errorText: error,
      filled: true,
      fillColor: background,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusSm),
        borderSide: const BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusSm),
        borderSide: const BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusSm),
        borderSide: const BorderSide(color: primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusSm),
        borderSide: const BorderSide(color: danger),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusSm),
        borderSide: const BorderSide(color: danger, width: 1.5),
      ),
    );
  }
}

class SurveyStatusChip extends StatelessWidget {
  const SurveyStatusChip({
    super.key,
    required this.status,
    this.archived = false,
    this.scheduled = false,
    this.windowEnded = false,
  });

  /// "Scheduled" only before the open date; "Window ended" once a published
  /// survey is past its close date.
  factory SurveyStatusChip.fromSurvey(Survey survey) {
    final outside = survey.isScheduledWindow;
    return SurveyStatusChip(
      status: survey.status,
      archived: survey.archived,
      scheduled: outside && !survey.isPastClose,
      windowEnded: outside && survey.isPastClose,
    );
  }

  final SurveyStatus status;
  final bool archived;
  final bool scheduled;
  final bool windowEnded;

  @override
  Widget build(BuildContext context) {
    if (archived) {
      return const _SurveyChip(
        label: 'Archived',
        bg: AdminSurveyTheme.surface,
        fg: AdminSurveyTheme.textMuted,
        icon: Icons.archive_outlined,
      );
    }
    final Color bg;
    final Color fg;
    final String label;
    switch (status) {
      case SurveyStatus.draft:
        bg = AdminSurveyTheme.warningBg;
        fg = AdminSurveyTheme.warning;
        label = 'Draft';
      case SurveyStatus.published:
        if (windowEnded) {
          bg = AdminSurveyTheme.warningBg;
          fg = AdminSurveyTheme.warning;
          label = 'Window ended';
        } else if (scheduled) {
          bg = AdminSurveyTheme.infoBg;
          fg = AdminSurveyTheme.primary;
          label = 'Scheduled';
        } else {
          bg = AdminSurveyTheme.successBg;
          fg = AdminSurveyTheme.success;
          label = 'Published';
        }
      case SurveyStatus.closed:
        bg = AdminSurveyTheme.surface;
        fg = AdminSurveyTheme.textSecondary;
        label = 'Closed';
    }
    return _SurveyChip(label: label, bg: bg, fg: fg);
  }
}

enum SurveyKindLabel { officialChed, chedPreset, custom }

SurveyKindLabel surveyKindLabelFor(Survey survey) {
  if (survey.isChedGtsBuiltin) return SurveyKindLabel.officialChed;
  if (survey.isFromTemplate) return SurveyKindLabel.chedPreset;
  return SurveyKindLabel.custom;
}

class SurveyKindChip extends StatelessWidget {
  const SurveyKindChip({super.key, required this.kind, this.schemaVersion});

  final SurveyKindLabel kind;
  final String? schemaVersion;

  factory SurveyKindChip.fromSurvey(Survey survey) {
    return SurveyKindChip(
      kind: surveyKindLabelFor(survey),
      schemaVersion: survey.schemaVersion ?? survey.templateVersion,
    );
  }

  @override
  Widget build(BuildContext context) {
    switch (kind) {
      case SurveyKindLabel.officialChed:
        final ver = schemaVersion != null && schemaVersion!.isNotEmpty
            ? ' · v$schemaVersion'
            : '';
        return _SurveyChip(
          label: 'Official CHED$ver',
          bg: const Color(0xFFFFF7ED),
          fg: const Color(0xFFC2410C),
          icon: Icons.school_outlined,
        );
      case SurveyKindLabel.chedPreset:
        return _SurveyChip(
          label: 'CHED preset',
          bg: AdminSurveyTheme.warningBg,
          fg: AdminSurveyTheme.warning,
          icon: Icons.fact_check_outlined,
        );
      case SurveyKindLabel.custom:
        return const _SurveyChip(
          label: 'Custom',
          bg: AdminSurveyTheme.surface,
          fg: AdminSurveyTheme.textSecondary,
          icon: Icons.tune_outlined,
        );
    }
  }
}

class _SurveyChip extends StatelessWidget {
  const _SurveyChip({
    required this.label,
    required this.bg,
    required this.fg,
    this.icon,
  });

  final String label;
  final Color bg;
  final Color fg;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: fg.withValues(alpha: 0.20),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

/// Status wording shared by the chip, confirmations and accessibility labels.
String surveyStatusText(Survey survey) {
  if (survey.archived) return 'Archived';
  return switch (survey.status) {
    SurveyStatus.draft => 'Draft',
    SurveyStatus.closed => 'Closed',
    SurveyStatus.published => !survey.isScheduledWindow
        ? 'Published'
        : (survey.isPastClose ? 'Window ended' : 'Scheduled'),
  };
}

/// "Aug 7 – Aug 14, 2026", "Opens …", "Closes …", or null without a window.
String? surveyWindowText(Survey survey) {
  final open = survey.openAt;
  final close = survey.closeAt;
  final full = DateFormat.yMMMd();
  if (open != null && close != null) {
    final start = open.year == close.year
        ? DateFormat.MMMd().format(open)
        : full.format(open);
    return '$start – ${full.format(close)}';
  }
  if (open != null) return 'Opens ${full.format(open)}';
  if (close != null) return 'Closes ${full.format(close)}';
  return null;
}

/// Submitted ÷ assigned as a whole percent; null when nobody is assigned.
int? surveyResponseRate(Survey survey) {
  if (survey.assignmentCount <= 0) return null;
  return (survey.responseCount * 100 / survey.assignmentCount).round();
}

/// Title, status and window (or created date) — tells identical titles apart.
String surveyIdentityText(Survey survey) {
  final title = survey.title.isEmpty ? 'Untitled survey' : survey.title;
  final when = surveyWindowText(survey) ??
      'Created ${DateFormat.yMMMd().format(survey.createdAt)}';
  return '“$title” · ${surveyStatusText(survey)} · $when';
}

/// Service messages are shown as-is; technical errors fall back to
/// [fallback].
String surveyFriendlyError(Object error, String fallback) {
  var text = '$error';
  while (text.startsWith('Exception: ')) {
    text = text.substring('Exception: '.length);
  }
  text = text.trim();
  final technical =
      text.isEmpty ||
      text.startsWith('Error ') ||
      text.contains('Exception') ||
      text.length > 160;
  return technical ? fallback : text;
}

class SurveySectionCard extends StatelessWidget {
  const SurveySectionCard({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AdminSurveyTheme.space2),
      decoration: AdminSurveyTheme.surfaceCard(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AdminText.sectionTitle),
                    if (subtitle != null && subtitle!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: AdminText.caption.copyWith(height: 1.35),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: AdminSurveyTheme.space1),
                trailing!,
              ],
            ],
          ),
          const SizedBox(height: AdminDensity.gridGap),
          child,
        ],
      ),
    );
  }
}

class SurveyCallout extends StatelessWidget {
  const SurveyCallout({
    super.key,
    required this.title,
    required this.body,
    this.icon = Icons.info_outline,
    this.tone = SurveyCalloutTone.info,
  });

  final String title;
  final String body;
  final IconData icon;
  final SurveyCalloutTone tone;

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color fg;
    final Color border;
    switch (tone) {
      case SurveyCalloutTone.info:
        bg = AdminSurveyTheme.infoBg;
        fg = AdminSurveyTheme.primary;
        border = AdminSurveyTheme.primary.withValues(alpha: 0.15);
      case SurveyCalloutTone.warning:
        bg = AdminSurveyTheme.warningBg;
        fg = AdminSurveyTheme.warning;
        border = AdminSurveyTheme.warning.withValues(alpha: 0.25);
      case SurveyCalloutTone.neutral:
        bg = AdminSurveyTheme.surface;
        fg = AdminSurveyTheme.textSecondary;
        border = AdminSurveyTheme.border;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AdminDensity.cardPadding),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AdminSurveyTheme.radiusMd),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: fg, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: fg,
                    fontSize: AdminDensity.sectionTitleFontSize,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  body,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    color: AdminSurveyTheme.textPrimary,
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

enum SurveyCalloutTone { info, warning, neutral }

/// Top bar for survey panels shown inside the admin dashboard (not a route).
class SurveyInlinePanelHeader extends StatelessWidget {
  const SurveyInlinePanelHeader({
    super.key,
    required this.title,
    required this.onClose,
    this.subtitle = 'Back to surveys',
    this.backTooltip,
    this.actions = const [],
    this.chips = const [],
    this.backBusy = false,
    this.margin,
  });

  final String title;

  /// Hidden when empty.
  final String subtitle;
  final String? backTooltip;
  final VoidCallback onClose;
  final List<Widget> actions;

  /// Shown after the title; wrap below it when space runs out.
  final List<Widget> chips;

  /// Replaces the back arrow with a spinner (e.g. while saves finish).
  final bool backBusy;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin ?? const EdgeInsets.fromLTRB(12, 12, 12, 0),
      decoration: BoxDecoration(
        color: AdminColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AdminColors.border),
        boxShadow: AdminSurfaces.cardShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 16, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: AdminColors.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AdminColors.border),
              ),
              child: IconButton(
                icon: backBusy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AdminColors.primary,
                        ),
                      )
                    : const Icon(Icons.arrow_back, size: 18),
                tooltip: backTooltip ?? subtitle,
                onPressed: backBusy ? null : onClose,
                style: IconButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: AdminColors.textPrimary,
                  padding: const EdgeInsets.all(8),
                ),
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final titleText = Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AdminText.sectionTitle,
                  );
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (chips.isEmpty)
                        titleText
                      else
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: constraints.maxWidth,
                              ),
                              child: titleText,
                            ),
                            ...chips,
                          ],
                        ),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AdminText.caption,
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
            if (actions.isNotEmpty) ...[const SizedBox(width: 8), ...actions],
          ],
        ),
      ),
    );
  }
}

/// Flat group inside the survey edit pane: small-caps heading, helper line,
/// optional trailing widget, and a divider above every group but the first.
class SurveyEditorSection extends StatelessWidget {
  const SurveyEditorSection({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.trailing,
    this.first = false,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;
  final bool first;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(top: first ? 4 : 16, bottom: 16),
      decoration: first
          ? null
          : const BoxDecoration(
              border: Border(top: BorderSide(color: AdminColors.border)),
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    title.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                      color: AdminColors.textPrimary,
                    ),
                  ),
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                trailing!,
              ],
            ],
          ),
          if (subtitle != null && subtitle!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(subtitle!, style: AdminText.caption.copyWith(height: 1.4)),
          ],
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

/// Loading placeholder shaped like the editor (edit pane + preview).
class SurveyEditorSkeleton extends StatelessWidget {
  const SurveyEditorSkeleton({super.key, this.sideBySideMinWidth = 900});

  final double sideBySideMinWidth;

  static BoxDecoration get _pane => BoxDecoration(
    color: AdminColors.card,
    borderRadius: BorderRadius.circular(AdminSurfaces.radiusMd),
    border: Border.all(color: AdminColors.border),
  );

  Widget _editPane() {
    Widget group(double titleWidth, List<Widget> fields) => Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Skeleton(width: titleWidth, height: 11),
          const SizedBox(height: 8),
          const FractionallySizedBox(
            widthFactor: 0.7,
            child: Skeleton(height: 10),
          ),
          const SizedBox(height: 12),
          ...fields,
        ],
      ),
    );
    const field = Padding(
      padding: EdgeInsets.only(bottom: 10),
      child: Skeleton(
        height: 40,
        borderRadius: BorderRadius.all(Radius.circular(8)),
      ),
    );
    return Container(
      decoration: _pane,
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            group(70, const [field, field]),
            group(80, const [field, field]),
            group(84, const [field]),
            group(96, const [field, field, field]),
          ],
        ),
      ),
    );
  }

  Widget _previewPane() {
    return Container(
      decoration: _pane,
      padding: const EdgeInsets.all(16),
      child: const SingleChildScrollView(
        physics: NeverScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Skeleton(width: 80, height: 13),
            SizedBox(height: 8),
            Skeleton(width: 180, height: 10),
            SizedBox(height: 24),
            FractionallySizedBox(widthFactor: 0.6, child: Skeleton(height: 16)),
            SizedBox(height: 16),
            Skeleton(height: 64),
            SizedBox(height: 12),
            Skeleton(height: 64),
            SizedBox(height: 12),
            Skeleton(height: 64),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ShimmerScope(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= sideBySideMinWidth;
          return Padding(
            padding: const EdgeInsets.all(12),
            child: wide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(flex: 11, child: _editPane()),
                      const SizedBox(width: 14),
                      Expanded(flex: 9, child: _previewPane()),
                    ],
                  )
                : _editPane(),
          );
        },
      ),
    );
  }
}

/// Keeps a Responses table at [minWidth] and scrolls it sideways when the
/// available width is smaller (fixed-width columns + avatar can't shrink).
class SurveyResponsesTableFrame extends StatefulWidget {
  const SurveyResponsesTableFrame({
    super.key,
    required this.child,
    this.minWidth = 720,
  });

  final Widget child;
  final double minWidth;

  @override
  State<SurveyResponsesTableFrame> createState() =>
      _SurveyResponsesTableFrameState();
}

class _SurveyResponsesTableFrameState extends State<SurveyResponsesTableFrame> {
  final _horizontal = ScrollController();

  @override
  void dispose() {
    _horizontal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= widget.minWidth) return widget.child;
        return Scrollbar(
          controller: _horizontal,
          thumbVisibility: true,
          child: SingleChildScrollView(
            controller: _horizontal,
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: widget.minWidth,
              height: constraints.maxHeight,
              child: widget.child,
            ),
          ),
        );
      },
    );
  }
}

/// Loading placeholder for the Survey Responses tabs: KPI row + two panes
/// (Overview) or toolbar + table rows (Pending / Submitted).
class SurveyResponsesSkeleton extends StatelessWidget {
  const SurveyResponsesSkeleton.overview({super.key}) : table = false;

  const SurveyResponsesSkeleton.table({super.key}) : table = true;

  final bool table;

  static BoxDecoration get _box => BoxDecoration(
    color: AdminColors.card,
    borderRadius: BorderRadius.circular(AdminSurfaces.radiusMd),
    border: Border.all(color: AdminColors.border),
  );

  Widget _kpi() => Container(
    height: 92,
    decoration: _box,
    padding: const EdgeInsets.all(14),
    child: const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Skeleton(width: 70, height: 10),
        SizedBox(height: 12),
        Skeleton(width: 44, height: 20),
        SizedBox(height: 8),
        Skeleton(width: 90, height: 10),
      ],
    ),
  );

  Widget _pane(List<double> blockHeights) => Container(
    decoration: _box,
    padding: const EdgeInsets.all(16),
    child: SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Skeleton(width: 90, height: 11),
          const SizedBox(height: 14),
          for (final h in blockHeights) ...[
            Skeleton(
              height: h,
              borderRadius: const BorderRadius.all(Radius.circular(8)),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    ),
  );

  Widget _overview(BoxConstraints constraints) {
    final wide = constraints.maxWidth >= 900;
    final kpis = wide
        ? Row(
            children: [
              for (var i = 0; i < 4; i++) ...[
                if (i > 0) const SizedBox(width: 12),
                Expanded(child: _kpi()),
              ],
            ],
          )
        : Column(
            children: [
              Row(
                children: [
                  Expanded(child: _kpi()),
                  const SizedBox(width: 12),
                  Expanded(child: _kpi()),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _kpi()),
                  const SizedBox(width: 12),
                  Expanded(child: _kpi()),
                ],
              ),
            ],
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        kpis,
        const SizedBox(height: 12),
        Expanded(
          child: wide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(flex: 4, child: _pane(const [40, 34, 34, 120])),
                    const SizedBox(width: 14),
                    Expanded(flex: 6, child: _pane(const [56, 140, 96, 96])),
                  ],
                )
              : _pane(const [40, 34, 120, 140]),
        ),
      ],
    );
  }

  Widget _table() {
    Widget row({bool header = false}) => Container(
      height: header ? 40 : 52,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: header ? AdminColors.surface : null,
        border: const Border(bottom: BorderSide(color: AdminColors.border)),
      ),
      child: Row(
        children: [
          if (!header) ...[
            const Skeleton(
              width: 28,
              height: 28,
              borderRadius: BorderRadius.all(Radius.circular(14)),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            flex: 3,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Skeleton(width: header ? 50 : 140, height: 10),
            ),
          ),
          for (var i = 0; i < 4; i++)
            Expanded(
              flex: 2,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Skeleton(width: header ? 44 : 64, height: 10),
              ),
            ),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Row(
          children: [
            Expanded(
              child: Skeleton(
                height: 40,
                borderRadius: BorderRadius.all(Radius.circular(8)),
              ),
            ),
            SizedBox(width: 12),
            Skeleton(
              width: 96,
              height: 32,
              borderRadius: BorderRadius.all(Radius.circular(8)),
            ),
            SizedBox(width: 8),
            Skeleton(
              width: 96,
              height: 32,
              borderRadius: BorderRadius.all(Radius.circular(8)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Container(
            decoration: _box,
            clipBehavior: Clip.antiAlias,
            child: SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              child: Column(
                children: [
                  row(header: true),
                  for (var i = 0; i < 8; i++) row(),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return ShimmerScope(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: LayoutBuilder(
          builder: (context, constraints) =>
              table ? _table() : _overview(constraints),
        ),
      ),
    );
  }
}

/// Workspace header for the admin Survey Responses panel (Phase 2).
class SurveyResponsesWorkspaceHeader extends StatelessWidget {
  const SurveyResponsesWorkspaceHeader({
    super.key,
    required this.onBack,
    this.survey,
    this.overflowItems = const [],
    this.onOverflowSelected,
    this.overflowEnabled = true,
    this.overflowBusy = false,
    this.showBottomBorder = true,
  });

  final Survey? survey;
  final VoidCallback onBack;
  final List<PopupMenuEntry<String>> overflowItems;
  final ValueChanged<String>? onOverflowSelected;
  final bool overflowEnabled;
  final bool overflowBusy;
  final bool showBottomBorder;

  /// Best-effort published timestamp without a dedicated column.
  /// Prefers sticky [Survey.publishedAt], then schedule [Survey.openAt].
  /// Never uses [Survey.updatedAt] — that moves on edits and other writes.
  static DateTime? publishedAtOf(Survey? survey) {
    if (survey == null || survey.status == SurveyStatus.draft) return null;
    return survey.publishedAt ?? survey.openAt;
  }

  @override
  Widget build(BuildContext context) {
    final title = (survey?.title.trim().isNotEmpty == true)
        ? survey!.title.trim()
        : 'Survey responses';

    return Material(
      color: AdminSurveyTheme.card,
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 10, 14, 10),
        decoration: BoxDecoration(
          color: AdminColors.card,
          border: showBottomBorder
              ? const Border(bottom: BorderSide(color: AdminSurveyTheme.border))
              : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded, size: 20),
              tooltip: 'Back to surveys',
              onPressed: onBack,
              style: IconButton.styleFrom(
                foregroundColor: AdminSurveyTheme.textSecondary,
                minimumSize: const Size(
                  AdminDensity.buttonHeight,
                  AdminDensity.buttonHeight,
                ),
                padding: const EdgeInsets.all(8),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 6, bottom: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                        letterSpacing: -0.2,
                        color: AdminSurveyTheme.textPrimary,
                      ),
                    ),
                    if (survey != null) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          SurveyStatusChip.fromSurvey(survey!),
                          SurveyKindChip.fromSurvey(survey!),
                          Text(
                            surveyWindowText(survey!) ?? 'No window set',
                            style: AdminText.caption,
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (overflowItems.isNotEmpty)
              PopupMenuButton<String>(
                enabled: overflowEnabled && !overflowBusy,
                tooltip: 'More actions',
                icon: overflowBusy
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(
                        Icons.more_vert_rounded,
                        color: AdminSurveyTheme.textSecondary,
                      ),
                onSelected: onOverflowSelected,
                itemBuilder: (_) => overflowItems,
              ),
          ],
        ),
      ),
    );
  }
}

/// Declarative tab for [SurveyWorkspaceSegmentedNav] — add entries later without redesign.
class SurveyWorkspaceTabSpec {
  const SurveyWorkspaceTabSpec({
    required this.id,
    required this.label,
    required this.icon,
    this.count,
  });

  final String id;
  final String label;
  final IconData icon;

  /// When null, no count badge is shown (e.g. Overview).
  final int? count;
}

/// Workspace tab bar — evenly spaced underline tabs across the workspace width.
class SurveyWorkspaceSegmentedNav extends StatelessWidget {
  const SurveyWorkspaceSegmentedNav({
    super.key,
    required this.tabs,
    required this.controller,
    this.showBottomBorder = true,
  });

  final List<SurveyWorkspaceTabSpec> tabs;
  final TabController controller;
  final bool showBottomBorder;

  @override
  Widget build(BuildContext context) {
    assert(tabs.isNotEmpty);

    return Material(
      color: AdminSurveyTheme.card,
      child: Container(
        decoration: BoxDecoration(
          border: showBottomBorder
              ? const Border(
                  bottom: BorderSide(color: AdminSurveyTheme.border),
                )
              : null,
        ),
        child: ListenableBuilder(
          listenable: controller,
          builder: (context, _) {
            final selected = controller.index;
            return TabBar(
              controller: controller,
              indicatorSize: TabBarIndicatorSize.label,
              indicatorColor: AdminSurveyTheme.primary,
              indicatorWeight: 2.5,
              labelColor: AdminSurveyTheme.primary,
              unselectedLabelColor: AdminSurveyTheme.textSecondary,
              labelStyle: AdminText.body.copyWith(fontWeight: FontWeight.w700),
              unselectedLabelStyle: AdminText.body.copyWith(
                fontWeight: FontWeight.w500,
              ),
              dividerColor: Colors.transparent,
              overlayColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.hovered) ||
                    states.contains(WidgetState.pressed)) {
                  return AdminSurveyTheme.primary.withValues(alpha: 0.06);
                }
                return Colors.transparent;
              }),
              tabs: [
                for (var i = 0; i < tabs.length; i++)
                  Tab(
                    height: 44,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(tabs[i].icon, size: 17),
                        const SizedBox(width: 7),
                        Text(tabs[i].label),
                        if (tabs[i].count != null) ...[
                          const SizedBox(width: 7),
                          _CountBadge(
                            count: tabs[i].count!,
                            selected: i == selected,
                          ),
                        ],
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Workspace keys: 1/2/3 and ←/→ select tabs, Esc calls [onEscape].
///
/// Tab keys are ignored while a text field has focus: the app-level
/// text-editing shortcuts sit above this widget, so handling them here would
/// swallow typed digits and caret moves.
class SurveyWorkspaceShortcuts extends StatelessWidget {
  const SurveyWorkspaceShortcuts({
    super.key,
    required this.currentTab,
    required this.onSelectTab,
    required this.onEscape,
    required this.child,
  });

  final int Function() currentTab;
  final ValueChanged<int> onSelectTab;
  final VoidCallback onEscape;
  final Widget child;

  static bool get _textFieldHasFocus {
    final focused = FocusManager.instance.primaryFocus?.context;
    if (focused == null) return false;
    return focused.widget is EditableText ||
        focused.findAncestorWidgetOfExactType<EditableText>() != null;
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final keyboard = HardwareKeyboard.instance;
    if (keyboard.isControlPressed ||
        keyboard.isAltPressed ||
        keyboard.isMetaPressed ||
        keyboard.isShiftPressed) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape) {
      if (event is KeyDownEvent) onEscape();
      return KeyEventResult.handled;
    }
    final int? target;
    if (key == LogicalKeyboardKey.digit1) {
      target = 0;
    } else if (key == LogicalKeyboardKey.digit2) {
      target = 1;
    } else if (key == LogicalKeyboardKey.digit3) {
      target = 2;
    } else if (key == LogicalKeyboardKey.arrowLeft) {
      target = currentTab() - 1;
    } else if (key == LogicalKeyboardKey.arrowRight) {
      target = currentTab() + 1;
    } else {
      target = null;
    }
    if (target == null || _textFieldHasFocus) return KeyEventResult.ignored;
    onSelectTab(target);
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(autofocus: true, onKeyEvent: _onKey, child: child);
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count, this.selected = false});

  final int count;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final text = count > 999 ? '999+' : '$count';
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: selected
            ? AdminSurveyTheme.primary.withValues(alpha: 0.12)
            : AdminSurveyTheme.infoBg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: selected
              ? AdminSurveyTheme.primary.withValues(alpha: 0.22)
              : Colors.transparent,
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          height: 1.2,
          color: selected
              ? AdminSurveyTheme.primary
              : AdminSurveyTheme.textSecondary,
        ),
      ),
    );
  }
}

/// Page shell: background, max-width content, optional sticky bottom actions.
class SurveyEditorScaffold extends StatelessWidget {
  const SurveyEditorScaffold({
    super.key,
    required this.body,
    this.bottomBar,
    this.appBar,
    this.header,
  });

  final PreferredSizeWidget? appBar;

  /// When set (inline panel mode), shown instead of [appBar] without a route Scaffold app bar.
  final Widget? header;
  final Widget body;
  final Widget? bottomBar;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (header != null) header!,
        Expanded(child: body),
        if (bottomBar != null) bottomBar!,
      ],
    );

    if (header != null) {
      return ColoredBox(color: AdminSurveyTheme.background, child: content);
    }

    return Scaffold(
      backgroundColor: AdminSurveyTheme.background,
      appBar: appBar,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: body),
          if (bottomBar != null) bottomBar!,
        ],
      ),
    );
  }
}

class SurveyEditorContentWidth extends StatelessWidget {
  const SurveyEditorContentWidth({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: AdminSurveyTheme.contentMaxWidth,
        ),
        child: child,
      ),
    );
  }
}

class SurveyStickyActionBar extends StatelessWidget {
  const SurveyStickyActionBar({
    super.key,
    required this.children,
    this.constrainWidth = true,
    this.leading,
  });

  static const stackBelowWidth = 440.0;

  final List<Widget> children;
  final bool constrainWidth;

  /// Status text on the left; when set, all [children] align right.
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final padded = Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < stackBelowWidth;
          if (narrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (leading != null) ...[leading!, const SizedBox(height: 8)],
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0) const SizedBox(height: 8),
                  children[i],
                ],
              ],
            );
          }
          if (leading != null) {
            return Row(
              children: [
                Expanded(child: leading!),
                for (var i = 0; i < children.length; i++) ...[
                  const SizedBox(width: 12),
                  children[i],
                ],
              ],
            );
          }
          return Row(
            children: [
              children.first,
              const Spacer(),
              for (var i = 1; i < children.length; i++) ...[
                if (i > 1) const SizedBox(width: 12),
                children[i],
              ],
            ],
          );
        },
      ),
    );

    return Material(
      color: AdminColors.card,
      shape: const Border(top: BorderSide(color: AdminColors.border)),
      child: SafeArea(
        top: false,
        child: constrainWidth
            ? SurveyEditorContentWidth(child: padded)
            : padded,
      ),
    );
  }
}

class SurveyPageHeader extends StatelessWidget {
  const SurveyPageHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.actions,
  });

  final String title;
  final String subtitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return AdminPageHeader(
      title: title,
      subtitle: subtitle,
      actions: actions,
      titleColor: AdminSurveyTheme.textPrimary,
      subtitleColor: AdminSurveyTheme.textSecondary,
      titleFontSize: AdminDensity.titleFontSize,
    );
  }
}

/// One row of the admin survey list. From [zoneLayoutMinWidth] it shows
/// identity · responses · window zones; below that a stacked card.
class SurveyListCard extends StatefulWidget {
  const SurveyListCard({
    super.key,
    required this.survey,
    required this.onMenuSelected,
    required this.menuItems,
    this.onOpen,
    this.busy = false,
  });

  static const zoneLayoutMinWidth = 960.0;

  final Survey survey;
  final ValueChanged<String> onMenuSelected;
  final List<PopupMenuEntry<String>> menuItems;
  final VoidCallback? onOpen;

  /// An action for this survey is running: the menu is replaced by a spinner.
  final bool busy;

  @override
  State<SurveyListCard> createState() => _SurveyListCardState();
}

class _SurveyListCardState extends State<SurveyListCard> {
  bool _hovered = false;

  static const _zoneLabel = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.3,
    color: AdminColors.textMuted,
  );
  static const _zoneValue = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: AdminColors.textPrimary,
  );
  static const _secondary = TextStyle(
    fontSize: 12,
    height: 1.35,
    color: AdminColors.textSecondary,
  );

  String get _title =>
      widget.survey.title.isEmpty ? 'Untitled survey' : widget.survey.title;

  @override
  Widget build(BuildContext context) {
    final s = widget.survey;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        margin: const EdgeInsets.only(bottom: AdminDensity.listItemGap),
        decoration: BoxDecoration(
          color: _hovered ? AdminColors.rowHover : AdminColors.card,
          borderRadius: BorderRadius.circular(AdminSurfaces.radiusMd),
          border: Border.all(color: AdminColors.border),
          boxShadow: AdminSurfaces.cardShadow,
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Material(
              type: MaterialType.transparency,
              child: Semantics(
                button: true,
                label: 'Open responses for $_title',
                child: InkWell(
                  onTap: widget.onOpen,
                  child: LayoutBuilder(
                    builder: (context, constraints) =>
                        constraints.maxWidth >=
                            SurveyListCard.zoneLayoutMinWidth
                        ? _buildZones(s)
                        : _buildStacked(s),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildZones(Survey s) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
      child: Row(
        children: [
          _buildIcon(s),
          const SizedBox(width: 12),
          Expanded(child: _buildIdentity(s, meta: _createdText(s))),
          const SizedBox(width: 24),
          SizedBox(width: 180, child: _buildResponsesZone(s)),
          const SizedBox(width: 24),
          SizedBox(width: 200, child: _buildWindowZone(s)),
          const SizedBox(width: 8),
          _buildMenu(),
        ],
      ),
    );
  }

  Widget _buildStacked(Survey s) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildIcon(s),
          const SizedBox(width: 12),
          Expanded(child: _buildIdentity(s, meta: _stackedMeta(s))),
          _buildMenu(),
        ],
      ),
    );
  }

  Widget _buildIcon(Survey s) {
    final official = s.isChedGtsBuiltin;
    return ExcludeSemantics(
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: official
              ? const Color(0xFFFFF7ED)
              : AdminColors.primaryTint,
          borderRadius: BorderRadius.circular(AdminSurfaces.radiusSm),
          border: Border.all(
            color: official
                ? const Color(0xFFFDBA74)
                : AdminColors.primary.withValues(alpha: 0.18),
            width: 1,
          ),
        ),
        child: Icon(
          official ? Icons.school_outlined : Icons.poll_outlined,
          size: 20,
          color: official ? const Color(0xFFC2410C) : AdminColors.primary,
        ),
      ),
    );
  }

  Widget _buildIdentity(Survey s, {required String meta}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Tooltip(
          message: _title,
          waitDuration: const Duration(milliseconds: 600),
          child: Text(
            _title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              height: 1.3,
              color: AdminColors.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            SurveyStatusChip.fromSurvey(s),
            SurveyKindChip.fromSurvey(s),
          ],
        ),
        const SizedBox(height: 6),
        Text(meta, style: _secondary),
      ],
    );
  }

  String _createdText(Survey s) =>
      'Created ${DateFormat.yMMMd().format(s.createdAt)}';

  String _stackedMeta(Survey s) {
    final fmt = DateFormat.yMMMd();
    final rate = surveyResponseRate(s);
    return [
      '${s.assignmentCount} assigned',
      '${s.responseCount} submitted${rate != null ? ' ($rate%)' : ''}',
      _createdText(s),
      if (s.openAt != null) 'Opens ${fmt.format(s.openAt!)}',
      if (s.closeAt != null) 'Closes ${fmt.format(s.closeAt!)}',
    ].join(' · ');
  }

  Widget _buildResponsesZone(Survey s) {
    final rate = surveyResponseRate(s);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('RESPONSES', style: _zoneLabel),
        const SizedBox(height: 4),
        if (rate != null) ...[
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '${s.responseCount} of ${s.assignmentCount}',
                  style: _zoneValue,
                ),
                TextSpan(text: ' · $rate%', style: _secondary),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          ExcludeSemantics(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: (rate / 100).clamp(0.0, 1.0),
                minHeight: 4,
                backgroundColor: AdminColors.surface,
                color: AdminColors.primary,
              ),
            ),
          ),
        ] else ...[
          Text('${s.responseCount} submitted', style: _zoneValue),
          const SizedBox(height: 2),
          const Text('Not assigned yet', style: _secondary),
        ],
      ],
    );
  }

  Widget _buildWindowZone(Survey s) {
    final window = surveyWindowText(s);
    final (String, Color)? state = s.archived ||
            s.status != SurveyStatus.published
        ? null
        : s.isNotYetOpen
        ? ('Not yet open', AdminColors.info)
        : s.isPastClose
        ? ('Window ended', AdminColors.warning)
        : s.isOpen
        ? ('Accepting responses', AdminColors.success)
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('WINDOW', style: _zoneLabel),
        const SizedBox(height: 4),
        Text(
          window ?? 'No window set',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: window == null ? _secondary : _zoneValue,
        ),
        if (state != null) ...[
          const SizedBox(height: 3),
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: state.$2,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  state.$1,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _secondary,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildMenu() {
    if (widget.busy) {
      return Tooltip(
        message: 'Working on $_title…',
        child: const SizedBox(
          width: 40,
          height: 40,
          child: Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AdminColors.primary,
              ),
            ),
          ),
        ),
      );
    }
    return PopupMenuButton<String>(
      tooltip: 'Actions for $_title',
      onSelected: widget.onMenuSelected,
      itemBuilder: (_) => widget.menuItems,
      color: AdminColors.card,
      elevation: 8,
      shadowColor: const Color(0xFF0F172A).withValues(alpha: 0.12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AdminSurfaces.radiusMd),
      ),
      icon: const Icon(Icons.more_vert, color: AdminColors.textMuted),
    );
  }
}

/// Survey action menu row: leading icon, optional note under the label.
PopupMenuItem<String> surveyMenuItem({
  required String value,
  required String label,
  required IconData icon,
  bool destructive = false,
  bool enabled = true,
  String? note,
}) {
  final Color textColor;
  final Color iconColor;
  if (!enabled) {
    textColor = AdminColors.textMuted;
    iconColor = AdminColors.textMuted;
  } else if (destructive) {
    textColor = AdminColors.danger;
    iconColor = AdminColors.danger;
  } else {
    textColor = AdminColors.textPrimary;
    iconColor = AdminColors.primary;
  }
  return PopupMenuItem<String>(
    value: value,
    enabled: enabled,
    height: note == null ? 40 : 52,
    child: Row(
      children: [
        Icon(icon, size: 18, color: iconColor),
        const SizedBox(width: 12),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  color: textColor,
                ),
              ),
              if (note != null)
                Text(
                  note,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AdminColors.textSecondary,
                  ),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}

/// Loading placeholder shaped like [SurveyListCard] rows.
class SurveyListSkeleton extends StatelessWidget {
  const SurveyListSkeleton({super.key, this.count = 5});

  final int count;

  @override
  Widget build(BuildContext context) {
    return ShimmerScope(
      child: ListView.separated(
        padding: const EdgeInsets.only(bottom: AdminDensity.space3),
        itemCount: count,
        separatorBuilder: (_, __) =>
            const SizedBox(height: AdminDensity.listItemGap),
        itemBuilder: (context, index) => Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            color: AdminColors.card,
            borderRadius: BorderRadius.circular(AdminSurfaces.radiusMd),
            border: Border.all(color: AdminColors.border),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final zones =
                  constraints.maxWidth >= SurveyListCard.zoneLayoutMinWidth;
              return Row(
                children: [
                  const Skeleton(
                    width: 36,
                    height: 36,
                    borderRadius: BorderRadius.all(Radius.circular(8)),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FractionallySizedBox(
                          widthFactor: 0.6,
                          child: Skeleton(height: 14),
                        ),
                        SizedBox(height: 8),
                        Skeleton(width: 140, height: 16),
                        SizedBox(height: 8),
                        Skeleton(width: 110, height: 11),
                      ],
                    ),
                  ),
                  if (zones) ...[
                    const SizedBox(width: 24),
                    const SizedBox(
                      width: 180,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Skeleton(width: 70, height: 10),
                          SizedBox(height: 8),
                          Skeleton(width: 90, height: 13),
                          SizedBox(height: 8),
                          Skeleton(height: 4),
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),
                    const SizedBox(
                      width: 200,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Skeleton(width: 60, height: 10),
                          SizedBox(height: 8),
                          Skeleton(width: 150, height: 13),
                        ],
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Themed empty placeholder for survey admin surfaces.
class SurveyEmptyState extends StatelessWidget {
  const SurveyEmptyState({
    super.key,
    required this.title,
    required this.subtitle,
    this.icon = Icons.poll_outlined,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AdminSurveyTheme.surface,
                shape: BoxShape.circle,
                border: Border.all(color: AdminSurveyTheme.border),
              ),
              child: Icon(icon, size: 28, color: AdminSurveyTheme.textMuted),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AdminText.sectionTitle,
            ),
            const SizedBox(height: 4),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Text(
                subtitle,
                textAlign: TextAlign.center,
                style: AdminText.caption.copyWith(height: 1.4),
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 12),
              FilledButton(
                onPressed: onAction,
                style: surveyFilledButtonStyle(),
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

ButtonStyle surveyOutlinedButtonStyle() => AdminButtonStyles.outlined();

ButtonStyle surveyFilledButtonStyle({Color? background}) =>
    AdminButtonStyles.filled(background: background);

class SurveyQuestionRow extends StatelessWidget {
  const SurveyQuestionRow({
    super.key,
    required this.prompt,
    required this.meta,
    required this.onDelete,
  });

  final String prompt;
  final String meta;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AdminSurveyTheme.background,
        borderRadius: BorderRadius.circular(AdminSurveyTheme.radiusMd),
        border: Border.all(color: AdminSurveyTheme.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  prompt,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: AdminSurveyTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  meta,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AdminSurveyTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Delete question',
            onPressed: onDelete,
            icon: const Icon(
              Icons.delete_outline,
              color: AdminSurveyTheme.danger,
            ),
            style: AdminDensity.iconButtonStyle(
              foregroundColor: AdminSurveyTheme.danger,
            ),
          ),
        ],
      ),
    );
  }
}
