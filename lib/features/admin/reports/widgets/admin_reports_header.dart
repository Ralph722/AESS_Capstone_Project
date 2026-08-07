import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:alumni_system/features/admin/reports/widgets/admin_reports_layout.dart';
import 'package:alumni_system/shared/widgets/admin/admin_density.dart';

/// Enterprise analytics dashboard header for Reports & Analytics.
class ReportsPageHeader extends StatelessWidget {
  const ReportsPageHeader({
    super.key,
    required this.reportDate,
    required this.lastUpdated,
    required this.onDownloads,
    required this.onAiSummary,
  });

  final DateTime reportDate;
  final DateTime? lastUpdated;
  final VoidCallback onDownloads;
  final VoidCallback onAiSummary;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 960;
    final dateFmt = DateFormat.yMMMd();
    final timeFmt = DateFormat.jm();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AdminReportsTheme.space3),
      decoration: BoxDecoration(
        color: AdminReportsTheme.card,
        borderRadius: BorderRadius.circular(AdminReportsTheme.radiusLg),
        border: Border.all(color: AdminReportsTheme.border),
        boxShadow: AdminReportsTheme.cardShadow,
      ),
      child: wide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _titleBlock(dateFmt, timeFmt)),
                const SizedBox(width: AdminReportsTheme.space2),
                _actionRow(),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _titleBlock(dateFmt, timeFmt),
                const SizedBox(height: AdminReportsTheme.space2),
                _actionRow(),
              ],
            ),
    );
  }

  Widget _titleBlock(DateFormat dateFmt, DateFormat timeFmt) {
    final updated = lastUpdated;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Reports & Analytics',
          style: TextStyle(
            fontSize: AdminDensity.titleFontSize,
            fontWeight: FontWeight.w800,
            color: AdminReportsTheme.textPrimary,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Clear briefs for tracer, surveys, and office report packs.',
          style: TextStyle(
            fontSize: AdminDensity.subtitleFontSize,
            height: 1.35,
            color: AdminReportsTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            const _LivePill(),
            _MetaChip(
              icon: Icons.calendar_today_outlined,
              label: 'Report date  ${dateFmt.format(reportDate)}',
            ),
            _MetaChip(
              icon: Icons.update_outlined,
              label: updated == null
                  ? 'Last updated  —'
                  : 'Last updated  ${dateFmt.format(updated)} · ${timeFmt.format(updated)}',
            ),
          ],
        ),
      ],
    );
  }

  Widget _actionRow() {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      alignment: WrapAlignment.end,
      children: [
        FilledButton.icon(
          onPressed: onDownloads,
          icon: const Icon(Icons.download_outlined, size: 18),
          label: const Text('Downloads'),
          style: FilledButton.styleFrom(
            backgroundColor: AdminReportsTheme.primary,
            foregroundColor: Colors.white,
            minimumSize: const Size(0, AdminDensity.buttonHeight),
          ),
        ),
        OutlinedButton.icon(
          onPressed: onAiSummary,
          icon: const Icon(Icons.auto_awesome_outlined, size: 18),
          label: const Text('AI summary'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AdminReportsTheme.primary,
            side: const BorderSide(color: AdminReportsTheme.border),
            minimumSize: const Size(0, AdminDensity.buttonHeight),
          ),
        ),
      ],
    );
  }
}

/// Pulsing "Live" badge — the dashboard refreshes itself on data changes.
class _LivePill extends StatefulWidget {
  const _LivePill();

  @override
  State<_LivePill> createState() => _LivePillState();
}

class _LivePillState extends State<_LivePill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const green = AdminReportsTheme.success;
    return Tooltip(
      message:
          'Updates automatically when roster, surveys, events, jobs, or other '
          'data change in the system.',
      waitDuration: const Duration(milliseconds: 400),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: green.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: green.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FadeTransition(
              opacity: Tween(begin: 0.35, end: 1.0).animate(
                CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
              ),
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: green,
                ),
              ),
            ),
            const SizedBox(width: 6),
            const Text(
              'Live · auto-updates',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: green,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AdminReportsTheme.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AdminReportsTheme.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AdminReportsTheme.textSecondary),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AdminReportsTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
