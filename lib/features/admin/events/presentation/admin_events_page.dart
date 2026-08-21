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
import 'package:alumni_system/features/events/widgets/event_cover.dart';
import 'package:alumni_system/features/events/widgets/event_status_badge.dart';
import 'package:alumni_system/features/events/widgets/events_month_calendar.dart';
import 'package:alumni_system/features/notifications/data/notification_service.dart';
import 'package:alumni_system/core/constants/event_category_constants.dart';
import 'package:alumni_system/features/admin/events/widgets/admin_event_ui.dart';
import 'package:alumni_system/features/admin/roster/widgets/alumni_directory_ui.dart';
import 'package:alumni_system/shared/widgets/admin/admin_density.dart';
import 'package:alumni_system/shared/widgets/admin/admin_page_header.dart';
import 'package:alumni_system/shared/widgets/admin/admin_skeletons.dart';
import 'package:alumni_system/shared/widgets/admin/admin_search_field.dart';

class AdminEventsScreen extends StatefulWidget {
  const AdminEventsScreen({super.key});

  @override
  State<AdminEventsScreen> createState() => _AdminEventsScreenState();
}

class _AdminEventsScreenState extends State<AdminEventsScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final _eventService = EventService();
  final _rsvpService = EventRsvpService();
  final _notificationService = NotificationService();
  final _searchController = TextEditingController();
  final _supabase = Supabase.instance.client;

  List<AlumniEvent> _active = [];
  List<AlumniEvent> _filtered = [];
  Map<String, EventRsvpCounts> _counts = {};
  bool _loading = false;
  bool _showCalendar = false;
  String? _batchYear;
  String? _venue;
  String? _category;
  DateTime? _from;
  DateTime? _to;
  String _search = '';
  int _quickFilter = 0; // 0 all, 1 this week, 2 soon (7d), 3 newest
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
      _startLiveUpdates();
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
      });
      _applyFilters();
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      if (showSpinner) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading events: $e')));
      }
    } finally {
      _reloadInFlight = false;
      if (_pendingReload && mounted) {
        _pendingReload = false;
        unawaited(_load(showSpinner: false));
      }
    }
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
      case 3:
        results = List<AlumniEvent>.from(results)
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      default:
        results.sort((a, b) => a.date.compareTo(b.date));
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
    setState(() => _filtered = results);
  }

  bool get _hasAdvancedFilters =>
      _batchYear != null ||
      _venue != null ||
      _category != null ||
      _from != null ||
      _to != null;

  bool get _hasAnyFilters =>
      _hasAdvancedFilters || _search.isNotEmpty || _quickFilter != 0;

  void _clearFilters() {
    setState(() {
      _batchYear = null;
      _venue = null;
      _category = null;
      _from = null;
      _to = null;
      _search = '';
      _quickFilter = 0;
      _searchController.clear();
      _selectedCalendarDay = null;
    });
    _applyFilters();
  }

  Future<void> _openEditor({AlumniEvent? event}) async {
    final saved = await showAdminEventEditorDialog(
      context: context,
      event: event,
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
    final ok = await _confirm(
      title: 'Archive event?',
      body: '“${event.theme}” will move to Archives.',
      confirmLabel: 'Archive',
    );
    if (ok != true) return;
    try {
      await _eventService.archiveEvent(event.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Event archived'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () async {
              await _eventService.restoreEvent(event.id);
              await _load();
            },
          ),
        ),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error archiving: $e')));
    }
  }

  Future<void> _delete(AlumniEvent event) async {
    final ok = await _confirm(
      title: 'Delete event?',
      body: 'This permanently deletes “${event.theme}”.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (ok != true) return;
    try {
      await _eventService.deleteEvent(event.id);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Event deleted')));
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error deleting: $e')));
    }
  }

  Future<void> _cancel(AlumniEvent event) async {
    final ok = await _confirm(
      title: 'Cancel event?',
      body: 'Alumni will be notified that “${event.theme}” is cancelled.',
      confirmLabel: 'Cancel event',
      destructive: true,
    );
    if (ok != true) return;
    try {
      await _eventService.cancelEvent(event.id);
      try {
        await _notificationService.notifyEventCancelled(
          eventId: event.id,
          eventTitle: event.theme,
        );
      } catch (_) {}
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Event cancelled')));
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error cancelling: $e')));
    }
  }

  Future<bool?> _confirm({
    required String title,
    required String body,
    required String confirmLabel,
    bool destructive = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: destructive
                  ? const Color(0xFFDC2626)
                  : AdminEventTheme.primary,
            ),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
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

  int _daysUntil(AlumniEvent event) {
    final today = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    final eventDay = DateTime(
      event.date.year,
      event.date.month,
      event.date.day,
    );
    return eventDay.difference(today).inDays;
  }

  String _countdownLabel(int daysUntil) {
    if (daysUntil < 0) return 'Past';
    if (daysUntil == 0) return 'Today';
    if (daysUntil == 1) return 'Tomorrow';
    if (daysUntil <= 7) return 'In $daysUntil days';
    return DateFormat(
      'MMM d',
    ).format(DateTime.now().add(Duration(days: daysUntil)));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
            AdminPageHeader(
              title: 'Events',
              subtitle: _showCalendar
                  ? 'Plan by date — tap a highlighted day to manage events'
                  : 'Create, monitor attendance, and keep alumni engaged',
              titleColor: AdminEventTheme.textPrimary,
              subtitleColor: AdminEventTheme.textSecondary,
              titleFontSize: AdminDensity.titleFontSize,
              actions: [
                _viewToggle(),
                FilledButton.icon(
                  onPressed: () => _openEditor(),
                  icon: const Icon(Icons.add_rounded, size: 17),
                  label: const Text('New Event'),
                  style: eventFilledButtonStyle(),
                ),
              ],
            ),
            const SizedBox(height: AdminEventTheme.space2),
            _buildMetrics(),
            const SizedBox(height: AdminEventTheme.space2),
            _buildToolbar(),
            const SizedBox(height: AdminEventTheme.space1),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: _loading && _filtered.isEmpty
                    ? const AdminEventsListSkeleton()
                    : _showCalendar
                    ? _calendarView()
                    : _filtered.isEmpty
                    ? _empty()
                    : _listView(),
              ),
            ),
          ],
    );
  }

  Widget _viewToggle() {
    return Container(
      decoration: BoxDecoration(
        color: AdminEventTheme.surface,
        borderRadius: BorderRadius.circular(AdminEventTheme.radiusSm),
        border: Border.all(color: AdminEventTheme.border),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _viewToggleBtn(
            selected: !_showCalendar,
            icon: Icons.view_agenda_rounded,
            label: 'List',
            onTap: () => setState(() => _showCalendar = false),
          ),
          _viewToggleBtn(
            selected: _showCalendar,
            icon: Icons.calendar_month_rounded,
            label: 'Calendar',
            onTap: () => setState(() => _showCalendar = true),
          ),
        ],
      ),
    );
  }

  Widget _viewToggleBtn({
    required bool selected,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: selected ? AdminEventTheme.primary : Colors.transparent,
      borderRadius: BorderRadius.circular(AdminEventTheme.radiusSm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AdminEventTheme.radiusSm),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            children: [
              Icon(
                icon,
                size: 16,
                color: selected
                    ? AdminEventTheme.gold
                    : AdminEventTheme.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: selected
                      ? Colors.white
                      : AdminEventTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetrics() {
    return DirectoryStatsGrid(
      children: [
        DirectoryStatCard(
          label: 'Active events',
          value: '${_active.length}',
          description: 'On the live calendar',
          icon: Icons.event_available_rounded,
          accent: AdminEventTheme.primary,
          onTap: () {
            setState(() => _quickFilter = 0);
            _applyFilters();
          },
        ),
        DirectoryStatCard(
          label: 'Coming this week',
          value: '$_soonCount',
          description: 'Next 7 days',
          icon: Icons.schedule_rounded,
          accent: AdminEventTheme.warning,
          onTap: () {
            setState(() => _quickFilter = 1);
            _applyFilters();
          },
        ),
        DirectoryStatCard(
          label: 'Going responses',
          value: '$_totalGoing',
          description: 'RSVP confirmations',
          icon: Icons.check_circle_outline_rounded,
          accent: AdminEventTheme.success,
        ),
        DirectoryStatCard(
          label: 'Comments',
          value: '$_totalComments',
          description: 'Across active events',
          icon: Icons.forum_outlined,
          accent: AdminEventTheme.info,
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
        2 => 'Soon',
        3 => 'Newest',
        _ => 'All',
      };
      chips.add(
        DirectoryActiveFilterChip(
          label: 'Quick: $label',
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
    return chips;
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

    return DirectoryToolbarCard(
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
      isLoading: _loading,
      onRefresh: () => _load(showSpinner: true),
      hasActiveFilters: _hasAnyFilters,
      onResetFilters: _clearFilters,
      searchHint: 'Search by title, batch, venue, or category…',
      activeFilterChips: _activeFilterChips(),
      filters: Wrap(
        spacing: 6,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          DirectoryFilterField<String?>(
            label: 'Category',
            value: _category,
            width: 140,
            items: [
              const DropdownMenuItem(
                value: null,
                child: Text('All categories'),
              ),
              ...EventCategoryConstants.all.map(
                (c) => DropdownMenuItem(value: c, child: Text(c)),
              ),
            ],
            onChanged: (v) {
              setState(() => _category = v);
              _applyFilters();
            },
          ),
          DirectoryFilterField<String?>(
            label: 'Batch',
            value: _batchYear,
            width: 120,
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
            value: _venue,
            width: 140,
            items: [
              const DropdownMenuItem(value: null, child: Text('All venues')),
              ...venues.map(
                (v) => DropdownMenuItem(
                  value: v,
                  child: Text(v.length > 22 ? '${v.substring(0, 22)}…' : v),
                ),
              ),
            ],
            onChanged: (v) {
              setState(() => _venue = v);
              _applyFilters();
            },
          ),
          DirectoryDateFilterChip(
            label: 'From',
            displayText: _from == null
                ? 'Any date'
                : DateFormat('MMM d').format(_from!),
            active: _from != null,
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _from ?? DateTime.now(),
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
              );
              if (picked != null) {
                setState(() => _from = picked);
                _applyFilters();
              }
            },
          ),
          DirectoryDateFilterChip(
            label: 'To',
            displayText: _to == null
                ? 'Any date'
                : DateFormat('MMM d').format(_to!),
            active: _to != null,
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _to ?? DateTime.now(),
                firstDate: _from ?? DateTime(2020),
                lastDate: DateTime(2100),
              );
              if (picked != null) {
                setState(() => _to = picked);
                _applyFilters();
              }
            },
          ),
          for (final chip in const [
            ('All', 0),
            ('This week', 1),
            ('Soon', 2),
            ('Newest', 3),
          ])
            FilterChip(
              label: Text(chip.$1),
              selected: _quickFilter == chip.$2,
              showCheckmark: false,
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              labelPadding: const EdgeInsets.symmetric(horizontal: 4),
              selectedColor: AdminEventTheme.infoBg,
              labelStyle: TextStyle(
                fontSize: 12,
                color: _quickFilter == chip.$2
                    ? AdminEventTheme.primary
                    : AdminEventTheme.textSecondary,
              ),
              side: const BorderSide(color: AdminEventTheme.border),
              onSelected: (_) {
                setState(() => _quickFilter = chip.$2);
                _applyFilters();
              },
            ),
        ],
      ),
    );
  }

  Widget _empty() {
    return DirectoryEmptyState(
      icon: _hasAnyFilters
          ? Icons.search_off_rounded
          : Icons.event_note_rounded,
      title: _hasAnyFilters ? 'No matching events' : 'No active events yet',
      subtitle: _hasAnyFilters
          ? 'Try clearing filters or searching with a different keyword.'
          : 'Create your first alumni event to get the calendar rolling.',
      primaryLabel: _hasAnyFilters ? 'Clear filters' : 'Create event',
      primaryAction: _hasAnyFilters ? _clearFilters : () => _openEditor(),
    );
  }

  Widget _listView() {
    return ListView.builder(
      key: const ValueKey('admin-events-list'),
      padding: const EdgeInsets.only(bottom: AdminDensity.space3),
      itemCount: _filtered.length,
      itemBuilder: (context, i) => _eventCard(_filtered[i]),
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

    return ListView(
      key: const ValueKey('admin-events-calendar'),
      padding: const EdgeInsets.only(bottom: AdminDensity.space3),
      children: [
        EventsMonthCalendar(
          month: _calendarMonth,
          events: _filtered,
          selectedDay: _selectedCalendarDay,
          onMonthChanged: (m) => setState(() {
            _calendarMonth = m;
            _selectedCalendarDay = null;
          }),
          onDaySelected: (day) {
            final eventsOnDay = _filtered.where((e) {
              return e.date.year == day.year &&
                  e.date.month == day.month &&
                  e.date.day == day.day;
            }).toList();
            setState(() => _selectedCalendarDay = day);
            if (eventsOnDay.length == 1) {
              _openDetails(eventsOnDay.first);
            }
          },
        ),
        const SizedBox(height: AdminEventTheme.space2),
        if (selected == null)
          Container(
            padding: const EdgeInsets.all(AdminDensity.cardPadding),
            decoration: AdminEventTheme.surfaceCard(),
            child: const Row(
              children: [
                Icon(
                  Icons.touch_app_rounded,
                  color: AdminEventTheme.primary,
                  size: 20,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Tap a highlighted date to view and manage that day’s events.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AdminEventTheme.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          )
        else ...[
          Row(
            children: [
              Text(
                dayEvents.isEmpty
                    ? 'No events on ${DateFormat('MMM d').format(selected)}'
                    : '${dayEvents.length} event${dayEvents.length == 1 ? '' : 's'} on ${DateFormat('EEEE, MMM d').format(selected)}',
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: AdminEventTheme.textPrimary,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _openEditor(),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Add for this day'),
              ),
            ],
          ),
          const SizedBox(height: AdminEventTheme.space1),
          if (dayEvents.isEmpty)
            Container(
              padding: const EdgeInsets.all(AdminDensity.space3),
              decoration: BoxDecoration(
                color: AdminEventTheme.surface,
                borderRadius: BorderRadius.circular(AdminEventTheme.radiusMd),
                border: Border.all(color: AdminEventTheme.border),
              ),
              child: const Text(
                'Nothing scheduled here yet. Create an event to fill this date.',
                style: TextStyle(color: AdminEventTheme.textSecondary),
              ),
            )
          else
            ...dayEvents.map((e) => _eventCard(e, compact: true)),
        ],
      ],
    );
  }

  Widget _eventCard(AlumniEvent event, {bool compact = false}) {
    final counts = _counts[event.id] ?? const EventRsvpCounts();
    final daysUntil = _daysUntil(event);
    final soon = daysUntil >= 0 && daysUntil <= 7;
    final today = daysUntil == 0;

    return AdminHoverShell(
      builder: (context, hovered) => Container(
        margin: const EdgeInsets.only(bottom: AdminDensity.listItemGap),
        decoration: AdminEventTheme.surfaceCard(hovered: hovered),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(AdminEventTheme.radiusLg),
            onTap: () => _openDetails(event),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AdminEventTheme.radiusLg),
                gradient: today
                    ? LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          AdminEventTheme.gold.withValues(alpha: 0.12),
                          Colors.white,
                        ],
                      )
                    : null,
              ),
              padding: EdgeInsets.symmetric(
                horizontal: AdminDensity.space3,
                vertical: compact ? 10 : AdminDensity.cardPadding,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    children: [
                      SizedBox(
                        width: compact ? 96 : 120,
                        child: EventCover(
                          event: event,
                          height: compact ? 64 : 76,
                          borderRadius: AdminEventTheme.radiusSm,
                        ),
                      ),
                      if (soon)
                        Positioned(
                          left: 6,
                          top: 6,
                          child: _countdownPill(daysUntil),
                        ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                event.theme,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: AdminEventTheme.textPrimary,
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            _actionsMenu(event),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            EventCategoryChip(category: event.category),
                            if (event.batchYear.isNotEmpty)
                              _metaPill(
                                Icons.groups_outlined,
                                'Batch ${event.batchYear}',
                              ),
                            _metaPill(
                              Icons.schedule_rounded,
                              '${DateFormat('MMM d, yyyy').format(event.date)} · ${event.startTime}–${event.endTime}',
                            ),
                            _metaPill(Icons.location_on_outlined, event.venue),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            _softStat(
                              'Going',
                              counts.going,
                              AdminEventTheme.success,
                            ),
                            _softStat(
                              'Interested',
                              counts.interested,
                              AdminEventTheme.warning,
                            ),
                            _softStat(
                              "Can't",
                              counts.cantAttend,
                              AdminEventTheme.danger,
                            ),
                            _softStat(
                              'Comments',
                              event.comments,
                              AdminEventTheme.info,
                            ),
                            if (event.capacity != null && event.capacity! > 0)
                              _softStat(
                                'Seats left',
                                (event.capacity! - counts.going).clamp(
                                  0,
                                  event.capacity!,
                                ),
                                AdminEventTheme.primary,
                              ),
                          ],
                        ),
                      ],
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

  Widget _countdownPill(int daysUntil) {
    final label = _countdownLabel(daysUntil);
    final hot = daysUntil <= 1;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: hot ? AdminEventTheme.danger : AdminEventTheme.primary,
        borderRadius: BorderRadius.circular(AdminEventTheme.radiusSm),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        label,
        style: TextStyle(
          color: hot ? Colors.white : AdminEventTheme.gold,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _metaPill(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AdminEventTheme.surface,
        borderRadius: BorderRadius.circular(AdminEventTheme.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AdminEventTheme.textSecondary),
          const SizedBox(width: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220),
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: AdminEventTheme.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _softStat(String label, int value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AdminEventTheme.radiusSm),
      ),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$value',
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
            TextSpan(
              text: ' $label',
              style: TextStyle(
                color: color.withValues(alpha: 0.9),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionsMenu(AlumniEvent event) {
    return PopupMenuButton<String>(
      tooltip: 'Actions',
      onSelected: (value) async {
        switch (value) {
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
      },
      itemBuilder: (_) => const [
        PopupMenuItem(value: 'details', child: Text('View details')),
        PopupMenuItem(value: 'edit', child: Text('Edit')),
        PopupMenuItem(value: 'archive', child: Text('Archive')),
        PopupMenuItem(value: 'cancel', child: Text('Cancel event')),
        PopupMenuItem(
          value: 'delete',
          child: Text('Delete', style: TextStyle(color: Color(0xFFDC2626))),
        ),
      ],
    );
  }
}
