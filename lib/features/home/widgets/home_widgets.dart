import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:alumni_system/core/utils/app_image.dart';
import 'package:alumni_system/features/announcements/models/announcement_model.dart';
import 'package:alumni_system/features/events/models/event_model.dart';
import 'package:alumni_system/features/events/models/event_display_status.dart';
import 'package:alumni_system/features/forum/models/forum_model.dart';
import 'package:alumni_system/features/forum/widgets/forum_ui.dart';
import 'package:alumni_system/features/home/models/home_calendar_item.dart';
import 'package:alumni_system/features/jobs/models/job_posting_model.dart';
import 'package:alumni_system/features/jobs/widgets/job_ui.dart';
import 'package:alumni_system/shared/widgets/user/portal_headers.dart';
import 'package:alumni_system/shared/widgets/user/portal_theme.dart';

/// Presentational Home pieces — keep navigation / data in [HomeScreen].

String homeGreetingForNow(DateTime now) {
  final h = now.hour;
  if (h < 12) return 'Good morning';
  if (h < 17) return 'Good afternoon';
  return 'Good evening';
}

const double _hPad = 16;

/// Consistent vertical gap above each home section card.
const double _sectionTop = 10;

/// Side padding for home section cards. The two-column desktop layout sets
/// it to 0 so its own gutters decide the spacing between columns.
class HomeSectionInset extends InheritedWidget {
  const HomeSectionInset({
    super.key,
    required this.horizontal,
    required super.child,
  });

  final double horizontal;

  static double of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<HomeSectionInset>()
          ?.horizontal ??
      _hPad;

  @override
  bool updateShouldNotify(HomeSectionInset oldWidget) =>
      oldWidget.horizontal != horizontal;
}

EdgeInsets _sectionPadding(BuildContext context) {
  final h = HomeSectionInset.of(context);
  return EdgeInsets.fromLTRB(h, _sectionTop, h, 0);
}

Widget _portalCard({
  required Widget child,
  VoidCallback? onTap,
  EdgeInsetsGeometry? padding,
  double radius = PortalTheme.radiusLg,
  Color? borderColor,
  double borderWidth = 1,
  double elevation = 1.25,
  Color? shadowColor,
  Color color = Colors.white,
}) {
  return PortalCardShell(
    onTap: onTap,
    padding: padding,
    borderRadius: BorderRadius.circular(radius),
    borderColor: borderColor ?? PortalTheme.border.withValues(alpha: 0.7),
    borderWidth: borderWidth,
    elevation: elevation,
    shadowColor: shadowColor,
    color: color,
    child: child,
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// WELCOME / IDENTITY
// ═══════════════════════════════════════════════════════════════════════════

/// Welcome / profile hero — tappable card that opens the Profile tab.
class HomeAlumniIdentityHero extends StatelessWidget {
  const HomeAlumniIdentityHero({
    super.key,
    required this.firstName,
    this.fullName,
    this.program,
    this.batchYear,
    this.profileImageUrl,
    this.onTap,
    @Deprecated('Use onTap — the whole card opens Profile') this.onAvatarTap,
  });

  final String firstName;
  final String? fullName;
  final String? program;
  final String? batchYear;
  final String? profileImageUrl;
  final VoidCallback? onTap;
  final VoidCallback? onAvatarTap;

  String? get _courseBatchBadge {
    final parts = <String>[
      if (program != null && program!.trim().isNotEmpty) program!.trim(),
      if (batchYear != null && batchYear!.trim().isNotEmpty)
        'Batch ${batchYear!.trim()}',
    ];
    if (parts.isEmpty) return null;
    return parts.join(' • ');
  }

  @override
  Widget build(BuildContext context) {
    final badge = _courseBatchBadge;
    final openProfile = onTap ?? onAvatarTap;
    final heroRadius = BorderRadius.circular(PortalTheme.radius2xl);

    return Padding(
      padding: _sectionPadding(context),
      child: Material(
        color: Colors.transparent,
        elevation: 3,
        shadowColor: PortalTheme.navy.withValues(alpha: 0.28),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: heroRadius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: openProfile,
          customBorder: RoundedRectangleBorder(borderRadius: heroRadius),
          child: Ink(
            decoration: const BoxDecoration(gradient: PortalTheme.heroGradient),
            child: Stack(
              children: [
                Positioned(
                  right: -28,
                  top: -36,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.06),
                    ),
                  ),
                ),
                Positioned(
                  right: 48,
                  bottom: -40,
                  child: Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: PortalTheme.gold.withValues(alpha: 0.12),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 18, 16, 18),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Welcome back,',
                              style: PortalTheme.meta.copyWith(
                                color: Colors.white.withValues(alpha: 0.78),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              firstName,
                              style: PortalTheme.display.copyWith(
                                color: Colors.white,
                                fontSize: 26,
                                height: 1.15,
                                fontWeight: FontWeight.w800,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (badge != null) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: PortalTheme.gold,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: PortalTheme.gold.withValues(
                                        alpha: 0.35,
                                      ),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  badge,
                                  style: PortalTheme.caption.copyWith(
                                    color: PortalTheme.navy,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      _IdentityAvatar(url: profileImageUrl, size: 68),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _IdentityAvatar extends StatelessWidget {
  const _IdentityAvatar({required this.url, required this.size});

  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) {
    final provider = url == null || url!.isEmpty
        ? null
        : AppImage.provider(url);
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: PortalTheme.gold, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.18),
          image: provider == null
              ? null
              : DecorationImage(
                  image: provider,
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.high,
                ),
        ),
        child: provider == null
            ? Icon(
                Icons.person_rounded,
                color: Colors.white.withValues(alpha: 0.85),
                size: size * 0.42,
              )
            : null,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// NEEDS ATTENTION — single yellow card, new pill/meta look
// ═══════════════════════════════════════════════════════════════════════════

/// Tracer line on the Home attention card, worded like the Tracer tab.
String homeTracerSubtitle({required bool started, String? dueLabel}) {
  if (dueLabel != null && dueLabel.trim().isNotEmpty) {
    return '$dueLabel · ${started ? 'In progress' : 'Not started'}';
  }
  return started
      ? 'In progress · pick up where you left off'
      : 'Not started · about 10–15 min';
}

class HomeNeedsAttentionPanel extends StatelessWidget {
  const HomeNeedsAttentionPanel({
    super.key,
    required this.tracerComplete,
    required this.pendingSurveys,
    required this.onOpenTracer,
    required this.onOpenSurveys,
    this.dueSoon = false,
    this.dueSoonLabel,
    this.tracerSubtitle,
    this.surveySubtitle,
  });

  final bool tracerComplete;
  final int pendingSurveys;
  final VoidCallback onOpenTracer;
  final VoidCallback onOpenSurveys;
  final bool dueSoon;
  final String? dueSoonLabel;
  final String? tracerSubtitle;
  final String? surveySubtitle;

  bool get _hasTracer => !tracerComplete;
  bool get _hasSurveys => pendingSurveys > 0;
  bool get hasActions => _hasTracer || _hasSurveys;

  @override
  Widget build(BuildContext context) {
    if (!hasActions) return const SizedBox.shrink();

    final actionCount = (_hasTracer ? 1 : 0) + (_hasSurveys ? 1 : 0);
    final badgeLabel = dueSoon ? 'DUE SOON' : 'ACTION';
    final title = actionCount == 1
        ? (_hasTracer
              ? 'Graduate Tracer Survey'
              : (pendingSurveys == 1
                    ? 'Assigned survey waiting'
                    : '$pendingSurveys assigned surveys waiting'))
        : '$actionCount actions waiting for you';

    final gradientColors = dueSoon
        ? const [Color(0xFFFFF0E8), Color(0xFFFFB347)]
        : const [Color(0xFFFFF4D6), Color(0xFFFCB315)];
    final borderColor = dueSoon
        ? const Color(0xFFE88A3C)
        : const Color(0xFFE8A80C);

    final needRadius = BorderRadius.circular(PortalTheme.radius2xl);
    return Padding(
      padding: _sectionPadding(context),
      child: Material(
        color: Colors.transparent,
        elevation: 2,
        shadowColor: (dueSoon ? PortalTheme.amber : PortalTheme.gold)
            .withValues(alpha: 0.4),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: needRadius,
          side: BorderSide(color: borderColor, width: 1.2),
        ),
        clipBehavior: Clip.antiAlias,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: gradientColors,
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                right: -18,
                top: -22,
                child: Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.22),
                  ),
                ),
              ),
              Positioned(
                right: 40,
                bottom: -28,
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: PortalTheme.navy.withValues(alpha: 0.06),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: PortalTheme.navy.withValues(alpha: 0.88),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: dueSoon
                                  ? PortalTheme.ember
                                  : PortalTheme.gold,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 7),
                          Text(
                            badgeLabel,
                            style: PortalTheme.caption.copyWith(
                              color: Colors.white.withValues(alpha: 0.95),
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.4,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      dueSoon
                          ? 'Due soon — needs your attention'
                          : 'Needs attention',
                      style: PortalTheme.meta.copyWith(
                        color: PortalTheme.navy.withValues(alpha: 0.7),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      title,
                      style: PortalTheme.display.copyWith(
                        color: PortalTheme.navy,
                        fontSize: 22,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (dueSoonLabel?.trim().isNotEmpty == true) ...[
                      const SizedBox(height: 6),
                      Text(
                        dueSoonLabel!,
                        style: PortalTheme.meta.copyWith(
                          color: PortalTheme.navy.withValues(alpha: 0.72),
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    if (_hasTracer)
                      _YellowMetaPill(
                        name: 'Tracer',
                        icon: Icons.assignment_outlined,
                        title: 'Graduate Tracer Survey',
                        subtitle: tracerSubtitle?.trim().isNotEmpty == true
                            ? tracerSubtitle!
                            : homeTracerSubtitle(started: false),
                        onTap: onOpenTracer,
                      ),
                    if (_hasTracer && _hasSurveys) const SizedBox(height: 8),
                    if (_hasSurveys)
                      _YellowMetaPill(
                        name: 'Survey',
                        icon: Icons.poll_outlined,
                        title: pendingSurveys == 1
                            ? 'Assigned survey waiting'
                            : '$pendingSurveys assigned surveys waiting',
                        subtitle: surveySubtitle?.trim().isNotEmpty == true
                            ? surveySubtitle!
                            : 'Respond when you can — separate from Tracer',
                        onTap: onOpenSurveys,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _YellowMetaPill extends StatelessWidget {
  const _YellowMetaPill({
    required this.name,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String name;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: PortalTheme.navy.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: PortalTheme.navy, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: PortalTheme.navy.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        name,
                        style: PortalTheme.caption.copyWith(
                          color: PortalTheme.navy,
                          fontWeight: FontWeight.w700,
                          fontSize: 10,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      title,
                      style: PortalTheme.cardTitle.copyWith(
                        fontSize: 13,
                        color: PortalTheme.navy,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: PortalTheme.meta.copyWith(
                        fontSize: 11,
                        color: PortalTheme.navy.withValues(alpha: 0.72),
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: PortalTheme.navy,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// SECTION HEADER — tight, scannable
// ═══════════════════════════════════════════════════════════════════════════

class HomeSectionLabel extends StatelessWidget {
  const HomeSectionLabel({
    super.key,
    required this.title,
    this.eyebrow,
    this.actionLabel,
    this.onAction,
    this.padding = const EdgeInsets.fromLTRB(_hPad, 18, 8, 10),
  });

  final String title;
  final String? eyebrow;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  if (eyebrow != null && eyebrow!.isNotEmpty) ...[
                    TextSpan(
                      text: '${eyebrow!}  ',
                      style: PortalTheme.caption.copyWith(
                        color: PortalTheme.textMuted,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                        fontSize: 10,
                      ),
                    ),
                  ],
                  TextSpan(
                    text: title,
                    style: PortalTheme.sectionTitle.copyWith(
                      fontSize: 16,
                      color: PortalTheme.navy,
                    ),
                  ),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (actionLabel != null && onAction != null)
            TextButton(
              onPressed: onAction,
              style: PortalTheme.ghostButton(dense: true),
              child: Text(
                actionLabel!,
                style: PortalTheme.meta.copyWith(
                  color: PortalTheme.navyMid,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// STATISTICS — three-card row
// ═══════════════════════════════════════════════════════════════════════════

class HomeStatCardsRow extends StatelessWidget {
  const HomeStatCardsRow({
    super.key,
    required this.announcementsCount,
    required this.communityTodayCount,
    required this.eventsCount,
    this.onAnnouncements,
    this.onCommunity,
    this.onEvents,
    this.loading = false,
  });

  /// Space between the stat cards.
  static const double gap = 10;

  final int announcementsCount;
  final int communityTodayCount;
  final int eventsCount;
  final VoidCallback? onAnnouncements;
  final VoidCallback? onCommunity;
  final VoidCallback? onEvents;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: _hPad),
        child: HomeStatCardsSkeleton(),
      );
    }

    return Padding(
      padding: _sectionPadding(context),
      child: Row(
        children: [
          Expanded(
            child: HomeStatCard(
              icon: Icons.campaign_outlined,
              iconColor: PortalTheme.navy,
              iconBg: PortalTheme.navy.withValues(alpha: 0.08),
              count: announcementsCount,
              label: 'Announcements',
              onTap: onAnnouncements,
            ),
          ),
          const SizedBox(width: gap),
          Expanded(
            child: HomeStatCard(
              icon: Icons.forum_outlined,
              iconColor: PortalTheme.navy,
              iconBg: PortalTheme.navy.withValues(alpha: 0.08),
              count: communityTodayCount,
              label: 'Posts today',
              onTap: onCommunity,
            ),
          ),
          const SizedBox(width: gap),
          Expanded(
            child: HomeStatCard(
              icon: Icons.event_outlined,
              iconColor: PortalTheme.navy,
              iconBg: PortalTheme.navy.withValues(alpha: 0.08),
              count: eventsCount,
              label: 'Events',
              onTap: onEvents,
            ),
          ),
        ],
      ),
    );
  }
}

class HomeStatCard extends StatelessWidget {
  const HomeStatCard({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.count,
    required this.label,
    this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final int count;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return _portalCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      radius: PortalTheme.radiusXl,
      elevation: 1,
      shadowColor: PortalTheme.navy.withValues(alpha: 0.08),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 15, color: iconColor),
          ),
          const SizedBox(height: 10),
          Text(
            '$count',
            style: PortalTheme.display.copyWith(
              fontSize: 22,
              height: 1,
              color: PortalTheme.navy,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: PortalTheme.caption.copyWith(
              color: PortalTheme.textSecondary,
              fontWeight: FontWeight.w600,
              fontSize: 10,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class HomeStatCardsSkeleton extends StatelessWidget {
  const HomeStatCardsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(
        3,
        (i) => Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              left: i == 0 ? 0 : 5,
              right: i == 2 ? 0 : 5,
            ),
            child: Container(
              height: 96,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(PortalTheme.radiusXl),
                border: Border.all(
                  color: PortalTheme.border.withValues(alpha: 0.5),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String homeFormatEventTimeRange(String start, String end) {
  String fmt(String raw) {
    final parts = raw.split(':');
    if (parts.length < 2) return raw;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return raw;
    return intl.DateFormat('h:mm a').format(DateTime(2000, 1, 1, h, m));
  }

  return '${fmt(start)} – ${fmt(end)}';
}

String homeEventRelativeLabel(AlumniEvent event, {DateTime? now}) {
  final clock = now ?? DateTime.now();
  final today = DateTime(clock.year, clock.month, clock.day);
  final eventDay = DateTime(event.date.year, event.date.month, event.date.day);
  final days = eventDay.difference(today).inDays;
  if (days <= 0) return 'Today';
  if (days == 1) return '1 day to go';
  return '$days days to go';
}

bool homeEventIsToday(AlumniEvent event, {DateTime? now}) {
  final status = deriveEventDisplayStatus(event, now: now);
  return status == EventDisplayStatus.today ||
      status == EventDisplayStatus.ongoing;
}

// ═══════════════════════════════════════════════════════════════════════════
// EVENTS — planner-style soft list card (no trailing arrows)
// ═══════════════════════════════════════════════════════════════════════════

class HomeUpcomingEventsList extends StatelessWidget {
  const HomeUpcomingEventsList({
    super.key,
    required this.events,
    required this.onTap,
    this.onSeeAll,
  });

  final List<AlumniEvent> events;
  final ValueChanged<AlumniEvent> onTap;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: _sectionPadding(context),
      child: _portalCard(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        radius: PortalTheme.radius2xl,
        elevation: 1,
        shadowColor: PortalTheme.navy.withValues(alpha: 0.08),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: PortalTheme.navy.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.event_rounded,
                    size: 18,
                    color: PortalTheme.navy,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Upcoming Events',
                        style: PortalTheme.cardTitle.copyWith(
                          fontSize: 15,
                          color: PortalTheme.navy,
                        ),
                      ),
                      Text(
                        'Alumni activities coming up',
                        style: PortalTheme.meta.copyWith(fontSize: 11),
                      ),
                    ],
                  ),
                ),
                if (onSeeAll != null)
                  TextButton(
                    onPressed: onSeeAll,
                    style: TextButton.styleFrom(
                      foregroundColor: PortalTheme.navy,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      'See all',
                      style: PortalTheme.meta.copyWith(
                        color: PortalTheme.navy,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _HomeEventSlideshow(events: events, onTap: onTap),
          ],
        ),
      ),
    );
  }
}

/// 16:9 slide height for [width], capped so wide single-column layouts
/// (tablets, narrow browser windows) don't push the rest of the page down.
double homeEventSlideHeight(double width) => math.min(width * 9 / 16, 260);

/// 16:9 cover slides with the event details on the photo. Auto-advances
/// every few seconds (paused while touched or hovered, off for reduced
/// motion); tappable dots underneath.
class _HomeEventSlideshow extends StatefulWidget {
  const _HomeEventSlideshow({required this.events, required this.onTap});

  final List<AlumniEvent> events;
  final ValueChanged<AlumniEvent> onTap;

  @override
  State<_HomeEventSlideshow> createState() => _HomeEventSlideshowState();
}

class _HomeEventSlideshowState extends State<_HomeEventSlideshow> {
  static const _interval = Duration(seconds: 5);
  static const _slideDuration = Duration(milliseconds: 450);

  final _controller = PageController();
  Timer? _timer;
  int _index = 0;
  bool _paused = false;
  bool _reduceMotion = false;

  int get _count => widget.events.length;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = MediaQuery.disableAnimationsOf(context);
    if (reduce != _reduceMotion || _timer == null) {
      _reduceMotion = reduce;
      _restartTimer();
    }
  }

  @override
  void didUpdateWidget(covariant _HomeEventSlideshow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.events.length != _count) {
      if (_index >= _count) _index = 0;
      _restartTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _restartTimer() {
    _timer?.cancel();
    _timer = null;
    if (_count < 2 || _reduceMotion) return;
    _timer = Timer.periodic(_interval, (_) {
      if (!mounted || _paused || !_controller.hasClients) return;
      _controller.animateToPage(
        (_index + 1) % _count,
        duration: _slideDuration,
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _setPaused(bool paused) {
    if (_paused == paused) return;
    _paused = paused;
    if (!paused) _restartTimer();
  }

  void _goTo(int i) {
    if (!_controller.hasClients) return;
    if (_reduceMotion) {
      _controller.jumpToPage(i);
    } else {
      _controller.animateToPage(
        i,
        duration: _slideDuration,
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final events = widget.events;
    return Column(
      children: [
        MouseRegion(
          onEnter: (_) => _setPaused(true),
          onExit: (_) => _setPaused(false),
          child: Listener(
            onPointerDown: (_) => _setPaused(true),
            onPointerUp: (_) => _setPaused(false),
            onPointerCancel: (_) => _setPaused(false),
            child: LayoutBuilder(
              builder: (context, constraints) => SizedBox(
                height: homeEventSlideHeight(constraints.maxWidth),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(PortalTheme.radiusLg),
                  child: ScrollConfiguration(
                    behavior: ScrollConfiguration.of(context).copyWith(
                      dragDevices: const {
                        PointerDeviceKind.touch,
                        PointerDeviceKind.mouse,
                        PointerDeviceKind.trackpad,
                        PointerDeviceKind.stylus,
                      },
                    ),
                    child: PageView.builder(
                      controller: _controller,
                      itemCount: events.length,
                      onPageChanged: (i) {
                        setState(() => _index = i);
                        _restartTimer();
                      },
                      itemBuilder: (context, i) => _HomeEventSlide(
                        event: events[i],
                        onTap: () => widget.onTap(events[i]),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (events.length > 1) ...[
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < events.length; i++)
                Semantics(
                  button: true,
                  selected: i == _index,
                  label: 'Show event ${i + 1} of ${events.length}',
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _goTo(i),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 3,
                        vertical: 4,
                      ),
                      child: AnimatedContainer(
                        duration: PortalTheme.normal,
                        curve: Curves.easeOutCubic,
                        width: i == _index ? 18 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: i == _index
                              ? PortalTheme.navy
                              : PortalTheme.borderStrong,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _HomeEventSlide extends StatelessWidget {
  const _HomeEventSlide({required this.event, required this.onTap});

  final AlumniEvent event;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isToday = homeEventIsToday(event);
    final statusLabel = homeEventRelativeLabel(event);
    final timeRange = homeFormatEventTimeRange(event.startTime, event.endTime);
    final venue = event.venue.trim();
    final details = venue.isEmpty ? timeRange : '$timeRange · $venue';
    final url = event.coverImageUrl.trim();

    return Semantics(
      button: true,
      label: '${event.theme}, $statusLabel, $details',
      excludeSemantics: true,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (url.isEmpty)
            const _HomeEventSlidePlaceholder()
          else
            AppImage.widget(
              url,
              width: 960,
              height: 540,
              fit: BoxFit.cover,
              semanticLabel: 'Cover for ${event.theme}',
              errorBuilder: (_, __, ___) => const _HomeEventSlidePlaceholder(),
            ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.35, 1],
                colors: [Colors.transparent, Color(0xC7000000)],
              ),
            ),
          ),
          Positioned(
            top: 12,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isToday
                    ? PortalTheme.gold
                    : Colors.white.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                statusLabel,
                style: PortalTheme.caption.copyWith(
                  color: PortalTheme.navy,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
            ),
          ),
          Positioned(
            left: 14,
            right: 14,
            bottom: 12,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  event.theme,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: PortalTheme.cardTitle.copyWith(
                    color: Colors.white,
                    fontSize: 17,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  details,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: PortalTheme.meta.copyWith(
                    color: Colors.white.withValues(alpha: 0.88),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Positioned.fill(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                splashColor: Colors.white.withValues(alpha: 0.12),
                highlightColor: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeEventSlidePlaceholder extends StatelessWidget {
  const _HomeEventSlidePlaceholder();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF090A4F), Color(0xFF1A237E)],
        ),
      ),
      child: Align(
        alignment: const Alignment(0.85, -0.6),
        child: Icon(
          Icons.event_rounded,
          size: 96,
          color: Colors.white.withValues(alpha: 0.08),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// COMMUNITY — planner-style soft list card
// ═══════════════════════════════════════════════════════════════════════════

class HomeCommunityCarousel extends StatelessWidget {
  const HomeCommunityCarousel({
    super.key,
    required this.topics,
    required this.onTapTopic,
    this.onSeeAll,
  });

  final List<ForumTopic> topics;
  final ValueChanged<ForumTopic> onTapTopic;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: _sectionPadding(context),
      child: _portalCard(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        radius: PortalTheme.radius2xl,
        elevation: 1,
        shadowColor: PortalTheme.navy.withValues(alpha: 0.08),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: PortalTheme.navy.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.forum_rounded,
                    size: 18,
                    color: PortalTheme.navy,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Community',
                        style: PortalTheme.cardTitle.copyWith(
                          fontSize: 15,
                          color: PortalTheme.navy,
                        ),
                      ),
                      Text(
                        'Recent alumni discussions',
                        style: PortalTheme.meta.copyWith(fontSize: 11),
                      ),
                    ],
                  ),
                ),
                if (onSeeAll != null)
                  TextButton(
                    onPressed: onSeeAll,
                    style: TextButton.styleFrom(
                      foregroundColor: PortalTheme.navy,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      'See all',
                      style: PortalTheme.meta.copyWith(
                        color: PortalTheme.navy,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            for (var i = 0; i < topics.length; i++) ...[
              if (i > 0) const SizedBox(height: 8),
              HomeCommunityCard(
                topic: topics[i],
                onTap: () => onTapTopic(topics[i]),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class HomeCommunityCard extends StatelessWidget {
  const HomeCommunityCard({
    super.key,
    required this.topic,
    required this.onTap,
  });

  final ForumTopic topic;
  final VoidCallback onTap;

  /// The one status or tag worth showing, matching the Forum list chips.
  Widget? _pill() {
    if (topic.isPinned) return ForumStatusChip.pinned();
    if (topic.isSolved) return ForumStatusChip.solved();
    if (topic.needsResponse) return ForumStatusChip.needsResponse();
    final tag = topic.tags.isEmpty ? '' : topic.tags.first.label.trim();
    if (tag.isEmpty) return null;
    return ForumStatusChip(
      label: tag,
      foreground: PortalTheme.navyMid,
      background: PortalTheme.sky.withValues(alpha: 0.15),
      icon: Icons.sell_outlined,
    );
  }

  String _relativeTime(DateTime value) {
    final diff = DateTime.now().difference(value);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return intl.DateFormat.MMMd().format(value);
  }

  @override
  Widget build(BuildContext context) {
    final authorName = topic.authorName.trim().isEmpty
        ? 'Alumni'
        : topic.authorName.trim();
    final replies = topic.replyCount;
    final subtitle =
        '$authorName · ${replies == 1 ? '1 reply' : '$replies replies'} · ${_relativeTime(topic.createdAt)}';
    final url = topic.authorAvatarUrl;
    final provider = url == null || url.isEmpty ? null : AppImage.provider(url);
    final pill = _pill();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(PortalTheme.radiusLg),
        child: Ink(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: PortalTheme.surfaceMuted.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(PortalTheme.radiusLg),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: PortalTheme.navy.withValues(alpha: 0.08),
                  border: Border.all(
                    color: PortalTheme.border.withValues(alpha: 0.8),
                  ),
                  image: provider == null
                      ? null
                      : DecorationImage(
                          image: provider,
                          fit: BoxFit.cover,
                          filterQuality: FilterQuality.high,
                        ),
                ),
                child: provider == null
                    ? Icon(
                        Icons.person_rounded,
                        size: 20,
                        color: PortalTheme.navy.withValues(alpha: 0.45),
                      )
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (pill != null) ...[pill, const SizedBox(height: 4)],
                    Text(
                      topic.title,
                      style: PortalTheme.cardTitle.copyWith(fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: PortalTheme.meta.copyWith(fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: PortalTheme.textMuted,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HomeCommunityEmpty extends StatelessWidget {
  const HomeCommunityEmpty({super.key, this.onBrowse});

  final VoidCallback? onBrowse;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: _sectionPadding(context),
      child: _portalCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        radius: PortalTheme.radiusXl,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'No community discussions yet.',
              style: PortalTheme.body.copyWith(
                color: PortalTheme.navy,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Start a conversation in the alumni forum.',
              style: PortalTheme.bodySecondary.copyWith(fontSize: 12),
            ),
            if (onBrowse != null) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: onBrowse,
                style: PortalTheme.ghostButton(dense: true),
                child: const Text('Explore community'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// CALENDAR — important dates from events, surveys, tracer, jobs
// ═══════════════════════════════════════════════════════════════════════════

class HomeImportantDatesCalendar extends StatefulWidget {
  const HomeImportantDatesCalendar({
    super.key,
    required this.items,
    required this.onItemTap,
  });

  final List<HomeCalendarItem> items;
  final ValueChanged<HomeCalendarItem> onItemTap;

  @override
  State<HomeImportantDatesCalendar> createState() =>
      _HomeImportantDatesCalendarState();
}

class _HomeImportantDatesCalendarState
    extends State<HomeImportantDatesCalendar> {
  late DateTime _month;
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month, 1);
    _selectedDay = DateTime(now.year, now.month, now.day);
  }

  Map<DateTime, List<HomeCalendarItem>> get _byDay {
    final map = <DateTime, List<HomeCalendarItem>>{};
    for (final item in widget.items) {
      map.putIfAbsent(item.dayKey, () => []).add(item);
    }
    return map;
  }

  List<HomeCalendarItem> _itemsForDay(DateTime day) {
    final key = DateTime(day.year, day.month, day.day);
    return _byDay[key] ?? const [];
  }

  Set<HomeCalendarItemKind> _kindsForDay(DateTime day) {
    return _itemsForDay(day).map((e) => e.kind).toSet();
  }

  @override
  Widget build(BuildContext context) {
    final firstOfMonth = DateTime(_month.year, _month.month, 1);
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final startWeekday = (firstOfMonth.weekday + 6) % 7;
    final totalCells = startWeekday + daysInMonth;
    final rows = ((totalCells + 6) / 7).floor();
    final selected = _selectedDay;
    final selectedItems = selected == null
        ? const <HomeCalendarItem>[]
        : _itemsForDay(selected);

    return Padding(
      padding: _sectionPadding(context),
      child: _portalCard(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
        radius: PortalTheme.radius2xl,
        elevation: 1,
        shadowColor: PortalTheme.navy.withValues(alpha: 0.08),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: () => setState(() {
                    _month = DateTime(_month.year, _month.month - 1, 1);
                  }),
                  icon: const Icon(Icons.chevron_left, color: PortalTheme.navy),
                ),
                Expanded(
                  child: Text(
                    intl.DateFormat('MMMM yyyy').format(_month),
                    textAlign: TextAlign.center,
                    style: PortalTheme.sectionTitle.copyWith(fontSize: 15),
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: () => setState(() {
                    _month = DateTime(_month.year, _month.month + 1, 1);
                  }),
                  icon: const Icon(
                    Icons.chevron_right,
                    color: PortalTheme.navy,
                  ),
                ),
              ],
            ),
            Row(
              children: ['S', 'M', 'T', 'W', 'T', 'F', 'S']
                  .map(
                    (d) => Expanded(
                      child: Center(
                        child: Text(
                          d,
                          style: PortalTheme.caption.copyWith(
                            fontWeight: FontWeight.w700,
                            color: PortalTheme.textMuted,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 6),
            for (var r = 0; r < rows; r++)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Row(
                  children: List.generate(7, (c) {
                    final cell = r * 7 + c;
                    final dayNum = cell - startWeekday + 1;
                    if (dayNum < 1 || dayNum > daysInMonth) {
                      return const Expanded(child: SizedBox(height: 40));
                    }
                    final day = DateTime(_month.year, _month.month, dayNum);
                    final kinds = _kindsForDay(day);
                    final hasItems = kinds.isNotEmpty;
                    final isSelected =
                        selected != null &&
                        selected.year == day.year &&
                        selected.month == day.month &&
                        selected.day == day.day;
                    final isToday = _isSameDay(day, DateTime.now());

                    return Expanded(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => setState(() => _selectedDay = day),
                        child: Container(
                          height: 40,
                          margin: const EdgeInsets.symmetric(horizontal: 1),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? PortalTheme.navy
                                : (hasItems
                                      ? PortalTheme.gold.withValues(alpha: 0.12)
                                      : Colors.transparent),
                            borderRadius: BorderRadius.circular(8),
                            border: isToday && !isSelected
                                ? Border.all(
                                    color: PortalTheme.navy,
                                    width: 1.2,
                                  )
                                : null,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '$dayNum',
                                style: PortalTheme.meta.copyWith(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                  color: isSelected
                                      ? Colors.white
                                      : PortalTheme.navy,
                                ),
                              ),
                              if (hasItems)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      for (final kind in kinds.take(3))
                                        Container(
                                          width: 4,
                                          height: 4,
                                          margin: const EdgeInsets.symmetric(
                                            horizontal: 1,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isSelected
                                                ? PortalTheme.gold
                                                : _kindColor(kind),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            if (selected != null) ...[
              const Divider(height: 20),
              Text(
                intl.DateFormat('MMMM d').format(selected),
                style: PortalTheme.cardTitle.copyWith(fontSize: 13),
              ),
              const SizedBox(height: 8),
              if (selectedItems.isEmpty)
                Text(
                  'No important dates on this day.',
                  style: PortalTheme.bodySecondary.copyWith(fontSize: 12),
                )
              else
                ...selectedItems.map(
                  (item) => _CalendarDayItemTile(
                    item: item,
                    onTap: () => widget.onItemTap(item),
                  ),
                ),
              if (selectedItems.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    _LegendDot(
                      color: _kindColor(HomeCalendarItemKind.event),
                      label: 'Event',
                    ),
                    _LegendDot(
                      color: _kindColor(HomeCalendarItemKind.survey),
                      label: 'Survey',
                    ),
                    _LegendDot(
                      color: _kindColor(HomeCalendarItemKind.tracer),
                      label: 'Tracer',
                    ),
                    _LegendDot(
                      color: _kindColor(HomeCalendarItemKind.job),
                      label: 'Job',
                    ),
                  ],
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

Color _kindColor(HomeCalendarItemKind kind) => switch (kind) {
  HomeCalendarItemKind.event => PortalTheme.navy,
  HomeCalendarItemKind.survey => const Color(0xFF2563EB),
  HomeCalendarItemKind.tracer => const Color(0xFF7C3AED),
  HomeCalendarItemKind.job => const Color(0xFFD97706),
};

class _CalendarDayItemTile extends StatelessWidget {
  const _CalendarDayItemTile({required this.item, required this.onTap});

  final HomeCalendarItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final kindLabel = switch (item.kind) {
      HomeCalendarItemKind.event => 'Event',
      HomeCalendarItemKind.survey => 'Survey',
      HomeCalendarItemKind.tracer => 'Tracer',
      HomeCalendarItemKind.job => 'Job deadline',
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(PortalTheme.radiusSm),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.only(top: 6),
                  decoration: BoxDecoration(
                    color: _kindColor(item.kind),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        kindLabel,
                        style: PortalTheme.caption.copyWith(
                          color: PortalTheme.textMuted,
                          fontWeight: FontWeight.w700,
                          fontSize: 10,
                        ),
                      ),
                      Text(
                        item.title,
                        style: PortalTheme.body.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: PortalTheme.navy,
                        ),
                      ),
                      if (item.subtitle.isNotEmpty)
                        Text(
                          item.subtitle,
                          style: PortalTheme.meta.copyWith(fontSize: 11),
                        ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: PortalTheme.textMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: PortalTheme.caption.copyWith(fontSize: 10)),
      ],
    );
  }
}

class HomeEventsEmpty extends StatelessWidget {
  const HomeEventsEmpty({super.key, this.onBrowse});

  final VoidCallback? onBrowse;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: _sectionPadding(context),
      child: _portalCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        radius: PortalTheme.radiusXl,
        child: Row(
          children: [
            Icon(
              Icons.event_available_outlined,
              size: 20,
              color: PortalTheme.textMuted,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'No upcoming events. Check back for upcoming alumni activities.',
                style: PortalTheme.bodySecondary.copyWith(fontSize: 13),
              ),
            ),
            if (onBrowse != null)
              TextButton(
                onPressed: onBrowse,
                style: PortalTheme.ghostButton(dense: true),
                child: const Text('Browse'),
              ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ANNOUNCEMENTS — compact 2-col / feed
// ═══════════════════════════════════════════════════════════════════════════

class HomeAnnouncementsGrid extends StatelessWidget {
  const HomeAnnouncementsGrid({
    super.key,
    required this.announcements,
    required this.onTap,
  });

  final List<Announcement> announcements;
  final ValueChanged<Announcement> onTap;

  @override
  Widget build(BuildContext context) {
    if (announcements.isEmpty) return const SizedBox.shrink();

    final items = announcements.take(4).toList();
    if (items.length == 1) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: _hPad),
        child: _AnnouncementTile(
          announcement: items.first,
          onTap: () => onTap(items.first),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _hPad),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final useGrid = constraints.maxWidth >= 340 && items.length >= 2;
          if (!useGrid) {
            return Column(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0) const SizedBox(height: 10),
                  _AnnouncementTile(
                    announcement: items[i],
                    onTap: () => onTap(items[i]),
                  ),
                ],
              ],
            );
          }

          return Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final a in items)
                SizedBox(
                  width: (constraints.maxWidth - 10) / 2,
                  child: _AnnouncementTile(
                    announcement: a,
                    onTap: () => onTap(a),
                    compact: true,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _AnnouncementTile extends StatelessWidget {
  const _AnnouncementTile({
    required this.announcement,
    required this.onTap,
    this.compact = false,
  });

  final Announcement announcement;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final important = announcement.priority == AnnouncementPriority.important;
    final date = announcement.publishedAt ?? announcement.createdAt;
    final dateLabel = intl.DateFormat.MMMd().format(date);

    return _portalCard(
      onTap: onTap,
      padding: EdgeInsets.all(compact ? 12 : 14),
      radius: PortalTheme.radiusLg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (important) ...[
                const PortalChip(
                  label: 'Important',
                  tone: PortalChipTone.warning,
                ),
                const SizedBox(width: 6),
              ],
              Text(dateLabel, style: PortalTheme.caption),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            announcement.title,
            style: PortalTheme.cardTitle.copyWith(fontSize: compact ? 13 : 14),
            maxLines: compact ? 3 : 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (!compact && announcement.body.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              announcement.body,
              style: PortalTheme.bodySecondary.copyWith(fontSize: 12),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}

class HomeAnnouncementsEmpty extends StatelessWidget {
  const HomeAnnouncementsEmpty({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _hPad),
      child: _portalCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        radius: PortalTheme.radiusXl,
        child: Row(
          children: [
            Icon(
              Icons.campaign_outlined,
              size: 18,
              color: PortalTheme.textMuted,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'No new announcements right now.',
                style: PortalTheme.bodySecondary.copyWith(fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// JOBS — compact 2-col grid
// ═══════════════════════════════════════════════════════════════════════════

class HomeJobsGrid extends StatelessWidget {
  const HomeJobsGrid({super.key, required this.jobs, required this.onTap});

  final List<JobPosting> jobs;
  final ValueChanged<JobPosting> onTap;

  @override
  Widget build(BuildContext context) {
    if (jobs.isEmpty) return const SizedBox.shrink();
    final items = jobs.take(4).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _hPad),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final useGrid = constraints.maxWidth >= 340 && items.length >= 2;
          if (!useGrid) {
            return Column(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0) const SizedBox(height: 10),
                  _JobTile(job: items[i], onTap: () => onTap(items[i])),
                ],
              ],
            );
          }

          return Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final job in items)
                SizedBox(
                  width: (constraints.maxWidth - 10) / 2,
                  child: _JobTile(
                    job: job,
                    onTap: () => onTap(job),
                    compact: true,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _JobTile extends StatelessWidget {
  const _JobTile({
    required this.job,
    required this.onTap,
    this.compact = false,
  });

  final JobPosting job;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return _portalCard(
      onTap: onTap,
      padding: EdgeInsets.all(compact ? 12 : 14),
      radius: PortalTheme.radius2xl,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              JobCompanyLogo(job: job, size: compact ? 36 : 40, radius: 10),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  job.jobTitle.isEmpty ? 'Open role' : job.jobTitle,
                  style: PortalTheme.cardTitle.copyWith(
                    fontSize: compact ? 13 : 14,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            [
              if (job.companyName.isNotEmpty) job.companyName,
              if (job.location.isNotEmpty) job.location,
            ].join(' · '),
            style: PortalTheme.meta.copyWith(fontSize: 11),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (job.jobType.isNotEmpty || job.isRemote) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                if (job.jobType.isNotEmpty) PortalChip(label: job.jobType),
                if (job.isRemote)
                  const PortalChip(
                    label: 'Remote',
                    tone: PortalChipTone.success,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class HomeJobsEmpty extends StatelessWidget {
  const HomeJobsEmpty({super.key, this.onBrowse});

  final VoidCallback? onBrowse;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _hPad),
      child: _portalCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        radius: PortalTheme.radiusXl,
        child: Row(
          children: [
            Icon(Icons.work_outline, size: 18, color: PortalTheme.textMuted),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'No openings posted yet.',
                style: PortalTheme.bodySecondary.copyWith(fontSize: 13),
              ),
            ),
            if (onBrowse != null)
              TextButton(
                onPressed: onBrowse,
                style: PortalTheme.ghostButton(dense: true),
                child: const Text('Browse'),
              ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// COMMUNITY — discussion snippet
// ═══════════════════════════════════════════════════════════════════════════

class HomeCommunityPreview extends StatelessWidget {
  const HomeCommunityPreview({
    super.key,
    this.topic,
    required this.onOpenCommunity,
    this.onOpenTopic,
  });

  final ForumTopic? topic;
  final VoidCallback onOpenCommunity;
  final VoidCallback? onOpenTopic;

  @override
  Widget build(BuildContext context) {
    final hasTopic = topic != null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _hPad),
      child: _portalCard(
        onTap: hasTopic && onOpenTopic != null ? onOpenTopic : onOpenCommunity,
        padding: const EdgeInsets.all(14),
        radius: PortalTheme.radiusXl,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _avatarStack(topic),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hasTopic ? 'Active discussion' : 'Community forum',
                        style: PortalTheme.meta.copyWith(
                          color: PortalTheme.navyMid,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        hasTopic ? topic!.title : 'Connect with fellow alumni',
                        style: PortalTheme.cardTitle.copyWith(fontSize: 14),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (hasTopic)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: PortalTheme.surfaceMuted,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline_rounded,
                          size: 12,
                          color: PortalTheme.navyMid,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${topic!.replyCount}',
                          style: PortalTheme.caption.copyWith(
                            color: PortalTheme.navy,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            if (hasTopic && topic!.authorName.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                'Started by ${topic!.authorName}',
                style: PortalTheme.meta.copyWith(fontSize: 11),
              ),
            ],
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: PortalTheme.navy,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        hasTopic ? 'Join conversation' : 'Explore community',
                        style: PortalTheme.button.copyWith(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        size: 14,
                        color: Colors.white,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _avatarStack(ForumTopic? topic) {
    final url = topic?.authorAvatarUrl;
    final provider = url == null || url.isEmpty ? null : AppImage.provider(url);

    return SizedBox(
      width: 44,
      height: 36,
      child: Stack(
        children: [
          Positioned(
            left: 10,
            child: _miniAvatar(
              color: PortalTheme.sky.withValues(alpha: 0.25),
              icon: Icons.person_outline,
            ),
          ),
          Positioned(
            left: 0,
            child: _miniAvatar(
              color: PortalTheme.navy.withValues(alpha: 0.1),
              provider: provider,
              icon: Icons.forum_outlined,
              iconColor: PortalTheme.navy,
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniAvatar({
    required Color color,
    ImageProvider? provider,
    IconData icon = Icons.person_rounded,
    Color? iconColor,
  }) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: Border.all(color: Colors.white, width: 2),
        image: provider == null
            ? null
            : DecorationImage(image: provider, fit: BoxFit.cover),
      ),
      child: provider == null
          ? Icon(icon, size: 14, color: iconColor ?? PortalTheme.textMuted)
          : null,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// HELP — grouped list
// ═══════════════════════════════════════════════════════════════════════════

class HomeSupportStrip extends StatelessWidget {
  const HomeSupportStrip({
    super.key,
    required this.onSupport,
    this.unreadMessages = 0,
  });

  final VoidCallback onSupport;
  final int unreadMessages;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(_hPad, 4, _hPad, 0),
      child: _portalCard(
        radius: PortalTheme.radiusXl,
        child: _SupportListTile(
          icon: Icons.support_agent_outlined,
          iconBg: PortalTheme.navy.withValues(alpha: 0.08),
          iconColor: PortalTheme.navy,
          title: 'Support',
          subtitle: unreadMessages > 0
              ? '$unreadMessages unread message${unreadMessages == 1 ? '' : 's'}'
              : 'Message the alumni office',
          onTap: onSupport,
          badge: unreadMessages > 0,
        ),
      ),
    );
  }
}

class _SupportListTile extends StatelessWidget {
  const _SupportListTile({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badge = false,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool badge;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 20, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: PortalTheme.cardTitle.copyWith(fontSize: 14),
                      ),
                      if (badge) ...[
                        const SizedBox(width: 8),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: PortalTheme.badge,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: PortalTheme.meta.copyWith(fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: PortalTheme.textMuted,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}
