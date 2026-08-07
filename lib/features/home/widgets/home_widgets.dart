import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:alumni_system/core/utils/app_image.dart';
import 'package:alumni_system/features/announcements/models/announcement_model.dart';
import 'package:alumni_system/features/events/models/event_model.dart';
import 'package:alumni_system/features/events/models/event_display_status.dart';
import 'package:alumni_system/features/events/widgets/event_cover.dart';
import 'package:alumni_system/features/forum/models/forum_model.dart';
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

    final heroRadius = BorderRadius.circular(PortalTheme.radiusXl);
    return Padding(
      padding: const EdgeInsets.fromLTRB(_hPad, 12, _hPad, 4),
      child: Material(
        color: Colors.transparent,
        elevation: 3,
        shadowColor: PortalTheme.navy.withValues(alpha: 0.35),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: heroRadius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: openProfile,
          customBorder: RoundedRectangleBorder(borderRadius: heroRadius),
          child: Ink(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF1A1851),
                  Color(0xFF2A2770),
                  Color(0xFF1E3A6E),
                ],
              ),
            ),
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
// NEEDS ATTENTION — compact navy action banner
// ═══════════════════════════════════════════════════════════════════════════

class HomeNeedsAttentionPanel extends StatelessWidget {
  const HomeNeedsAttentionPanel({
    super.key,
    required this.tracerComplete,
    required this.tracerPercent,
    required this.pendingSurveys,
    required this.onOpenTracer,
    required this.onOpenSurveys,
    this.dueSoon = false,
    this.dueSoonLabel,
    this.tracerSubtitle,
    this.surveySubtitle,
  });

  final bool tracerComplete;
  final double tracerPercent;
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
    final gradientColors = dueSoon
        ? const [Color(0xFFFFF0E8), Color(0xFFFFB347)]
        : const [Color(0xFFFFF4D6), Color(0xFFFCB315)];
    final borderColor = dueSoon
        ? const Color(0xFFE88A3C)
        : const Color(0xFFE8A80C);

    final needRadius = BorderRadius.circular(PortalTheme.radiusXl);
    return Padding(
      padding: const EdgeInsets.fromLTRB(_hPad, 10, _hPad, 4),
      child: Material(
        color: Colors.transparent,
        elevation: 2,
        shadowColor: (dueSoon ? PortalTheme.amber : PortalTheme.gold)
            .withValues(alpha: 0.45),
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
                    color: Colors.white.withValues(alpha: 0.18),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: PortalTheme.navy.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            dueSoon
                                ? Icons.schedule_rounded
                                : Icons.priority_high_rounded,
                            size: 16,
                            color: PortalTheme.gold,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                dueSoon
                                    ? 'Due soon — needs your attention'
                                    : 'Needs your attention',
                                style: PortalTheme.cardTitle.copyWith(
                                  color: PortalTheme.navy,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                dueSoonLabel?.trim().isNotEmpty == true
                                    ? dueSoonLabel!
                                    : (actionCount == 1
                                          ? '1 action waiting for you'
                                          : '$actionCount actions waiting for you'),
                                style: PortalTheme.meta.copyWith(
                                  color: PortalTheme.navy.withValues(
                                    alpha: 0.72,
                                  ),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_hasTracer)
                      _AttentionBannerRow(
                        icon: Icons.assignment_outlined,
                        title: 'Graduate Tracer Survey',
                        subtitle: tracerSubtitle?.trim().isNotEmpty == true
                            ? tracerSubtitle!
                            : '${tracerPercent.toStringAsFixed(0)}% complete — finish your CHED Tracer',
                        onTap: onOpenTracer,
                        progress: (tracerPercent / 100).clamp(0.0, 1.0),
                      ),
                    if (_hasTracer && _hasSurveys) const SizedBox(height: 8),
                    if (_hasSurveys)
                      _AttentionBannerRow(
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

class _AttentionBannerRow extends StatelessWidget {
  const _AttentionBannerRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.progress,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final double? progress;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(PortalTheme.radiusMd),
        child: Ink(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(PortalTheme.radiusMd),
            border: Border.all(color: Colors.white),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
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
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: PortalTheme.cardTitle.copyWith(
                        color: PortalTheme.navy,
                        fontSize: 13,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: PortalTheme.meta.copyWith(
                        color: PortalTheme.textSecondary,
                        fontSize: 11,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (progress != null) ...[
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 4,
                          backgroundColor: PortalTheme.surfaceMuted,
                          valueColor: const AlwaysStoppedAnimation(
                            PortalTheme.navy,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 22,
                color: Color(0xFF9CA3AF),
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
      padding: const EdgeInsets.fromLTRB(_hPad, 8, _hPad, 4),
      child: Row(
        children: [
          Expanded(
            child: HomeStatCard(
              icon: Icons.campaign_outlined,
              iconColor: PortalTheme.navyMid,
              iconBg: PortalTheme.sky.withValues(alpha: 0.2),
              count: announcementsCount,
              label: 'Announcements',
              onTap: onAnnouncements,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: HomeStatCard(
              icon: Icons.forum_outlined,
              iconColor: const Color(0xFF7C3AED),
              iconBg: const Color(0xFF7C3AED).withValues(alpha: 0.12),
              count: communityTodayCount,
              label: 'Posts today',
              onTap: onCommunity,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: HomeStatCard(
              icon: Icons.event_outlined,
              iconColor: const Color(0xFF059669),
              iconBg: const Color(0xFF059669).withValues(alpha: 0.12),
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
      radius: PortalTheme.radiusLg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(8),
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
                borderRadius: BorderRadius.circular(PortalTheme.radiusLg),
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
  if (days == 0) return 'Today';
  if (days == 1) return 'Tomorrow';
  if (days > 1 && days <= 14) return '$days days';
  return intl.DateFormat('MMM d').format(event.date);
}

bool homeEventIsToday(AlumniEvent event, {DateTime? now}) {
  final status = deriveEventDisplayStatus(event, now: now);
  return status == EventDisplayStatus.today ||
      status == EventDisplayStatus.ongoing;
}

// ═══════════════════════════════════════════════════════════════════════════
// EVENTS — compact vertical list (restored old layout)
// ═══════════════════════════════════════════════════════════════════════════

class HomeUpcomingEventsList extends StatelessWidget {
  const HomeUpcomingEventsList({
    super.key,
    required this.events,
    required this.onTap,
  });

  final List<AlumniEvent> events;
  final ValueChanged<AlumniEvent> onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _hPad),
      child: Column(
        children: [
          for (var i = 0; i < events.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            HomeCompactEventCard(
              event: events[i],
              onTap: () => onTap(events[i]),
            ),
          ],
        ],
      ),
    );
  }
}

class HomeCompactEventCard extends StatelessWidget {
  const HomeCompactEventCard({
    super.key,
    required this.event,
    required this.onTap,
  });

  final AlumniEvent event;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isToday = homeEventIsToday(event);
    final month = intl.DateFormat('MMM').format(event.date).toUpperCase();
    final day = intl.DateFormat('d').format(event.date);
    final timeRange = homeFormatEventTimeRange(event.startTime, event.endTime);
    final statusLabel = homeEventRelativeLabel(event);
    final venue = event.venue.trim();

    return _portalCard(
      onTap: onTap,
      padding: const EdgeInsets.all(12),
      radius: PortalTheme.radiusLg,
      borderColor: isToday
          ? PortalTheme.gold.withValues(alpha: 0.85)
          : PortalTheme.border.withValues(alpha: 0.75),
      borderWidth: isToday ? 1.5 : 1,
      elevation: isToday ? 2.25 : 1.25,
      shadowColor: isToday ? PortalTheme.gold.withValues(alpha: 0.45) : null,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 54,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: PortalTheme.navy,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    month,
                    style: PortalTheme.caption.copyWith(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontWeight: FontWeight.w700,
                      fontSize: 9,
                      letterSpacing: 0.4,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    day,
                    style: PortalTheme.cardTitle.copyWith(
                      color: Colors.white,
                      fontSize: 18,
                      height: 1,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.theme,
                    style: PortalTheme.cardTitle.copyWith(fontSize: 14),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.schedule_rounded,
                        size: 13,
                        color: PortalTheme.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          timeRange,
                          style: PortalTheme.meta.copyWith(fontSize: 11),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (venue.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 13,
                          color: PortalTheme.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            venue,
                            style: PortalTheme.meta.copyWith(fontSize: 11),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isToday
                      ? PortalTheme.gold.withValues(alpha: 0.25)
                      : const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(20),
                  border: isToday
                      ? Border.all(
                          color: PortalTheme.gold.withValues(alpha: 0.6),
                        )
                      : null,
                ),
                child: Text(
                  statusLabel,
                  style: PortalTheme.caption.copyWith(
                    color: isToday ? PortalTheme.navy : const Color(0xFFC2410C),
                    fontWeight: FontWeight.w800,
                    fontSize: 10,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// COMMUNITY — horizontal carousel
// ═══════════════════════════════════════════════════════════════════════════

class HomeCommunityCarousel extends StatelessWidget {
  const HomeCommunityCarousel({
    super.key,
    required this.topics,
    required this.onTapTopic,
  });

  final List<ForumTopic> topics;
  final ValueChanged<ForumTopic> onTapTopic;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 198,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: _hPad),
        itemCount: topics.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          return HomeCommunityCard(
            topic: topics[i],
            onTap: () => onTapTopic(topics[i]),
          );
        },
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
    final url = topic.authorAvatarUrl;
    final provider = url == null || url.isEmpty ? null : AppImage.provider(url);
    final authorName = topic.authorName.trim().isEmpty
        ? 'Alumni'
        : topic.authorName.trim();
    final body = topic.body.trim().replaceAll(RegExp(r'\s+'), ' ');
    final isLongBody = body.length > 72;
    final preview = isLongBody ? '${body.substring(0, 72).trimRight()}…' : body;

    return SizedBox(
      width: 248,
      child: _portalCard(
        onTap: onTap,
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        radius: PortalTheme.radiusXl,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: PortalTheme.surfaceMuted,
                    border: Border.all(
                      color: PortalTheme.border.withValues(alpha: 0.8),
                    ),
                    image: provider == null
                        ? null
                        : DecorationImage(image: provider, fit: BoxFit.cover),
                  ),
                  child: provider == null
                      ? Icon(
                          Icons.person_rounded,
                          size: 16,
                          color: PortalTheme.navy.withValues(alpha: 0.45),
                        )
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        authorName,
                        style: PortalTheme.cardTitle.copyWith(
                          fontSize: 12,
                          color: PortalTheme.navy,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 1),
                      Text(
                        _relativeTime(topic.createdAt),
                        style: PortalTheme.caption.copyWith(
                          fontSize: 10,
                          color: PortalTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 4,
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
                        size: 11,
                        color: PortalTheme.navyMid,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '${topic.replyCount}',
                        style: PortalTheme.caption.copyWith(
                          fontWeight: FontWeight.w800,
                          fontSize: 10,
                          color: PortalTheme.navy,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              topic.title,
              style: PortalTheme.cardTitle.copyWith(
                fontSize: 14,
                height: 1.25,
                color: PortalTheme.navy,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (preview.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: preview,
                      style: PortalTheme.meta.copyWith(
                        fontSize: 12,
                        height: 1.4,
                        color: const Color(0xFF5B6475),
                      ),
                    ),
                    if (isLongBody)
                      TextSpan(
                        text: ' See more',
                        style: PortalTheme.meta.copyWith(
                          fontSize: 12,
                          height: 1.4,
                          color: PortalTheme.navyMid,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                  ],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const Spacer(),
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
                        'Join conversation',
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
}

class HomeCommunityEmpty extends StatelessWidget {
  const HomeCommunityEmpty({super.key, this.onBrowse});

  final VoidCallback? onBrowse;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _hPad),
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
      padding: const EdgeInsets.symmetric(horizontal: _hPad),
      child: _portalCard(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
        radius: PortalTheme.radiusXl,
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

// ═══════════════════════════════════════════════════════════════════════════
// EVENTS — horizontal carousel / sleek preview (legacy)
// ═══════════════════════════════════════════════════════════════════════════

class HomeEventsCarousel extends StatelessWidget {
  const HomeEventsCarousel({
    super.key,
    required this.events,
    required this.onTap,
  });

  final List<AlumniEvent> events;
  final ValueChanged<AlumniEvent> onTap;

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) return const SizedBox.shrink();

    if (events.length == 1) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: _hPad),
        child: HomeEventPreviewCard(
          event: events.first,
          onTap: () => onTap(events.first),
          width: double.infinity,
        ),
      );
    }

    return SizedBox(
      height: 210,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: _hPad),
        itemCount: events.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final e = events[i];
          return HomeEventPreviewCard(
            event: e,
            onTap: () => onTap(e),
            width: 268,
          );
        },
      ),
    );
  }
}

class HomeEventPreviewCard extends StatelessWidget {
  const HomeEventPreviewCard({
    super.key,
    required this.event,
    required this.onTap,
    this.width = 268,
  });

  final AlumniEvent event;
  final VoidCallback onTap;
  final double width;

  @override
  Widget build(BuildContext context) {
    final date = event.date;
    final month = intl.DateFormat('MMM').format(date).toUpperCase();
    final day = intl.DateFormat('d').format(date);
    final when = intl.DateFormat('EEE · h:mm a').format(date);
    final imageH = width == double.infinity ? 128.0 : 112.0;

    return SizedBox(
      width: width == double.infinity ? null : width,
      child: _portalCard(
        onTap: onTap,
        radius: PortalTheme.radiusXl,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(PortalTheme.radiusXl),
              ),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    EventCover(
                      event: event,
                      height: imageH,
                      borderRadius: 0,
                      fit: BoxFit.cover,
                    ),
                    Positioned(
                      left: 10,
                      top: 10,
                      child: Container(
                        width: 44,
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: PortalTheme.border.withValues(alpha: 0.7),
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(
                              month,
                              style: PortalTheme.caption.copyWith(
                                color: PortalTheme.navy,
                                fontWeight: FontWeight.w800,
                                fontSize: 9,
                                letterSpacing: 0.3,
                              ),
                            ),
                            Text(
                              day,
                              style: PortalTheme.cardTitle.copyWith(
                                fontSize: 16,
                                height: 1.1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (event.category.isNotEmpty)
                      Positioned(
                        right: 10,
                        top: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: PortalTheme.navy.withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            event.category,
                            style: PortalTheme.caption.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.theme,
                    style: PortalTheme.cardTitle.copyWith(fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    event.venue.trim().isEmpty
                        ? when
                        : '$when · ${event.venue}',
                    style: PortalTheme.meta.copyWith(fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HomeEventsEmpty extends StatelessWidget {
  const HomeEventsEmpty({super.key, this.onBrowse});

  final VoidCallback? onBrowse;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _hPad),
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
      radius: PortalTheme.radiusLg,
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
    required this.onAiHelp,
    this.unreadMessages = 0,
  });

  final VoidCallback onSupport;
  final VoidCallback onAiHelp;
  final int unreadMessages;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(_hPad, 4, _hPad, 0),
      child: _portalCard(
        radius: PortalTheme.radiusXl,
        child: Column(
          children: [
            _SupportListTile(
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
            Divider(
              height: 1,
              color: PortalTheme.border.withValues(alpha: 0.8),
            ),
            _SupportListTile(
              icon: Icons.auto_awesome_outlined,
              iconBg: PortalTheme.gold.withValues(alpha: 0.2),
              iconColor: PortalTheme.navy,
              title: 'AI Help',
              subtitle: 'Ask questions about the portal',
              onTap: onAiHelp,
            ),
          ],
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
