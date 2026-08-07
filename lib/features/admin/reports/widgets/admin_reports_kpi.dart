import 'package:flutter/material.dart';
import 'package:alumni_system/features/admin/reports/widgets/admin_reports_layout.dart';
import 'package:alumni_system/shared/widgets/admin/admin_density.dart';

enum ReportsKpiStatus { positive, neutral, watch, attention }

/// Premium KPI card for the Reports dashboard (presentation only).
class ReportsKpiCard extends StatefulWidget {
  const ReportsKpiCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.growthPercent,
    this.comparisonLabel,
    this.status,
    this.statusLabel,
    this.sparkline,
    this.height = AdminDensity.reportsKpiHeight,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  /// Period growth when available; null means no trend chip.
  final double? growthPercent;

  /// Extra context under the value (e.g. "of roster").
  final String? comparisonLabel;

  final ReportsKpiStatus? status;
  final String? statusLabel;

  /// Optional sparkline points (0–1). Omitted when null or too short —
  /// never invents decorative history.
  final List<double>? sparkline;

  final double height;

  @override
  State<ReportsKpiCard> createState() => _ReportsKpiCardState();
}

class _ReportsKpiCardState extends State<ReportsKpiCard> {
  final ValueNotifier<bool> _hovered = ValueNotifier(false);

  @override
  void dispose() {
    _hovered.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final growth = widget.growthPercent;
    final status = widget.status;
    final spark = (widget.sparkline != null && widget.sparkline!.length >= 2)
        ? widget.sparkline!
        : null;

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: AdminDensity.kpiIconBox,
              height: AdminDensity.kpiIconBox,
              decoration: BoxDecoration(
                color: widget.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                widget.icon,
                color: widget.color,
                size: AdminDensity.kpiIconSize,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: AdminDensity.kpiLabelFontSize,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                  color: AdminReportsTheme.textSecondary,
                ),
              ),
            ),
            if (status != null && (widget.statusLabel?.isNotEmpty ?? false))
              _StatusBadge(status: status, label: widget.statusLabel!),
          ],
        ),
        const Spacer(),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: AdminDensity.kpiValueFontSize,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      color: AdminReportsTheme.textPrimary,
                      height: 1.1,
                    ),
                  ),
                  if (growth != null ||
                      (widget.comparisonLabel?.isNotEmpty ?? false)) ...[
                    const SizedBox(height: 2),
                    _comparisonRow(growth),
                  ],
                ],
              ),
            ),
            if (spark != null) ...[
              const SizedBox(width: 8),
              SizedBox(
                width: 56,
                height: 24,
                child: CustomPaint(
                  painter: _SparklinePainter(
                    points: spark,
                    color: widget.color,
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );

    return MouseRegion(
      hitTestBehavior: HitTestBehavior.deferToChild,
      onEnter: (_) => _hovered.value = true,
      onExit: (_) => _hovered.value = false,
      child: Semantics(
        label:
            '${widget.label}: ${widget.value}${widget.statusLabel != null ? ', ${widget.statusLabel}' : ''}',
        child: ListenableBuilder(
          listenable: _hovered,
          child: content,
          builder: (context, child) {
            return AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              height: widget.height,
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
              decoration: BoxDecoration(
                color: AdminReportsTheme.card,
                borderRadius: BorderRadius.circular(AdminReportsTheme.radiusMd),
                border: Border.all(
                  color: _hovered.value
                      ? widget.color.withValues(alpha: 0.35)
                      : AdminReportsTheme.border,
                ),
                boxShadow: _hovered.value
                    ? AdminDirectoryHoverShadow.elevated
                    : AdminReportsTheme.cardShadow,
              ),
              child: child,
            );
          },
        ),
      ),
    );
  }

  Widget _comparisonRow(double? growth) {
    final comparison = widget.comparisonLabel;

    return Wrap(
      spacing: 6,
      runSpacing: 2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (growth != null) _GrowthChip(percent: growth),
        if (comparison != null)
          Text(
            comparison,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AdminReportsTheme.textMuted,
            ),
          ),
      ],
    );
  }
}

class AdminDirectoryHoverShadow {
  static List<BoxShadow> get elevated => [
    BoxShadow(
      color: AdminReportsTheme.primary.withValues(alpha: 0.08),
      blurRadius: 16,
      offset: const Offset(0, 6),
    ),
  ];
}

ReportsKpiStatus reportsKpiStatusFromRate(double rate) {
  if (rate >= 0.75) return ReportsKpiStatus.positive;
  if (rate >= 0.45) return ReportsKpiStatus.watch;
  if (rate <= 0) return ReportsKpiStatus.neutral;
  return ReportsKpiStatus.attention;
}

String reportsKpiStatusLabel(ReportsKpiStatus status) => switch (status) {
  ReportsKpiStatus.positive => 'On track',
  ReportsKpiStatus.neutral => 'Neutral',
  ReportsKpiStatus.watch => 'Watch',
  ReportsKpiStatus.attention => 'Needs attention',
};

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status, required this.label});

  final ReportsKpiStatus status;
  final String label;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      ReportsKpiStatus.positive => AdminReportsTheme.success,
      ReportsKpiStatus.neutral => AdminReportsTheme.textMuted,
      ReportsKpiStatus.watch => AdminReportsTheme.warning,
      ReportsKpiStatus.attention => AdminReportsTheme.danger,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _GrowthChip extends StatelessWidget {
  const _GrowthChip({required this.percent});

  final double percent;

  @override
  Widget build(BuildContext context) {
    final up = percent >= 0;
    final color = up ? AdminReportsTheme.success : AdminReportsTheme.danger;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          up ? Icons.trending_up : Icons.trending_down,
          size: 12,
          color: color,
        ),
        const SizedBox(width: 2),
        Text(
          '${percent >= 0 ? '+' : ''}${percent.toStringAsFixed(0)}%',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({required this.points, required this.color});

  final List<double> points;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final paint = Paint()
      ..color = color.withValues(alpha: 0.85)
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final x = size.width * (i / (points.length - 1));
      final y = size.height * (1 - points[i].clamp(0.0, 1.0));
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) =>
      oldDelegate.points != points || oldDelegate.color != color;
}

/// Skeleton placeholder matching [ReportsKpiCard] footprint.
class ReportsKpiCardSkeleton extends StatelessWidget {
  const ReportsKpiCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: AdminDensity.reportsKpiHeight,
      padding: const EdgeInsets.all(AdminDensity.kpiCardPadding),
      decoration: BoxDecoration(
        color: AdminReportsTheme.card,
        borderRadius: BorderRadius.circular(AdminReportsTheme.radiusMd),
        border: Border.all(color: AdminReportsTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: AdminDensity.kpiIconBox,
                height: AdminDensity.kpiIconBox,
                decoration: BoxDecoration(
                  color: AdminReportsTheme.border,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(height: 12, color: AdminReportsTheme.border),
              ),
            ],
          ),
          const Spacer(),
          Container(height: 20, width: 64, color: AdminReportsTheme.border),
          const SizedBox(height: 6),
          Container(height: 10, width: 100, color: AdminReportsTheme.border),
        ],
      ),
    );
  }
}
