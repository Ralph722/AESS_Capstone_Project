import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:alumni_system/shared/widgets/admin/admin_buttons.dart';
import 'package:alumni_system/shared/widgets/admin/admin_compact_header.dart';
import 'package:alumni_system/shared/widgets/admin/admin_density.dart';
import 'package:alumni_system/shared/widgets/admin/admin_theme.dart';

/// Enterprise analytics dashboard header for Reports & Analytics.
///
/// Matches the standardized 36px [AdminCompactHeader] height, typography, live
/// status pill, and unified refresh action.
class ReportsPageHeader extends StatelessWidget {
  const ReportsPageHeader({
    super.key,
    this.subtitle,
    this.updatedAt,
    this.onRefresh,
    this.refreshing = false,
  });

  /// Standardized compact header height (36px) matching the AESS admin portal shell.
  static const double height = AdminDensity.buttonHeight;

  final String? subtitle;

  /// When the dashboard data last finished loading.
  final DateTime? updatedAt;
  final VoidCallback? onRefresh;
  final bool refreshing;

  @override
  Widget build(BuildContext context) {
    return AdminCompactHeader(
      title: 'Reports & Analytics',
      subtitle: subtitle,
      actions: [
        if (updatedAt != null) _LiveStatus(updatedAt: updatedAt!),
        if (onRefresh != null)
          OutlinedButton.icon(
            onPressed: refreshing ? null : onRefresh,
            icon: refreshing
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded, size: 15),
            label: Text(refreshing ? 'Refreshing…' : 'Refresh'),
            style: AdminButtonStyles.outlined(),
          ),
      ],
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
          'Figures refresh automatically when alumni, tracer, or survey data changes.',
      waitDuration: const Duration(milliseconds: 500),
      child: Container(
        height: AdminDensity.buttonHeight,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: AdminColors.surface,
          borderRadius: BorderRadius.circular(AdminSurfaces.radiusSm),
          border: Border.all(color: AdminColors.border),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: AdminColors.success,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AdminColors.success.withValues(alpha: 0.35),
                    blurRadius: 4,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            const Text(
              'Live',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: AdminColors.textPrimary,
              ),
            ),
            Text(
              ' · $time',
              style: const TextStyle(
                fontSize: 11.5,
                color: AdminColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
