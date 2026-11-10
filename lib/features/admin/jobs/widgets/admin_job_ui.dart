import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:alumni_system/core/utils/csv_safe.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:alumni_system/core/utils/app_image.dart';
import 'package:alumni_system/core/utils/export_platform.dart';
import 'package:alumni_system/features/admin/roster/widgets/alumni_directory_ui.dart';
import 'package:alumni_system/features/jobs/models/job_interest_model.dart';
import 'package:alumni_system/features/jobs/models/job_posting_model.dart';
import 'package:alumni_system/features/jobs/widgets/job_ui.dart';
import 'package:alumni_system/features/messages/data/message_open_bus.dart';
import 'package:alumni_system/shared/widgets/admin/admin_badge.dart';
import 'package:alumni_system/shared/widgets/admin/admin_buttons.dart';
import 'package:alumni_system/shared/widgets/admin/admin_density.dart';
import 'package:alumni_system/shared/widgets/admin/admin_dialogs.dart';
import 'package:alumni_system/shared/widgets/admin/admin_form_layout.dart';
import 'package:alumni_system/shared/widgets/admin/admin_state_view.dart';
import 'package:alumni_system/shared/widgets/admin/admin_surface.dart';
import 'package:alumni_system/shared/widgets/admin/admin_theme.dart';
import 'package:url_launcher/url_launcher.dart';

/// Jobs admin chrome — aliases Directory tokens (no second color system).
abstract final class AdminJobTheme {
  static const primary = AdminDirectoryTheme.primary;
  static const background = AdminDirectoryTheme.background;
  static const surface = AdminDirectoryTheme.surface;
  static const border = AdminDirectoryTheme.border;
  static const textPrimary = AdminDirectoryTheme.textPrimary;
  static const textSecondary = AdminDirectoryTheme.textSecondary;
  static const textMuted = AdminDirectoryTheme.textMuted;
  static const success = AdminDirectoryTheme.success;
  static const danger = AdminDirectoryTheme.danger;
  static const warning = AdminDirectoryTheme.warning;
  static const info = AdminDirectoryTheme.info;
  static const infoBg = AdminDirectoryTheme.infoBg;

  static const space1 = AdminDirectoryTheme.space1;
  static const space2 = AdminDirectoryTheme.space2;
  static const sectionGap = AdminDensity.sectionGap;
  static const cardPadding = AdminDensity.cardPadding;
  static const listItemGap = AdminDensity.listItemGap;
  static const buttonHeight = AdminDirectoryTheme.buttonHeight;
  static const radiusSm = AdminDirectoryTheme.radiusSm;
  static const radiusMd = AdminDirectoryTheme.radiusMd;

  static BoxDecoration surfaceCard({bool hovered = false}) =>
      AdminDirectoryTheme.surfaceCard(hovered: hovered);
}

ButtonStyle jobFilledButtonStyle({Color? background}) =>
    AdminButtonStyles.filled(background: background);

ButtonStyle jobOutlinedButtonStyle() => AdminButtonStyles.outlined();

/// Maps technical exceptions to concise admin-facing copy.
String jobFriendlyError(Object error, String fallback) {
  var text = '$error';
  while (text.startsWith('Exception: ')) {
    text = text.substring('Exception: '.length);
  }
  text = text.trim();
  final technical =
      text.isEmpty ||
      text.startsWith('Error ') ||
      text.contains('Exception') ||
      text.contains('Postgrest') ||
      text.contains('SocketException') ||
      text.length > 160;
  return technical ? fallback : text;
}

/// Job moderation popup menu item with leading icon and consistent destructive tone.
PopupMenuItem<String> adminJobMenuItem({
  required String value,
  required String label,
  required IconData icon,
  bool destructive = false,
  bool enabled = true,
  String? note,
}) {
  final Color textColor;
  final Color iconColor;
  if (!enabled) {
    textColor = AdminColors.textMuted;
    iconColor = AdminColors.textMuted;
  } else if (destructive) {
    textColor = AdminColors.danger;
    iconColor = AdminColors.danger;
  } else {
    textColor = AdminColors.textPrimary;
    iconColor = AdminColors.primary;
  }
  return PopupMenuItem<String>(
    value: value,
    enabled: enabled,
    height: note == null ? 40 : 52,
    child: Row(
      children: [
        Icon(icon, size: 18, color: iconColor),
        const SizedBox(width: 12),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  color: textColor,
                ),
              ),
              if (note != null)
                Text(
                  note,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AdminColors.textSecondary,
                  ),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}

/// Brand-aligned Admin status & metadata badges for job postings.
class AdminJobStatusBadges extends StatelessWidget {
  const AdminJobStatusBadges({super.key, required this.job});

  final JobPosting job;

  @override
  Widget build(BuildContext context) {
    final normalized = job.status.toLowerCase();
    final deadlineHint = jobDeadlineHint(job.applicationDeadline);

    final AdminBadge statusBadge;
    switch (normalized) {
      case 'active':
        statusBadge = const AdminBadge.success(
          label: 'Active',
          icon: Icons.check_circle_outline,
          dense: true,
        );
      case 'expired':
        statusBadge = const AdminBadge.danger(
          label: 'Expired',
          icon: Icons.event_busy_outlined,
          dense: true,
        );
      case 'archived':
        statusBadge = const AdminBadge.neutral(
          label: 'Archived',
          icon: Icons.archive_outlined,
          dense: true,
        );
      default:
        statusBadge = AdminBadge.info(
          label: job.status.trim().isEmpty ? 'Open' : job.status.trim(),
          icon: Icons.work_outline,
          dense: true,
        );
    }

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        statusBadge,
        AdminBadge.info(
          label: job.category.trim().isEmpty ? 'Others' : job.category.trim(),
          icon: Icons.category_outlined,
          dense: true,
        ),
        if (job.isRemote)
          const AdminBadge.neutral(
            label: 'Remote',
            icon: Icons.laptop_mac_outlined,
            dense: true,
          ),
        if (normalized == 'active' && deadlineHint != null)
          deadlineHint == 'Application closed'
              ? AdminBadge.danger(
                  label: deadlineHint,
                  icon: Icons.schedule_rounded,
                  dense: true,
                )
              : AdminBadge.warning(
                  label: deadlineHint,
                  icon: Icons.schedule_rounded,
                  dense: true,
                ),
      ],
    );
  }
}

/// Multi-zone SaaS row card for Job Postings list.
class AdminJobCard extends StatefulWidget {
  const AdminJobCard({
    super.key,
    required this.job,
    required this.onEdit,
    required this.onDetails,
    required this.onInterested,
    required this.onToggleArchive,
    required this.onDelete,
    this.onShare,
    this.busy = false,
  });

  static const double zoneLayoutMinWidth = 900.0;

  final JobPosting job;
  final VoidCallback onEdit;
  final VoidCallback onDetails;
  final VoidCallback onInterested;
  final VoidCallback onToggleArchive;
  final VoidCallback onDelete;
  final VoidCallback? onShare;
  final bool busy;

  @override
  State<AdminJobCard> createState() => _AdminJobCardState();
}

class _AdminJobCardState extends State<AdminJobCard> {
  bool _hovered = false;

  static const _zoneLabel = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.3,
    color: AdminColors.textSecondary,
  );
  static const _zoneValue = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: AdminColors.textPrimary,
  );
  static const _secondary = TextStyle(
    fontSize: 12,
    height: 1.35,
    color: AdminColors.textSecondary,
  );

  String _metaLine(JobPosting job) {
    final salary = formatJobSalaryPhp(job.salaryRange);
    return [
      if (job.companyName.trim().isNotEmpty) job.companyName.trim(),
      if (job.jobType.trim().isNotEmpty) job.jobType.trim(),
      if (job.isRemote)
        'Remote'
      else if (job.location.trim().isNotEmpty)
        job.location.trim(),
      if (salary.isNotEmpty) salary,
    ].join(' · ');
  }

  String _engagementLine(JobPosting job) {
    final views = '${job.views} ${job.views == 1 ? 'view' : 'views'}';
    final interest = '${job.interestedCount} interested';
    return '$views · $interest';
  }

  String _deadlineLine(JobPosting job) {
    final fmt = DateFormat.yMMMd();
    return 'Deadline ${fmt.format(job.applicationDeadline)}';
  }

  @override
  Widget build(BuildContext context) {
    final job = widget.job;
    final title = job.jobTitle.trim().isEmpty ? 'Untitled job' : job.jobTitle.trim();

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        margin: const EdgeInsets.only(bottom: AdminDensity.listItemGap),
        decoration: BoxDecoration(
          color: _hovered ? AdminColors.rowHover : AdminColors.card,
          borderRadius: BorderRadius.circular(AdminSurfaces.radiusMd),
          border: Border.all(color: AdminColors.border),
          boxShadow: AdminSurfaces.cardShadow,
        ),
        clipBehavior: Clip.antiAlias,
        child: Material(
          type: MaterialType.transparency,
          child: Semantics(
            button: true,
            label: 'Open details for $title',
            child: InkWell(
              onTap: widget.onDetails,
              child: LayoutBuilder(
                builder: (context, constraints) =>
                    constraints.maxWidth >= AdminJobCard.zoneLayoutMinWidth
                        ? _buildZones(job, title)
                        : _buildStacked(job, title),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildZones(JobPosting job, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ExcludeSemantics(child: JobCompanyLogo(job: job, size: 40, radius: 8)),
          const SizedBox(width: 12),
          Expanded(child: _buildIdentity(job, title)),
          const SizedBox(width: 24),
          SizedBox(width: 205, child: _buildEngagementZone(job)),
          const SizedBox(width: 8),
          _buildMenu(job),
        ],
      ),
    );
  }

  Widget _buildStacked(JobPosting job, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(child: JobCompanyLogo(job: job, size: 36, radius: 8)),
          const SizedBox(width: 10),
          Expanded(child: _buildIdentity(job, title, showCompactStats: true)),
          _buildMenu(job),
        ],
      ),
    );
  }

  Widget _buildIdentity(
    JobPosting job,
    String title, {
    bool showCompactStats = false,
  }) {
    final meta = _metaLine(job);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Tooltip(
          message: title,
          waitDuration: const Duration(milliseconds: 600),
          child: Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              letterSpacing: -0.2,
              height: 1.3,
              color: AdminColors.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: 5),
        AdminJobStatusBadges(job: job),
        if (meta.isNotEmpty) ...[
          const SizedBox(height: 5),
          Text(
            meta,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _secondary,
          ),
        ],
        if (showCompactStats) ...[
          const SizedBox(height: 4),
          Wrap(
            spacing: 10,
            runSpacing: 2,
            children: [
              _metaItem(Icons.visibility_outlined, _engagementLine(job)),
              _metaItem(Icons.event_outlined, _deadlineLine(job)),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildEngagementZone(JobPosting job) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('ENGAGEMENT & DEADLINE', style: _zoneLabel),
        const SizedBox(height: 4),
        Text(
          _engagementLine(job),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _zoneValue,
        ),
        const SizedBox(height: 4),
        _metaItem(Icons.event_outlined, _deadlineLine(job)),
      ],
    );
  }

  Widget _metaItem(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AdminColors.textSecondary),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _secondary,
          ),
        ),
      ],
    );
  }

  Widget _buildMenu(JobPosting job) {
    if (widget.busy) {
      return const Padding(
        padding: EdgeInsets.all(10),
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    return PopupMenuButton<String>(
      tooltip: 'Job actions',
      onSelected: (value) {
        switch (value) {
          case 'details':
            widget.onDetails();
          case 'interested':
            widget.onInterested();
          case 'share':
            widget.onShare?.call();
          case 'edit':
            widget.onEdit();
          case 'archive':
            widget.onToggleArchive();
          case 'delete':
            widget.onDelete();
        }
      },
      itemBuilder: (_) => [
        adminJobMenuItem(
          value: 'details',
          label: 'View details',
          icon: Icons.open_in_new_rounded,
        ),
        adminJobMenuItem(
          value: 'interested',
          label: 'Interested (${job.interestedCount})',
          icon: Icons.star_outline,
        ),
        if (widget.onShare != null && job.isActiveForAlumni)
          adminJobMenuItem(
            value: 'share',
            label: 'Share link…',
            icon: Icons.share_outlined,
          ),
        const PopupMenuDivider(height: 8),
        adminJobMenuItem(
          value: 'edit',
          label: 'Edit',
          icon: Icons.edit_outlined,
        ),
        adminJobMenuItem(
          value: 'archive',
          label: job.status == 'archived' ? 'Activate' : 'Archive',
          icon: job.status == 'archived'
              ? Icons.unarchive_outlined
              : Icons.archive_outlined,
        ),
        const PopupMenuDivider(height: 8),
        adminJobMenuItem(
          value: 'delete',
          label: 'Delete',
          icon: Icons.delete_outline_rounded,
          destructive: true,
        ),
      ],
      icon: const Icon(Icons.more_vert, color: AdminColors.textSecondary),
    );
  }
}

Future<void> showAdminJobInsightsDialog({
  required BuildContext context,
  required List<JobPosting> jobs,
}) {
  final byCategory = <String, int>{};
  final byCompany = <String, int>{};
  final byStatus = <String, int>{};
  for (final j in jobs) {
    byCategory[j.category] = (byCategory[j.category] ?? 0) + 1;
    if (j.companyName.trim().isNotEmpty) {
      byCompany[j.companyName] = (byCompany[j.companyName] ?? 0) + 1;
    }
    byStatus[j.status] = (byStatus[j.status] ?? 0) + 1;
  }
  final topViewed = List<JobPosting>.from(jobs)
    ..sort((a, b) => b.views.compareTo(a.views));
  final topInterest = List<JobPosting>.from(jobs)
    ..sort((a, b) => b.interestedCount.compareTo(a.interestedCount));
  final topCompanies = byCompany.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  final categories = byCategory.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  final totalViews = jobs.fold<int>(0, (s, j) => s + j.views);
  final totalInterest = jobs.fold<int>(0, (s, j) => s + j.interestedCount);
  final height = math.min(620.0, MediaQuery.sizeOf(context).height * 0.88);

  return showAdminDialogSurface<void>(
    context: context,
    maxWidth: kAdminDialogMd,
    maxHeight: height,
    child: SizedBox(
      width: kAdminDialogMd,
      height: height,
      child: _JobInsightsDialogBody(
        jobCount: jobs.length,
        totalViews: totalViews,
        totalInterest: totalInterest,
        topViewed: topViewed.take(5).toList(),
        topInterest: topInterest.take(5).toList(),
        categories: categories,
        topCompanies: topCompanies.take(5).toList(),
        byStatus: byStatus,
      ),
    ),
  );
}

class _JobInsightsDialogBody extends StatelessWidget {
  const _JobInsightsDialogBody({
    required this.jobCount,
    required this.totalViews,
    required this.totalInterest,
    required this.topViewed,
    required this.topInterest,
    required this.categories,
    required this.topCompanies,
    required this.byStatus,
  });

  final int jobCount;
  final int totalViews;
  final int totalInterest;
  final List<JobPosting> topViewed;
  final List<JobPosting> topInterest;
  final List<MapEntry<String, int>> categories;
  final List<MapEntry<String, int>> topCompanies;
  final Map<String, int> byStatus;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 12, 10),
          child: AdminModalHeader(
            title: 'Quick insights',
            subtitle: 'Snapshot of engagement across all job postings',
            icon: Icons.insights_outlined,
            onClose: () => Navigator.pop(context),
          ),
        ),
        const Divider(height: 1, color: AdminColors.border),
        Expanded(
          child: jobCount == 0
              ? const AdminStateView.empty(
                  compact: true,
                  icon: Icons.insights_outlined,
                  title: 'No job postings yet',
                  message: 'Insights will appear after you post openings.',
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _insightStat(
                            icon: Icons.work_outline,
                            label: 'Jobs',
                            value: '$jobCount',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _insightStat(
                            icon: Icons.visibility_outlined,
                            label: 'Total views',
                            value: '$totalViews',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _insightStat(
                            icon: Icons.star_outline,
                            label: 'Interested',
                            value: '$totalInterest',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _section(
                      title: 'Most viewed',
                      icon: Icons.visibility_outlined,
                      child: topViewed.isEmpty
                          ? _emptyHint('No view data yet')
                          : Column(
                              children: [
                                for (var i = 0; i < topViewed.length; i++)
                                  _rankedJobRow(
                                    rank: i + 1,
                                    title: topViewed[i].jobTitle,
                                    subtitle: topViewed[i].companyName,
                                    metric: '${topViewed[i].views} views',
                                  ),
                              ],
                            ),
                    ),
                    const SizedBox(height: 14),
                    _section(
                      title: 'Most interested',
                      icon: Icons.star_outline,
                      child: topInterest.every((j) => j.interestedCount == 0)
                          ? _emptyHint('No interest signals yet')
                          : Column(
                              children: [
                                for (var i = 0; i < topInterest.length; i++)
                                  if (topInterest[i].interestedCount > 0)
                                    _rankedJobRow(
                                      rank: i + 1,
                                      title: topInterest[i].jobTitle,
                                      subtitle: topInterest[i].companyName,
                                      metric:
                                          '${topInterest[i].interestedCount} interested',
                                    ),
                              ],
                            ),
                    ),
                    const SizedBox(height: 14),
                    _section(
                      title: 'By category',
                      icon: Icons.category_outlined,
                      child: categories.isEmpty
                          ? _emptyHint('No categories')
                          : Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final e in categories)
                                  _countChip(label: e.key, count: e.value),
                              ],
                            ),
                    ),
                    const SizedBox(height: 14),
                    _section(
                      title: 'By status',
                      icon: Icons.flag_outlined,
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final e in byStatus.entries)
                            _countChip(label: e.key, count: e.value),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    _section(
                      title: 'Top companies',
                      icon: Icons.business_outlined,
                      child: topCompanies.isEmpty
                          ? _emptyHint('No companies yet')
                          : Column(
                              children: [
                                for (var i = 0; i < topCompanies.length; i++)
                                  _rankedJobRow(
                                    rank: i + 1,
                                    title: topCompanies[i].key,
                                    subtitle: null,
                                    metric:
                                        '${topCompanies[i].value} posting${topCompanies[i].value == 1 ? '' : 's'}',
                                  ),
                              ],
                            ),
                    ),
                  ],
                ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: () => Navigator.pop(context),
              style: jobFilledButtonStyle(),
              child: const Text('Close'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _insightStat({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AdminJobTheme.surface,
        borderRadius: BorderRadius.circular(AdminJobTheme.radiusSm),
        border: Border.all(color: AdminJobTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AdminJobTheme.textMuted),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AdminJobTheme.textPrimary,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11.5,
              color: AdminJobTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _section({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AdminJobTheme.radiusSm),
        border: Border.all(color: AdminJobTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AdminJobTheme.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AdminJobTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _rankedJobRow({
    required int rank,
    required String title,
    required String? subtitle,
    required String metric,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AdminJobTheme.infoBg,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '$rank',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AdminJobTheme.primary,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.isEmpty ? '—' : title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AdminJobTheme.textPrimary,
                  ),
                ),
                if (subtitle != null && subtitle.isNotEmpty)
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AdminColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            metric,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AdminColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _countChip({required String label, required int count}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AdminColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AdminColors.border),
      ),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: label,
              style: const TextStyle(
                fontSize: 12,
                color: AdminColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            TextSpan(
              text: '  $count',
              style: const TextStyle(
                fontSize: 12,
                color: AdminColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyHint(String text) {
    return Text(
      text,
      style: const TextStyle(fontSize: 12.5, color: AdminColors.textSecondary),
    );
  }
}

Future<void> showAdminJobDetailsDrawer({
  required BuildContext context,
  required JobPosting job,
  required VoidCallback onOpenInterested,
}) {
  final child = _JobDetailsPanel(job: job, onOpenInterested: onOpenInterested);
  if (adminIsWideSurface(context)) {
    return showAdminSidePanel<void>(context: context, width: 480, child: child);
  }
  return showAdminDialogSurface<void>(
    context: context,
    maxWidth: 560,
    child: SizedBox(
      height: math.min(720.0, MediaQuery.sizeOf(context).height * 0.9),
      child: child,
    ),
  );
}

class _JobDetailsPanel extends StatelessWidget {
  const _JobDetailsPanel({required this.job, required this.onOpenInterested});

  final JobPosting job;
  final VoidCallback onOpenInterested;

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat.yMMMMd();

    return ColoredBox(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                JobCompanyLogo(job: job, size: 48, radius: 10),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        job.jobTitle.isEmpty ? 'Untitled job' : job.jobTitle,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: AdminJobTheme.textPrimary,
                          height: 1.25,
                        ),
                      ),
                      if (job.companyName.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          job.companyName,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AdminJobTheme.textSecondary,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      AdminJobStatusBadges(job: job),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.pop(context),
                  style: AdminDensity.iconButtonStyle(
                    foregroundColor: AdminColors.textSecondary,
                  ),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AdminColors.border),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
              children: [
                if (job.hasCoverImage) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: AppImage.widget(
                        job.coverImage,
                        fit: BoxFit.cover,
                        semanticLabel: 'Cover photo for ${job.jobTitle}',
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                Row(
                  children: [
                    Expanded(
                      child: _metricTile(
                        icon: Icons.visibility_outlined,
                        label: 'Views',
                        value: '${job.views}',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _metricTile(
                        icon: Icons.star_outline,
                        label: 'Interested',
                        value: '${job.interestedCount}',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _metricTile(
                        icon: Icons.bookmark_border,
                        label: 'Saved',
                        value: '${job.favoriteCount}',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _cardSection(
                  title: 'Overview',
                  icon: Icons.info_outline,
                  child: Column(
                    children: [
                      _detailRow(
                        icon: Icons.work_outline,
                        label: 'Type',
                        value: job.jobType,
                      ),
                      _detailRow(
                        icon: Icons.trending_up,
                        label: 'Experience',
                        value: job.experienceLevel,
                      ),
                      _detailRow(
                        icon: Icons.place_outlined,
                        label: 'Location',
                        value: job.location,
                      ),
                      _detailRow(
                        icon: Icons.payments_outlined,
                        label: 'Salary',
                        value: formatJobSalaryPhp(job.salaryRange),
                      ),
                      _detailRow(
                        icon: Icons.event_outlined,
                        label: 'Deadline',
                        value: fmt.format(job.applicationDeadline),
                      ),
                      _detailRow(
                        icon: Icons.schedule_outlined,
                        label: 'Posted',
                        value: fmt.format(job.postedDate),
                        isLast: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _cardSection(
                  title: 'Description',
                  icon: Icons.notes_outlined,
                  child: Text(
                    job.description.trim().isEmpty
                        ? 'No description provided.'
                        : job.description.trim(),
                    style: TextStyle(
                      fontSize: 13.5,
                      height: 1.45,
                      color: job.description.trim().isEmpty
                          ? AdminJobTheme.textMuted
                          : AdminJobTheme.textSecondary,
                    ),
                  ),
                ),
                if (job.requirements.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _cardSection(
                    title: 'Requirements',
                    icon: Icons.checklist_outlined,
                    child: Column(
                      children: [
                        for (var i = 0; i < job.requirements.length; i++)
                          _bulletRow(
                            job.requirements[i],
                            isLast: i == job.requirements.length - 1,
                          ),
                      ],
                    ),
                  ),
                ],
                if (job.benefits.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _cardSection(
                    title: 'Benefits',
                    icon: Icons.card_giftcard_outlined,
                    child: Column(
                      children: [
                        for (var i = 0; i < job.benefits.length; i++)
                          _bulletRow(
                            job.benefits[i],
                            isLast: i == job.benefits.length - 1,
                            icon: Icons.check_circle_outline,
                          ),
                      ],
                    ),
                  ),
                ],
                if (job.targetPrograms.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _cardSection(
                    title: 'Target programs',
                    icon: Icons.school_outlined,
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final p in job.targetPrograms)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AdminJobTheme.infoBg,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              p,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AdminJobTheme.primary,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                _cardSection(
                  title: 'Contact & apply',
                  icon: Icons.mail_outline,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (job.contactEmail.trim().isEmpty)
                        const Text(
                          'No contact email set.',
                          style: TextStyle(
                            fontSize: 13,
                            color: AdminJobTheme.textMuted,
                          ),
                        )
                      else ...[
                        Text(
                          job.contactEmail.trim(),
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: AdminJobTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () async {
                                  await Clipboard.setData(
                                    ClipboardData(text: job.contactEmail),
                                  );
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Email copied'),
                                      ),
                                    );
                                  }
                                },
                                icon: const Icon(Icons.copy, size: 16),
                                label: const Text('Copy'),
                                style: jobOutlinedButtonStyle(),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: () => launchUrl(
                                  Uri.parse('mailto:${job.contactEmail}'),
                                ),
                                icon: const Icon(Icons.mail_outline, size: 16),
                                label: const Text('Email'),
                                style: jobFilledButtonStyle(),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (job.applicationUrl.trim().isNotEmpty) ...[
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: () => launchUrl(
                            Uri.parse(job.applicationUrl.trim()),
                            mode: LaunchMode.externalApplication,
                          ),
                          icon: const Icon(Icons.open_in_new, size: 16),
                          label: const Text('Open application link'),
                          style: jobOutlinedButtonStyle(),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: FilledButton.icon(
              onPressed: () {
                Navigator.pop(context);
                onOpenInterested();
              },
              icon: const Icon(Icons.star_outline, size: 18),
              label: Text('Interested alumni (${job.interestedCount})'),
              style: jobFilledButtonStyle(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricTile({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: AdminJobTheme.surface,
        borderRadius: BorderRadius.circular(AdminJobTheme.radiusSm),
        border: Border.all(color: AdminJobTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: AdminJobTheme.textMuted),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AdminJobTheme.textPrimary,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AdminJobTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _cardSection({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AdminJobTheme.radiusSm),
        border: Border.all(color: AdminJobTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AdminJobTheme.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AdminJobTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _detailRow({
    required IconData icon,
    required String label,
    required String value,
    bool isLast = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: AdminJobTheme.textMuted),
          const SizedBox(width: 8),
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AdminJobTheme.textMuted,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.trim().isEmpty ? '—' : value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AdminJobTheme.textPrimary,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bulletRow(
    String text, {
    bool isLast = false,
    IconData icon = Icons.circle,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Icon(
              icon == Icons.circle ? Icons.circle : icon,
              size: icon == Icons.circle ? 6 : 15,
              color: icon == Icons.circle
                  ? AdminJobTheme.textMuted
                  : AdminDirectoryTheme.success,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                height: 1.4,
                color: AdminJobTheme.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> showAdminInterestedDrawer({
  required BuildContext context,
  required JobPosting job,
  required List<JobInterestedAlumni> alumni,
  required Future<void> Function() onExportCsv,
  VoidCallback? onOpenMessages,
}) {
  final child = _InterestedPanel(
    job: job,
    alumni: alumni,
    onExportCsv: onExportCsv,
    onOpenMessages: onOpenMessages,
  );
  if (adminIsWideSurface(context)) {
    return showAdminSidePanel<void>(context: context, width: 500, child: child);
  }
  return showAdminDialogSurface<void>(
    context: context,
    maxWidth: 560,
    child: SizedBox(
      height: math.min(720.0, MediaQuery.sizeOf(context).height * 0.9),
      child: child,
    ),
  );
}

class _InterestedPanel extends StatefulWidget {
  const _InterestedPanel({
    required this.job,
    required this.alumni,
    required this.onExportCsv,
    this.onOpenMessages,
  });

  final JobPosting job;
  final List<JobInterestedAlumni> alumni;
  final Future<void> Function() onExportCsv;
  final VoidCallback? onOpenMessages;

  @override
  State<_InterestedPanel> createState() => _InterestedPanelState();
}

class _InterestedPanelState extends State<_InterestedPanel> {
  final _searchController = TextEditingController();
  String _query = '';
  String _sort = 'newest';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<JobInterestedAlumni> get _filtered {
    var list = List<JobInterestedAlumni>.from(widget.alumni);
    final q = _query.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list
          .where(
            (a) =>
                a.name.toLowerCase().contains(q) ||
                a.email.toLowerCase().contains(q) ||
                a.course.toLowerCase().contains(q) ||
                a.batch.toLowerCase().contains(q) ||
                a.employmentStatus.toLowerCase().contains(q),
          )
          .toList();
    }
    if (_sort == 'az') {
      list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    } else {
      list.sort((a, b) => b.interestedAt.compareTo(a.interestedAt));
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final rows = _filtered;
    final total = widget.alumni.length;

    return ColoredBox(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AdminJobTheme.infoBg,
                    borderRadius: BorderRadius.circular(AdminJobTheme.radiusSm),
                  ),
                  child: const Icon(
                    Icons.star_outline,
                    size: 20,
                    color: AdminJobTheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Interested alumni',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: AdminJobTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.job.jobTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AdminJobTheme.textSecondary,
                          fontSize: 12.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$total signal${total == 1 ? '' : 's'}'
                        '${rows.length != total ? ' · ${rows.length} shown' : ''}',
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AdminColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Export CSV',
                  onPressed: total == 0 ? null : () => widget.onExportCsv(),
                  style: AdminDensity.iconButtonStyle(
                    foregroundColor: AdminColors.textSecondary,
                  ),
                  icon: const Icon(Icons.download_outlined),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.pop(context),
                  style: AdminDensity.iconButtonStyle(
                    foregroundColor: AdminColors.textSecondary,
                  ),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: AdminDirectoryTheme.toolbarControlHeight,
                    child: TextField(
                      controller: _searchController,
                      onChanged: (v) => setState(() => _query = v),
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Search name, email, program…',
                        isDense: true,
                        filled: true,
                        fillColor: AdminJobTheme.surface,
                        prefixIcon: const Icon(Icons.search, size: 18),
                        suffixIcon: _query.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Clear',
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _query = '');
                                },
                                icon: const Icon(Icons.close, size: 16),
                              ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            AdminJobTheme.radiusSm,
                          ),
                          borderSide: const BorderSide(
                            color: AdminJobTheme.border,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            AdminJobTheme.radiusSm,
                          ),
                          borderSide: const BorderSide(
                            color: AdminJobTheme.border,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 128,
                  child: DirectoryFilterField<String>(
                    label: 'Sort',
                    dense: true,
                    value: _sort,
                    items: const [
                      DropdownMenuItem(value: 'newest', child: Text('Newest')),
                      DropdownMenuItem(value: 'az', child: Text('Name A–Z')),
                    ],
                    onChanged: (v) => setState(() => _sort = v ?? 'newest'),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AdminColors.border),
          Expanded(
            child: rows.isEmpty
                ? AdminStateView.empty(
                    compact: true,
                    icon: total == 0 ? Icons.star_border : Icons.search_off,
                    title: total == 0
                        ? 'No interested alumni yet'
                        : 'No matches',
                    message: total == 0
                        ? 'Alumni who mark this job as Interested will appear here.'
                        : 'Try a different search or sort.',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
                    itemCount: rows.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AdminDensity.listItemGap),
                    itemBuilder: (context, i) {
                      final a = rows[i];
                      return _InterestedAlumniCard(
                        alumni: a,
                        onMessage: () {
                          final userId = a.userId.trim();
                          Navigator.pop(context);
                          // Switch to Messages first so the page can mount and
                          // subscribe, then emit the deep-link on the next frame.
                          widget.onOpenMessages?.call();
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (userId.isNotEmpty) {
                              MessageOpenBus.openConversation(userId);
                            }
                          });
                        },
                        onCopyEmail: a.email.isEmpty
                            ? null
                            : () async {
                                await Clipboard.setData(
                                  ClipboardData(text: a.email),
                                );
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Email copied'),
                                    ),
                                  );
                                }
                              },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _InterestedAlumniCard extends StatefulWidget {
  const _InterestedAlumniCard({
    required this.alumni,
    required this.onMessage,
    this.onCopyEmail,
  });

  final JobInterestedAlumni alumni;
  final VoidCallback onMessage;
  final VoidCallback? onCopyEmail;

  @override
  State<_InterestedAlumniCard> createState() => _InterestedAlumniCardState();
}

class _InterestedAlumniCardState extends State<_InterestedAlumniCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final a = widget.alumni;
    final provider = AppImage.provider(a.avatarUrl);
    final programLine = [
      if (a.course.isNotEmpty) a.course,
      if (a.batch.isNotEmpty) a.batch,
    ].join(' · ');
    final interestedLabel = DateFormat.yMMMd().add_jm().format(a.interestedAt);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        decoration: AdminJobTheme.surfaceCard(hovered: _hovered),
        padding: const EdgeInsets.all(AdminDensity.cardPadding),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 20,
              backgroundImage: provider,
              backgroundColor: AdminJobTheme.primary.withValues(alpha: 0.08),
              child: provider == null
                  ? Text(
                      a.name.isNotEmpty ? a.name[0].toUpperCase() : 'A',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AdminJobTheme.primary,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    a.name.isEmpty ? 'Alumni' : a.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                      color: AdminJobTheme.textPrimary,
                    ),
                  ),
                  if (a.email.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      a.email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AdminJobTheme.textSecondary,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (programLine.isNotEmpty)
                        _infoChip(
                          icon: Icons.school_outlined,
                          label: programLine,
                        ),
                      if (a.employmentStatus.isNotEmpty)
                        _infoChip(
                          icon: Icons.work_outline,
                          label: a.employmentStatus,
                        ),
                      _infoChip(
                        icon: Icons.schedule_outlined,
                        label: interestedLabel,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: widget.onMessage,
                        icon: const Icon(Icons.chat_bubble_outline, size: 15),
                        label: const Text('Message'),
                        style: TextButton.styleFrom(
                          foregroundColor: AdminJobTheme.primary,
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                      ),
                      if (widget.onCopyEmail != null)
                        TextButton.icon(
                          onPressed: widget.onCopyEmail,
                          icon: const Icon(Icons.copy, size: 15),
                          label: const Text('Copy email'),
                          style: TextButton.styleFrom(
                            foregroundColor: AdminJobTheme.textSecondary,
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoChip({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: AdminJobTheme.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AdminJobTheme.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AdminColors.textSecondary),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11.5,
              color: AdminColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> exportInterestedAlumniCsv({
  required BuildContext context,
  required JobPosting job,
  required List<JobInterestedAlumni> alumni,
}) async {
  final buf = StringBuffer();
  buf.writeln('Name,Email,Course,Batch,Employment,Interested At');
  for (final a in alumni) {
    const esc = CsvSafe.cell;
    buf.writeln(
      [
        esc(a.name),
        esc(a.email),
        esc(a.course),
        esc(a.batch),
        esc(a.employmentStatus),
        esc(a.interestedAt.toIso8601String()),
      ].join(','),
    );
  }
  final ok = tryDownloadTextOnWeb(
    context,
    content: buf.toString(),
    fileName:
        'interested-${job.jobTitle.replaceAll(RegExp(r"[^a-zA-Z0-9]+"), "-").toLowerCase()}.csv',
    mimeType: 'text/csv',
  );
  if (ok && context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('CSV downloaded')));
  }
}
