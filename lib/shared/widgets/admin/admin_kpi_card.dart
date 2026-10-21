import 'package:flutter/material.dart';
import 'package:alumni_system/shared/widgets/admin/admin_density.dart';
import 'package:alumni_system/shared/widgets/admin/admin_theme.dart';

enum AdminTone { neutral, info, success, warning, danger }

extension AdminToneColors on AdminTone {
  Color get foreground => switch (this) {
    AdminTone.neutral => AdminColors.textSecondary,
    AdminTone.info => AdminColors.info,
    AdminTone.success => AdminColors.success,
    AdminTone.warning => AdminColors.warning,
    AdminTone.danger => AdminColors.danger,
  };

  Color get background => switch (this) {
    AdminTone.neutral => AdminColors.surface,
    AdminTone.info => AdminColors.infoBg,
    AdminTone.success => AdminColors.successBg,
    AdminTone.warning => AdminColors.warningBg,
    AdminTone.danger => AdminColors.dangerBg,
  };
}

class AdminKpiPill {
  const AdminKpiPill(this.label, {this.tone = AdminTone.neutral});

  final String label;
  final AdminTone tone;
}

/// Change versus a comparison period, e.g. `+12%` "vs last month".
class AdminKpiTrend {
  const AdminKpiTrend({
    required this.percent,
    required this.comparison,
    this.positiveIsGood = true,
  });

  final double percent;
  final String comparison;

  /// When false, an increase is shown in the danger tone.
  final bool positiveIsGood;

  String get formatted {
    final rounded = percent.abs() >= 10
        ? percent.abs().toStringAsFixed(0)
        : percent.abs().toStringAsFixed(1);
    final sign = percent > 0 ? '+' : (percent < 0 ? '−' : '');
    return '$sign$rounded%';
  }
}

/// KPI card: label, large value, optional pill, trend, caption, detail rows
/// and an embedded chart.
class AdminKpiCard extends StatefulWidget {
  const AdminKpiCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.accent = AdminColors.primary,
    this.palette,
    this.caption,
    this.pill,
    this.trend,
    this.rows = const [],
    this.chart,
    this.onTap,
    this.dense = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color accent;

  /// Adds a top colour strip and tints the icon chip; overrides [accent].
  final AdminAccent? palette;

  /// Denominator or context, e.g. "3 of 8 programs".
  final String? caption;
  final AdminKpiPill? pill;
  final AdminKpiTrend? trend;
  final List<(String, String)> rows;
  final Widget? chart;
  final VoidCallback? onTap;

  /// Uses the 22px value size for dense KPI strips.
  final bool dense;

  @override
  State<AdminKpiCard> createState() => _AdminKpiCardState();
}

class _AdminKpiCardState extends State<AdminKpiCard> {
  bool _hovered = false;

  String get _semanticLabel {
    final parts = <String>[
      widget.label,
      widget.value,
      if (widget.pill != null) widget.pill!.label,
      if (widget.trend != null)
        '${widget.trend!.formatted} ${widget.trend!.comparison}',
      if (widget.caption != null) widget.caption!,
      for (final (label, value) in widget.rows) '$label: $value',
    ];
    return parts.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final interactive = widget.onTap != null;
    final padding = widget.dense ? AdminDensity.kpiCardPadding : 16.0;

    final Widget body = Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(AdminSurfaces.radiusLg),
          child: Padding(
            padding: EdgeInsets.all(padding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHeader(),
                SizedBox(height: widget.dense ? 8 : 12),
                _buildValueLine(),
                if (widget.caption != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    widget.caption!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AdminText.caption,
                  ),
                ],
                if (widget.rows.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  const Divider(height: 1, color: AdminColors.border),
                  const SizedBox(height: 6),
                  for (final (label, value) in widget.rows)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AdminText.caption,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            value,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AdminColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
                if (widget.chart != null) ...[
                  const SizedBox(height: 12),
                  ExcludeSemantics(child: widget.chart!),
                ],
              ],
            ),
          ),
        ),
    );

    final card = AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      decoration: AdminSurfaces.card(hovered: interactive && _hovered),
      child: body,
    );

    return Semantics(
      container: true,
      button: interactive,
      label: _semanticLabel,
      excludeSemantics: true,
      onTap: widget.onTap,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: card,
      ),
    );
  }

  Widget _buildHeader() {
    final palette = widget.palette;
    return Row(
      children: [
        Container(
          width: AdminDensity.kpiIconBox,
          height: AdminDensity.kpiIconBox,
          decoration: BoxDecoration(
            color: palette?.tint ?? widget.accent.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AdminSurfaces.radiusSm),
          ),
          child: Icon(
            widget.icon,
            size: AdminDensity.kpiIconSize,
            color: palette?.onTint ?? widget.accent,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            widget.label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AdminText.kpiLabel,
          ),
        ),
        if (widget.pill != null) ...[
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: widget.pill!.tone.background,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                widget.pill!.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: widget.pill!.tone.foreground,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildValueLine() {
    final trend = widget.trend;
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.end,
      spacing: 8,
      runSpacing: 4,
      children: [
        Text(
          widget.value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: widget.dense ? AdminText.kpiValueDense : AdminText.kpiValue,
        ),
        if (trend != null) _buildTrend(trend),
      ],
    );
  }

  Widget _buildTrend(AdminKpiTrend trend) {
    final tone = trend.percent == 0
        ? AdminTone.neutral
        : ((trend.percent > 0) == trend.positiveIsGood
              ? AdminTone.success
              : AdminTone.danger);
    final icon = trend.percent > 0
        ? Icons.arrow_upward_rounded
        : (trend.percent < 0
              ? Icons.arrow_downward_rounded
              : Icons.remove_rounded);
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: tone.foreground),
          const SizedBox(width: 2),
          Text(
            trend.formatted,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: tone.foreground,
            ),
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              trend.comparison,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AdminText.caption,
            ),
          ),
        ],
      ),
    );
  }
}
