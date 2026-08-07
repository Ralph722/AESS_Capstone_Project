import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:alumni_system/core/utils/app_image.dart';
import 'package:alumni_system/core/services/app_session.dart';
import 'package:alumni_system/features/events/data/event_comment_service.dart';
import 'package:alumni_system/features/events/data/event_rsvp_service.dart';
import 'package:alumni_system/features/events/data/event_service.dart';
import 'package:alumni_system/features/events/data/reminder_service.dart';
import 'package:alumni_system/features/events/models/event_comment_model.dart';
import 'package:alumni_system/features/events/models/event_model.dart';
import 'package:alumni_system/features/events/models/event_rsvp_model.dart';
import 'package:alumni_system/features/events/widgets/event_cover.dart';
import 'package:alumni_system/features/events/widgets/event_rsvp_bar.dart';
import 'package:alumni_system/features/events/widgets/event_status_badge.dart';
import 'package:alumni_system/features/events/widgets/events_month_calendar.dart';
import 'package:alumni_system/shared/widgets/user/portal_skeletons.dart';
import 'package:alumni_system/shared/widgets/user/portal_theme.dart';
import 'package:alumni_system/shared/widgets/user/portal_breakpoints.dart';
import 'package:alumni_system/shared/widgets/user/portal_states.dart';
import 'package:alumni_system/shared/widgets/user/portal_headers.dart';
import 'package:alumni_system/features/events/widgets/alumni_event_list_widgets.dart';

class EventsScreen extends StatefulWidget {
  const EventsScreen({
    super.key,
    this.initialEventId,
    this.openCommentsOnLaunch = false,
  });

  final String? initialEventId;
  final bool openCommentsOnLaunch;

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  static const _navy = PortalTheme.navy;
  static const _gold = PortalTheme.gold;

  int _selectedFilter = 0;
  final List<String> _filters = [
    'All',
    'This Week',
    'This Month',
    'Newest',
    'Going & Interested',
  ];
  final EventService _eventService = EventService();
  final ReminderService _reminderService = ReminderService();
  final EventCommentService _commentService = EventCommentService();
  final EventRsvpService _rsvpService = EventRsvpService();
  final TextEditingController _searchController = TextEditingController();

  List<AlumniEvent> allEvents = [];
  List<AlumniEvent> filteredEvents = [];
  Map<String, EventRsvpStatus> _myRsvps = {};
  Map<String, EventRsvpCounts> _rsvpCounts = {};
  final Set<String> _rsvpBusy = {};
  bool isLoading = false;
  Object? _loadError;
  String _searchQuery = '';

  /// false = list, true = calendar
  bool _showCalendar = false;
  DateTime _calendarMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime? _selectedCalendarDay;
  bool _handledInitialTarget = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _initializeReminders();
      _loadEvents();
    });
  }

  Future<void> _initializeReminders() async {
    await _reminderService.initialize();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadEvents() async {
    try {
      setState(() {
        isLoading = true;
        _loadError = null;
      });
      final events = await _eventService.getUpcomingEvents();
      final ids = events.map((e) => e.id).toList();
      final myRsvps = await _rsvpService.getMyRsvpsForEvents(ids);
      final counts = await _rsvpService.getCountsForEvents(ids);
      if (!mounted) return;
      setState(() {
        allEvents = events;
        _myRsvps = myRsvps;
        _rsvpCounts = counts;
        isLoading = false;
        _loadError = null;
      });
      _recomputeFilteredEvents();
      _openInitialTargetIfNeeded();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
        _loadError = e;
      });
    }
  }

  Future<void> _refreshRsvpMeta() async {
    final ids = allEvents.map((e) => e.id).toList();
    if (ids.isEmpty) return;
    final myRsvps = await _rsvpService.getMyRsvpsForEvents(ids);
    final counts = await _rsvpService.getCountsForEvents(ids);
    if (!mounted) return;
    setState(() {
      _myRsvps = myRsvps;
      _rsvpCounts = counts;
    });
  }

  void _filterEvents(int filterIndex) {
    _selectedFilter = filterIndex;
    _recomputeFilteredEvents();
  }

  void _recomputeFilteredEvents() {
    final now = DateTime.now();
    List<AlumniEvent> next = [];
    switch (_selectedFilter) {
      case 0:
        next = List<AlumniEvent>.from(allEvents);
        break;
      case 1:
        final weekLater = now.add(const Duration(days: 7));
        next = allEvents.where((event) {
          return event.date.isAfter(now.subtract(const Duration(days: 1))) &&
              event.date.isBefore(weekLater);
        }).toList();
        break;
      case 2:
        final monthLater = DateTime(now.year, now.month + 1, now.day);
        next = allEvents.where((event) {
          return event.date.isAfter(now.subtract(const Duration(days: 1))) &&
              event.date.isBefore(monthLater);
        }).toList();
        break;
      case 3:
        next = List<AlumniEvent>.from(allEvents)
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case 4:
        next = allEvents.where((event) {
          final s = _myRsvps[event.id];
          return s == EventRsvpStatus.going || s == EventRsvpStatus.interested;
        }).toList();
        break;
    }
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      next = next.where((event) {
        return event.theme.toLowerCase().contains(query) ||
            event.venue.toLowerCase().contains(query) ||
            event.batchYear.toLowerCase().contains(query) ||
            event.description.toLowerCase().contains(query) ||
            event.category.toLowerCase().contains(query);
      }).toList();
    }
    setState(() => filteredEvents = next);
  }

  void _openInitialTargetIfNeeded() {
    if (_handledInitialTarget) return;
    final targetEventId = widget.initialEventId?.trim();
    if (targetEventId == null || targetEventId.isEmpty) return;
    final matches = allEvents.where((e) => e.id == targetEventId);
    if (matches.isEmpty) return;
    _handledInitialTarget = true;
    final event = matches.first;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _showEventDetails(
        event,
        openCommentsImmediately: widget.openCommentsOnLaunch,
      );
    });
  }

  void _onSearchChanged(String query) {
    _searchQuery = query;
    _recomputeFilteredEvents();
  }

  EventRsvpCounts _countsFor(AlumniEvent event) =>
      _rsvpCounts[event.id] ?? const EventRsvpCounts();

  EventRsvpStatus? _statusFor(AlumniEvent event) => _myRsvps[event.id];

  bool _goingEnabled(AlumniEvent event) {
    if (!event.isRegistrationOpen) return false;
    final status = _statusFor(event);
    if (status == EventRsvpStatus.going) return true;
    return !event.isFull(_countsFor(event).going);
  }

  List<String> _constraintLabels(AlumniEvent event) {
    final labels = <String>[];
    if (!event.isRegistrationOpen) {
      labels.add('Registration closed');
    }
    final counts = _countsFor(event);
    if (event.isFull(counts.going) &&
        _statusFor(event) != EventRsvpStatus.going) {
      labels.add('Capacity full');
    }
    return labels;
  }

  Future<void> _onRsvpChanged(AlumniEvent event, EventRsvpStatus status) async {
    if (_rsvpBusy.contains(event.id)) return;
    final previous = _statusFor(event);

    if (status == EventRsvpStatus.going && !_goingEnabled(event)) {
      final closed = !event.isRegistrationOpen;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              closed ? 'Registration is closed' : 'This event is at capacity',
            ),
            backgroundColor: const Color(0xFFFF6B6B),
          ),
        );
      }
      return;
    }

    setState(() {
      _rsvpBusy.add(event.id);
      _myRsvps = {..._myRsvps, event.id: status};
    });

    try {
      await _rsvpService.setRsvp(eventId: event.id, status: status);
      final userId = AppSession.userId;

      if (status == EventRsvpStatus.going) {
        await _reminderService.scheduleEventReminder(event);
        if (userId != null) {
          await _eventService.addReminder(userId, event.id);
        }
      } else if (previous == EventRsvpStatus.going) {
        await _reminderService.cancelEventReminders(event.id);
        if (userId != null) {
          await _eventService.removeReminder(userId, event.id);
        }
      }

      await _refreshRsvpMeta();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Response saved: ${status.label}'),
          backgroundColor: const Color(0xFF4CAF50),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (previous == null) {
          _myRsvps = Map<String, EventRsvpStatus>.from(_myRsvps)
            ..remove(event.id);
        } else {
          _myRsvps = {..._myRsvps, event.id: previous};
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating response: $e'),
          backgroundColor: const Color(0xFFFF6B6B),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _rsvpBusy.remove(event.id));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: PortalTheme.pageBg,
      appBar: PortalAppBar(
        title: 'Events',
        subtitle: 'Discover alumni gatherings',
        automaticallyImplyLeading: false,
        actions: [
          PortalHeaderAction(
            icon: _showCalendar
                ? Icons.view_list_rounded
                : Icons.calendar_month_rounded,
            tooltip: _showCalendar ? 'List view' : 'Calendar view',
            onPressed: () => setState(() => _showCalendar = !_showCalendar),
          ),
          PortalHeaderAction(
            icon: Icons.refresh_rounded,
            tooltip: 'Refresh',
            onPressed: isLoading ? () {} : _loadEvents,
          ),
        ],
      ),
      body: PortalContentFrame(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: 44,
                      child: TextField(
                        controller: _searchController,
                        onChanged: _onSearchChanged,
                        style: PortalTheme.body,
                        decoration: InputDecoration(
                          hintText: 'Search by title, venue, or category',
                          hintStyle: PortalTheme.bodySecondary,
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            size: 20,
                            color: PortalTheme.textSecondary,
                          ),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () {
                                    _searchController.clear();
                                    _onSearchChanged('');
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor: PortalTheme.surfaceMuted,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 0,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              PortalTheme.radiusMd,
                            ),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              PortalTheme.radiusMd,
                            ),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              PortalTheme.radiusMd,
                            ),
                            borderSide: const BorderSide(
                              color: _navy,
                              width: 1.2,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 36,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _filters.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final selected = _selectedFilter == index;
                          return FilterChip(
                            selected: selected,
                            showCheckmark: false,
                            label: Text(_filters[index]),
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            labelPadding: const EdgeInsets.symmetric(
                              horizontal: 8,
                            ),
                            onSelected: (v) {
                              if (v) _filterEvents(index);
                            },
                            selectedColor: PortalTheme.navy,
                            backgroundColor: PortalTheme.surfaceMuted,
                            labelStyle: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: selected
                                  ? Colors.white
                                  : PortalTheme.textSecondary,
                            ),
                            side: BorderSide(
                              color: selected
                                  ? PortalTheme.navy
                                  : PortalTheme.border,
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '${filteredEvents.length} ${filteredEvents.length == 1 ? 'event' : 'events'}',
                      style: PortalTheme.meta,
                    ),
                  ],
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 12)),

            if (isLoading)
              const SliverToBoxAdapter(child: EventListSkeleton(grid: false))
            else if (_loadError != null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: PortalErrorState(
                  error: _loadError,
                  onRetry: _loadEvents,
                ),
              )
            else if (filteredEvents.isEmpty)
              SliverFillRemaining(child: _buildEmptyState())
            else if (_showCalendar)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                sliver: SliverToBoxAdapter(child: _buildCalendarView()),
              )
            else
              Builder(
                builder: (context) {
                  final width = MediaQuery.sizeOf(context).width;
                  final cols = PortalBreakpoints.eventListColumns(width);
                  if (cols <= 1) {
                    return SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: _buildEventCard(
                              filteredEvents[index],
                              featured:
                                  index == 0 &&
                                  _selectedFilter == 0 &&
                                  _searchQuery.isEmpty,
                            ),
                          ),
                          childCount: filteredEvents.length,
                        ),
                      ),
                    );
                  }

                  // Match tile height to card content so rows stay tight.
                  const hPad = 12.0;
                  const gap = 12.0;
                  const bodyEstimate = 228.0;
                  final tileWidth =
                      (width - (hPad * 2) - gap * (cols - 1)) / cols;
                  final imageHeight = tileWidth / EventCover.feedTeaserRatio;
                  final mainAxisExtent = imageHeight + bodyEstimate;

                  return SliverPadding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    sliver: SliverGrid(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: cols,
                        mainAxisSpacing: gap,
                        crossAxisSpacing: gap,
                        mainAxisExtent: mainAxisExtent,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) =>
                            _buildEventCard(filteredEvents[index]),
                        childCount: filteredEvents.length,
                      ),
                    ),
                  );
                },
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 88)),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarView() {
    final selected = _selectedCalendarDay;
    final dayEvents = selected == null
        ? const <AlumniEvent>[]
        : filteredEvents.where((e) {
            return e.date.year == selected.year &&
                e.date.month == selected.month &&
                e.date.day == selected.day;
          }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EventsMonthCalendar(
          month: _calendarMonth,
          events: filteredEvents,
          selectedDay: _selectedCalendarDay,
          onMonthChanged: (m) => setState(() {
            _calendarMonth = m;
            _selectedCalendarDay = null;
          }),
          onDaySelected: (day) {
            final eventsOnDay = filteredEvents.where((e) {
              return e.date.year == day.year &&
                  e.date.month == day.month &&
                  e.date.day == day.day;
            }).toList();
            setState(() => _selectedCalendarDay = day);
            if (eventsOnDay.length == 1) {
              _showEventDetails(eventsOnDay.first);
            }
          },
        ),
        if (selected != null) ...[
          const SizedBox(height: 10),
          if (dayEvents.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'No events on ${DateFormat('MMM d').format(selected)}',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600),
              ),
            )
          else ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                dayEvents.length == 1
                    ? '1 event on ${DateFormat('MMM d').format(selected)}'
                    : '${dayEvents.length} events on ${DateFormat('MMM d').format(selected)}',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: _navy,
                  fontSize: 14,
                ),
              ),
            ),
            ...dayEvents.map(
              (e) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _buildEventCard(e),
              ),
            ),
          ],
        ] else
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 12, 8, 4),
            child: Text(
              'Tap a highlighted date to view events for that day.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
          ),
      ],
    );
  }

  Widget _buildConstraintLabels(AlumniEvent event) {
    return EventConstraintLabels(labels: _constraintLabels(event));
  }

  Widget _buildEventCard(AlumniEvent event, {bool featured = false}) {
    return AlumniEventListCard(
      event: event,
      featured: featured,
      counts: _countsFor(event),
      selectedStatus: _statusFor(event),
      goingEnabled: _goingEnabled(event),
      busy: _rsvpBusy.contains(event.id),
      constraintLabels: _constraintLabels(event),
      onTap: () => _showEventDetails(event),
      onRsvpChanged: (s) => _onRsvpChanged(event, s),
    );
  }

  Widget _buildEmptyState() {
    return AlumniEventsEmptyState(
      hasSearchQuery: _searchQuery.isNotEmpty,
      onClearSearch: () {
        _searchController.clear();
        _onSearchChanged('');
      },
    );
  }

  void _showEventDetails(
    AlumniEvent event, {
    bool openCommentsImmediately = false,
  }) {
    _eventService.incrementViews(event.id);
    var currentEvent = event;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final status = _statusFor(currentEvent);
            final busy = _rsvpBusy.contains(currentEvent.id);
            final counts = _countsFor(currentEvent);

            Future<void> handleRsvp(EventRsvpStatus s) async {
              await _onRsvpChanged(currentEvent, s);
              if (context.mounted) setSheetState(() {});
            }

            Future<void> openComments() async {
              await _showCommentsDialog(
                currentEvent,
                onCommentsChanged: (count) {
                  setSheetState(() {
                    currentEvent = currentEvent.copyWith(comments: count);
                  });
                },
              );
            }

            if (openCommentsImmediately) {
              openCommentsImmediately = false;
              WidgetsBinding.instance.addPostFrameCallback(
                (_) => openComments(),
              );
            }

            return DraggableScrollableSheet(
              initialChildSize: 0.9,
              minChildSize: 0.5,
              maxChildSize: 0.97,
              builder: (context, scrollController) => Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    Expanded(
                      child: ListView(
                        controller: scrollController,
                        padding: EdgeInsets.zero,
                        children: [
                          // Full event image (aspect-preserving, not feed crop)
                          Stack(
                            children: [
                              ColoredBox(
                                color: PortalTheme.surfaceMuted,
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    maxHeight:
                                        MediaQuery.sizeOf(context).height * 0.42,
                                    minHeight: 180,
                                  ),
                                  child: ClipRect(
                                    child: EventCoverHero(
                                      event: currentEvent,
                                      borderRadius: 0,
                                      showDownload: false,
                                    ),
                                  ),
                                ),
                              ),
                              const Positioned(
                                left: 0,
                                right: 0,
                                top: 0,
                                height: 88,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Color(0x990A1128),
                                        Color(0x000A1128),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 10,
                                left: 0,
                                right: 0,
                                child: Center(
                                  child: Container(
                                    width: 36,
                                    height: 4,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                        alpha: 0.55,
                                      ),
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 14,
                                right: 14,
                                child: Material(
                                  color: Colors.black.withValues(alpha: 0.4),
                                  shape: const CircleBorder(),
                                  child: InkWell(
                                    customBorder: const CircleBorder(),
                                    onTap: () => Navigator.pop(context),
                                    child: const Padding(
                                      padding: EdgeInsets.all(8),
                                      child: Icon(
                                        Icons.close_rounded,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  currentEvent.theme,
                                  style: PortalTheme.display.copyWith(
                                    fontSize: 22,
                                    color: const Color(0xFF0F172A),
                                    height: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: [
                                    EventCategoryChip(
                                      category: currentEvent.category,
                                    ),
                                    EventStatusBadge(
                                      event: currentEvent,
                                      compact: true,
                                    ),
                                    if (currentEvent.batchYear.isNotEmpty)
                                      EventCategoryChip(
                                        category:
                                            'Batch ${currentEvent.batchYear}',
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                // RSVP near top — primary action
                                Text(
                                  'Your response',
                                  style: PortalTheme.sectionTitle.copyWith(
                                    fontSize: 14,
                                    color: const Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                IgnorePointer(
                                  ignoring: busy,
                                  child: Opacity(
                                    opacity: busy ? 0.55 : 1,
                                    child: EventRsvpBar(
                                      expanded: true,
                                      selected: status,
                                      goingEnabled: _goingEnabled(
                                        currentEvent,
                                      ),
                                      onChanged: handleRsvp,
                                    ),
                                  ),
                                ),
                                if (_constraintLabels(currentEvent)
                                    .isNotEmpty) ...[
                                  const SizedBox(height: 10),
                                  _buildConstraintLabels(currentEvent),
                                ],
                                const SizedBox(height: 18),
                                _detailMetaCard(
                                  children: [
                                    _detailMetaRow(
                                      Icons.calendar_today_outlined,
                                      'Date',
                                      DateFormat(
                                        'EEEE, MMMM d, yyyy',
                                      ).format(currentEvent.date),
                                    ),
                                    _detailMetaDivider(),
                                    _detailMetaRow(
                                      Icons.access_time_rounded,
                                      'Time',
                                      formatAlumniEventTimeRange(
                                        currentEvent.startTime,
                                        currentEvent.endTime,
                                      ),
                                    ),
                                    _detailMetaDivider(),
                                    _detailMetaRow(
                                      Icons.location_on_outlined,
                                      'Venue',
                                      currentEvent.venue.trim().isEmpty
                                          ? 'Venue TBA'
                                          : currentEvent.venue,
                                      trailing: TextButton(
                                        onPressed: () =>
                                            openEventVenueInMaps(currentEvent),
                                        style: TextButton.styleFrom(
                                          foregroundColor: PortalTheme.navyMid,
                                          visualDensity: VisualDensity.compact,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 4,
                                          ),
                                        ),
                                        child: Text(
                                          currentEvent.hasVenuePin
                                              ? 'Open pinned location'
                                              : 'Open in Maps',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ),
                                    _detailMetaDivider(),
                                    _detailMetaRow(
                                      Icons.groups_outlined,
                                      'Responses',
                                      '${counts.going} Going · ${counts.interested} Interested',
                                    ),
                                    if (currentEvent.capacity != null &&
                                        currentEvent.capacity! > 0) ...[
                                      _detailMetaDivider(),
                                      _detailMetaRow(
                                        Icons.event_seat_outlined,
                                        'Capacity',
                                        '${currentEvent.seatsRemaining(counts.going) ?? 0} of ${currentEvent.capacity} seats left',
                                      ),
                                    ],
                                    if (currentEvent.registrationDeadline !=
                                        null) ...[
                                      _detailMetaDivider(),
                                      _detailMetaRow(
                                        Icons.hourglass_bottom_outlined,
                                        'Registration',
                                        currentEvent.isRegistrationOpen
                                            ? 'Open until ${DateFormat('MMM d, yyyy').format(currentEvent.registrationDeadline!)}'
                                            : 'Closed',
                                      ),
                                    ],
                                  ],
                                ),
                                if (currentEvent.description.isNotEmpty) ...[
                                  const SizedBox(height: 20),
                                  Text(
                                    'About',
                                    style: PortalTheme.sectionTitle.copyWith(
                                      fontSize: 15,
                                      color: const Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    currentEvent.description,
                                    style: PortalTheme.body.copyWith(
                                      fontSize: 14,
                                      height: 1.55,
                                      color: PortalTheme.textSecondary,
                                    ),
                                  ),
                                ],
                                if (currentEvent.agenda.isNotEmpty) ...[
                                  const SizedBox(height: 20),
                                  Text(
                                    'Agenda',
                                    style: PortalTheme.sectionTitle.copyWith(
                                      fontSize: 15,
                                      color: const Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  ...currentEvent.agenda.map(
                                    (item) => Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 10,
                                      ),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          SizedBox(
                                            width: 56,
                                            child: Text(
                                              item.time,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w800,
                                                color: Color(0xFF0F172A),
                                              ),
                                            ),
                                          ),
                                          Container(
                                            width: 8,
                                            height: 8,
                                            margin: const EdgeInsets.only(
                                              top: 4,
                                            ),
                                            decoration: const BoxDecoration(
                                              color: _gold,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              item.title,
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: Colors.grey.shade800,
                                                fontWeight: FontWeight.w500,
                                                height: 1.35,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 24),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Sticky comments CTA
                    Container(
                      padding: EdgeInsets.fromLTRB(
                        16,
                        10,
                        16,
                        10 + MediaQuery.paddingOf(context).bottom,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border(
                          top: BorderSide(
                            color: PortalTheme.border.withValues(alpha: 0.9),
                          ),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFF0F172A,
                            ).withValues(alpha: 0.06),
                            blurRadius: 12,
                            offset: const Offset(0, -4),
                          ),
                        ],
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: openComments,
                          icon: const Icon(Icons.forum_outlined, size: 18),
                          label: Text(
                            currentEvent.comments == 0
                                ? 'Discuss'
                                : 'Discuss (${currentEvent.comments})',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: PortalTheme.navy,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                PortalTheme.radiusMd,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _detailMetaCard({required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(PortalTheme.radiusXl),
        border: Border.all(color: PortalTheme.border.withValues(alpha: 0.85)),
        boxShadow: PortalTheme.softShadow,
      ),
      child: Column(children: children),
    );
  }

  Widget _detailMetaDivider() {
    return Divider(
      height: 1,
      thickness: 1,
      color: PortalTheme.border.withValues(alpha: 0.7),
    );
  }

  Widget _detailMetaRow(
    IconData icon,
    String label,
    String value, {
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: PortalTheme.surfaceMuted,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 18, color: const Color(0xFF0F172A)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: PortalTheme.caption.copyWith(
                    fontWeight: FontWeight.w600,
                    color: PortalTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: PortalTheme.meta.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  Future<void> _showCommentsDialog(
    AlumniEvent event, {
    ValueChanged<int>? onCommentsChanged,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CommentsDialog(
        event: event,
        commentService: _commentService,
        onCommentsChanged: (count) {
          onCommentsChanged?.call(count);
          _loadEvents();
        },
      ),
    );
  }
}

class _CommentsDialog extends StatefulWidget {
  final AlumniEvent event;
  final EventCommentService commentService;
  final ValueChanged<int> onCommentsChanged;

  const _CommentsDialog({
    required this.event,
    required this.commentService,
    required this.onCommentsChanged,
  });

  @override
  State<_CommentsDialog> createState() => _CommentsDialogState();
}

class _CommentsDialogState extends State<_CommentsDialog> {
  final TextEditingController _commentController = TextEditingController();
  bool _isSubmitting = false;
  String? _editingCommentId;
  final TextEditingController _editController = TextEditingController();
  List<EventComment> _comments = [];
  final Map<String, List<EventComment>> _repliesByComment = {};
  bool _loadingComments = true;
  String? _loadError;

  static const _navy = Color(0xFF090A4F);
  static const _gold = Color(0xFFFFD700);

  @override
  void initState() {
    super.initState();
    _reloadComments();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _editController.dispose();
    super.dispose();
  }

  Future<void> _reloadComments() async {
    setState(() {
      _loadingComments = true;
      _loadError = null;
    });
    try {
      final comments = await widget.commentService.getComments(widget.event.id);
      final replies = <String, List<EventComment>>{};
      for (final c in comments) {
        try {
          replies[c.id] = await widget.commentService.getReplies(
            widget.event.id,
            c.id,
          );
        } catch (_) {
          replies[c.id] = const [];
        }
      }
      if (!mounted) return;
      setState(() {
        _comments = comments;
        _repliesByComment
          ..clear()
          ..addAll(replies);
        _loadingComments = false;
      });
      widget.onCommentsChanged(comments.length);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingComments = false;
        _loadError = e.toString();
      });
    }
  }

  Future<void> _submitComment() async {
    if (_commentController.text.trim().isEmpty) return;
    setState(() => _isSubmitting = true);
    try {
      await widget.commentService.createComment(
        eventId: widget.event.id,
        comment: _commentController.text,
      );
      _commentController.clear();
      await _reloadComments();
      widget.onCommentsChanged(_comments.length);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Comment added successfully'),
            backgroundColor: Color(0xFF4CAF50),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding comment: $e'),
            backgroundColor: const Color(0xFFFF6B6B),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _updateComment(String commentId) async {
    if (_editController.text.trim().isEmpty) {
      setState(() {
        _editingCommentId = null;
        _editController.clear();
      });
      return;
    }
    try {
      await widget.commentService.updateComment(
        eventId: widget.event.id,
        commentId: commentId,
        newComment: _editController.text,
      );
      setState(() {
        _editingCommentId = null;
        _editController.clear();
      });
      await _reloadComments();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Comment updated successfully'),
            backgroundColor: Color(0xFF4CAF50),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating comment: $e'),
            backgroundColor: const Color(0xFFFF6B6B),
          ),
        );
      }
    }
  }

  Future<void> _deleteComment(String commentId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Comment'),
        content: const Text('Are you sure you want to delete this comment?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFFF6B6B),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await widget.commentService.deleteComment(
          eventId: widget.event.id,
          commentId: commentId,
        );
        await _reloadComments();
        widget.onCommentsChanged(_comments.length);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Comment deleted successfully'),
              backgroundColor: Color(0xFF4CAF50),
              duration: Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting comment: $e'),
              backgroundColor: const Color(0xFFFF6B6B),
            ),
          );
        }
      }
    }
  }

  bool _canEditDelete(EventComment comment) {
    final userId = AppSession.userId;
    if (userId == null) return false;
    return comment.userId == userId;
  }

  Widget _buildAvatar(
    EventComment comment, {
    double radius = 14,
    Color background = _navy,
    Color foreground = Colors.white,
  }) {
    final provider = AppImage.provider(comment.profileImageUrl);
    if (provider != null) {
      return CircleAvatar(radius: radius, backgroundImage: provider);
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: background,
      child: Text(
        comment.userName.isNotEmpty ? comment.userName[0].toUpperCase() : '?',
        style: TextStyle(
          color: foreground,
          fontSize: radius * 0.78,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildReplies(EventComment comment) {
    final replies = _repliesByComment[comment.id] ?? const <EventComment>[];
    if (replies.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        const SizedBox(height: 8),
        ...replies.map(
          (reply) => Container(
            margin: const EdgeInsets.only(left: 22, bottom: 6),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _navy.withValues(alpha: 0.18)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildAvatar(
                  reply,
                  radius: 12,
                  background: _gold,
                  foreground: _navy,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            reply.userName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                              color: _navy,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: _gold.withValues(alpha: 0.22),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'Admin',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: _navy,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(reply.comment, style: const TextStyle(fontSize: 12)),
                      const SizedBox(height: 2),
                      Text(
                        _formatDate(reply.createdAt),
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade500,
                        ),
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

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.forum_outlined, color: _navy, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Comments',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: _navy,
                          ),
                        ),
                        Text(
                          widget.event.theme,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loadingComments
                  ? const CommentListSkeleton()
                  : _loadError != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.wifi_off_rounded,
                              size: 40,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Could not load comments',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextButton.icon(
                              onPressed: _reloadComments,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Try again'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : _comments.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.comment_outlined,
                            size: 48,
                            color: Colors.grey.shade300,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No comments yet',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Be the first to ask a question!',
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _reloadComments,
                      child: ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                        itemCount: _comments.length,
                        itemBuilder: (context, index) {
                          final comment = _comments[index];
                          final isEditing = _editingCommentId == comment.id;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8F9FA),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    _buildAvatar(comment),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            comment.userName,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 13,
                                            ),
                                          ),
                                          Text(
                                            _formatDate(comment.createdAt),
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (_canEditDelete(comment))
                                      PopupMenuButton(
                                        icon: const Icon(
                                          Icons.more_vert,
                                          size: 18,
                                          color: Colors.grey,
                                        ),
                                        itemBuilder: (context) => [
                                          PopupMenuItem(
                                            onTap: () {
                                              Future.delayed(
                                                const Duration(
                                                  milliseconds: 100,
                                                ),
                                                () {
                                                  setState(() {
                                                    _editingCommentId =
                                                        comment.id;
                                                    _editController.text =
                                                        comment.comment;
                                                  });
                                                },
                                              );
                                            },
                                            child: const Row(
                                              children: [
                                                Icon(Icons.edit, size: 16),
                                                SizedBox(width: 8),
                                                Text('Edit'),
                                              ],
                                            ),
                                          ),
                                          PopupMenuItem(
                                            onTap: () {
                                              Future.delayed(
                                                const Duration(
                                                  milliseconds: 100,
                                                ),
                                                () =>
                                                    _deleteComment(comment.id),
                                              );
                                            },
                                            child: const Row(
                                              children: [
                                                Icon(
                                                  Icons.delete,
                                                  size: 16,
                                                  color: Color(0xFFFF6B6B),
                                                ),
                                                SizedBox(width: 8),
                                                Text(
                                                  'Delete',
                                                  style: TextStyle(
                                                    color: Color(0xFFFF6B6B),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                if (isEditing)
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      TextField(
                                        controller: _editController,
                                        maxLines: 3,
                                        style: const TextStyle(fontSize: 13),
                                        decoration: InputDecoration(
                                          hintText: 'Edit your comment…',
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          contentPadding: const EdgeInsets.all(
                                            10,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.end,
                                        children: [
                                          TextButton(
                                            onPressed: () {
                                              setState(() {
                                                _editingCommentId = null;
                                                _editController.clear();
                                              });
                                            },
                                            child: const Text('Cancel'),
                                          ),
                                          ElevatedButton(
                                            onPressed: () =>
                                                _updateComment(comment.id),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: _navy,
                                            ),
                                            child: const Text('Save'),
                                          ),
                                        ],
                                      ),
                                    ],
                                  )
                                else
                                  Text(
                                    comment.comment,
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                if (comment.updatedAt != null &&
                                    comment.updatedAt != comment.createdAt)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Text(
                                      'Edited ${_formatDate(comment.updatedAt!)}',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey.shade500,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ),
                                _buildReplies(comment),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
            ),
            Container(
              padding: EdgeInsets.fromLTRB(
                12,
                10,
                12,
                10 + MediaQuery.of(context).viewInsets.bottom,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      maxLines: null,
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Ask a question or share a thought…',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(22),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _isSubmitting ? null : _submitComment,
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_rounded, size: 20),
                    color: _navy,
                    style: IconButton.styleFrom(
                      backgroundColor: _navy.withValues(alpha: 0.08),
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

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) return 'Just now';
        return '${difference.inMinutes}m ago';
      }
      return '${difference.inHours}h ago';
    }
    if (difference.inDays == 1) return 'Yesterday';
    if (difference.inDays < 7) return '${difference.inDays}d ago';
    return DateFormat('MMM d, yyyy').format(date);
  }
}
