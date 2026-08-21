import 'package:flutter/material.dart';
import 'package:alumni_system/features/admin/dashboard/widgets/admin_instant_content.dart';
import 'package:alumni_system/features/admin/jobs/widgets/admin_job_ui.dart';
import 'package:alumni_system/features/admin/roster/widgets/alumni_directory_ui.dart';
import 'package:alumni_system/features/jobs/application/job_deadline_reminders.dart';
import 'package:alumni_system/features/jobs/data/job_interest_service.dart';
import 'package:alumni_system/features/jobs/data/job_service.dart';
import 'package:alumni_system/features/jobs/models/job_category_constants.dart';
import 'package:alumni_system/features/jobs/models/job_posting_model.dart';
import 'package:alumni_system/features/jobs/presentation/add_job_dialog.dart';
import 'package:alumni_system/features/notifications/data/notification_service.dart';
import 'package:alumni_system/shared/widgets/admin/admin_density.dart';
import 'package:alumni_system/shared/widgets/admin/admin_form_layout.dart';
import 'package:alumni_system/shared/widgets/admin/admin_page_header.dart';
import 'package:alumni_system/shared/widgets/admin/admin_skeletons.dart';
import 'package:alumni_system/shared/widgets/admin/admin_surface.dart';

class AdminJobManagement extends StatefulWidget {
  const AdminJobManagement({super.key, this.onOpenAdminMenu});

  /// Switches admin shell menu (e.g. Messages = 6) after deep-links.
  final ValueChanged<int>? onOpenAdminMenu;

  @override
  State<AdminJobManagement> createState() => _AdminJobManagementState();
}

class _AdminJobManagementState extends State<AdminJobManagement>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final _searchController = TextEditingController();
  final _jobService = JobService();
  final _interestService = JobInterestService();

  List<JobPosting> _jobs = [];
  bool _loading = true;
  String _status = 'active';
  String _category = 'all';
  String _jobType = 'all';
  String _experience = 'all';
  String? _remote; // null all, 'yes', 'no'
  String _sort = 'newest';
  int _page = 0;
  static const _pageSize = 20;

  int get _totalInterest =>
      _jobs.fold<int>(0, (s, j) => s + j.interestedCount);

  double get _avgInterest {
    if (_jobs.isEmpty) return 0;
    return _totalInterest / _jobs.length;
  }

  int get _activeCount => _jobs.where((j) => j.status == 'active').length;
  int get _archivedCount => _jobs.where((j) => j.status == 'archived').length;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final raw = await _jobService.getAllJobs();
      final withCounts = await attachJobEngagementCounts(raw);
      if (!mounted) return;
      setState(() {
        _jobs = withCounts;
        _loading = false;
        _page = 0;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading jobs: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  List<JobPosting> get _filtered {
    final q = _searchController.text.trim().toLowerCase();
    var list = _jobs.where((j) {
      if (_status != 'all' && j.status != _status) return false;
      if (_category != 'all' && j.category != _category) return false;
      if (_jobType != 'all' && j.jobType != _jobType) return false;
      if (_experience != 'all' && j.experienceLevel != _experience) {
        return false;
      }
      if (_remote == 'yes' && !j.isRemote) return false;
      if (_remote == 'no' && j.isRemote) return false;
      if (q.isEmpty) return true;
      return j.jobTitle.toLowerCase().contains(q) ||
          j.companyName.toLowerCase().contains(q) ||
          j.location.toLowerCase().contains(q) ||
          j.category.toLowerCase().contains(q);
    }).toList();

    switch (_sort) {
      case 'oldest':
        list.sort((a, b) => a.postedDate.compareTo(b.postedDate));
      case 'deadline':
        list.sort(
          (a, b) => a.applicationDeadline.compareTo(b.applicationDeadline),
        );
      case 'views':
        list.sort((a, b) => b.views.compareTo(a.views));
      case 'interested':
        list.sort((a, b) => b.interestedCount.compareTo(a.interestedCount));
      case 'salary_high':
        list.sort(
          (a, b) =>
              _salaryNum(b.salaryRange).compareTo(_salaryNum(a.salaryRange)),
        );
      default:
        list.sort((a, b) => b.postedDate.compareTo(a.postedDate));
    }
    return list;
  }

  double _salaryNum(String raw) {
    final m = RegExp(r'[\d,]+').firstMatch(raw);
    if (m == null) return 0;
    return double.tryParse(m.group(0)!.replaceAll(',', '')) ?? 0;
  }

  List<JobPosting> get _pageItems {
    final all = _filtered;
    final start = _page * _pageSize;
    if (start >= all.length) return [];
    return all.sublist(start, (start + _pageSize).clamp(0, all.length));
  }

  bool get _hasFilters {
    final q = _searchController.text.trim();
    return q.isNotEmpty ||
        _status != 'active' ||
        _category != 'all' ||
        _jobType != 'all' ||
        _experience != 'all' ||
        _remote != null ||
        _sort != 'newest';
  }

  void _resetFilters() {
    setState(() {
      _searchController.clear();
      _status = 'active';
      _category = 'all';
      _jobType = 'all';
      _experience = 'all';
      _remote = null;
      _sort = 'newest';
      _page = 0;
    });
  }

  List<Widget> _activeFilterChips() {
    final chips = <Widget>[];
    final q = _searchController.text.trim();
    if (q.isNotEmpty) {
      chips.add(
        DirectoryActiveFilterChip(
          label: 'Search: $q',
          onRemoved: () {
            _searchController.clear();
            setState(() => _page = 0);
          },
        ),
      );
    }
    if (_status != 'active') {
      chips.add(
        DirectoryActiveFilterChip(
          label: 'Status: ${_status == 'all' ? 'All' : _status}',
          onRemoved: () => setState(() {
            _status = 'active';
            _page = 0;
          }),
        ),
      );
    }
    if (_category != 'all') {
      chips.add(
        DirectoryActiveFilterChip(
          label: 'Category: $_category',
          onRemoved: () => setState(() {
            _category = 'all';
            _page = 0;
          }),
        ),
      );
    }
    if (_jobType != 'all') {
      chips.add(
        DirectoryActiveFilterChip(
          label: 'Type: $_jobType',
          onRemoved: () => setState(() {
            _jobType = 'all';
            _page = 0;
          }),
        ),
      );
    }
    if (_experience != 'all') {
      chips.add(
        DirectoryActiveFilterChip(
          label: 'Experience: $_experience',
          onRemoved: () => setState(() {
            _experience = 'all';
            _page = 0;
          }),
        ),
      );
    }
    if (_remote != null) {
      chips.add(
        DirectoryActiveFilterChip(
          label: _remote == 'yes' ? 'Remote' : 'On-site',
          onRemoved: () => setState(() {
            _remote = null;
            _page = 0;
          }),
        ),
      );
    }
    if (_sort != 'newest') {
      chips.add(
        DirectoryActiveFilterChip(
          label: 'Sort: $_sort',
          onRemoved: () => setState(() {
            _sort = 'newest';
            _page = 0;
          }),
        ),
      );
    }
    return chips;
  }

  Future<void> _openEditor({JobPosting? job}) async {
    final result = await showAdminDialogSurface<bool>(
      context: context,
      maxWidth: kAdminDialogXl,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 8, 0),
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
                    Icons.work_outline,
                    size: 20,
                    color: AdminJobTheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        job == null ? 'Post new job' : 'Edit job',
                        style: const TextStyle(
                          fontSize: AdminDensity.titleFontSize,
                          fontWeight: FontWeight.w700,
                          color: AdminJobTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        job == null
                            ? 'Share a career opportunity with alumni'
                            : 'Update posting details and targeting',
                        style: const TextStyle(
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
          const Divider(height: 12),
          Expanded(
            child: AddJobDialog(
              job: job,
              onJobAdded: (_) {},
              onJobUpdated: (_) {},
            ),
          ),
        ],
      ),
    );
    if (result == true) await _load();
  }

  Future<void> _toggleArchive(JobPosting job) async {
    final next = job.status == 'archived' ? 'active' : 'archived';
    final updated = job.copyWith(
      status: next,
      isActive: next == 'active',
    );
    await _jobService.updateJobPosting(updated);
    if (next == 'active') {
      try {
        await NotificationService().notifyJobRestored(
          jobId: job.id,
          jobTitle: job.jobTitle,
          companyName: job.companyName,
        );
      } catch (_) {}
    }
    await _load();
  }

  Future<void> _delete(JobPosting job) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete job?'),
        content: Text('Permanently delete "${job.jobTitle}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: jobFilledButtonStyle(background: AdminJobTheme.danger),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _jobService.deleteJobPosting(job.id);
    await _load();
  }

  Future<void> _openInterested(JobPosting job) async {
    final alumni = await _interestService.listAlumniForJob(job.id);
    if (!mounted) return;
    await showAdminInterestedDrawer(
      context: context,
      job: job,
      alumni: alumni,
      onExportCsv: () => exportInterestedAlumniCsv(
        context: context,
        job: job,
        alumni: alumni,
      ),
      onOpenMessages: () => widget.onOpenAdminMenu?.call(6),
    );
  }

  Widget _buildMetrics() {
    return DirectoryStatsGrid(
      children: [
        DirectoryStatCard(
          label: 'Total',
          value: '${_jobs.length}',
          description: 'All postings',
          icon: Icons.work_outline,
          accent: AdminJobTheme.primary,
          onTap: () => setState(() {
            _status = 'all';
            _page = 0;
          }),
        ),
        DirectoryStatCard(
          label: 'Active',
          value: '$_activeCount',
          description: 'Visible to alumni',
          icon: Icons.check_circle_outline,
          accent: AdminDirectoryTheme.success,
          onTap: () => setState(() {
            _status = 'active';
            _page = 0;
          }),
        ),
        DirectoryStatCard(
          label: 'Interested',
          value: '$_totalInterest',
          description: 'Total interest signals',
          icon: Icons.star_outline,
          accent: AdminDirectoryTheme.warning,
        ),
        DirectoryStatCard(
          label: 'Avg interest',
          value: _avgInterest.toStringAsFixed(1),
          description: 'Per job posting',
          icon: Icons.insights_outlined,
          accent: AdminDirectoryTheme.info,
        ),
      ],
    );
  }

  Widget _statusChip({
    required String value,
    required String label,
  }) {
    final selected = _status == value;
    return FilterChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      labelPadding: const EdgeInsets.symmetric(horizontal: 4),
      selectedColor: AdminJobTheme.infoBg,
      labelStyle: TextStyle(
        fontSize: 12,
        color: selected ? AdminJobTheme.primary : AdminJobTheme.textSecondary,
      ),
      side: const BorderSide(color: AdminJobTheme.border),
      onSelected: (_) => setState(() {
        _status = value;
        _page = 0;
      }),
    );
  }

  Widget _buildToolbar() {
    return DirectoryToolbarCard(
      searchHint: 'Search title, company, location…',
      searchController: _searchController,
      onSearchChanged: (_) => setState(() => _page = 0),
      onClearSearch: () {
        _searchController.clear();
        setState(() => _page = 0);
      },
      isLoading: _loading,
      onRefresh: _load,
      hasActiveFilters: _hasFilters,
      onResetFilters: _resetFilters,
      activeFilterChips: _activeFilterChips(),
      filters: Wrap(
        spacing: 6,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          DirectoryFilterField<String>(
            label: 'Category',
            value: _category,
            width: 140,
            items: [
              const DropdownMenuItem(value: 'all', child: Text('All')),
              ...JobCategoryConstants.all.map(
                (c) => DropdownMenuItem(value: c, child: Text(c)),
              ),
            ],
            onChanged: (v) => setState(() {
              _category = v ?? 'all';
              _page = 0;
            }),
          ),
          DirectoryFilterField<String>(
            label: 'Type',
            value: _jobType,
            width: 132,
            items: [
              const DropdownMenuItem(value: 'all', child: Text('All')),
              ...JobCategoryConstants.jobTypes.map(
                (c) => DropdownMenuItem(value: c, child: Text(c)),
              ),
            ],
            onChanged: (v) => setState(() {
              _jobType = v ?? 'all';
              _page = 0;
            }),
          ),
          DirectoryFilterField<String>(
            label: 'Experience',
            value: _experience,
            width: 140,
            items: [
              const DropdownMenuItem(value: 'all', child: Text('All')),
              ...JobCategoryConstants.experienceLevels.map(
                (c) => DropdownMenuItem(value: c, child: Text(c)),
              ),
            ],
            onChanged: (v) => setState(() {
              _experience = v ?? 'all';
              _page = 0;
            }),
          ),
          DirectoryFilterField<String>(
            label: 'Remote',
            value: _remote ?? 'all',
            width: 120,
            items: const [
              DropdownMenuItem(value: 'all', child: Text('All')),
              DropdownMenuItem(value: 'yes', child: Text('Remote')),
              DropdownMenuItem(value: 'no', child: Text('On-site')),
            ],
            onChanged: (v) => setState(() {
              _remote = v == 'all' ? null : v;
              _page = 0;
            }),
          ),
          DirectoryFilterField<String>(
            label: 'Sort',
            value: _sort,
            width: 148,
            items: const [
              DropdownMenuItem(value: 'newest', child: Text('Newest')),
              DropdownMenuItem(value: 'oldest', child: Text('Oldest')),
              DropdownMenuItem(value: 'deadline', child: Text('Deadline')),
              DropdownMenuItem(value: 'views', child: Text('Most viewed')),
              DropdownMenuItem(
                value: 'interested',
                child: Text('Most interested'),
              ),
              DropdownMenuItem(
                value: 'salary_high',
                child: Text('Salary high→low'),
              ),
            ],
            onChanged: (v) => setState(() {
              _sort = v ?? 'newest';
              _page = 0;
            }),
          ),
          _statusChip(value: 'all', label: 'All'),
          _statusChip(value: 'active', label: 'Active'),
          _statusChip(value: 'expired', label: 'Expired'),
          _statusChip(
            value: 'archived',
            label: 'Archived ($_archivedCount)',
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final filtered = _filtered;
    final pageCount = (filtered.length / _pageSize).ceil().clamp(1, 9999);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
            AdminPageHeader(
              title: 'Job Postings',
              subtitle: 'University career board for alumni opportunities',
              actions: [
                OutlinedButton.icon(
                  onPressed: _loading
                      ? null
                      : () => showAdminJobInsightsDialog(
                            context: context,
                            jobs: _jobs,
                          ),
                  icon: const Icon(Icons.insights_outlined, size: 17),
                  label: const Text('Insights'),
                  style: jobOutlinedButtonStyle(),
                ),
                FilledButton.icon(
                  onPressed: _loading ? null : () => _openEditor(),
                  icon: const Icon(Icons.add, size: 17),
                  label: const Text('Post new job'),
                  style: jobFilledButtonStyle(),
                ),
              ],
            ),
            const SizedBox(height: AdminJobTheme.space2),
            _buildMetrics(),
            const SizedBox(height: AdminJobTheme.space2),
            _buildToolbar(),
            const SizedBox(height: AdminJobTheme.space1),
            Expanded(
              child: AdminInstantContent(
                loading: _loading,
                loadingSkeleton: const PortalCardListSkeleton(),
                isEmpty: filtered.isEmpty,
                empty: DirectoryEmptyState(
                  title: _hasFilters ? 'No matching jobs' : 'No jobs yet',
                  subtitle: _hasFilters
                      ? 'Try clearing filters or search.'
                      : 'Post a career opportunity for alumni.',
                  icon: Icons.work_off_outlined,
                  primaryAction: _hasFilters ? null : () => _openEditor(),
                  primaryLabel: _hasFilters ? null : 'Post new job',
                ),
                child: ListView(
                  padding: const EdgeInsets.only(bottom: AdminDensity.space3),
                  children: [
                    DirectoryResultsBar(
                      message:
                          '${filtered.length} job${filtered.length == 1 ? '' : 's'}',
                    ),
                    const SizedBox(height: AdminDensity.space1),
                    ..._pageItems.map(
                      (job) => AdminJobCard(
                        job: job,
                        onEdit: () => _openEditor(job: job),
                        onDetails: () => showAdminJobDetailsDrawer(
                          context: context,
                          job: job,
                          onOpenInterested: () => _openInterested(job),
                        ),
                        onInterested: () => _openInterested(job),
                        onToggleArchive: () => _toggleArchive(job),
                        onDelete: () => _delete(job),
                      ),
                    ),
                    if (pageCount > 1)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: AdminDensity.space1,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              onPressed: _page > 0
                                  ? () => setState(() => _page--)
                                  : null,
                              style: AdminDensity.iconButtonStyle(),
                              icon: const Icon(Icons.chevron_left),
                            ),
                            Text(
                              'Page ${_page + 1} of $pageCount',
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: AdminJobTheme.textSecondary,
                              ),
                            ),
                            IconButton(
                              onPressed: _page < pageCount - 1
                                  ? () => setState(() => _page++)
                                  : null,
                              style: AdminDensity.iconButtonStyle(),
                              icon: const Icon(Icons.chevron_right),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
    );
  }
}
