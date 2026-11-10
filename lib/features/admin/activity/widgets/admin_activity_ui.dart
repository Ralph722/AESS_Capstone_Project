import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:alumni_system/core/services/audit_events.dart';
import 'package:alumni_system/features/admin/activity/models/audit_log_model.dart';
import 'package:alumni_system/shared/widgets/admin/admin_badge.dart';
import 'package:alumni_system/shared/widgets/admin/admin_buttons.dart';
import 'package:alumni_system/shared/widgets/admin/admin_data_table.dart';
import 'package:alumni_system/shared/widgets/admin/admin_dialogs.dart';
import 'package:alumni_system/shared/widgets/admin/admin_surface.dart';
import 'package:alumni_system/shared/widgets/admin/admin_theme.dart';

/// Maps low-level exceptions to concise, admin-safe feedback copy.
String auditFriendlyError(Object error, String fallback) {
  var text = '$error';
  while (text.startsWith('Exception: ')) {
    text = text.substring('Exception: '.length);
  }
  text = text.trim();
  final technical = text.isEmpty ||
      text.startsWith('Error ') ||
      text.contains('Exception') ||
      text.contains('Postgrest') ||
      text.contains('SocketException') ||
      text.length > 160;
  return technical ? fallback : text;
}

/// Readable fallback name for an [AuditLog] actor.
String auditActorDisplayName(AuditLog log) {
  final trimmed = log.userName.trim();
  if (trimmed.isNotEmpty) return trimmed;
  return log.actorType == AuditActorTypes.system ? 'System' : 'Unknown';
}

/// Summarizes the audit target (`targetLabel` or `resource · resourceId`).
String auditTargetSummary(AuditLog log) {
  final target = log.targetLabel?.trim() ?? '';
  if (target.isNotEmpty) return target;
  if (log.resource.isEmpty) return '—';
  return log.resourceId.isNotEmpty
      ? '${log.resource} · ${log.resourceId}'
      : log.resource;
}

/// Formats `changes` payload cleanly for inspection / clipboard export.
String auditFormatChanges(Map<String, dynamic> changes) {
  final buffer = StringBuffer();
  for (final entry in changes.entries) {
    final value = entry.value;
    if (value is Map && value.containsKey('from') && value.containsKey('to')) {
      buffer.writeln('${entry.key}: ${value['from']} → ${value['to']}');
    } else {
      buffer.writeln('${entry.key}: $value');
    }
  }
  return buffer.toString().trimRight();
}

/// Visual tone for an audit outcome status (`SUCCESS`, `REJECTED`, `FAILED`).
AdminBadgeTone auditStatusBadgeTone(String status) {
  if (status == AuditStatus.success) return AdminBadgeTone.success;
  if (status == AuditStatus.rejected) return AdminBadgeTone.warning;
  return AdminBadgeTone.danger;
}

/// Table cell badge colors distinguishing `SUCCESS`, `REJECTED`, and `FAILED`.
({Color bg, Color fg}) auditStatusTableColors(String status) {
  return switch (auditStatusBadgeTone(status)) {
    AdminBadgeTone.success => (
        bg: AdminTableTheme.successBg,
        fg: AdminTableTheme.success,
      ),
    AdminBadgeTone.warning => (
        bg: AdminTableTheme.warningBg,
        fg: AdminTableTheme.warning,
      ),
    AdminBadgeTone.danger ||
    AdminBadgeTone.info ||
    AdminBadgeTone.neutral =>
      (
        bg: AdminTableTheme.dangerBg,
        fg: AdminTableTheme.danger,
      ),
  };
}

/// Status indicator pill for audit cards and detail headers.
class AdminActivityStatusBadge extends StatelessWidget {
  const AdminActivityStatusBadge({
    super.key,
    required this.status,
    this.dense = true,
  });

  final String status;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final tone = auditStatusBadgeTone(status);
    final icon = switch (tone) {
      AdminBadgeTone.success => Icons.check_circle_outline,
      AdminBadgeTone.warning => Icons.block_outlined,
      _ => Icons.error_outline,
    };
    return AdminBadge(
      label: status,
      tone: tone,
      icon: icon,
      dense: dense,
    );
  }
}

/// Compact narrow-screen row card for [AuditLog] entries (`< 720px`).
class AdminActivityLogCard extends StatelessWidget {
  const AdminActivityLogCard({
    super.key,
    required this.log,
    required this.onTap,
  });

  final AuditLog log;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isSecurity = log.category == AuditCategories.security;
    final actor = auditActorDisplayName(log);
    final target = auditTargetSummary(log);

    return Container(
      decoration: BoxDecoration(
        color: AdminColors.card,
        borderRadius: BorderRadius.circular(AdminSurfaces.radiusSm),
        border: Border.all(color: AdminColors.border),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AdminSurfaces.radiusSm),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (isSecurity) ...[
                      const Icon(
                        Icons.shield_outlined,
                        size: 15,
                        color: AdminColors.warning,
                      ),
                      const SizedBox(width: 6),
                    ],
                    Expanded(
                      child: Text(
                        log.action,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: AdminColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    AdminActivityStatusBadge(status: log.status, dense: true),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      DateFormat('MMM d, HH:mm').format(log.timestamp),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AdminColors.textSecondary,
                      ),
                    ),
                    const Text(
                      '·',
                      style: TextStyle(color: AdminColors.textMuted),
                    ),
                    Text(
                      '$actor (${log.actorType})',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AdminColors.textPrimary,
                      ),
                    ),
                    if (log.module.isNotEmpty)
                      AdminBadge.neutral(label: log.module, dense: true),
                  ],
                ),
                if (target != '—' || log.description.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          log.description.isNotEmpty
                              ? log.description
                              : target,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AdminColors.textSecondary,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: AdminColors.textSecondary,
                      ),
                    ],
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

/// Opens the structured audit detail inspector in a responsive drawer / dialog.
Future<void> showAdminActivityLogDetailPanel(
  BuildContext context,
  AuditLog log,
) {
  final child = AdminActivityLogDetailPanel(log: log);
  if (adminIsWideSurface(context)) {
    return showAdminSidePanel<void>(
      context: context,
      width: 480,
      backgroundColor: AdminColors.card,
      child: child,
    );
  }
  return showAdminDialogSurface<void>(
    context: context,
    maxWidth: 560,
    child: SizedBox(
      height: math.min(680.0, MediaQuery.sizeOf(context).height * 0.9),
      child: child,
    ),
  );
}

/// Structured audit event inspector for [showAdminActivityLogDetailPanel].
class AdminActivityLogDetailPanel extends StatelessWidget {
  const AdminActivityLogDetailPanel({super.key, required this.log});

  final AuditLog log;

  Future<void> _copy(
    BuildContext context,
    String text,
    String confirmation,
  ) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(confirmation),
          duration: const Duration(seconds: 2),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final isSecurity = log.category == AuditCategories.security;
    final actor = auditActorDisplayName(log);
    final hasChanges = log.changes != null && log.changes!.isNotEmpty;
    final hasIp = log.ipAddress != null && log.ipAddress!.trim().isNotEmpty;

    return ColoredBox(
      color: AdminColors.card,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
              child: AdminModalHeader(
                title: log.action,
                subtitle: DateFormat('MMM d, yyyy · HH:mm:ss')
                    .format(log.timestamp),
                icon: isSecurity
                    ? Icons.shield_outlined
                    : Icons.history_rounded,
                iconColor:
                    isSecurity ? AdminColors.warning : AdminColors.primary,
                iconBackground:
                    isSecurity ? AdminColors.warningBg : AdminColors.primaryTint,
                onClose: () => Navigator.of(context).pop(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  AdminActivityStatusBadge(status: log.status, dense: true),
                  isSecurity
                      ? const AdminBadge.warning(
                          label: 'security',
                          icon: Icons.shield_outlined,
                          dense: true,
                        )
                      : AdminBadge.neutral(label: log.category, dense: true),
                  AdminBadge(
                    label: log.actorType,
                    tone: log.actorType == AuditActorTypes.admin
                        ? AdminBadgeTone.info
                        : AdminBadgeTone.neutral,
                    dense: true,
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AdminColors.border),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _sectionLabel('Actor & context'),
                  const SizedBox(height: 8),
                  _infoCard([
                    _DetailItem('Actor', actor),
                    _DetailItem(
                      'Email',
                      log.userEmail.isEmpty ? '—' : log.userEmail,
                    ),
                    _DetailItem('Role', log.userRole),
                    _DetailItem('Actor type', log.actorType),
                    _DetailItem(
                      'Module',
                      log.module.isEmpty ? '—' : log.module,
                    ),
                    _DetailItem('Category', log.category),
                    if (hasIp) _DetailItem('IP address', log.ipAddress!),
                  ]),
                  const SizedBox(height: 16),
                  _sectionLabel('Target & tracing'),
                  const SizedBox(height: 8),
                  _infoCard([
                    _DetailItem(
                      'Resource',
                      log.resource.isEmpty ? '—' : log.resource,
                    ),
                    _DetailItem(
                      'Target ID',
                      log.resourceId.isEmpty ? '—' : log.resourceId,
                      copyTooltip: log.resourceId.isEmpty
                          ? null
                          : 'Copy target ID',
                      onCopy: log.resourceId.isEmpty
                          ? null
                          : () => _copy(
                              context,
                              log.resourceId,
                              'Target ID copied',
                            ),
                    ),
                    if (log.targetLabel != null && log.targetLabel!.isNotEmpty)
                      _DetailItem('Target', log.targetLabel!),
                    _DetailItem('Result', log.status),
                    if (log.correlationId != null &&
                        log.correlationId!.isNotEmpty)
                      _DetailItem(
                        'Correlation ID',
                        log.correlationId!,
                        copyTooltip: 'Copy correlation ID',
                        onCopy: () => _copy(
                          context,
                          log.correlationId!,
                          'Correlation ID copied',
                        ),
                      ),
                  ]),
                  const SizedBox(height: 16),
                  _sectionLabel('Description'),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AdminColors.surface,
                      borderRadius:
                          BorderRadius.circular(AdminSurfaces.radiusSm),
                      border: Border.all(color: AdminColors.border),
                    ),
                    child: Text(
                      log.description.isEmpty ? '—' : log.description,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.45,
                        color: AdminColors.textPrimary,
                      ),
                    ),
                  ),
                  if (hasChanges) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: _sectionLabel('Changes / metadata')),
                        TextButton.icon(
                          onPressed: () => _copy(
                            context,
                            auditFormatChanges(log.changes!),
                            'Metadata copied',
                          ),
                          style: AdminButtonStyles.ghost(
                            foreground: AdminColors.primary,
                          ),
                          icon: const Icon(Icons.copy_outlined, size: 15),
                          label: const Text('Copy metadata'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AdminColors.background,
                        borderRadius:
                            BorderRadius.circular(AdminSurfaces.radiusSm),
                        border: Border.all(color: AdminColors.border),
                      ),
                      child: SelectableText(
                        auditFormatChanges(log.changes!),
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          height: 1.45,
                          color: AdminColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: AdminColors.textSecondary,
        letterSpacing: 0.2,
      ),
    );
  }

  Widget _infoCard(List<_DetailItem> items) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AdminColors.surface,
        borderRadius: BorderRadius.circular(AdminSurfaces.radiusSm),
        border: Border.all(color: AdminColors.border),
      ),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++)
            _DetailRow(item: items[i], isLast: i == items.length - 1),
        ],
      ),
    );
  }
}

class _DetailItem {
  const _DetailItem(
    this.label,
    this.value, {
    this.copyTooltip,
    this.onCopy,
  });

  final String label;
  final String value;
  final String? copyTooltip;
  final VoidCallback? onCopy;
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.item, required this.isLast});

  final _DetailItem item;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 112,
            child: Text(
              item.label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AdminColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              item.value,
              style: const TextStyle(
                fontSize: 13,
                color: AdminColors.textPrimary,
              ),
            ),
          ),
          if (item.onCopy != null)
            IconButton(
              tooltip: item.copyTooltip ?? 'Copy',
              onPressed: item.onCopy,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
              icon: const Icon(
                Icons.copy_outlined,
                size: 14,
                color: AdminColors.textSecondary,
              ),
            ),
        ],
      ),
    );
  }
}
