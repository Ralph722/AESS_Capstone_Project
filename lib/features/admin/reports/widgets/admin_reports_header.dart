import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:alumni_system/features/admin/reports/widgets/admin_reports_layout.dart';
import 'package:alumni_system/shared/widgets/admin/admin_density.dart';

/// Enterprise analytics dashboard header for Reports & Analytics.
///
/// Renders as the top half of a card whose bottom half is the pinned tab
/// strip, so it has no bottom border or bottom radius of its own.
class ReportsPageHeader extends StatelessWidget {
  const ReportsPageHeader({
    super.key,
    this.subtitle =
        'Clear briefs for tracer, surveys, and office report packs.',
    this.updatedAt,
    this.onRefresh,
    this.refreshing = false,
  });

  /// Fixed so tabs can size themselves to the remaining viewport.
  static const double height = 72;

  final String subtitle;

  /// When the dashboard data last finished loading.
  final DateTime? updatedAt;
  final VoidCallback? onRefresh;
  final bool refreshing;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AdminReportsTheme.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AdminReportsTheme.border),
        boxShadow: AdminReportsTheme.cardShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AdminReportsTheme.space3,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final showStatus = constraints.maxWidth >= 620;
            return Row(
              children: [
                const _HeaderEmblem(),
                const SizedBox(width: AdminReportsTheme.space2),
                Expanded(child: _titleBlock()),
                if (showStatus && updatedAt != null) ...[
                  const SizedBox(width: AdminReportsTheme.space2),
                  _LiveStatus(updatedAt: updatedAt!),
                ],
                if (onRefresh != null) ...[
                  const SizedBox(width: 8),
                  _RefreshButton(
                    onPressed: refreshing ? null : onRefresh,
                    refreshing: refreshing,
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _titleBlock() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Reports & Analytics',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: AdminDensity.titleFontSize,
            fontWeight: FontWeight.w800,
            color: AdminReportsTheme.textPrimary,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 2),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Text(
            subtitle,
            key: ValueKey(subtitle),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: AdminDensity.subtitleFontSize,
              height: 1.35,
              color: AdminReportsTheme.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

class _HeaderEmblem extends StatelessWidget {
  const _HeaderEmblem();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AdminReportsTheme.radiusMd),
        color: AdminReportsTheme.primary,
        boxShadow: [
          BoxShadow(
            color: AdminReportsTheme.primary.withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Icon(Icons.insights_rounded, size: 20, color: Colors.white),
          Positioned(
            right: 6,
            top: 6,
            child: Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: AdminReportsTheme.gold,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveStatus extends StatelessWidget {
  const _LiveStatus({required this.updatedAt});

  final DateTime updatedAt;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final sameDay =
        now.year == updatedAt.year &&
        now.month == updatedAt.month &&
        now.day == updatedAt.day;
    final time = DateFormat(
      sameDay ? 'h:mm a' : 'MMM d, h:mm a',
    ).format(updatedAt);
    return Tooltip(
      message:
          'Figures refresh automatically when alumni, tracer, or survey '
          'data changes.',
      waitDuration: const Duration(milliseconds: 500),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AdminReportsTheme.card,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AdminReportsTheme.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: AdminReportsTheme.success,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AdminReportsTheme.success.withValues(alpha: 0.35),
                    blurRadius: 4,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 7),
            const Text(
              'Live',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: AdminReportsTheme.textPrimary,
              ),
            ),
            Text(
              ' · Updated $time',
              style: const TextStyle(
                fontSize: 11.5,
                color: AdminReportsTheme.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RefreshButton extends StatelessWidget {
  const _RefreshButton({required this.onPressed, required this.refreshing});

  final VoidCallback? onPressed;
  final bool refreshing;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 34,
      height: 34,
      child: IconButton(
        onPressed: onPressed,
        tooltip: refreshing ? 'Refreshing…' : 'Refresh data',
        padding: EdgeInsets.zero,
        style: IconButton.styleFrom(
          backgroundColor: AdminReportsTheme.card,
          side: const BorderSide(color: AdminReportsTheme.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AdminReportsTheme.radiusMd),
          ),
        ),
        icon: refreshing
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AdminReportsTheme.primary,
                ),
              )
            : const Icon(
                Icons.refresh_rounded,
                size: 18,
                color: AdminReportsTheme.primary,
              ),
      ),
    );
  }
}
