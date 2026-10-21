import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:alumni_system/core/constants/gts_constants.dart';
import 'package:alumni_system/core/services/app_session.dart';
import 'package:alumni_system/features/alumni/profile/data/user_profile_service.dart';
import 'package:alumni_system/features/jobs/data/favorite_job_service.dart';
import 'package:alumni_system/features/jobs/data/job_interest_service.dart';
import 'package:alumni_system/features/jobs/data/job_recommendation.dart';
import 'package:alumni_system/features/jobs/data/job_service.dart';
import 'package:alumni_system/features/jobs/models/job_category_constants.dart';
import 'package:alumni_system/features/jobs/models/job_posting_model.dart';
import 'package:alumni_system/features/jobs/widgets/job_cover_photo.dart';
import 'package:alumni_system/features/jobs/widgets/job_ui.dart';
import 'package:alumni_system/shared/widgets/user/portal_filters.dart';
import 'package:alumni_system/shared/widgets/user/portal_floating.dart';
import 'package:alumni_system/shared/widgets/user/portal_skeletons.dart';
import 'package:alumni_system/shared/widgets/user/portal_breakpoints.dart';
import 'package:alumni_system/shared/widgets/user/portal_states.dart';
import 'package:alumni_system/shared/widgets/user/portal_headers.dart';
import 'package:alumni_system/shared/widgets/user/portal_theme.dart';

class JobPostingScreen extends StatefulWidget {
  const JobPostingScreen({super.key, this.initialJobId});

  final String? initialJobId;

  @override
  State<JobPostingScreen> createState() => JobPostingScreenState();
}

class JobPostingScreenState extends State<JobPostingScreen> {
  final _search = TextEditingController();
  final _jobService = JobService();
  final _favService = FavoriteJobService();
  final _interestService = JobInterestService();

  List<JobPosting> _jobs = [];
  List<JobPosting> _recommended = [];
  Set<String> _favoriteIds = {};
  Set<String> _interestedIds = {};
  Map<String, DateTime> _favoriteDates = {};
  final Set<String> _favoriteBusy = {};
  final Set<String> _interestBusy = {};
  bool _loading = true;
  Object? _loadError;
  String? _alumniCourse;

  /// Profile employment status is Unemployed / Never employed.
  bool _lookingForWork = false;

  /// Never employed or graduated within the last year: entry-level first.
  bool _preferEntryLevel = false;

  /// "Looking for work?" card closed for this app session.
  static bool _lookingForWorkDismissed = false;
  bool _handledInitialJob = false;

  String _category = 'all';
  String _type = 'all';
  String _sort = 'newest';
  bool? _remoteOnly;
  bool _showSavedOnly = false;
  bool _showRecommendedOnly = false;
  int _page = 0;
  static const _pageSize = 20;

  StreamSubscription<List<String>>? _favSub;
  StreamSubscription<List<String>>? _interestSub;

  @override
  void initState() {
    super.initState();
    _favSub = _favService.getFavoriteJobIdsStream().listen((ids) {
      if (mounted) setState(() => _favoriteIds = ids.toSet());
    });
    _interestSub = _interestService.watchMyInterestedJobIds().listen((ids) {
      if (mounted) setState(() => _interestedIds = ids.toSet());
    });
    unawaited(_bootstrap());
  }

  @override
  void dispose() {
    _favSub?.cancel();
    _interestSub?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    try {
      final uid = AppSession.userId;
      if (uid != null) {
        final profile = await UserProfileService().getTracerProfile(uid);
        _alumniCourse = profile?.program;
        final status = profile?.employmentStatus.trim() ?? '';
        final neverEmployed = status == GtsConstants.neverEmployed;
        _lookingForWork = neverEmployed || status == GtsConstants.unemployed;
        final graduated = int.tryParse(profile?.yearGraduated.trim() ?? '');
        _preferEntryLevel =
            neverEmployed ||
            (graduated != null && graduated >= DateTime.now().year - 1);
      }
    } catch (_) {}
    await _load();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _loadError = null;
      });
    }
    try {
      final jobs = await _jobService.getActiveJobs();
      final dates = await _favService.getFavoriteJobDates();
      final rec = JobRecommendation.pick(
        activeJobs: jobs,
        alumniCourse: _alumniCourse,
        preferEntryLevel: _preferEntryLevel,
      );
      if (!mounted) return;
      setState(() {
        _jobs = jobs;
        _recommended = rec;
        _favoriteDates = dates;
        _loading = false;
        _loadError = null;
        if (!silent) _page = 0;
      });
      _openInitialJobIfNeeded();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (!silent) _loadError = e;
      });
    }
  }

  Set<String> get _openJobIds =>
      _jobs.where((j) => j.isActiveForAlumni).map((j) => j.id).toSet();

  /// Saved jobs that are still open (closed/expired/archived ones stay saved
  /// in case they reopen, but aren't counted or listed).
  int get _savedOpenCount {
    final open = _openJobIds;
    return _favoriteIds.where(open.contains).length;
  }

  List<String> get _savedClosedIds {
    if (_loading || _loadError != null) return const [];
    final open = _openJobIds;
    return _favoriteIds.where((id) => !open.contains(id)).toList();
  }

  bool _clearingClosed = false;

  Future<void> _clearClosedSaved() async {
    final ids = _savedClosedIds;
    if (ids.isEmpty || _clearingClosed) return;
    setState(() => _clearingClosed = true);
    try {
      for (final id in ids) {
        await _favService.removeFromFavorites(id);
      }
      if (!mounted) return;
      setState(() {
        _favoriteIds = {..._favoriteIds}..removeAll(ids);
        _favoriteDates = Map<String, DateTime>.from(_favoriteDates)
          ..removeWhere((id, _) => ids.contains(id));
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not clear closed saved jobs')),
        );
      }
    } finally {
      if (mounted) setState(() => _clearingClosed = false);
    }
  }

  List<JobPosting> get _filtered {
    final q = _search.text.trim().toLowerCase();
    var list = List<JobPosting>.from(_jobs);
    if (_showSavedOnly) {
      list = list
          .where((j) => _favoriteIds.contains(j.id) && j.isActiveForAlumni)
          .toList();
    }
    if (_showRecommendedOnly) {
      final ids = _recommended.map((j) => j.id).toSet();
      list = list.where((j) => ids.contains(j.id)).toList();
    }
    list = list.where((j) {
      if (_category != 'all' && j.category != _category) return false;
      if (_type != 'all' && j.jobType != _type) return false;
      if (_remoteOnly == true && !j.isRemote) return false;
      if (_remoteOnly == false && j.isRemote) return false;
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
      case 'salary_high':
        list.sort(
          (a, b) => _salary(b.salaryRange).compareTo(_salary(a.salaryRange)),
        );
      case 'salary_low':
        list.sort(
          (a, b) => _salary(a.salaryRange).compareTo(_salary(b.salaryRange)),
        );
      default:
        list.sort((a, b) => b.postedDate.compareTo(a.postedDate));
    }
    return list;
  }

  double _salary(String raw) {
    final m = RegExp(r'[\d,]+').firstMatch(raw);
    if (m == null) return 0;
    return double.tryParse(m.group(0)!.replaceAll(',', '')) ?? 0;
  }

  List<JobPosting> get _pageItems {
    final all = _filtered;
    final start = _page * _pageSize;
    if (start >= all.length) return const [];
    return all.sublist(start, (start + _pageSize).clamp(0, all.length));
  }

  Future<void> _toggleFavorite(String jobId) async {
    if (_favoriteBusy.contains(jobId)) return;
    final wasFav = _favoriteIds.contains(jobId);
    // Optimistic UI so bookmark feedback is instant.
    setState(() {
      _favoriteBusy.add(jobId);
      if (wasFav) {
        _favoriteIds = {..._favoriteIds}..remove(jobId);
        _favoriteDates = Map<String, DateTime>.from(_favoriteDates)
          ..remove(jobId);
      } else {
        _favoriteIds = {..._favoriteIds, jobId};
        _favoriteDates = {..._favoriteDates, jobId: DateTime.now()};
      }
    });
    try {
      if (wasFav) {
        await _favService.removeFromFavorites(jobId);
      } else {
        await _favService.addToFavorites(jobId);
      }
      final dates = await _favService.getFavoriteJobDates();
      if (mounted) setState(() => _favoriteDates = dates);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (wasFav) {
          _favoriteIds = {..._favoriteIds, jobId};
        } else {
          _favoriteIds = {..._favoriteIds}..remove(jobId);
          _favoriteDates = Map<String, DateTime>.from(_favoriteDates)
            ..remove(jobId);
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update saved job')),
      );
    } finally {
      if (mounted) {
        setState(() => _favoriteBusy.remove(jobId));
      } else {
        _favoriteBusy.remove(jobId);
      }
    }
  }

  Future<void> _toggleInterest(String jobId) async {
    if (_interestBusy.contains(jobId)) return;
    final wasInterested = _interestedIds.contains(jobId);
    final nowInterested = !wasInterested;
    setState(() {
      _interestBusy.add(jobId);
      if (nowInterested) {
        _interestedIds = {..._interestedIds, jobId};
      } else {
        _interestedIds = {..._interestedIds}..remove(jobId);
      }
    });
    try {
      final confirmed = await _interestService.toggleInterest(jobId);
      if (!mounted) return;
      // Server is source of truth if it diverges (rare race).
      if (confirmed != nowInterested) {
        setState(() {
          if (confirmed) {
            _interestedIds = {..._interestedIds, jobId};
          } else {
            _interestedIds = {..._interestedIds}..remove(jobId);
          }
        });
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            confirmed ? 'Interest expressed' : 'Interest withdrawn',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (wasInterested) {
          _interestedIds = {..._interestedIds, jobId};
        } else {
          _interestedIds = {..._interestedIds}..remove(jobId);
        }
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(portalFriendlyError(e))));
    } finally {
      if (mounted) {
        setState(() => _interestBusy.remove(jobId));
      } else {
        _interestBusy.remove(jobId);
      }
    }
  }

  void _openInitialJobIfNeeded() {
    if (_handledInitialJob) return;
    final targetId = widget.initialJobId?.trim();
    if (targetId == null || targetId.isEmpty) return;
    _handledInitialJob = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(openJobById(targetId));
    });
  }

  /// Opens job details by id (used by Home deep-links and initial route).
  Future<void> openJobById(String jobId) async {
    final id = jobId.trim();
    if (id.isEmpty || !mounted) return;

    JobPosting? match;
    for (final j in _jobs) {
      if (j.id == id) {
        match = j;
        break;
      }
    }
    match ??= await _jobService.getJobPosting(id);
    if (!mounted) return;
    if (match == null || !match.isActiveForAlumni) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            match != null && match.isExpiredByDeadline
                ? 'This job posting has expired.'
                : 'This job is no longer available.',
          ),
        ),
      );
      return;
    }

    final exists = _jobs.any((j) => j.id == match!.id);
    if (!exists) {
      setState(() => _jobs = [match!, ..._jobs]);
    }

    await _openDetails(match);
  }

  Future<void> _openDetails(JobPosting job) async {
    unawaited(_jobService.incrementViewCount(job.id));
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.88,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, scroll) => _AlumniJobDetails(
          job: job,
          scrollController: scroll,
          isFavorite: _favoriteIds.contains(job.id),
          isInterested: _interestedIds.contains(job.id),
          onToggleFavorite: () => _toggleFavorite(job.id),
          onToggleInterest: () => _toggleInterest(job.id),
        ),
      ),
    );
    if (mounted) await _load(silent: true);
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final pages = (filtered.length / _pageSize).ceil().clamp(1, 9999);

    return Scaffold(
      backgroundColor: JobUiTheme.pageBg,
      appBar: PortalAppBar(
        title: 'Jobs',
        subtitle: 'Career discovery',
        automaticallyImplyLeading: false,
        actions: [
          PortalHeaderAction(
            icon: _showSavedOnly
                ? Icons.bookmark_rounded
                : Icons.bookmark_border_rounded,
            tooltip: _showSavedOnly ? 'Show all jobs' : 'Saved jobs',
            badgeCount: _savedOpenCount,
            onPressed: () => setState(() {
              _showSavedOnly = !_showSavedOnly;
              _showRecommendedOnly = false;
              _page = 0;
            }),
          ),
          PortalHeaderAction(
            icon: Icons.refresh_rounded,
            tooltip: 'Refresh',
            onPressed: _load,
          ),
        ],
      ),
      body: PortalContentFrame(
        child: RefreshIndicator(
          color: JobUiTheme.navy,
          onRefresh: _load,
          child: CustomScrollView(
            slivers: [
              PortalFloatingFilterHeader(child: _filterCardContent()),
              if (_showSavedOnly && _savedClosedIds.isNotEmpty)
                SliverToBoxAdapter(child: _closedSavedNote()),
              if (!_loading &&
                  !_showSavedOnly &&
                  _recommended.isNotEmpty &&
                  !_showRecommendedOnly)
                SliverToBoxAdapter(
                  child: _lookingForWork && !_lookingForWorkDismissed
                      ? _lookingForWorkSection()
                      : _recommendedSection(),
                ),
              if (_loading)
                const SliverFillRemaining(child: JobListSkeleton())
              else if (_loadError != null)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: PortalErrorState(
                    title: 'Unable to load jobs',
                    error: _loadError,
                    onRetry: _load,
                  ),
                )
              else if (filtered.isEmpty)
                SliverFillRemaining(hasScrollBody: false, child: _emptyState())
              else ...[
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
                  sliver: SliverToBoxAdapter(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'All opportunities',
                                style: PortalTheme.sectionTitle.copyWith(
                                  fontSize: 16,
                                  color: JobUiTheme.navy,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                filtered.length == 1
                                    ? '1 job available'
                                    : '${filtered.length} jobs available',
                                style: PortalTheme.meta.copyWith(
                                  fontSize: 12,
                                  color: JobUiTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                  sliver: SliverList.builder(
                    itemCount: _pageItems.length,
                    itemBuilder: (context, i) {
                      final job = _pageItems[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _AlumniJobCard(
                          job: job,
                          isFavorite: _favoriteIds.contains(job.id),
                          savedAt: _favoriteDates[job.id],
                          onOpen: () => _openDetails(job),
                          onFavorite: () => _toggleFavorite(job.id),
                        ),
                      );
                    },
                  ),
                ),
                if (pages > 1)
                  SliverToBoxAdapter(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          onPressed: _page > 0
                              ? () => setState(() => _page--)
                              : null,
                          icon: const Icon(Icons.chevron_left),
                        ),
                        Text('Page ${_page + 1} / $pages'),
                        IconButton(
                          onPressed: _page < pages - 1
                              ? () => setState(() => _page++)
                              : null,
                          icon: const Icon(Icons.chevron_right),
                        ),
                      ],
                    ),
                  ),
              ],
              SliverToBoxAdapter(
                child: SizedBox(
                  height: PortalFloating.bottomClearance(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _closedSavedNote() {
    final count = _savedClosedIds.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
        decoration: BoxDecoration(
          color: JobUiTheme.surfaceMuted,
          borderRadius: BorderRadius.circular(JobUiTheme.radiusLg),
          border: Border.all(color: JobUiTheme.border),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.info_outline_rounded,
              size: 18,
              color: JobUiTheme.textSecondary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                count == 1
                    ? '1 saved job is no longer open'
                    : '$count saved jobs are no longer open',
                style: PortalTheme.meta.copyWith(
                  color: JobUiTheme.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            TextButton(
              onPressed: _clearingClosed ? null : _clearClosedSaved,
              style: PortalTheme.ghostButton(dense: true),
              child: Text(_clearingClosed ? 'Clearing…' : 'Clear'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterCardContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PortalSearchField(
          controller: _search,
          onChanged: (_) => setState(() => _page = 0),
          hintText: 'Search title, company, or location…',
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: PortalFilterChip.height,
          width: double.infinity,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.hardEdge,
            child: Row(
              children: [
                PortalFilterChip(
                  label: 'Recommended',
                  icon: Icons.auto_awesome_rounded,
                  selected: _showRecommendedOnly,
                  onTap: () => setState(() {
                    _showRecommendedOnly = !_showRecommendedOnly;
                    _showSavedOnly = false;
                    _page = 0;
                  }),
                ),
                const SizedBox(width: 8),
                _dropdownChip(
                  value: _category,
                  items: [
                    ('all', 'Category'),
                    ...JobCategoryConstants.all.map((c) => (c, c)),
                  ],
                  onChanged: (v) => setState(() {
                    _category = v;
                    _page = 0;
                  }),
                ),
                const SizedBox(width: 8),
                _dropdownChip(
                  value: _type,
                  items: [
                    ('all', 'Type'),
                    ...JobCategoryConstants.jobTypes.map((c) => (c, c)),
                  ],
                  onChanged: (v) => setState(() {
                    _type = v;
                    _page = 0;
                  }),
                ),
                const SizedBox(width: 8),
                PortalFilterChip(
                  label: 'Remote',
                  icon: Icons.home_work_outlined,
                  selected: _remoteOnly == true,
                  onTap: () => setState(() {
                    _remoteOnly = _remoteOnly == true ? null : true;
                    _page = 0;
                  }),
                ),
                const SizedBox(width: 8),
                _dropdownChip(
                  value: _sort,
                  icon: Icons.swap_vert_rounded,
                  items: const [
                    ('newest', 'Newest'),
                    ('oldest', 'Oldest'),
                    ('deadline', 'Deadline'),
                    ('salary_high', 'Salary ↓'),
                    ('salary_low', 'Salary ↑'),
                  ],
                  onChanged: (v) => setState(() {
                    _sort = v;
                    _page = 0;
                  }),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _dropdownChip({
    required String value,
    required List<(String, String)> items,
    required ValueChanged<String> onChanged,
    IconData? icon,
  }) {
    return PortalDropdownChip<String>(
      value: value,
      items: items,
      onChanged: onChanged,
      icon: icon,
      selected: value != 'all' && value != 'newest',
    );
  }

  /// Highlighted recommendations for alumni whose profile says they are not
  /// currently employed.
  Widget _lookingForWorkSection() {
    final count = _recommended.length.clamp(0, 8);
    final matched = !JobRecommendation.usedFallback(
      activeJobs: _jobs,
      alumniCourse: _alumniCourse,
    );
    final program = _alumniCourse?.trim() ?? '';
    final subtitle = StringBuffer(
      matched && program.isNotEmpty
          ? 'Here are openings for $program alumni'
          : 'Here are the latest openings to get you started',
    )..write(_preferEntryLevel ? ', entry-level roles first.' : '.');

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 6, 10),
        decoration: BoxDecoration(
          gradient: PortalTheme.heroGradient,
          borderRadius: BorderRadius.circular(JobUiTheme.radius2xl),
          boxShadow: JobUiTheme.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: JobUiTheme.gold.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.work_outline_rounded,
                    color: JobUiTheme.gold,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Looking for work?',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle.toString(),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.82),
                          fontSize: 13,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Hide',
                  visualDensity: VisualDensity.compact,
                  color: Colors.white.withValues(alpha: 0.7),
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () =>
                      setState(() => _lookingForWorkDismissed = true),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 86,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(right: 10),
                itemCount: count,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, i) {
                  final job = _recommended[i];
                  return _RecommendedMiniCard(
                    job: job,
                    onTap: () => _openDetails(job),
                  );
                },
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Shown because your profile says you are not currently '
                    'employed.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 11.5,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() {
                    _showRecommendedOnly = true;
                    _showSavedOnly = false;
                    _page = 0;
                  }),
                  style: TextButton.styleFrom(
                    foregroundColor: JobUiTheme.gold,
                    textStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  child: const Text('See all'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _recommendedSection() {
    final count = _recommended.length.clamp(0, 8);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 0, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Text(
              'Recommended for you',
              style: PortalTheme.sectionTitle.copyWith(
                fontSize: 15,
                color: JobUiTheme.navy,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 86,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(right: 16),
              itemCount: count,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, i) {
                final job = _recommended[i];
                return _RecommendedMiniCard(
                  job: job,
                  onTap: () => _openDetails(job),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    final saved = _showSavedOnly;
    final searching = _search.text.trim().isNotEmpty;
    final filtered =
        _category != 'all' ||
        _type != 'all' ||
        _remoteOnly == true ||
        _showRecommendedOnly;
    return PortalEmptyState(
      icon: saved
          ? Icons.bookmark_border_rounded
          : searching
          ? Icons.search_off_rounded
          : Icons.work_off_outlined,
      title: saved
          ? 'No saved jobs yet'
          : searching
          ? 'No jobs found'
          : filtered
          ? 'No opportunities match your filters'
          : 'No openings right now',
      subtitle: saved
          ? 'Bookmark jobs to find them here later.'
          : searching
          ? 'Try a different title, company, or location.'
          : filtered
          ? 'Clear filters to see more openings.'
          : 'New alumni job postings will appear here.',
      actionLabel: (searching || filtered) && !saved ? 'Clear filters' : null,
      onAction: (searching || filtered) && !saved
          ? () => setState(() {
              _search.clear();
              _category = 'all';
              _type = 'all';
              _remoteOnly = null;
              _showRecommendedOnly = false;
              _sort = 'newest';
              _page = 0;
            })
          : null,
    );
  }
}

class _RecommendedMiniCard extends StatelessWidget {
  const _RecommendedMiniCard({required this.job, required this.onTap});

  final JobPosting job;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 228,
      child: JobCardShell(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          children: [
            JobCompanyLogo(job: job, size: 44, radius: 12),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    job.companyName.trim().isEmpty
                        ? 'Company'
                        : job.companyName.trim(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: PortalTheme.meta.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: JobUiTheme.navy,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    job.jobTitle.isEmpty ? 'Open role' : job.jobTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: PortalTheme.cardTitle.copyWith(
                      fontSize: 13.5,
                      height: 1.2,
                      color: JobUiTheme.navy,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AlumniJobCard extends StatelessWidget {
  const _AlumniJobCard({
    required this.job,
    required this.isFavorite,
    required this.onOpen,
    required this.onFavorite,
    this.savedAt,
  });

  final JobPosting job;
  final bool isFavorite;
  final VoidCallback onOpen;
  final VoidCallback onFavorite;
  final DateTime? savedAt;

  static const Color _salaryGreen = PortalTheme.success;
  static const Color _levelOrange = PortalTheme.ember;

  @override
  Widget build(BuildContext context) {
    final salary = formatJobSalaryPhp(job.salaryRange);
    final experience = job.experienceLevel.trim();
    final company = job.companyName.trim().isEmpty
        ? 'Company'
        : job.companyName.trim();
    final title = job.jobTitle.isEmpty ? 'Open role' : job.jobTitle;
    final deadlineHint = jobDeadlineHint(job.applicationDeadline);

    return JobCardShell(
      onTap: onOpen,
      padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              JobCompanyLogo(job: job, size: 52, radius: 14),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      company,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: PortalTheme.meta.copyWith(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: JobUiTheme.navy,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: PortalTheme.cardTitle.copyWith(
                        fontSize: 17,
                        height: 1.22,
                        fontWeight: FontWeight.w800,
                        color: JobUiTheme.navy,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      jobPostedShort(job.postedDate),
                      style: PortalTheme.caption.copyWith(
                        color: JobUiTheme.textMuted,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: isFavorite ? 'Remove saved' : 'Save job',
                onPressed: onFavorite,
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                icon: Icon(
                  isFavorite
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                  color: isFavorite ? JobUiTheme.navy : JobUiTheme.textMuted,
                  size: 24,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          JobMetaRow(
            location: job.location,
            jobType: job.jobType,
            posted: '',
            isRemote: job.isRemote,
          ),
          if (salary.isNotEmpty ||
              experience.isNotEmpty ||
              deadlineHint != null) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                if (salary.isNotEmpty)
                  Flexible(
                    child: Text(
                      salary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _salaryGreen,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                  ),
                if (salary.isNotEmpty && experience.isNotEmpty)
                  const SizedBox(width: 14),
                if (experience.isNotEmpty)
                  Flexible(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.trending_up_rounded,
                          size: 15,
                          color: _levelOrange,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            experience,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _levelOrange,
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (deadlineHint != null) ...[
                  const Spacer(),
                  Text(
                    deadlineHint,
                    style: PortalTheme.caption.copyWith(
                      color: deadlineHint == 'Application closed'
                          ? JobUiTheme.danger
                          : PortalTheme.warning,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ],
          if (savedAt != null) ...[
            const SizedBox(height: 8),
            Text(
              'Saved ${DateFormat.MMMd().format(savedAt!)}',
              style: PortalTheme.caption.copyWith(color: JobUiTheme.textMuted),
            ),
          ],
        ],
      ),
    );
  }
}

class _AlumniJobDetails extends StatefulWidget {
  const _AlumniJobDetails({
    required this.job,
    required this.scrollController,
    required this.isFavorite,
    required this.isInterested,
    required this.onToggleFavorite,
    required this.onToggleInterest,
  });

  final JobPosting job;
  final ScrollController scrollController;
  final bool isFavorite;
  final bool isInterested;
  final VoidCallback onToggleFavorite;
  final VoidCallback onToggleInterest;

  @override
  State<_AlumniJobDetails> createState() => _AlumniJobDetailsState();
}

class _AlumniJobDetailsState extends State<_AlumniJobDetails> {
  late bool _favorite = widget.isFavorite;
  late bool _interested = widget.isInterested;
  bool _applyBusy = false;

  JobPosting get job => widget.job;
  bool get _hasApplyUrl => job.applicationUrl.trim().isNotEmpty;

  @override
  void didUpdateWidget(covariant _AlumniJobDetails oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isFavorite != widget.isFavorite) {
      _favorite = widget.isFavorite;
    }
    if (oldWidget.isInterested != widget.isInterested) {
      _interested = widget.isInterested;
    }
  }

  Future<void> _onFavorite() async {
    setState(() => _favorite = !_favorite);
    widget.onToggleFavorite();
  }

  Future<void> _onInterest() async {
    setState(() => _interested = !_interested);
    widget.onToggleInterest();
  }

  Future<void> _applyNow() async {
    final url = job.applicationUrl.trim();
    if (url.isEmpty || _applyBusy) return;
    setState(() => _applyBusy = true);
    try {
      final ok = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (!mounted) return;
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open the application link')),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the application link')),
      );
    } finally {
      if (mounted) setState(() => _applyBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final deadlineHint = jobDeadlineHint(job.applicationDeadline);
    final locationLabel = job.location.trim().isEmpty
        ? (job.isRemote ? 'Remote' : '')
        : job.location.trim();

    return Material(
      color: PortalTheme.card,
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(PortalTheme.radius2xl),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Expanded(
            child: ListView(
              controller: widget.scrollController,
              padding: EdgeInsets.zero,
              children: [
                if (job.hasCoverImage)
                  JobCoverPhoto(
                    job: job,
                    overlay: Center(
                      child: Container(
                        margin: const EdgeInsets.only(top: 10),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(999),
                          boxShadow: const [
                            BoxShadow(color: Colors.black26, blurRadius: 4),
                          ],
                        ),
                      ),
                    ),
                  ),
                Container(
                  width: double.infinity,
                  color: PortalTheme.surfaceMuted,
                  child: Column(
                    children: [
                      if (!job.hasCoverImage) ...[
                        const SizedBox(height: 10),
                        Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: PortalTheme.borderStrong,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ],
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(
                                  JobUiTheme.radiusLg,
                                ),
                                border: Border.all(color: PortalTheme.border),
                              ),
                              child: JobCompanyLogo(
                                job: job,
                                size: 56,
                                radius: 11,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    job.jobTitle.isEmpty
                                        ? 'Open role'
                                        : job.jobTitle,
                                    style: const TextStyle(
                                      color: PortalTheme.navy,
                                      fontSize: 21,
                                      fontWeight: FontWeight.w800,
                                      height: 1.2,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    job.companyName,
                                    style: const TextStyle(
                                      color: PortalTheme.textPrimary,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  if (locationLabel.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.place_outlined,
                                          size: 14,
                                          color: PortalTheme.textSecondary,
                                        ),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            locationLabel,
                                            style: const TextStyle(
                                              color: PortalTheme.textSecondary,
                                              fontSize: 12.5,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: [
                                      if (job.jobType.isNotEmpty)
                                        JobHeaderPill(label: job.jobType),
                                      if (job.isRemote)
                                        const JobHeaderPill(label: 'Remote'),
                                      if (job.category.isNotEmpty)
                                        JobHeaderPill(label: job.category),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    jobPostedAgo(job.postedDate),
                                    style: const TextStyle(
                                      color: PortalTheme.textSecondary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (deadlineHint != null) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: deadlineHint == 'Application closed'
                                ? JobUiTheme.danger.withValues(alpha: 0.08)
                                : PortalTheme.warning.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(
                              JobUiTheme.radiusXl,
                            ),
                            border: Border.all(
                              color: deadlineHint == 'Application closed'
                                  ? JobUiTheme.danger.withValues(alpha: 0.25)
                                  : PortalTheme.warning.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                deadlineHint == 'Application closed'
                                    ? Icons.event_busy_outlined
                                    : Icons.schedule_rounded,
                                size: 18,
                                color: deadlineHint == 'Application closed'
                                    ? JobUiTheme.danger
                                    : PortalTheme.warning,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  deadlineHint == 'Application closed'
                                      ? 'Application closed'
                                      : 'Application deadline · $deadlineHint',
                                  style: PortalTheme.meta.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: deadlineHint == 'Application closed'
                                        ? JobUiTheme.danger
                                        : PortalTheme.warning,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      Text(
                        'Key details',
                        style: PortalTheme.sectionTitle.copyWith(
                          fontSize: 15,
                          color: JobUiTheme.navy,
                        ),
                      ),
                      const SizedBox(height: 10),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final cellW = (constraints.maxWidth - 10) / 2;
                          final cells = <Widget>[
                            if (job.jobType.isNotEmpty)
                              SizedBox(
                                width: cellW,
                                child: JobOverviewCell(
                                  icon: Icons.work_outline_rounded,
                                  label: 'Type',
                                  value: job.jobType,
                                ),
                              ),
                            if (job.experienceLevel.trim().isNotEmpty)
                              SizedBox(
                                width: cellW,
                                child: JobOverviewCell(
                                  icon: Icons.trending_up_rounded,
                                  label: 'Experience',
                                  value: job.experienceLevel,
                                ),
                              ),
                            if (locationLabel.isNotEmpty)
                              SizedBox(
                                width: cellW,
                                child: JobOverviewCell(
                                  icon: Icons.location_on_outlined,
                                  label: 'Location',
                                  value: locationLabel,
                                ),
                              ),
                            if (job.salaryRange.trim().isNotEmpty)
                              SizedBox(
                                width: cellW,
                                child: JobOverviewCell(
                                  icon: Icons.payments_outlined,
                                  label: 'Salary',
                                  value: formatJobSalaryPhp(job.salaryRange),
                                ),
                              ),
                            SizedBox(
                              width: cellW,
                              child: JobOverviewCell(
                                icon: Icons.event_outlined,
                                label: 'Deadline',
                                value: DateFormat.yMMMd().format(
                                  job.applicationDeadline,
                                ),
                              ),
                            ),
                            SizedBox(
                              width: cellW,
                              child: JobOverviewCell(
                                icon: Icons.schedule_rounded,
                                label: 'Posted',
                                value: DateFormat.yMMMd().format(
                                  job.postedDate,
                                ),
                              ),
                            ),
                          ];
                          return Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: cells,
                          );
                        },
                      ),
                      const SizedBox(height: 22),
                      _sectionTitle('Description'),
                      const SizedBox(height: 8),
                      Text(
                        job.description.isEmpty
                            ? 'No description provided.'
                            : job.description,
                        style: PortalTheme.body.copyWith(
                          height: 1.55,
                          fontSize: 14,
                          color: JobUiTheme.textPrimary.withValues(alpha: 0.88),
                        ),
                      ),
                      if (job.requirements.isNotEmpty) ...[
                        const SizedBox(height: 22),
                        _sectionTitle('Requirements'),
                        const SizedBox(height: 10),
                        ...job.requirements.map(
                          (e) => _bulletRow(
                            e,
                            Icons.check_circle_rounded,
                            JobUiTheme.navy,
                          ),
                        ),
                      ],
                      if (job.benefits.isNotEmpty) ...[
                        const SizedBox(height: 22),
                        _sectionTitle('Benefits'),
                        const SizedBox(height: 10),
                        ...job.benefits.map(
                          (e) => _bulletRow(
                            e,
                            Icons.redeem_rounded,
                            JobUiTheme.gold,
                          ),
                        ),
                      ],
                      const SizedBox(height: 22),
                      _sectionTitle('Contact'),
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: JobUiTheme.card,
                          borderRadius: BorderRadius.circular(
                            JobUiTheme.radius2xl,
                          ),
                          border: Border.all(
                            color: JobUiTheme.border.withValues(alpha: 0.75),
                          ),
                          boxShadow: JobUiTheme.cardShadow,
                        ),
                        child: job.contactEmail.isEmpty
                            ? Text(
                                'No contact email listed',
                                style: PortalTheme.bodySecondary,
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    job.contactEmail,
                                    style: PortalTheme.body.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: JobUiTheme.navy,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          onPressed: () async {
                                            await Clipboard.setData(
                                              ClipboardData(
                                                text: job.contactEmail,
                                              ),
                                            );
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                const SnackBar(
                                                  content: Text('Email copied'),
                                                ),
                                              );
                                            }
                                          },
                                          icon: const Icon(
                                            Icons.copy_rounded,
                                            size: 16,
                                          ),
                                          label: const Text('Copy Email'),
                                          style: PortalTheme.secondaryButton(),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: FilledButton.icon(
                                          onPressed: () => launchUrl(
                                            Uri.parse(
                                              'mailto:${job.contactEmail}',
                                            ),
                                          ),
                                          icon: const Icon(
                                            Icons.mail_outline_rounded,
                                            size: 16,
                                          ),
                                          label: const Text('Send Email'),
                                          style: PortalTheme.primaryButton(),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                      ),
                      const SizedBox(height: 28),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.fromLTRB(
              16,
              12,
              16,
              12 + MediaQuery.paddingOf(context).bottom,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(
                  color: JobUiTheme.border.withValues(alpha: 0.95),
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: JobUiTheme.navy.withValues(alpha: 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final narrow = constraints.maxWidth < 420;
                final bookmark = Material(
                  color: _favorite
                      ? JobUiTheme.navy.withValues(alpha: 0.1)
                      : JobUiTheme.surfaceMuted,
                  borderRadius: BorderRadius.circular(JobUiTheme.radiusMd),
                  child: InkWell(
                    onTap: _onFavorite,
                    borderRadius: BorderRadius.circular(JobUiTheme.radiusMd),
                    child: SizedBox(
                      width: 48,
                      height: 48,
                      child: Icon(
                        _favorite
                            ? Icons.bookmark_rounded
                            : Icons.bookmark_border_rounded,
                        color: _favorite
                            ? JobUiTheme.navy
                            : JobUiTheme.textSecondary,
                      ),
                    ),
                  ),
                );
                final interestAction = SizedBox(
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: _onInterest,
                    icon: Icon(
                      _interested
                          ? Icons.star_rounded
                          : Icons.star_border_rounded,
                      size: 18,
                    ),
                    label: Text(
                      _interested ? 'Interested' : 'Express Interest',
                    ),
                    style: PortalTheme.secondaryButton().copyWith(
                      backgroundColor: WidgetStatePropertyAll(
                        _interested
                            ? JobUiTheme.navy.withValues(alpha: 0.08)
                            : Colors.white,
                      ),
                      side: WidgetStatePropertyAll(
                        BorderSide(
                          color: _interested
                              ? JobUiTheme.navy.withValues(alpha: 0.45)
                              : JobUiTheme.border,
                          width: _interested ? 1.4 : 1,
                        ),
                      ),
                    ),
                  ),
                );
                final apply = SizedBox(
                  height: 48,
                  child: FilledButton(
                    onPressed: _applyBusy ? null : _applyNow,
                    style: PortalTheme.primaryButton(),
                    child: _applyBusy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Apply Now',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                  ),
                );

                if (_hasApplyUrl) {
                  if (narrow) {
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            bookmark,
                            const SizedBox(width: 10),
                            Expanded(child: apply),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SizedBox(width: double.infinity, child: interestAction),
                      ],
                    );
                  }
                  return Row(
                    children: [
                      bookmark,
                      const SizedBox(width: 10),
                      Expanded(child: interestAction),
                      const SizedBox(width: 10),
                      Expanded(child: apply),
                    ],
                  );
                }

                return Row(
                  children: [
                    bookmark,
                    const SizedBox(width: 10),
                    Expanded(child: interestAction),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: PortalTheme.sectionTitle.copyWith(
        fontSize: 15,
        color: JobUiTheme.navy,
      ),
    );
  }

  Widget _bulletRow(String text, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 17, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: PortalTheme.body.copyWith(
                height: 1.45,
                fontSize: 14,
                color: JobUiTheme.textPrimary.withValues(alpha: 0.88),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
