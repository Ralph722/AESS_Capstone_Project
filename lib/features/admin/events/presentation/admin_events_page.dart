import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:alumni_system/features/admin/events/presentation/admin_event_detail_panel.dart';
import 'package:alumni_system/features/admin/events/presentation/admin_event_editor_dialog.dart';
import 'package:alumni_system/features/events/data/event_rsvp_service.dart';
import 'package:alumni_system/features/events/data/event_service.dart';
import 'package:alumni_system/features/events/models/event_model.dart';
import 'package:alumni_system/features/events/models/event_rsvp_model.dart';
import 'package:alumni_system/features/events/widgets/events_month_calendar.dart';
import 'package:alumni_system/core/constants/event_category_constants.dart';
import 'package:alumni_system/features/admin/events/widgets/admin_event_ui.dart';
import 'package:alumni_system/features/share/share_link_sheet.dart';
import 'package:alumni_system/features/share/shareable_content.dart';
import 'package:alumni_system/features/admin/roster/widgets/alumni_directory_ui.dart';
import 'package:alumni_system/shared/widgets/admin/admin_badge.dart';
import 'package:alumni_system/shared/widgets/admin/admin_buttons.dart';
import 'package:alumni_system/shared/widgets/admin/admin_compact_header.dart';
import 'package:alumni_system/shared/widgets/admin/admin_confirm_dialog.dart';
import 'package:alumni_system/shared/widgets/admin/admin_density.dart';
import 'package:alumni_system/shared/widgets/admin/admin_metric_ribbon.dart';
import 'package:alumni_system/shared/widgets/admin/admin_saas_tabs.dart';
import 'package:alumni_system/shared/widgets/admin/admin_saas_toolbar.dart';
import 'package:alumni_system/shared/widgets/admin/admin_skeletons.dart';
import 'package:alumni_system/shared/widgets/admin/admin_state_view.dart';
import 'package:alumni_system/shared/widgets/admin/admin_theme.dart';

enum _EventSort { soonest, newestAdded, mostGoing, titleAsc }

class AdminEventsScreen extends StatefulWidget {
  const AdminEventsScreen({
    super.key,
    this.eventService,
    this.rsvpService,
    this.enableLiveUpdates = true,
  });

  final EventService? eventService;
  final EventRsvpService? rsvpService;
  final bool enableLiveUpdates;

  @override
  State<AdminEventsScreen> createState() => _AdminEventsScreenState();
}

class _AdminEventsScreenState extends State<AdminEventsScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  late final EventService _eventService = widget.eventService ?? EventService();
  late final EventRsvpService _rsvpService =
      widget.rsvpService ?? EventRsvpService();
  final _searchController = TextEditingController();
  final _supabase = Supabase.instance.client;

  List<AlumniEvent> _active = [];
  List<AlumniEvent> _filtered = [];
  Map<String, EventRsvpCounts> _counts = {};
  bool _loading = false;
  bool _hasLoaded = false;
  String? _loadError;
  String? _loadErrorDetails;
  bool _showCalendar = false;
  String? _batchYear;
  String? _venue;
  String? _category;
  DateTime? _from;
  DateTime? _to;
  String _search = '';
  int _quickFilter = 0; // 0 all, 1 this week (7d), 2 next 3 days
  _EventSort _sort = _EventSort.soonest;
  DateTime _calendarMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime? _selectedCalendarDay;

  StreamSubscription<dynamic>? _eventsSub;
  StreamSubscription<dynamic>? _rsvpSub;
  Timer? _livePoller;
  bool _reloadInFlight = false;
  bool _pendingReload = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _load(showSpinner: true);
      if (widget.enableLiveUpdates) {
        _startLiveUpdates();
      }
    });
  }

  @override
  void dispose() {
    _eventsSub?.cancel();
    _rsvpSub?.cancel();
    _livePoller?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _startLiveUpdates() {
    Future<void> softReload() => _load(showSpinner: false);

    void startPolling() {
      _livePoller?.cancel();
      _livePoller = Timer.periodic(
        const Duration(seconds: 8),
        (_) => softReload(),
      );
    }

    try {
      _eventsSub = _supabase
          .from('events')
          .stream(primaryKey: ['id'])
          .listen((_) => softReload(), onError: (_) => startPolling());
      _rsvpSub = _supabase
          .from('event_rsvps')
          .stream(primaryKey: ['id'])
          .listen((_) => softReload(), onError: (_) => startPolling());
    } catch (_) {
      startPolling();
    }
  }

  Future<void> _load({bool showSpinner = true}) async {
    if (_reloadInFlight) {
      _pendingReload = true;
      return;
    }
    _reloadInFlight = true;
    if (showSpinner && mounted) setState(() => _loading = true);
    try {
      final events = await _eventService.getActiveEvents(runAutoArchive: false);
      final counts = await _rsvpService.getCountsForEvents(
        events.map((e) => e.id).toList(),
      );
      if (!mounted) return;
      setState(() {
        _active = events;
        _counts = counts;
        _loading = false;
        _hasLoaded = true;
        _loadError = null;
        _loadErrorDetails = null;
      });
      _applyFilters();
    } catch (e) {
      if (!mounted) return;
      final friendly = eventFriendlyError(
        e,
        'Check your connection and try again.',
      );
      setState(() {
        _loading = false;
        _loadError = friendly;
        _loadErrorDetails = '$e';
      });
      if (showSpinner && _hasLoaded) {
        _showSnack(friendly, isError: true);
      }
    } finally {
      _reloadInFlight = false;
      if (_pendingReload && mounted) {
        _pendingReload = false;
        unawaited(_load(showSpinner: false));
      }
    }
  }

  void _showSnack(String message, {bool isError = false, SnackBarAction? action}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AdminColors.danger : null,
        action: action,
      ),
    );
  }

  void _applyFilters() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    var results = List<AlumniEvent>.from(_active);

    switch (_quickFilter) {
      case 1:
        final weekEnd = today.add(const Duration(days: 7));
        results = results.where((e) {
          final d = DateTime(e.date.year, e.date.month, e.date.day);
          return !d.isBefore(today) && d.isBefore(weekEnd);
        }).toList();
      case 2:
        final soonEnd = today.add(const Duration(days: 3));
        results = results.where((e) {
          final d = DateTime(e.date.year, e.date.month, e.date.day);
          return !d.isBefore(today) && !d.isAfter(soonEnd);
        }).toList();
    }

    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      results = results
          .where(
            (e) =>
                e.theme.toLowerCase().contains(q) ||
                e.batchYear.contains(q) ||
                e.venue.toLowerCase().contains(q) ||
                e.category.toLowerCase().contains(q) ||
                e.description.toLowerCase().contains(q),
          )
          .toList();
    }
    if (_batchYear != null) {
      results = results.where((e) => e.batchYear == _batchYear).toList();
    }
    if (_venue != null) {
      results = results
          .where((e) => e.venue.toLowerCase().contains(_venue!.toLowerCase()))
          .toList();
    }
    if (_category != null) {
      results = results.where((e) => e.category == _category).toList();
    }
    if (_from != null) {
      final start = DateTime(_from!.year, _from!.month, _from!.day);
      results = results.where((e) {
        final d = DateTime(e.date.year, e.date.month, e.date.day);
        return !d.isBefore(start);
      }).toList();
    }
    if (_to != null) {
      final end = DateTime(_to!.year, _to!.month, _to!.day);
      results = results.where((e) {
        final d = DateTime(e.date.year, e.date.month, e.date.day);
        return !d.isAfter(end);
      }).toList();
    }

    switch (_sort) {
      case _EventSort.soonest:
        results.sort((a, b) => a.date.compareTo(b.date));
      case _EventSort.newestAdded:
        results.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      case _EventSort.mostGoing:
        results.sort((a, b) {
          final byGoing = (_counts[b.id]?.going ?? 0).compareTo(
            _counts[a.id]?.going ?? 0,
          );
          return byGoing != 0 ? byGoing : a.date.compareTo(b.date);
        });
      case _EventSort.titleAsc:
        results.sort(
          (a, b) => a.theme.toLowerCase().compareTo(b.theme.toLowerCase()),
        );
    }

    setState(() => _filtered = results);
  }

  bool get _hasAdvancedFilters =>
      _batchYear != null ||
      _venue != null ||
      _category != null ||
      _from != null ||
      _to != null;

  bool get _hasAnyFilters =>
      _hasAdvancedFilters ||
      _search.isNotEmpty ||
      _quickFilter != 0 ||
      _sort != _EventSort.soonest;

  void _clearFilters() {
    setState(() {
      _batchYear = null;
      _venue = null;
      _category = null;
      _from = null;
      _to = null;
      _search = '';
      _quickFilter = 0;
      _sort = _EventSort.soonest;
      _searchController.clear();
      _selectedCalendarDay = null;
    });
    _applyFilters();
  }

  Future<void> _openEditor({AlumniEvent? event, DateTime? initialDate}) async {
    final saved = await showAdminEventEditorDialog(
      context: context,
      event: event,
      initialDate: initialDate,
    );
    if (saved == true) await _load();
  }

  Future<void> _openDetails(AlumniEvent event) {
    return showAdminEventDetail(
      context: context,
      event: event,
      onChanged: _load,
      initialCounts: _counts[event.id],
    );
  }

  Future<void> _archive(AlumniEvent event) async {
    final ok = await showAdminConfirmDialog(
      context,
      title: 'Archive event?',
      message: '“${event.theme}” will move to Archives. You can restore it later.',
      confirmLabel: 'Archive',
      icon: Icons.archive_outlined,
    );
    if (!ok) return;
    try {
      await _eventService.archiveEvent(event.id);
      if (!mounted) return;
      _showSnack(
        'Event archived',
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () async {
            await _eventService.restoreEvent(event.id);
            await _load();
          },
        ),
      );
      await _load();
    } catch (e) {
      _showSnack(
        eventFriendlyError(e, "Couldn't archive the event. Please try again."),
        isError: true,
      );
    }
  }

  Future<void> _delete(AlumniEvent event) async {
    final ok = await showAdminConfirmDialog(
      context,
      title: 'Delete event?',
      message:
          'This permanently deletes “${event.theme}” along with its RSVPs and comments.',
      confirmLabel: 'Delete',
      destructive: true,
      icon: Icons.delete_outline_rounded,
    );
    if (!ok) return;
    try {
      await _eventService.deleteEvent(event.id);
      _showSnack('Event deleted');
      await _load();
    } catch (e) {
      _showSnack(
        eventFriendlyError(e, "Couldn't delete the event. Please try again."),
        isError: true,
      );
    }
  }

  Future<void> _cancel(AlumniEvent event) async {
    final ok = await showAdminConfirmDialog(
      context,
      title: 'Cancel event?',
      message: 'Alumni will be notified that “${event.theme}” is cancelled.',
      confirmLabel: 'Cancel event',
      destructive: true,
      icon: Icons.event_busy_outlined,
    );
    if (!ok) return;
    try {
      // Alumni are notified by the events table trigger.
      await _eventService.cancelEvent(event.id);
      _showSnack('Event cancelled');
      await _load();
    } catch (e) {
      _showSnack(
        eventFriendlyError(e, "Couldn't cancel the event. Please try again."),
        isError: true,
      );
    }
  }

  int get _soonCount {
    final today = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    return _active.where((e) {
      final d = DateTime(e.date.year, e.date.month, e.date.day);
      final days = d.difference(today).inDays;
      return days >= 0 && days <= 7;
    }).length;
  }

  int get _totalGoing => _counts.values.fold<int>(0, (sum, c) => sum + c.going);

  int get _totalComments => _active.fold<int>(0, (sum, e) => sum + e.comments);

  String _sortLabel(_EventSort s) => switch (s) {
    _EventSort.soonest => 'Soonest event',
    _EventSort.newestAdded => 'Newest added',
    _EventSort.mostGoing => 'Most going',
    _EventSort.titleAsc => 'Title A–Z',
  };

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AdminCompactHeader(
          title: 'Events',
          actions: [
            OutlinedButton.icon(
              onPressed: _loading ? null : () => _load(showSpinner: true),
              icon: _loading
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh_rounded, size: 15),
              label: Text(_loading ? 'Refreshing…' : 'Refresh'),
              style: AdminButtonStyles.outlined(),
            ),
            FilledButton.icon(
              onPressed: () => _openEditor(),
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('New Event'),
              style: AdminButtonStyles.filled(),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: AdminSaaSTabs(
            tabs: [
              AdminSaaSTabSpec(
                label: 'List',
                icon: Icons.view_agenda_outlined,
                count: _hasLoaded && _filtered.isNotEmpty
                    ? _filtered.length
                    : null,
                isSelected: !_showCalendar,
                onTap: () => setState(() => _showCalendar = false),
              ),
              AdminSaaSTabSpec(
                label: 'Calendar',
                icon: Icons.calendar_month_outlined,
                isSelected: _showCalendar,
                onTap: () => setState(() => _showCalendar = true),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _buildMetrics(),
        const SizedBox(height: 10),
        _buildToolbar(),
        if (_hasLoaded && _loadError != null) ...[
          const SizedBox(height: AdminEventTheme.space1),
          _buildRefreshErrorNotice(),
        ],
        const SizedBox(height: 8),
        Expanded(child: _buildBody()),
      ],
    );
  }

  Widget _buildBody() {
    if (!_hasLoaded && _loadError != null && !_loading) {
      return AdminStateView.error(
        title: "Couldn't load events",
        message: _loadError,
        details: _loadErrorDetails,
        onRetry: () => _load(showSpinner: true),
      );
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: _loading && _filtered.isEmpty
          ? const AdminEventsListSkeleton()
          : _showCalendar
          ? _calendarView()
          : _filtered.isEmpty
          ? _empty()
          : _listView(),
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
              "Couldn't refresh events. Showing the last loaded list.",
              style: TextStyle(fontSize: 13, color: AdminColors.textPrimary),
            ),
          ),
          TextButton(
            onPressed: _loading ? null : () => _load(showSpinner: true),
            child: const Text('Try again'),
          ),
        ],
      ),
    );
  }

  Widget _buildMetrics() {
    return AdminMetricRibbon(
      items: [
        AdminMetricRibbonItem(
          label: 'Active events',
          value: '${_active.length}',
          icon: Icons.event_available_rounded,
          color: AdminColors.primary,
          tooltip: 'Events on the live calendar — click to show all dates',
          onTap: () {
            setState(() {
              _quickFilter = 0;
              _from = null;
              _to = null;
            });
            _applyFilters();
          },
        ),
        AdminMetricRibbonItem(
          label: 'Coming this week',
          value: '$_soonCount',
          icon: Icons.schedule_rounded,
          color: AdminColors.warning,
          isSelected: _quickFilter == 1,
          tooltip: 'Events happening in the next 7 days — click to filter',
          onTap: () {
            setState(() => _quickFilter = _quickFilter == 1 ? 0 : 1);
            _applyFilters();
          },
        ),
        AdminMetricRibbonItem(
          label: 'Going responses',
          value: '$_totalGoing',
          icon: Icons.check_circle_outline_rounded,
          color: AdminColors.success,
          isSelected: _sort == _EventSort.mostGoing,
          tooltip: 'Confirmed Going RSVPs — click to sort by most attended',
          onTap: () {
            setState(() {
              _sort = _sort == _EventSort.mostGoing
                  ? _EventSort.soonest
                  : _EventSort.mostGoing;
            });
            _applyFilters();
          },
        ),
        AdminMetricRibbonItem(
          label: 'Comments',
          value: '$_totalComments',
          icon: Icons.forum_outlined,
          color: AdminColors.secondary,
          tooltip: 'Alumni comments and replies across active events',
        ),
      ],
    );
  }

  List<Widget> _activeFilterChips() {
    final chips = <Widget>[];
    if (_search.isNotEmpty) {
      chips.add(
        DirectoryActiveFilterChip(
          label: 'Search: $_search',
          onRemoved: () {
            _searchController.clear();
            setState(() => _search = '');
            _applyFilters();
          },
        ),
      );
    }
    if (_quickFilter != 0) {
      final label = switch (_quickFilter) {
        1 => 'This week',
        2 => 'Next 3 days',
        _ => 'All',
      };
      chips.add(
        DirectoryActiveFilterChip(
          label: 'Window: $label',
          onRemoved: () {
            setState(() => _quickFilter = 0);
            _applyFilters();
          },
        ),
      );
    }
    if (_category != null) {
      chips.add(
        DirectoryActiveFilterChip(
          label: 'Category: $_category',
          onRemoved: () {
            setState(() => _category = null);
            _applyFilters();
          },
        ),
      );
    }
    if (_batchYear != null) {
      chips.add(
        DirectoryActiveFilterChip(
          label: 'Batch: $_batchYear',
          onRemoved: () {
            setState(() => _batchYear = null);
            _applyFilters();
          },
        ),
      );
    }
    if (_venue != null) {
      chips.add(
        DirectoryActiveFilterChip(
          label: 'Venue: $_venue',
          onRemoved: () {
            setState(() => _venue = null);
            _applyFilters();
          },
        ),
      );
    }
    if (_from != null) {
      chips.add(
        DirectoryActiveFilterChip(
          label: 'From ${DateFormat('MMM d').format(_from!)}',
          onRemoved: () {
            setState(() => _from = null);
            _applyFilters();
          },
        ),
      );
    }
    if (_to != null) {
      chips.add(
        DirectoryActiveFilterChip(
          label: 'To ${DateFormat('MMM d').format(_to!)}',
          onRemoved: () {
            setState(() => _to = null);
            _applyFilters();
          },
        ),
      );
    }
    if (_sort != _EventSort.soonest) {
      chips.add(
        DirectoryActiveFilterChip(
          label: 'Sort: ${_sortLabel(_sort)}',
          onRemoved: () {
            setState(() => _sort = _EventSort.soonest);
            _applyFilters();
          },
        ),
      );
    }
    return chips;
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await DirectoryDateTimePickers.pickDateRange(
      context,
      initialDateRange: _from != null || _to != null
          ? DateTimeRange(start: _from ?? _to!, end: _to ?? _from!)
          : DateTimeRange(
              start: DateTime(now.year, now.month, now.day),
              end: DateTime(now.year, now.month, now.day)
                  .add(const Duration(days: 30)),
            ),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText: 'Filter by event dates',
    );
    if (picked == null || !mounted) return;
    setState(() {
      _from = picked.start;
      _to = picked.end;
    });
    _applyFilters();
  }

  Widget _buildToolbar() {
    final years =
        _active
            .map((e) => e.batchYear)
            .where((y) => y.isNotEmpty)
            .toSet()
            .toList()
          ..sort((a, b) => b.compareTo(a));
    final venues =
        _active.map((e) => e.venue).where((v) => v.isNotEmpty).toSet().toList()
          ..sort();
    // Keep dropdown selection valid if live updates remove an option.
    final safeBatch =
        _batchYear != null && years.contains(_batchYear) ? _batchYear : null;
    final safeVenue =
        _venue != null && venues.contains(_venue) ? _venue : null;

    return AdminSaaSToolbar(
      searchController: _searchController,
      onSearchChanged: (q) {
        _search = q.trim();
        _applyFilters();
      },
      onClearSearch: () {
        _searchController.clear();
        setState(() => _search = '');
        _applyFilters();
      },
      searchHint: 'Search title, batch, venue, or category…',
      searchWidth: 240,
      filters: [
        AdminEventDateRangeChip(
          from: _from,
          to: _to,
          onTap: _pickDateRange,
          onClear: (_from != null || _to != null)
              ? () {
                  setState(() {
                    _from = null;
                    _to = null;
                  });
                  _applyFilters();
                }
              : null,
        ),
        for (final chip in const [
          ('All', 0),
          ('This week', 1),
          ('Next 3 days', 2),
        ])
          DirectoryToolbarFilterChip(
            label: chip.$1,
            selected: _quickFilter == chip.$2,
            onSelected: (_) {
              setState(() => _quickFilter = chip.$2);
              _applyFilters();
            },
          ),
        DirectoryFilterField<String?>(
          label: 'Category',
          value: _category,
          dense: true,
          width: 132,
          items: [
            const DropdownMenuItem(value: null, child: Text('All categories')),
            ...EventCategoryConstants.all.map(
              (c) => DropdownMenuItem(
                value: c,
                child: Text(c, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ),
          ],
          onChanged: (v) {
            setState(() => _category = v);
            _applyFilters();
          },
        ),
        DirectoryFilterField<String?>(
          label: 'Batch',
          value: safeBatch,
          dense: true,
          width: 110,
          items: [
            const DropdownMenuItem(value: null, child: Text('All batches')),
            ...years.map((y) => DropdownMenuItem(value: y, child: Text(y))),
          ],
          onChanged: (v) {
            setState(() => _batchYear = v);
            _applyFilters();
          },
        ),
        DirectoryFilterField<String?>(
          label: 'Venue',
          value: safeVenue,
          dense: true,
          width: 134,
          items: [
            const DropdownMenuItem(value: null, child: Text('All venues')),
            ...venues.map(
              (v) => DropdownMenuItem(
                value: v,
                child: Text(v, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ),
          ],
          onChanged: (v) {
            setState(() => _venue = v);
            _applyFilters();
          },
        ),
      ],
      sortControl: DirectoryFilterField<_EventSort>(
        label: 'Sort',
        value: _sort,
        dense: true,
        width: 136,
        items: [
          for (final s in _EventSort.values)
            DropdownMenuItem(
              value: s,
              child: Text(
                _sortLabel(s),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
        onChanged: (v) {
          if (v != null) {
            setState(() => _sort = v);
            _applyFilters();
          }
        },
      ),
      activeFilterChips: _activeFilterChips(),
      hasActiveFilters: _hasAnyFilters,
      onResetFilters: _clearFilters,
    );
  }

  Widget _empty() {
    return AdminStateView.empty(
      icon: _hasAnyFilters
          ? Icons.search_off_rounded
          : Icons.event_note_rounded,
      title: _hasAnyFilters ? 'No matching events' : 'No active events yet',
      message: _hasAnyFilters
          ? 'Try clearing filters or searching with a different keyword.'
          : 'Create your first alumni event to get the calendar rolling.',
      primaryAction: AdminStateAction(
        label: _hasAnyFilters ? 'Clear filters' : 'Create event',
        icon: _hasAnyFilters ? Icons.filter_alt_off_outlined : Icons.add_rounded,
        onPressed: _hasAnyFilters ? _clearFilters : () => _openEditor(),
      ),
    );
  }

  Widget _listView() {
    return ListView.builder(
      key: const ValueKey('admin-events-list'),
      padding: const EdgeInsets.only(bottom: AdminDensity.space3),
      itemCount: _filtered.length,
      itemBuilder: (context, i) => _buildEventRow(_filtered[i]),
    );
  }

  Widget _buildEventRow(AlumniEvent event, {bool compact = false}) {
    return AdminEventListCard(
      event: event,
      counts: _counts[event.id] ?? const EventRsvpCounts(),
      compact: compact,
      menuItems: _menuItemsFor(event),
      onMenuSelected: (v) => _onEventMenuAction(event, v),
      onOpen: () => _openDetails(event),
    );
  }

  Widget _calendarView() {
    final selected = _selectedCalendarDay;
    final dayEvents = selected == null
        ? const <AlumniEvent>[]
        : _filtered.where((e) {
            return e.date.year == selected.year &&
                e.date.month == selected.month &&
                e.date.day == selected.day;
          }).toList();

    final calendarCard = EventsMonthCalendar(
      month: _calendarMonth,
      events: _filtered,
      selectedDay: _selectedCalendarDay,
      adminSurface: true,
      showSelectedSummary: false,
      onMonthChanged: (m) => setState(() {
        _calendarMonth = m;
        _selectedCalendarDay = null;
      }),
      onDaySelected: (day) => setState(() => _selectedCalendarDay = day),
    );

    return LayoutBuilder(
      key: const ValueKey('admin-events-calendar'),
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 960;
        if (wide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 12,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: AdminDensity.space3),
                  child: calendarCard,
                ),
              ),
              const SizedBox(width: AdminDensity.gridGap),
              Expanded(
                flex: 9,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: AdminDensity.space3),
                  child: _buildSelectedDayPanel(
                    selected,
                    dayEvents,
                    fillHeight: true,
                  ),
                ),
              ),
            ],
          );
        }

        return ListView(
          padding: const EdgeInsets.only(bottom: AdminDensity.space3),
          children: [
            calendarCard,
            const SizedBox(height: AdminDensity.gridGap),
            _buildSelectedDayPanel(selected, dayEvents, fillHeight: false),
          ],
        );
      },
    );
  }

  Widget _buildSelectedDayPanel(
    DateTime? selected,
    List<AlumniEvent> dayEvents, {
    required bool fillHeight,
  }) {
    final headerTitle = selected == null
        ? 'Day schedule'
        : DateFormat('EEEE, MMM d').format(selected);

    final Widget body;
    if (selected == null) {
      body = const AdminStateView.empty(
        compact: true,
        icon: Icons.touch_app_rounded,
        title: 'Select a date',
        message:
            'Click any day on the calendar to review scheduled events or add one for that date.',
      );
    } else if (dayEvents.isEmpty) {
      body = AdminStateView.empty(
        compact: true,
        icon: Icons.event_available_outlined,
        title: 'No events on ${DateFormat('MMM d').format(selected)}',
        message: 'Nothing is scheduled on this date with the current filters.',
        primaryAction: AdminStateAction(
          label: 'Add for this day',
          icon: Icons.add_rounded,
          onPressed: () => _openEditor(initialDate: selected),
        ),
      );
    } else {
      body = ListView.builder(
        shrinkWrap: !fillHeight,
        physics: fillHeight
            ? const AlwaysScrollableScrollPhysics()
            : const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(12),
        itemCount: dayEvents.length,
        itemBuilder: (_, i) => _buildEventRow(dayEvents[i], compact: true),
      );
    }

    return Container(
      decoration: AdminSurfaces.card(),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: fillHeight ? MainAxisSize.max : MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 12, 10),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          headerTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AdminText.sectionTitle,
                        ),
                      ),
                      if (selected != null) ...[
                        const SizedBox(width: 8),
                        AdminBadge.neutral(
                          label:
                              '${dayEvents.length} ${dayEvents.length == 1 ? 'event' : 'events'}',
                          dense: true,
                        ),
                      ],
                    ],
                  ),
                ),
                if (selected != null)
                  OutlinedButton.icon(
                    onPressed: () => _openEditor(initialDate: selected),
                    icon: const Icon(Icons.add_rounded, size: 15),
                    label: const Text('Add for this day'),
                    style: AdminButtonStyles.outlined().copyWith(
                      minimumSize: const WidgetStatePropertyAll(Size(0, 32)),
                      padding: const WidgetStatePropertyAll(
                        EdgeInsets.symmetric(horizontal: 10),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1, color: AdminColors.border),
          if (fillHeight) Expanded(child: body) else body,
        ],
      ),
    );
  }

  Future<void> _onEventMenuAction(AlumniEvent event, String value) async {
    switch (value) {
      case 'share':
        await showShareLinkSheet(context, ShareableContent.fromEvent(event));
      case 'details':
        await _openDetails(event);
      case 'edit':
        await _openEditor(event: event);
      case 'archive':
        await _archive(event);
      case 'cancel':
        await _cancel(event);
      case 'delete':
        await _delete(event);
    }
  }

  List<PopupMenuEntry<String>> _menuItemsFor(AlumniEvent event) {
    final canShare =
        !event.cancelled && event.status.trim().toLowerCase() != 'archived';
    return [
      adminEventMenuItem(
        value: 'details',
        label: 'View details',
        icon: Icons.visibility_outlined,
      ),
      adminEventMenuItem(
        value: 'edit',
        label: 'Edit event',
        icon: Icons.edit_outlined,
      ),
      if (canShare)
        adminEventMenuItem(
          value: 'share',
          label: 'Share link…',
          icon: Icons.share_outlined,
        ),
      const PopupMenuDivider(height: 8),
      adminEventMenuItem(
        value: 'archive',
        label: 'Archive',
        icon: Icons.archive_outlined,
      ),
      if (!event.cancelled)
        adminEventMenuItem(
          value: 'cancel',
          label: 'Cancel event',
          icon: Icons.event_busy_outlined,
          destructive: true,
        ),
      adminEventMenuItem(
        value: 'delete',
        label: 'Delete',
        icon: Icons.delete_outline_rounded,
        destructive: true,
      ),
    ];
  }
}
