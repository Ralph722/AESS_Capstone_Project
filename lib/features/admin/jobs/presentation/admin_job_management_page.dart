import 'package:flutter/material.dart';
import 'package:alumni_system/features/admin/jobs/widgets/admin_job_ui.dart';
import 'package:alumni_system/features/admin/roster/widgets/alumni_directory_ui.dart';
import 'package:alumni_system/features/jobs/application/job_deadline_reminders.dart';
import 'package:alumni_system/features/jobs/data/job_interest_service.dart';
import 'package:alumni_system/features/jobs/data/job_service.dart';
import 'package:alumni_system/features/jobs/models/job_category_constants.dart';
import 'package:alumni_system/features/jobs/models/job_interest_model.dart';
import 'package:alumni_system/features/jobs/models/job_posting_model.dart';
import 'package:alumni_system/features/jobs/presentation/add_job_dialog.dart';
import 'package:alumni_system/features/share/share_link_sheet.dart';
import 'package:alumni_system/features/share/shareable_content.dart';
import 'package:alumni_system/shared/widgets/admin/admin_buttons.dart';
import 'package:alumni_system/shared/widgets/admin/admin_compact_header.dart';
import 'package:alumni_system/shared/widgets/admin/admin_confirm_dialog.dart';
import 'package:alumni_system/shared/widgets/admin/admin_density.dart';
import 'package:alumni_system/shared/widgets/admin/admin_dialogs.dart';
import 'package:alumni_system/shared/widgets/admin/admin_form_layout.dart';
import 'package:alumni_system/shared/widgets/admin/admin_metric_ribbon.dart';
import 'package:alumni_system/shared/widgets/admin/admin_pagination.dart';
import 'package:alumni_system/shared/widgets/admin/admin_saas_tabs.dart';
import 'package:alumni_system/shared/widgets/admin/admin_saas_toolbar.dart';
import 'package:alumni_system/shared/widgets/admin/admin_skeletons.dart';
import 'package:alumni_system/shared/widgets/admin/admin_state_view.dart';
import 'package:alumni_system/shared/widgets/admin/admin_surface.dart';
import 'package:alumni_system/shared/widgets/admin/admin_theme.dart';

typedef JobEngagementLoader =
    Future<List<JobPosting>> Function(List<JobPosting> jobs);

class AdminJobManagement extends StatefulWidget {
  const AdminJobManagement({
    super.key,
    this.onOpenAdminMenu,
    this.service,
    this.interestService,
    this.engagementLoader,
  });

  /// Switches admin shell menu (e.g. Messages = 6) after deep-links.
  final ValueChanged<int>? onOpenAdminMenu;

  /// Optional overrides for widget tests.
  final JobService? service;
  final JobInterestService? interestService;
  final JobEngagementLoader? engagementLoader;

  @override
  State<AdminJobManagement> createState() => _AdminJobManagementState();
}

class _AdminJobManagementState extends State<AdminJobManagement>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final _searchController = TextEditingController();
  late final JobService _jobService = widget.service ?? JobService();
  late final JobInterestService _interestService =
      widget.interestService ?? JobInterestService();
  final Set<String> _busyJobIds = {};

  List<JobPosting> _jobs = [];
  bool _loading = true;
  bool _hasLoaded = false;
  String? _error;
  String _status = 'active';
  String _category = 'all';
  String _jobType = 'all';
  String _experience = 'all';
  String? _remote; // null all, 'yes', 'no'
  String _sort = 'newest';
  int _page = 0;
  static const _pageSize = 20;

  int get _totalInterest => _jobs.fold<int>(0, (s, j) => s + j.interestedCount);

  double get _avgInterest {
    if (_jobs.isEmpty) return 0;
    return _totalInterest / _jobs.length;
  }

  int get _activeCount => _jobs.where((j) => j.status == 'active').length;
  int get _expiredCount => _jobs.where((j) => j.status == 'expired').length;
  int get _archivedCount => _jobs.where((j) => j.status == 'archived').length;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final raw = await _jobService.getAllJobs();
      final loader = widget.engagementLoader ?? attachJobEngagementCounts;
      final withCounts = await loader(raw);
      if (!mounted) return;
      setState(() {
        _jobs = withCounts;
        _loading = false;
        _hasLoaded = true;
        _error = null;
        _page = adminClampPage(_page, _filtered.length, _pageSize);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _hasLoaded = true;
        _error = '$e';
      });
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

  String _sortLabel(String value) {
    switch (value) {
      case 'oldest':
        return 'Oldest';
      case 'deadline':
        return 'Deadline';
      case 'views':
        return 'Most viewed';
      case 'interested':
        return 'Most interested';
      case 'salary_high':
        return 'Salary high→low';
      default:
        return 'Newest';
    }
  }

  String _statusLabel(String value) {
    switch (value) {
      case 'active':
        return 'Active';
      case 'expired':
        return 'Expired';
      case 'archived':
        return 'Archived';
      default:
        return 'All';
    }
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
          label: 'Status: ${_statusLabel(_status)}',
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
          label: 'Sort: ${_sortLabel(_sort)}',
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
            padding: const EdgeInsets.fromLTRB(20, 14, 12, 8),
            child: AdminModalHeader(
              title: job == null ? 'Post new job' : 'Edit job',
              subtitle: job == null
                  ? 'Share a career opportunity with alumni'
                  : 'Update posting details and targeting',
              icon: Icons.work_outline,
              onClose: () => Navigator.pop(context),
            ),
          ),
          const Divider(height: 12, color: AdminColors.border),
          Expanded(
            child: AddJobDialog(
              job: job,
              service: _jobService,
              onJobAdded: (_) {},
              onJobUpdated: (_) {},
            ),
          ),
        ],
      ),
    );
    if (result == true) await _load();
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? AdminColors.danger : null,
        ),
      );
  }

  Future<void> _toggleArchive(JobPosting job) async {
    if (_busyJobIds.contains(job.id)) return;
    final next = job.status == 'archived' ? 'active' : 'archived';
    final updated = job.copyWith(status: next, isActive: next == 'active');
    setState(() => _busyJobIds.add(job.id));
    try {
      await _jobService.updateJobPosting(updated);
      _showSnack(next == 'archived' ? 'Job archived' : 'Job activated');
      await _load();
    } catch (e) {
      _showSnack(
        jobFriendlyError(e, 'Could not update job status.'),
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _busyJobIds.remove(job.id));
    }
  }

  Future<void> _delete(JobPosting job) async {
    if (_busyJobIds.contains(job.id)) return;
    final label = job.jobTitle.trim().isEmpty
        ? 'this job posting'
        : '“${job.jobTitle.trim()}”';
    final ok = await showAdminConfirmDialog(
      context,
      title: 'Delete job?',
      message:
          'Permanently delete $label? Alumni will no longer see this opportunity and this cannot be undone.',
      confirmLabel: 'Delete',
      destructive: true,
      icon: Icons.delete_outline_rounded,
    );
    if (!ok || !mounted) return;

    setState(() => _busyJobIds.add(job.id));
    try {
      await _jobService.deleteJobPosting(job.id);
      _showSnack('Job deleted');
      await _load();
    } catch (e) {
      _showSnack(
        jobFriendlyError(e, 'Could not delete this job posting.'),
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _busyJobIds.remove(job.id));
    }
  }

  Future<void> _openInterested(JobPosting job) async {
    if (_busyJobIds.contains(job.id)) return;
    setState(() => _busyJobIds.add(job.id));
    List<JobInterestedAlumni>? alumni;
    try {
      alumni = await _interestService.listAlumniForJob(job.id);
    } catch (e) {
      _showSnack(
        jobFriendlyError(e, 'Could not load interested alumni.'),
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _busyJobIds.remove(job.id));
    }
    if (!mounted || alumni == null) return;
    final loadedAlumni = alumni;
    await showAdminInterestedDrawer(
      context: context,
      job: job,
      alumni: loadedAlumni,
      onExportCsv: () => exportInterestedAlumniCsv(
        context: context,
        job: job,
        alumni: loadedAlumni,
      ),
      onOpenMessages: () => widget.onOpenAdminMenu?.call(6),
    );
  }

  Widget _buildTabs() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: AdminSaaSTabs(
        tabs: [
          AdminSaaSTabSpec(
            label: 'Active',
            icon: Icons.check_circle_outline,
            count: _hasLoaded ? _activeCount : null,
            isSelected: _status == 'active',
            onTap: () => setState(() {
              _status = 'active';
              _page = 0;
            }),
          ),
          AdminSaaSTabSpec(
            label: 'Expired',
            icon: Icons.event_busy_outlined,
            count: _hasLoaded ? _expiredCount : null,
            isSelected: _status == 'expired',
            onTap: () => setState(() {
              _status = 'expired';
              _page = 0;
            }),
          ),
          AdminSaaSTabSpec(
            label: 'Archived',
            icon: Icons.archive_outlined,
            count: _hasLoaded ? _archivedCount : null,
            isSelected: _status == 'archived',
            onTap: () => setState(() {
              _status = 'archived';
              _page = 0;
            }),
          ),
          AdminSaaSTabSpec(
            label: 'All',
            icon: Icons.work_outline,
            count: _hasLoaded ? _jobs.length : null,
            isSelected: _status == 'all',
            onTap: () => setState(() {
              _status = 'all';
              _page = 0;
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildMetrics() {
    return AdminMetricRibbon(
      items: [
        AdminMetricRibbonItem(
          label: 'Total',
          value: '${_jobs.length}',
          icon: Icons.work_outline,
          color: AdminColors.primary,
          isSelected: _status == 'all',
          tooltip: 'All job postings — click to show every status',
          onTap: () => setState(() {
            _status = 'all';
            _page = 0;
          }),
        ),
        AdminMetricRibbonItem(
          label: 'Active',
          value: '$_activeCount',
          icon: Icons.check_circle_outline,
          color: AdminColors.success,
          isSelected: _status == 'active',
          tooltip: 'Visible to alumni — click to filter active jobs',
          onTap: () => setState(() {
            _status = 'active';
            _page = 0;
          }),
        ),
        AdminMetricRibbonItem(
          label: 'Interested',
          value: '$_totalInterest',
          icon: Icons.star_outline,
          color: AdminColors.warning,
          isSelected: _sort == 'interested',
          tooltip: 'Total alumni interest signals — click to sort by most interested',
          onTap: () => setState(() {
            _sort = _sort == 'interested' ? 'newest' : 'interested';
            _page = 0;
          }),
        ),
        AdminMetricRibbonItem(
          label: 'Avg interest',
          value: _avgInterest.toStringAsFixed(1),
          icon: Icons.insights_outlined,
          color: AdminColors.secondary,
          tooltip: 'Average interest signals per job posting',
        ),
      ],
    );
  }

  Widget _buildToolbar() {
    return AdminSaaSToolbar(
      searchHint: 'Search title, company, location…',
      searchWidth: 230,
      searchController: _searchController,
      onSearchChanged: (_) => setState(() => _page = 0),
      onClearSearch: () {
        _searchController.clear();
        setState(() => _page = 0);
      },
      isLoading: _loading,
      onRefresh: _load,
      refreshTooltip: 'Refresh job postings',
      hasActiveFilters: _hasFilters,
      onResetFilters: _resetFilters,
      activeFilterChips: _activeFilterChips(),
      filters: [
        DirectoryFilterField<String>(
          label: 'Category',
          value: _category,
          dense: true,
          width: 132,
          items: [
            const DropdownMenuItem(value: 'all', child: Text('All categories')),
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
          dense: true,
          width: 124,
          items: [
            const DropdownMenuItem(value: 'all', child: Text('All types')),
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
          dense: true,
          width: 134,
          items: [
            const DropdownMenuItem(value: 'all', child: Text('All levels')),
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
          dense: true,
          width: 112,
          items: const [
            DropdownMenuItem(value: 'all', child: Text('All modes')),
            DropdownMenuItem(value: 'yes', child: Text('Remote')),
            DropdownMenuItem(value: 'no', child: Text('On-site')),
          ],
          onChanged: (v) => setState(() {
            _remote = v == 'all' ? null : v;
            _page = 0;
          }),
        ),
      ],
      sortControl: DirectoryFilterField<String>(
        label: 'Sort',
        value: _sort,
        dense: true,
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
    );
  }

  Widget _buildRefreshErrorNotice() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
      decoration: BoxDecoration(
        color: AdminColors.warningBg,
        borderRadius: BorderRadius.circular(AdminSurfaces.radiusSm),
        border: Border.all(color: AdminColors.warning.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.cloud_off_outlined,
            size: 18,
            color: AdminColors.warning,
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              "Couldn't refresh job postings. Showing the last loaded list.",
              style: TextStyle(fontSize: 13, color: AdminColors.textPrimary),
            ),
          ),
          TextButton(
            onPressed: _loading ? null : _load,
            child: const Text('Try again'),
          ),
        ],
      ),
    );
  }

  Widget _buildListPane() {
    final filtered = _filtered;

    if (_loading && _jobs.isEmpty) {
      return const AdminJobsListSkeleton();
    }
    if (_error != null && _jobs.isEmpty) {
      return AdminStateView.error(
        title: "Couldn't load job postings",
        message: jobFriendlyError(
          _error!,
          'Check your connection and try again.',
        ),
        details: _error,
        onRetry: _load,
      );
    }
    if (filtered.isEmpty) {
      final catalogEmpty = _jobs.isEmpty;
      return AdminStateView.empty(
        icon: Icons.work_off_outlined,
        title: catalogEmpty
            ? 'No job postings yet'
            : (_hasFilters ? 'No matching job postings' : 'No active job postings'),
        message: catalogEmpty
            ? 'Post a career opportunity to share it with alumni.'
            : (_hasFilters
                  ? 'Try clearing filters or searching with a different keyword.'
                  : 'Switch to All to review expired or archived job postings.'),
        primaryAction: catalogEmpty
            ? AdminStateAction(
                label: 'Post new job',
                icon: Icons.add,
                onPressed: _openEditor,
              )
            : (_hasFilters
                  ? AdminStateAction(
                      label: 'Clear filters',
                      icon: Icons.filter_alt_off_outlined,
                      onPressed: _resetFilters,
                    )
                  : AdminStateAction(
                      label: 'Show all statuses',
                      icon: Icons.work_outline,
                      onPressed: () => setState(() {
                        _status = 'all';
                        _page = 0;
                      }),
                    )),
      );
    }

    final safePage = adminClampPage(_page, filtered.length, _pageSize);
    final pageCount = adminPageCount(filtered.length, _pageSize);
    final pageItems = adminPaginate(filtered, safePage, _pageSize);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.only(bottom: AdminDensity.space2),
              children: [
                DirectoryResultsBar(
                  message:
                      '${filtered.length} job${filtered.length == 1 ? '' : 's'}',
                ),
                const SizedBox(height: AdminDensity.space1),
                ...pageItems.map(
                  (job) => AdminJobCard(
                    job: job,
                    busy: _busyJobIds.contains(job.id),
                    onEdit: () => _openEditor(job: job),
                    onDetails: () => showAdminJobDetailsDrawer(
                      context: context,
                      job: job,
                      onOpenInterested: () => _openInterested(job),
                    ),
                    onShare: () => showShareLinkSheet(
                      context,
                      ShareableContent.fromJob(job),
                    ),
                    onInterested: () => _openInterested(job),
                    onToggleArchive: () => _toggleArchive(job),
                    onDelete: () => _delete(job),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (pageCount > 1) ...[
          const SizedBox(height: AdminDensity.space1),
          Container(
            decoration: BoxDecoration(
              color: AdminColors.card,
              borderRadius: BorderRadius.circular(AdminSurfaces.radiusSm),
              border: Border.all(color: AdminColors.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: AdminPaginationBar(
              totalItems: filtered.length,
              page: safePage,
              pageSize: _pageSize,
              dense: true,
              onPageChanged: (nextPage) => setState(() => _page = nextPage),
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AdminCompactHeader(
          title: 'Job Postings',
          countBadge: _hasLoaded ? '$_activeCount active' : null,
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
              style: AdminButtonStyles.outlined(),
            ),
            FilledButton.icon(
              onPressed: _loading ? null : () => _openEditor(),
              icon: const Icon(Icons.add, size: 17),
              label: const Text('Post new job'),
              style: AdminButtonStyles.filled(),
            ),
          ],
        ),
        const SizedBox(height: AdminDensity.space2),
        Align(
          alignment: Alignment.centerLeft,
          child: _buildTabs(),
        ),
        const SizedBox(height: AdminDensity.space2),
        _buildMetrics(),
        const SizedBox(height: AdminDensity.space2),
        _buildToolbar(),
        if (_error != null && _jobs.isNotEmpty) ...[
          const SizedBox(height: AdminDensity.space1),
          _buildRefreshErrorNotice(),
        ],
        const SizedBox(height: AdminDensity.space1),
        Expanded(child: _buildListPane()),
      ],
    );
  }
}
