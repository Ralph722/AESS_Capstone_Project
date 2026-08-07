import 'package:flutter/material.dart';
import 'package:alumni_system/shared/widgets/admin/admin_density.dart';

const _navy = Color(0xFF090A4F);

/// Compact KPI for single-screen dashboard row.
class DashboardCompactKpi extends StatelessWidget {
  const DashboardCompactKpi({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.accent = _navy,
    this.onTap,
    this.hint,
  });

  final String label;
  final String value;
  final String? hint;
  final IconData icon;
  final Color accent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          constraints: const BoxConstraints(minHeight: AdminDensity.kpiMinHeight),
          padding: const EdgeInsets.symmetric(
            horizontal: AdminDensity.kpiCardPadding,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Container(
                width: AdminDensity.kpiIconBox,
                height: AdminDensity.kpiIconBox,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: accent, size: AdminDensity.kpiIconSize),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: AdminDensity.kpiValueFontSize,
                        fontWeight: FontWeight.bold,
                        color: _navy,
                        height: 1.1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: AdminDensity.kpiLabelFontSize,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade800,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (hint != null) ...[
                      const SizedBox(height: 1),
                      Text(
                        hint!,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade700,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
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

/// Small tappable stat chip.
class DashboardStatChip extends StatelessWidget {
  const DashboardStatChip({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.color = _navy,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Ink(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.15)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 16, color: color),
                  const SizedBox(width: 6),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: color,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(width: 6),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 120),
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade800,
                        height: 1.15,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
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

/// Primary KPI tile on the dashboard.
class DashboardInsightCard extends StatelessWidget {
  const DashboardInsightCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.subtitle,
    this.accent = _navy,
    this.onTap,
    this.badge,
  });

  final String label;
  final String value;
  final String? subtitle;
  final IconData icon;
  final Color accent;
  final VoidCallback? onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(AdminDensity.kpiCardPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: AdminDensity.kpiIconBox,
                      height: AdminDensity.kpiIconBox,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        icon,
                        color: accent,
                        size: AdminDensity.kpiIconSize,
                      ),
                    ),
                    const Spacer(),
                    if (badge != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange.shade200),
                        ),
                        child: Text(
                          badge!,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.orange.shade900,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: AdminDensity.kpiValueFontSize,
                    fontWeight: FontWeight.bold,
                    color: _navy,
                    height: 1,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: AdminDensity.kpiLabelFontSize,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Compact stat chip for secondary metrics row.
class DashboardMiniStat extends StatelessWidget {
  const DashboardMiniStat({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.color = _navy,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Icon(icon, size: AdminDensity.kpiIconSize, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _navy,
                      ),
                    ),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, size: 16, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }
}

/// Section container with title.
class DashboardPanel extends StatelessWidget {
  const DashboardPanel({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.trailing,
    this.icon,
    this.dense = false,
    this.expandBody = false,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? trailing;
  final IconData? icon;
  final bool dense;
  final bool expandBody;

  @override
  Widget build(BuildContext context) {
    final headerPad = dense
        ? const EdgeInsets.fromLTRB(12, 10, 12, 8)
        : const EdgeInsets.fromLTRB(14, 12, 14, 10);
    final bodyPad = dense
        ? const EdgeInsets.fromLTRB(12, 4, 12, 12)
        : const EdgeInsets.all(14);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(dense ? 12 : 16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: dense ? 6 : 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: headerPad,
            child: Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: dense ? 20 : 22, color: _navy),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: dense ? 16 : 17,
                      fontWeight: FontWeight.bold,
                      color: _navy,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
          ),
          if (!dense && subtitle != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  subtitle!,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ),
            ),
          const Divider(height: 1),
          if (expandBody)
            Expanded(
              child: Padding(padding: bodyPad, child: child),
            )
          else
            Padding(padding: bodyPad, child: child),
        ],
      ),
    );
  }
}

/// Quick action button in a grid.
class DashboardQuickAction extends StatelessWidget {
  const DashboardQuickAction({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.color = _navy,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 26),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color.withValues(alpha: 0.95),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Progress insight row (tracer, surveys, etc.).
class DashboardProgressInsight extends StatelessWidget {
  const DashboardProgressInsight({
    super.key,
    required this.label,
    required this.rate,
    required this.detail,
    required this.color,
    this.dense = false,
  });

  final String label;
  final double rate;
  final String detail;
  final Color color;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final pct = (rate * 100).clamp(0, 100);
    final hasDetail = detail.trim().isNotEmpty;
    final labelStyle = TextStyle(
      fontWeight: FontWeight.w600,
      fontSize: dense ? 12 : 14,
      color: _navy,
      height: 1.15,
    );
    final pctStyle = TextStyle(
      fontWeight: FontWeight.bold,
      color: color,
      fontSize: dense ? 13 : 15,
      height: 1.1,
    );

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: labelStyle,
                maxLines: dense ? 1 : 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text('${pct.toStringAsFixed(0)}%', style: pctStyle),
          ],
        ),
        if (hasDetail && !dense) ...[
          const SizedBox(height: 4),
          Text(
            detail,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        SizedBox(height: dense ? 4 : 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(dense ? 4 : 6),
          child: LinearProgressIndicator(
            value: rate.clamp(0.0, 1.0),
            minHeight: dense ? 6 : 10,
            backgroundColor: Colors.grey.shade200,
            color: color,
          ),
        ),
        if (hasDetail && dense) ...[
          const SizedBox(height: 2),
          Text(
            detail,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade700,
              height: 1.1,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );

    if (!dense) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: content,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.topLeft,
          child: SizedBox(width: constraints.maxWidth, child: content),
        );
      },
    );
  }
}
