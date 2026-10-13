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
import 'package:alumni_system/shared/widgets/admin/admin_density.dart';
import 'package:alumni_system/shared/widgets/admin/admin_form_layout.dart';
import 'package:alumni_system/shared/widgets/admin/admin_surface.dart';
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

ButtonStyle jobFilledButtonStyle({Color? background}) => FilledButton.styleFrom(
  backgroundColor: background ?? AdminJobTheme.primary,
  foregroundColor: Colors.white,
  minimumSize: const Size(0, AdminJobTheme.buttonHeight),
  padding: const EdgeInsets.symmetric(horizontal: 16),
  elevation: 0,
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(AdminJobTheme.radiusSm),
  ),
);

ButtonStyle jobOutlinedButtonStyle() => OutlinedButton.styleFrom(
  foregroundColor: AdminJobTheme.textPrimary,
  side: const BorderSide(color: AdminJobTheme.border),
  minimumSize: const Size(0, AdminJobTheme.buttonHeight),
  padding: const EdgeInsets.symmetric(horizontal: 14),
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(AdminJobTheme.radiusSm),
  ),
);

/// Compact survey-style row card for Job Postings list.
class AdminJobCard extends StatefulWidget {
  const AdminJobCard({
    super.key,
    required this.job,
    required this.onEdit,
    required this.onDetails,
    required this.onInterested,
    required this.onToggleArchive,
    required this.onDelete,
  });

  final JobPosting job;
  final VoidCallback onEdit;
  final VoidCallback onDetails;
  final VoidCallback onInterested;
  final VoidCallback onToggleArchive;
  final VoidCallback onDelete;

  @override
  State<AdminJobCard> createState() => _AdminJobCardState();
}

class _AdminJobCardState extends State<AdminJobCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final job = widget.job;
    final fmt = DateFormat.yMMMd();
    final metaParts = <String>[
      if (job.companyName.isNotEmpty) job.companyName,
      if (job.jobType.isNotEmpty) job.jobType,
      if (job.isRemote) 'Remote' else if (job.location.isNotEmpty) job.location,
      'Deadline ${fmt.format(job.applicationDeadline)}',
    ];
    final metaLine = metaParts.join(' · ');

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        margin: const EdgeInsets.only(bottom: AdminJobTheme.listItemGap),
        decoration: AdminJobTheme.surfaceCard(hovered: _hovered),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onDetails,
            borderRadius: BorderRadius.circular(AdminJobTheme.radiusMd),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AdminDensity.space3,
                vertical: AdminDensity.cardPadding,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  JobCompanyLogo(job: job, size: 32, radius: 8),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          job.jobTitle.isEmpty ? 'Untitled job' : job.jobTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: AdminJobTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: [
                            JobStatusBadge(status: job.status),
                            JobCategoryBadge(category: job.category),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          metaLine,
                          style: const TextStyle(
                            fontSize: 12,
                            height: 1.35,
                            color: AdminJobTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Job actions',
                    onSelected: (value) {
                      switch (value) {
                        case 'details':
                          widget.onDetails();
                        case 'interested':
                          widget.onInterested();
                        case 'edit':
                          widget.onEdit();
                        case 'archive':
                          widget.onToggleArchive();
                        case 'delete':
                          widget.onDelete();
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'details',
                        child: Text('Details'),
                      ),
                      PopupMenuItem(
                        value: 'interested',
                        child: Text('Interested (${job.interestedCount})'),
                      ),
                      const PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(
                        value: 'archive',
                        child: Text(
                          job.status == 'archived' ? 'Activate' : 'Archive',
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete'),
                      ),
                    ],
                    icon: const Icon(
                      Icons.more_vert,
                      color: AdminJobTheme.textMuted,
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
          padding: const EdgeInsets.fromLTRB(20, 14, 8, 0),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AdminJobTheme.infoBg,
                  borderRadius: BorderRadius.circular(AdminJobTheme.radiusSm),
                ),
                child: const Icon(
                  Icons.insights_outlined,
                  size: 20,
                  color: AdminJobTheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Quick insights',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AdminJobTheme.textPrimary,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Snapshot of engagement across all job postings',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: AdminJobTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                style: AdminDensity.iconButtonStyle(
                  foregroundColor: AdminJobTheme.textMuted,
                ),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const Divider(height: 1),
        Expanded(
          child: jobCount == 0
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'No jobs yet — insights will appear after you post openings.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AdminJobTheme.textSecondary),
                    ),
                  ),
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
                      color: AdminJobTheme.textMuted,
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
              color: AdminJobTheme.textSecondary,
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
        color: AdminJobTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AdminJobTheme.border),
      ),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: label,
              style: const TextStyle(
                fontSize: 12,
                color: AdminJobTheme.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            TextSpan(
              text: '  $count',
              style: const TextStyle(
                fontSize: 12,
                color: AdminJobTheme.textMuted,
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
      style: const TextStyle(fontSize: 12.5, color: AdminJobTheme.textMuted),
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
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          JobStatusBadge(status: job.status),
                          JobCategoryBadge(category: job.category),
                          if (job.isRemote)
                            const JobCategoryBadge(category: 'Remote'),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.pop(context),
                  style: AdminDensity.iconButtonStyle(
                    foregroundColor: AdminJobTheme.textMuted,
                  ),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
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
                        value: job.salaryRange,
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
                          color: AdminJobTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Export CSV',
                  onPressed: total == 0 ? null : () => widget.onExportCsv(),
                  style: AdminDensity.iconButtonStyle(
                    foregroundColor: AdminJobTheme.textSecondary,
                  ),
                  icon: const Icon(Icons.download_outlined),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.pop(context),
                  style: AdminDensity.iconButtonStyle(
                    foregroundColor: AdminJobTheme.textMuted,
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
          const Divider(height: 1),
          Expanded(
            child: rows.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            total == 0 ? Icons.star_border : Icons.search_off,
                            size: 40,
                            color: AdminJobTheme.textMuted,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            total == 0
                                ? 'No interested alumni yet'
                                : 'No matches',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: AdminJobTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            total == 0
                                ? 'Alumni who mark this job as Interested will appear here.'
                                : 'Try a different search or sort.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: AdminJobTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
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
          Icon(icon, size: 12, color: AdminJobTheme.textMuted),
          const SizedBox(width: 4),
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
