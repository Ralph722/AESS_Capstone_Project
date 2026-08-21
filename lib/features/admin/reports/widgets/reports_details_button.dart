import 'package:flutter/material.dart';

import 'package:alumni_system/features/admin/reports/widgets/admin_reports_layout.dart';

class _DetailSection {
  const _DetailSection({required this.label, required this.body});

  final String label;
  final String body;
}

/// Compact ⓘ control that reveals metric/chart methodology without
/// permanently occupying card space.
class ReportsDetailsButton extends StatelessWidget {
  const ReportsDetailsButton({
    super.key,
    required this.title,
    required this.body,
    this.tooltip = 'Details',
  });

  final String title;
  final String body;
  final String tooltip;

  /// Builds a consistent Details body for KPIs and charts.
  ///
  /// Section labels are written for office admins (not developers).
  static String compose({
    required String definition,
    String? calculation,
    String? scope,
    String? limitation,
  }) {
    final parts = <String>['What this shows\n$definition'];
    if (calculation != null && calculation.trim().isNotEmpty) {
      parts.add('How it\'s counted\n${calculation.trim()}');
    }
    if (scope != null && scope.trim().isNotEmpty) {
      parts.add('Who\'s included\n${scope.trim()}');
    }
    if (limitation != null && limitation.trim().isNotEmpty) {
      parts.add('Please note\n${limitation.trim()}');
    }
    return parts.join('\n\n');
  }

  static List<_DetailSection> _parseSections(String raw) {
    final chunks = raw
        .split(RegExp(r'\n\s*\n'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList(growable: false);
    final sections = <_DetailSection>[];
    for (final chunk in chunks) {
      final nl = chunk.indexOf('\n');
      if (nl <= 0) {
        sections.add(_DetailSection(label: 'About', body: chunk));
        continue;
      }
      sections.add(
        _DetailSection(
          label: chunk.substring(0, nl).trim(),
          body: chunk.substring(nl + 1).trim(),
        ),
      );
    }
    return sections;
  }

  Widget _sectionCard(_DetailSection section) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: AdminReportsTheme.surface,
        borderRadius: BorderRadius.circular(AdminReportsTheme.radiusMd),
        border: Border.all(color: AdminReportsTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            section.label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
              color: AdminReportsTheme.primary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            section.body,
            style: const TextStyle(
              fontSize: 13.5,
              height: 1.45,
              color: AdminReportsTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailsBody() {
    final sections = _parseSections(body);
    if (sections.isEmpty) {
      return Text(
        body,
        style: const TextStyle(
          fontSize: 13.5,
          height: 1.45,
          color: AdminReportsTheme.textSecondary,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < sections.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          _sectionCard(sections[i]),
        ],
      ],
    );
  }

  Future<void> _show(BuildContext context) async {
    final wide = MediaQuery.sizeOf(context).width >= 720;
    final content = _detailsBody();

    if (wide) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AdminReportsTheme.radiusLg),
          ),
          titlePadding: const EdgeInsets.fromLTRB(20, 18, 12, 0),
          contentPadding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          title: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AdminReportsTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.info_outline,
                  size: 18,
                  color: AdminReportsTheme.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AdminReportsTheme.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(child: content),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
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
      backgroundColor: AdminReportsTheme.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AdminReportsTheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.info_outline,
                      size: 18,
                      color: AdminReportsTheme.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AdminReportsTheme.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.65,
                ),
                child: SingleChildScrollView(child: content),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: () => _show(context),
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
      icon: const Icon(
        Icons.info_outline,
        size: 16,
        color: AdminReportsTheme.textMuted,
      ),
    );
  }
}
