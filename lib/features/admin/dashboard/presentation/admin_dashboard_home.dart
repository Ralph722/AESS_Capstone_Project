import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:alumni_system/features/events/models/event_model.dart';
import 'package:alumni_system/features/admin/activity/models/audit_log_model.dart';
import 'package:alumni_system/features/admin/dashboard/application/admin_dashboard_metrics.dart';
import 'package:alumni_system/features/admin/dashboard/widgets/admin_dashboard_widgets.dart';
import 'package:alumni_system/shared/widgets/admin/admin_density.dart';
import 'package:alumni_system/shared/widgets/admin/admin_skeletons.dart';
import 'package:alumni_system/features/admin/dashboard/application/dashboard_activity_trend.dart';
import 'package:alumni_system/features/admin/dashboard/widgets/dashboard_engagement_chart.dart';

class AdminDashboardHome extends StatelessWidget {
  const AdminDashboardHome({
    super.key,
    required this.isLoading,
    required this.metrics,
    required this.activeEvents,
    required this.recentActivity,
    required this.activityTrend,
    required this.onMenuSelected,
    required this.onRefresh,
  });

  final bool isLoading;
  final AdminDashboardMetrics metrics;
  final List<AlumniEvent> activeEvents;
  final List<AuditLog> recentActivity;
  final DashboardActivityTrend activityTrend;
  final ValueChanged<int> onMenuSelected;
  final Future<void> Function() onRefresh;

  static const _navy = Color(0xFF090A4F);
  static const _gold = Color(0xFFFFD700);

  bool get _showInitialSkeleton =>
      isLoading && activeEvents.isEmpty && recentActivity.isEmpty;

  @override
  Widget build(BuildContext context) {
    if (_showInitialSkeleton) {
      return RefreshIndicator(
        color: _navy,
        onRefresh: onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 16),
          children: const [AdminDashboardHomeSkeleton()],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= AdminDensity.desktopSplitMin;
        final tallEnough = constraints.maxHeight >= 520;

        if (wide && tallEnough && constraints.maxHeight.isFinite) {
          // SizedBox gives bounded height so Column/Expanded layout works.
          // ListView (not SliverFillRemaining) keeps RefreshIndicator working.
          return RefreshIndicator(
            color: _navy,
            onRefresh: onRefresh,
            child: ListView(
              // Let scroll wheels reach nested panels (Community, etc.).
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              children: [
                SizedBox(
                  height: constraints.maxHeight,
                  child: _buildSingleScreenLayout(),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          color: _navy,
          onRefresh: onRefresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 16),
            children: [
              _buildCompactHeader(),
              const SizedBox(height: 10),
              _buildKpiRow(),
              const SizedBox(height: 12),
              _buildEngagementDense(),
              const SizedBox(height: 12),
              _buildCommunityChips(),
              const SizedBox(height: 12),
              _buildQuickActionsGrid(crossAxisCount: 4),
              const SizedBox(height: 12),
              _buildFeedPanels(maxActivity: 4, maxEvents: 3),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSingleScreenLayout() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildCompactHeader(),
        const SizedBox(height: 8),
        _buildKpiRow(),
        const SizedBox(height: 10),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 5,
                child: Column(
                  children: [
                    Expanded(
                      flex: 2,
                      child: _buildEngagementDense(expand: true),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      flex: 3,
                      child: _buildCommunityPanel(expand: true),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 4,
                child: _buildQuickActionsGrid(crossAxisCount: 4, fill: true),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 5,
                child: _buildFeedPanels(
                  maxActivity: 3,
                  maxEvents: 2,
                  expand: true,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCompactHeader() {
    final m = metrics;
    final dateStr = DateFormat('EEE, MMM d').format(DateTime.now());

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF090A4F), Color(0xFF1A2B6B)],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dateStr,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Dashboard overview',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          _headerStat('${m.rosterTotal}', 'Roster', Icons.groups_outlined),
          const SizedBox(width: 8),
          _headerStat(
            '${m.registeredOnRoster}',
            'Registered',
            Icons.how_to_reg,
          ),
          const SizedBox(width: 8),
          _headerStat(
            '${(m.surveyResponseRate * 100).toStringAsFixed(0)}%',
            'Surveys',
            Icons.poll_outlined,
          ),
        ],
      ),
    );
  }

  Widget _headerStat(String value, String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: _gold),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKpiRow() {
    final m = metrics;
    final cards = [
      DashboardCompactKpi(
        label: 'Alumni roster',
        value: m.rosterTotal.toString(),
        hint:
            '${m.registeredOnRoster} registered · ${m.unclaimedRoster} unclaimed',
        icon: Icons.people_outline,
        accent: Colors.indigo,
        onTap: () => onMenuSelected(2),
      ),
      DashboardCompactKpi(
        label: 'Tracer complete',
        value: '${(m.tracerCompletionRate * 100).toStringAsFixed(0)}%',
        hint:
            '${m.tracerCompleteCount} of ${m.registeredOnRoster} registered alumni',
        icon: Icons.assignment_turned_in_outlined,
        accent: Colors.teal,
        onTap: () => onMenuSelected(9),
      ),
      DashboardCompactKpi(
        label: 'Survey completion',
        value: '${(m.surveyResponseRate * 100).toStringAsFixed(0)}%',
        hint:
            '${m.totalSurveyResponses} of ${m.totalSurveyAssignments} responses',
        icon: Icons.poll_outlined,
        accent: _navy,
        onTap: () => onMenuSelected(10),
      ),
      DashboardCompactKpi(
        label: 'Employment records',
        value: m.employmentSubmissions.toString(),
        hint: 'Tracer employment submissions',
        icon: Icons.work_history_outlined,
        accent: Colors.green,
        onTap: () => onMenuSelected(9),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final fourAcross =
            constraints.maxWidth >= AdminDensity.statsFourColMin;
        if (fourAcross) {
          return Row(
            children: [
              for (var i = 0; i < cards.length; i++) ...[
                if (i > 0) const SizedBox(width: AdminDensity.gridGap),
                Expanded(child: cards[i]),
              ],
            ],
          );
        }

        // 2×2 on laptop content widths so KPIs stay readable without overflow.
        return Column(
          children: [
            Row(
              children: [
                Expanded(child: cards[0]),
                const SizedBox(width: AdminDensity.gridGap),
                Expanded(child: cards[1]),
              ],
            ),
            const SizedBox(height: AdminDensity.gridGap),
            Row(
              children: [
                Expanded(child: cards[2]),
                const SizedBox(width: AdminDensity.gridGap),
                Expanded(child: cards[3]),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildEngagementDense({bool expand = false}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        child: expand
            ? DashboardEngagementTrendChart(
                trend: activityTrend,
                isLoading: isLoading,
                expand: true,
                onViewReports: () => onMenuSelected(9),
              )
            : SizedBox(
                height: 220,
                child: DashboardEngagementTrendChart(
                  trend: activityTrend,
                  isLoading: isLoading,
                  expand: true,
                  onViewReports: () => onMenuSelected(9),
                ),
              ),
      ),
    );
  }

  Widget _buildCommunityPanel({bool expand = false}) {
    final m = metrics;
    final chips = <(String, String, IconData, Color, int)>[
      ('Events', '${m.activeEventsCount}', Icons.event, Colors.blue, 1),
      (
        'Upcoming',
        '${m.upcomingEventsCount}',
        Icons.event_available,
        Colors.orange,
        1,
      ),
      ('Jobs', '${m.activeJobs}', Icons.work_outline, Colors.green, 5),
      (
        'Announcements',
        '${m.publishedAnnouncements}',
        Icons.campaign_outlined,
        Colors.deepOrange,
        11,
      ),
      ('Forum', '${m.forumTopics}', Icons.forum_outlined, Colors.brown, 12),
      (
        'Registered',
        '${m.registeredOnRoster}',
        Icons.account_circle_outlined,
        Colors.deepPurple,
        2,
      ),
    ];

    List<Widget> chipTiles() {
      return chips
          .map(
            (c) => DashboardStatChip(
              label: c.$1,
              value: c.$2,
              icon: c.$3,
              color: c.$4,
              onTap: () => onMenuSelected(c.$5),
            ),
          )
          .toList();
    }

    const crossAxisCount = 2;
    const spacing = 8.0;
    const rowCount = 3;

    Widget communityGrid({
      required double width,
      required double height,
      required bool fillHeight,
    }) {
      final cellWidth = (width - spacing) / crossAxisCount;
      final cellHeight = (height - spacing * (rowCount - 1)) / rowCount;
      final aspectRatio = cellWidth / cellHeight.clamp(1.0, double.infinity);

      return GridView.count(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: spacing,
        crossAxisSpacing: spacing,
        shrinkWrap: !fillHeight,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: aspectRatio,
        children: chipTiles(),
      );
    }

    final body = expand
        ? LayoutBuilder(
            builder: (context, constraints) {
              return communityGrid(
                width: constraints.maxWidth,
                height: constraints.maxHeight,
                fillHeight: true,
              );
            },
          )
        : LayoutBuilder(
            builder: (context, constraints) {
              const minCellHeight = 34.0;
              final height =
                  minCellHeight * rowCount + spacing * (rowCount - 1);
              return SizedBox(
                height: height,
                child: communityGrid(
                  width: constraints.maxWidth,
                  height: height,
                  fillHeight: true,
                ),
              );
            },
          );

    return DashboardPanel(
      dense: true,
      expandBody: expand,
      title: 'Community',
      icon: Icons.hub_outlined,
      child: body,
    );
  }

  Widget _buildCommunityChips() {
    return _buildCommunityPanel();
  }

  Widget _buildQuickActionsGrid({
    required int crossAxisCount,
    bool fill = false,
  }) {
    return DashboardPanel(
      dense: true,
      expandBody: fill,
      title: 'Quick actions',
      icon: Icons.bolt_outlined,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Prefer slightly taller cells when the panel is short so labels fit.
          final aspectRatio = fill
              ? (constraints.maxHeight.isFinite && constraints.maxHeight < 200
                    ? 0.95
                    : 1.05)
              : 1.15;
          return GridView.count(
            crossAxisCount: crossAxisCount,
            shrinkWrap: !fill,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: aspectRatio,
            children: [
              _quickTile('Roster', Icons.people, Colors.indigo, 2),
              _quickTile('Surveys', Icons.poll_outlined, _navy, 10),
              _quickTile('Reports', Icons.bar_chart, Colors.teal, 9),
              _quickTile('Events', Icons.event, Colors.blue, 1),
              _quickTile('Messages', Icons.mail_outline, Colors.pink, 6),
              _quickTile('Announce', Icons.campaign_outlined, Colors.orange, 11),
              _quickTile('Forum', Icons.forum_outlined, Colors.brown, 12),
              _quickTile(
                'Feedback',
                Icons.feedback_outlined,
                Colors.redAccent,
                14,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _quickTile(String label, IconData icon, Color color, int menuIndex) {
    return Material(
      color: color.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: () => onMenuSelected(menuIndex),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 22),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 1.1,
                    color: color.withValues(alpha: 0.95),
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeedPanels({
    required int maxActivity,
    required int maxEvents,
    bool expand = false,
  }) {
    final upcoming = _upcomingEvents();

    final activityPanel = DashboardPanel(
      dense: true,
      expandBody: expand,
      title: 'Recent activity',
      icon: Icons.history,
      trailing: TextButton(
        onPressed: () => onMenuSelected(7),
        style: TextButton.styleFrom(
          padding: EdgeInsets.zero,
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: const Text('All', style: TextStyle(fontSize: 13)),
      ),
      child: recentActivity.isEmpty
          ? Text(
              'No activity yet',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
            )
          : Column(
              children: recentActivity
                  .take(maxActivity)
                  .map(_activityRowCompact)
                  .toList(),
            ),
    );

    final eventsPanel = DashboardPanel(
      dense: true,
      expandBody: expand,
      title: 'Upcoming events',
      icon: Icons.calendar_month_outlined,
      trailing: TextButton(
        onPressed: () => onMenuSelected(1),
        style: TextButton.styleFrom(
          padding: EdgeInsets.zero,
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: const Text('All', style: TextStyle(fontSize: 13)),
      ),
      child: upcoming.isEmpty
          ? Text(
              'No upcoming events',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
            )
          : Column(
              children: upcoming.take(maxEvents).map(_eventRowCompact).toList(),
            ),
    );

    if (expand) {
      return Column(
        children: [
          Expanded(child: activityPanel),
          const SizedBox(height: 8),
          Expanded(child: eventsPanel),
        ],
      );
    }

    return Column(
      children: [activityPanel, const SizedBox(height: 10), eventsPanel],
    );
  }

  List<AlumniEvent> _upcomingEvents() {
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    return activeEvents.where((e) {
      final d = DateTime(e.date.year, e.date.month, e.date.day);
      return !d.isBefore(todayStart);
    }).toList()..sort((a, b) => a.date.compareTo(b.date));
  }

  Widget _activityRowCompact(AuditLog log) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 5),
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: _navy.withValues(alpha: 0.35),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              log.description.isNotEmpty
                  ? log.description
                  : '${log.action} ${log.resource}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: _navy,
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            DateFormat('MMM d').format(log.timestamp),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _eventRowCompact(AlumniEvent event) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 44,
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: _navy.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Text(
                  DateFormat('MMM').format(event.date).toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: _navy.withValues(alpha: 0.7),
                  ),
                ),
                Text(
                  DateFormat('d').format(event.date),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _navy,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              event.theme,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _navy,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
