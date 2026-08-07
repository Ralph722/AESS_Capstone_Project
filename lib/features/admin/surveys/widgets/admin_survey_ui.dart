import 'package:flutter/material.dart';
import 'package:alumni_system/features/admin/roster/widgets/alumni_directory_ui.dart';
import 'package:alumni_system/features/surveys/models/survey_model.dart';
import 'package:alumni_system/shared/widgets/admin/admin_density.dart';
import 'package:alumni_system/shared/widgets/admin/admin_page_header.dart';

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
  });

  final SurveyStatus status;
  final bool archived;
  final bool scheduled;

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
        if (scheduled) {
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
          bg: AdminSurveyTheme.infoBg,
          fg: AdminSurveyTheme.primary,
          icon: Icons.lock_outline,
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
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
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: AdminDensity.sectionTitleFontSize,
                        fontWeight: FontWeight.w700,
                        color: AdminSurveyTheme.textPrimary,
                      ),
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: const TextStyle(
                          fontSize: AdminDensity.subtitleFontSize,
                          height: 1.35,
                          color: AdminSurveyTheme.textSecondary,
                        ),
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
    this.actions = const [],
  });

  final String title;
  final String subtitle;
  final VoidCallback onClose;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AdminSurveyTheme.card,
      child: Container(
        padding: const EdgeInsets.fromLTRB(4, 6, 8, 6),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AdminSurveyTheme.border)),
        ),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, size: 20),
              tooltip: 'Back to surveys',
              onPressed: onClose,
              style: IconButton.styleFrom(
                foregroundColor: AdminSurveyTheme.textSecondary,
                minimumSize: AdminDensity.minTapSize,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: const EdgeInsets.all(8),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AdminSurveyTheme.textPrimary,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AdminSurveyTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            ...actions,
          ],
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
  });

  final Survey? survey;
  final VoidCallback onBack;
  final List<PopupMenuEntry<String>> overflowItems;
  final ValueChanged<String>? onOverflowSelected;
  final bool overflowEnabled;
  final bool overflowBusy;

  /// Best-effort published timestamp without schema changes.
  /// Draft → null; otherwise schedule [Survey.openAt] or [Survey.updatedAt].
  static DateTime? publishedAtOf(Survey? survey) {
    if (survey == null || survey.status == SurveyStatus.draft) return null;
    return survey.openAt ?? survey.updatedAt;
  }

  @override
  Widget build(BuildContext context) {
    final title = (survey?.title.trim().isNotEmpty == true)
        ? survey!.title.trim()
        : 'Survey responses';

    return Material(
      color: AdminSurveyTheme.card,
      child: Container(
        padding: const EdgeInsets.fromLTRB(6, 6, 8, 8),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AdminSurveyTheme.border)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, size: 20),
                  tooltip: 'Back to surveys',
                  onPressed: onBack,
                  style: IconButton.styleFrom(
                    foregroundColor: AdminSurveyTheme.textSecondary,
                    minimumSize: AdminDensity.minTapSize,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: const EdgeInsets.all(8),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                          color: AdminSurveyTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (survey != null) ...[
                            SurveyStatusChip(
                              status: survey!.status,
                              archived: survey!.archived,
                              scheduled: survey!.isScheduledWindow,
                            ),
                            SurveyKindChip.fromSurvey(survey!),
                          ],
                        ],
                      ),
                    ],
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
                            Icons.more_vert,
                            color: AdminSurveyTheme.textSecondary,
                          ),
                    onSelected: onOverflowSelected,
                    itemBuilder: (_) => overflowItems,
                  ),
              ],
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

/// Workspace tab bar — matches member-details underline tabs (no filled chip).
class SurveyWorkspaceSegmentedNav extends StatelessWidget {
  const SurveyWorkspaceSegmentedNav({
    super.key,
    required this.tabs,
    required this.controller,
  });

  final List<SurveyWorkspaceTabSpec> tabs;
  final TabController controller;

  @override
  Widget build(BuildContext context) {
    assert(tabs.isNotEmpty);

    return Material(
      color: AdminSurveyTheme.card,
      child: TabBar(
        controller: controller,
        indicatorColor: AdminSurveyTheme.primary,
        indicatorWeight: 2.5,
        labelColor: AdminSurveyTheme.primary,
        unselectedLabelColor: AdminSurveyTheme.textSecondary,
        labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 13,
        ),
        dividerColor: AdminSurveyTheme.border,
        tabs: [
          for (final tab in tabs)
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(tab.icon, size: 16),
                  const SizedBox(width: 6),
                  Text(tab.label),
                  if (tab.count != null) ...[
                    const SizedBox(width: 6),
                    _CountBadge(count: tab.count!),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final text = count > 999 ? '999+' : '$count';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AdminSurveyTheme.infoBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AdminSurveyTheme.primary,
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
  });

  final List<Widget> children;
  final bool constrainWidth;

  @override
  Widget build(BuildContext context) {
    final padded = Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 520;
          if (narrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0) const SizedBox(height: 8),
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
      color: AdminSurveyTheme.card,
      elevation: 8,
      shadowColor: const Color(0xFF0F172A).withValues(alpha: 0.12),
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

class SurveyListCard extends StatefulWidget {
  const SurveyListCard({
    super.key,
    required this.survey,
    required this.metaLine,
    required this.onMenuSelected,
    required this.menuItems,
    this.onOpen,
  });

  final Survey survey;
  final String metaLine;
  final ValueChanged<String> onMenuSelected;
  final List<PopupMenuEntry<String>> menuItems;
  final VoidCallback? onOpen;

  @override
  State<SurveyListCard> createState() => _SurveyListCardState();
}

class _SurveyListCardState extends State<SurveyListCard> {
  bool _hovered = false;

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
          color: _hovered ? AdminSurveyTheme.surface : Colors.white,
          borderRadius: BorderRadius.circular(AdminSurveyTheme.radiusMd),
          border: Border.all(color: AdminSurveyTheme.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onOpen,
            borderRadius: BorderRadius.circular(AdminSurveyTheme.radiusMd),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (s.isChedGtsBuiltin || s.isFromTemplate)
                    Container(
                      width: 4,
                      color: s.isChedGtsBuiltin
                          ? const Color(0xFFC2410C)
                          : const Color(0xFFEA580C),
                    ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AdminDensity.space3,
                        vertical: AdminDensity.cardPadding,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Semantics(
                            label: 'Survey',
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: s.isChedGtsBuiltin
                                    ? const Color(0xFFFFF7ED)
                                    : AdminSurveyTheme.infoBg,
                                borderRadius: BorderRadius.circular(
                                  AdminSurveyTheme.radiusSm,
                                ),
                              ),
                              child: Icon(
                                s.isChedGtsBuiltin
                                    ? Icons.school_outlined
                                    : Icons.poll_outlined,
                                size: 18,
                                color: s.isChedGtsBuiltin
                                    ? const Color(0xFFC2410C)
                                    : AdminSurveyTheme.primary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  s.title.isEmpty
                                      ? 'Untitled survey'
                                      : s.title,
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                    color: AdminSurveyTheme.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Wrap(
                                  spacing: 4,
                                  runSpacing: 4,
                                  children: [
                                    SurveyStatusChip(
                                      status: s.status,
                                      archived: s.archived,
                                      scheduled: s.isScheduledWindow,
                                    ),
                                    SurveyKindChip.fromSurvey(s),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  widget.metaLine,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    height: 1.35,
                                    color: AdminSurveyTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          PopupMenuButton<String>(
                            tooltip: 'Survey actions',
                            onSelected: widget.onMenuSelected,
                            itemBuilder: (_) => widget.menuItems,
                            icon: const Icon(
                              Icons.more_vert,
                              color: AdminSurveyTheme.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
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
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AdminSurveyTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: AdminSurveyTheme.textSecondary,
                ),
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

ButtonStyle surveyOutlinedButtonStyle() => OutlinedButton.styleFrom(
  foregroundColor: AdminSurveyTheme.textPrimary,
  side: const BorderSide(color: AdminSurveyTheme.border),
  minimumSize: const Size(0, AdminSurveyTheme.buttonHeight),
  padding: const EdgeInsets.symmetric(horizontal: 14),
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(AdminSurveyTheme.radiusSm),
  ),
);

ButtonStyle surveyFilledButtonStyle({Color? background}) =>
    FilledButton.styleFrom(
      backgroundColor: background ?? AdminSurveyTheme.primary,
      foregroundColor: Colors.white,
      minimumSize: const Size(0, AdminSurveyTheme.buttonHeight),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AdminSurveyTheme.radiusSm),
      ),
    );

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
