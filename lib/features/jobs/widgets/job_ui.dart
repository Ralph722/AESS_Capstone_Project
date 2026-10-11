import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:alumni_system/core/utils/app_image.dart';
import 'package:alumni_system/features/jobs/models/job_posting_model.dart';
import 'package:alumni_system/shared/widgets/user/portal_theme.dart';
import 'package:alumni_system/shared/widgets/user/portal_headers.dart';

/// Shared jobs visual tokens — aligned with [PortalTheme] (USTP navy/gold).
abstract final class JobUiTheme {
  static const Color navy = PortalTheme.navy;
  static const Color navyDeep = PortalTheme.navyDeep;
  static const Color navyMid = PortalTheme.navyMid;
  static const Color amber = PortalTheme.gold;
  static const Color gold = PortalTheme.gold;
  static const Color sky = PortalTheme.sky;
  static const Color pageBg = PortalTheme.pageBg;
  static const Color surfaceMuted = PortalTheme.surfaceMuted;
  static const Color card = Colors.white;
  static const Color border = PortalTheme.border;
  static const Color textPrimary = PortalTheme.textPrimary;
  static const Color textSecondary = PortalTheme.textSecondary;
  static const Color textMuted = PortalTheme.textMuted;
  static const Color success = PortalTheme.success;
  static const Color danger = PortalTheme.danger;

  static const double radiusSm = PortalTheme.radiusSm;
  static const double radiusMd = PortalTheme.radiusMd;
  static const double radiusLg = PortalTheme.radiusLg;
  static const double radiusXl = PortalTheme.radiusXl;
  static const double radius2xl = PortalTheme.radius2xl;

  static BorderRadius get cardRadius => BorderRadius.circular(radius2xl);

  /// Soft elevation kept outside the clipped card surface.
  static List<BoxShadow> get cardShadow => PortalTheme.softShadow;

  /// Surface fill + border only (no shadow — avoids grey corner leftovers).
  static BoxDecoration get cardDecoration => BoxDecoration(
        color: card,
        borderRadius: cardRadius,
        border: Border.all(color: border.withValues(alpha: 0.75)),
      );
}

/// Tappable job card shell — clipped Material elevation (no corner leftovers).
class JobCardShell extends StatelessWidget {
  const JobCardShell({
    super.key,
    required this.onTap,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  final VoidCallback onTap;
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return PortalCardShell(
      onTap: onTap,
      padding: padding,
      borderRadius: JobUiTheme.cardRadius,
      color: JobUiTheme.card,
      borderColor: JobUiTheme.border.withValues(alpha: 0.75),
      elevation: 1,
      shadowColor: JobUiTheme.navy.withValues(alpha: 0.08),
      child: child,
    );
  }
}

/// Relative posted label for feed cards.
String jobPostedAgo(DateTime dt, {DateTime? now}) {
  final clock = now ?? DateTime.now();
  final d = clock.difference(dt);
  if (d.inDays >= 7) return 'Posted ${DateFormat.MMMd().format(dt)}';
  if (d.inDays >= 2) return 'Posted ${d.inDays} days ago';
  if (d.inDays == 1) return 'Posted yesterday';
  if (d.inHours >= 1) return 'Posted today';
  if (d.inMinutes >= 1) return 'Posted today';
  return 'Posted today';
}

/// Compact date for card headers (e.g. Dec 5).
String jobPostedShort(DateTime dt) => DateFormat.MMMd().format(dt);

/// Display salary with Philippine peso. Replaces `$` and adds `₱` when missing.
String formatJobSalaryPhp(String raw) {
  var s = raw.trim();
  if (s.isEmpty) return '';
  s = s.replaceAll('\$', '₱').replaceAll('USD', '₱').replaceAll('usd', '₱');
  if (!s.contains('₱') && RegExp(r'\d').hasMatch(s)) {
    s = '₱ $s';
  }
  // Prefer "₱ 50,000" spacing after the symbol when glued.
  s = s.replaceAllMapped(
    RegExp(r'₱\s*'),
    (_) => '₱ ',
  );
  return s.replaceAll(RegExp(r'\s{2,}'), ' ').trim();
}

/// Compact deadline hint for cards/details, or null if far away / invalid.
String? jobDeadlineHint(DateTime deadline, {DateTime? now}) {
  final clock = now ?? DateTime.now();
  final end = DateTime(
    deadline.year,
    deadline.month,
    deadline.day,
    23,
    59,
    59,
  );
  if (clock.isAfter(end)) return 'Application closed';
  final days = DateTime(end.year, end.month, end.day)
      .difference(DateTime(clock.year, clock.month, clock.day))
      .inDays;
  if (days <= 0) return 'Due today';
  if (days == 1) return '1 day left';
  if (days <= 7) return '$days days left';
  return null;
}

class JobCompanyLogo extends StatelessWidget {
  const JobCompanyLogo({
    super.key,
    required this.job,
    this.size = 48,
    this.radius = 12,
  });

  final JobPosting job;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final url = job.companyLogo.trim();
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: JobUiTheme.navy.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: JobUiTheme.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: url.isEmpty
          ? Icon(
              Icons.business_rounded,
              color: JobUiTheme.navy.withValues(alpha: 0.7),
              size: size * 0.42,
            )
          : AppImage.widget(
              url,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Icon(
                Icons.business_rounded,
                color: JobUiTheme.navy.withValues(alpha: 0.7),
                size: size * 0.42,
              ),
            ),
    );
  }
}

class JobStatusBadge extends StatelessWidget {
  const JobStatusBadge({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final s = status.toLowerCase();
    final PortalChipTone tone;
    switch (s) {
      case 'active':
        tone = PortalChipTone.success;
      case 'expired':
        tone = PortalChipTone.danger;
      case 'archived':
        tone = PortalChipTone.neutral;
      default:
        tone = PortalChipTone.brand;
    }
    return PortalChip(label: s.toUpperCase(), tone: tone);
  }
}

class JobMetricChip extends StatelessWidget {
  const JobMetricChip({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: JobUiTheme.textMuted),
          const SizedBox(width: 4),
          Text(
            value,
            style: PortalTheme.caption.copyWith(
              color: JobUiTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class JobCategoryBadge extends StatelessWidget {
  const JobCategoryBadge({
    super.key,
    required this.category,
    this.compact = false,
  });

  final String category;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return PortalChip(label: category, tone: PortalChipTone.brand);
  }
}

/// Soft muted pill for job metadata tags.
class JobTagPill extends StatelessWidget {
  const JobTagPill({
    super.key,
    required this.label,
    this.emphasized = false,
    this.icon,
  });

  final String label;
  final bool emphasized;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final fg = JobUiTheme.navy;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: emphasized
            ? JobUiTheme.navy.withValues(alpha: 0.08)
            : JobUiTheme.surfaceMuted,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: emphasized
              ? JobUiTheme.navy.withValues(alpha: 0.16)
              : JobUiTheme.border.withValues(alpha: 0.9),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: fg.withValues(alpha: 0.85)),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: PortalTheme.caption.copyWith(
              color: fg,
              fontWeight: FontWeight.w700,
              fontSize: 11.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// Inline meta chips for job cards (type / location / remote).
class JobMetaRow extends StatelessWidget {
  const JobMetaRow({
    super.key,
    required this.location,
    required this.jobType,
    required this.posted,
    this.isRemote = false,
    this.experienceLevel = '',
  });

  final String location;
  final String jobType;
  final String posted;
  final bool isRemote;
  final String experienceLevel;

  @override
  Widget build(BuildContext context) {
    final loc = location.trim();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (jobType.isNotEmpty)
          JobTagPill(label: jobType, icon: Icons.work_outline_rounded),
        if (loc.isNotEmpty)
          JobTagPill(label: loc, icon: Icons.place_outlined),
        if (isRemote)
          const JobTagPill(
            label: 'Remote',
            icon: Icons.home_work_outlined,
            emphasized: true,
          ),
      ],
    );
  }
}

/// Pill for the grey job details header.
class JobHeaderPill extends StatelessWidget {
  const JobHeaderPill({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: PortalTheme.border),
      ),
      child: Text(
        label,
        style: PortalTheme.caption.copyWith(
          color: PortalTheme.navy,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }
}

/// Overview grid cell for job details.
class JobOverviewCell extends StatelessWidget {
  const JobOverviewCell({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: JobUiTheme.card,
        borderRadius: BorderRadius.circular(JobUiTheme.radiusXl),
        border: Border.all(color: JobUiTheme.border.withValues(alpha: 0.75)),
        boxShadow: JobUiTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: JobUiTheme.navy),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: PortalTheme.caption.copyWith(
                    color: JobUiTheme.textSecondary,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value.isEmpty ? '—' : value,
            style: PortalTheme.meta.copyWith(
              color: JobUiTheme.navy,
              fontWeight: FontWeight.w800,
              fontSize: 13,
              height: 1.25,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
