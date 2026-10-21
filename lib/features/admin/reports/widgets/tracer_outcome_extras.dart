import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:alumni_system/features/admin/reports/widgets/admin_reports_layout.dart';
import 'package:alumni_system/shared/widgets/admin/admin_buttons.dart';
import 'package:alumni_system/shared/widgets/admin/admin_dialogs.dart';
import 'package:alumni_system/shared/widgets/admin/admin_theme.dart';

/// Compact caution when a Tracer chart has too few answers to generalize.
class ReportsSmallNBanner extends StatelessWidget {
  const ReportsSmallNBanner({
    super.key,
    required this.n,
    this.noun = 'responses',
    this.threshold = 5,
  });

  final int n;
  final String noun;
  final int threshold;

  @override
  Widget build(BuildContext context) {
    if (n >= threshold) return const SizedBox.shrink();
    final message = n <= 0
        ? 'No $noun match this filter yet.'
        : n == 1
            ? 'Based on 1 $noun — percentages can look extreme.'
            : 'Based on $n $noun — interpret percentages carefully.';
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AdminReportsTheme.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AdminReportsTheme.radiusMd),
        border: Border.all(
          color: AdminReportsTheme.warning.withValues(alpha: 0.28),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            size: 15,
            color: AdminReportsTheme.warning.withValues(alpha: 0.9),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 12,
                height: 1.3,
                fontWeight: FontWeight.w500,
                color: AdminReportsTheme.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class TracerRespondentRow {
  const TracerRespondentRow({
    required this.userId,
    required this.displayName,
    this.subtitle,
    this.status,
  });

  final String userId;
  final String displayName;
  final String? subtitle;
  final String? status;
}

/// Dialog / sheet listing who answered a wave or cohort slice.
Future<void> showTracerRespondentsDialog({
  required BuildContext context,
  required String title,
  required String subtitle,
  required List<TracerRespondentRow> rows,
}) async {
  final body = rows.isEmpty
      ? const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'No matching respondents in this slice.',
            style: TextStyle(color: AdminReportsTheme.textMuted),
          ),
        )
      : ListView.separated(
          shrinkWrap: true,
          itemCount: rows.length,
          separatorBuilder: (_, __) =>
              const Divider(height: 1, color: AdminReportsTheme.border),
          itemBuilder: (context, i) {
            final r = rows[i];
            return ListTile(
              dense: true,
              leading: CircleAvatar(
                radius: 14,
                backgroundColor:
                    AdminReportsTheme.primary.withValues(alpha: 0.1),
                child: Text(
                  r.displayName.trim().isNotEmpty
                      ? r.displayName.trim()[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AdminReportsTheme.primary,
                  ),
                ),
              ),
              title: Text(
                r.displayName,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: r.subtitle == null
                  ? null
                  : Text(
                      r.subtitle!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AdminReportsTheme.textMuted,
                      ),
                    ),
              trailing: r.status == null
                  ? null
                  : Text(
                      r.status!,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AdminReportsTheme.textSecondary,
                      ),
                    ),
            );
          },
        );

  final wide = MediaQuery.sizeOf(context).width >= 720;
  if (wide) {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: AdminDialogStandards.shape,
        backgroundColor: AdminDialogStandards.backgroundColor,
        surfaceTintColor: Colors.transparent,
        insetPadding: AdminDialogStandards.defaultInsetPadding,
        contentPadding: AdminDialogStandards.defaultContentPadding,
        titlePadding: EdgeInsets.zero,
        actionsPadding: const EdgeInsets.fromLTRB(22, 0, 22, 18),
        title: Padding(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 0),
          child: AdminModalHeader(
            title: title,
            subtitle: subtitle,
            icon: Icons.trending_up_rounded,
            onClose: () => Navigator.pop(ctx),
          ),
        ),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Divider(height: 1, color: AdminColors.border),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 420),
                child: body,
              ),
            ],
          ),
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx),
            style: AdminButtonStyles.outlined(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
    return;
  }

  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 12.5,
                color: AdminReportsTheme.textMuted,
              ),
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.55,
              ),
              child: body,
            ),
          ],
        ),
      ),
    ),
  );
}

class TracerWaveStatusPoint {
  const TracerWaveStatusPoint({
    required this.waveLabel,
    required this.waveDate,
    required this.status,
  });

  final String waveLabel;
  final DateTime waveDate;
  final String status;
}

class TracerLongitudinalRow {
  const TracerLongitudinalRow({
    required this.userId,
    required this.displayName,
    required this.points,
  });

  final String userId;
  final String displayName;
  final List<TracerWaveStatusPoint> points;
}

/// Alumni who answered more than one tracer wave (employment status over time).
class TracerLongitudinalPanel extends StatelessWidget {
  const TracerLongitudinalPanel({
    super.key,
    required this.rows,
    this.onOpenPerson,
  });

  final List<TracerLongitudinalRow> rows;
  final ValueChanged<TracerLongitudinalRow>? onOpenPerson;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AdminReportsTheme.surface,
          borderRadius: BorderRadius.circular(AdminReportsTheme.radiusMd),
          border: Border.all(color: AdminReportsTheme.border),
        ),
        child: const Text(
          'No alumni appear in more than one tracer wave yet. '
          'This panel fills in as the same people submit later waves.',
          style: TextStyle(
            fontSize: 13,
            height: 1.4,
            color: AdminReportsTheme.textMuted,
          ),
        ),
      );
    }

    final fmt = DateFormat.yMMMd();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          Material(
            color: AdminReportsTheme.card,
            borderRadius: BorderRadius.circular(AdminReportsTheme.radiusMd),
            child: InkWell(
              borderRadius: BorderRadius.circular(AdminReportsTheme.radiusMd),
              onTap: onOpenPerson == null ? null : () => onOpenPerson!(rows[i]),
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                decoration: BoxDecoration(
                  borderRadius:
                      BorderRadius.circular(AdminReportsTheme.radiusMd),
                  border: Border.all(color: AdminReportsTheme.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            rows[i].displayName,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Text(
                          '${rows[i].points.length} waves',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: AdminReportsTheme.textMuted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final p in rows[i].points)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: p.status.toLowerCase() == 'yes'
                                  ? Colors.green.withValues(alpha: 0.1)
                                  : Colors.orange.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: p.status.toLowerCase() == 'yes'
                                    ? Colors.green.withValues(alpha: 0.25)
                                    : Colors.orange.withValues(alpha: 0.25),
                              ),
                            ),
                            child: Text(
                              '${fmt.format(p.waveDate)} · ${p.status}',
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
