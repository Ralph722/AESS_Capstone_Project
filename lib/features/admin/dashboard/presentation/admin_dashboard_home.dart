import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:alumni_system/features/events/models/event_model.dart';
import 'package:alumni_system/features/admin/activity/models/audit_log_model.dart';
import 'package:alumni_system/features/admin/dashboard/application/admin_dashboard_metrics.dart';
import 'package:alumni_system/features/admin/dashboard/application/dashboard_insights.dart';
import 'package:alumni_system/features/admin/dashboard/widgets/admin_dashboard_widgets.dart';
import 'package:alumni_system/shared/widgets/admin/admin_density.dart';
import 'package:alumni_system/shared/widgets/admin/admin_kpi_card.dart';
import 'package:alumni_system/shared/widgets/admin/admin_page_header.dart';
import 'package:alumni_system/shared/widgets/admin/admin_skeletons.dart';
import 'package:alumni_system/shared/widgets/admin/admin_state_view.dart';
import 'package:alumni_system/features/admin/dashboard/application/dashboard_activity_trend.dart';
import 'package:alumni_system/features/admin/dashboard/widgets/dashboard_engagement_chart.dart';
import 'package:alumni_system/features/alumni/card/presentation/alumni_card_verify_dialog.dart';
import 'package:alumni_system/shared/widgets/admin/admin_theme.dart';

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
    this.metricsLoaded = true,
    this.metricsFailed = false,
    this.feedsFailed = false,
    this.insights,
    this.insightsFailed = false,
    this.adminName,
    this.lastUpdated,
    this.now,
  });

  final bool isLoading;
  final AdminDashboardMetrics metrics;
  final List<AlumniEvent> activeEvents;
  final List<AuditLog> recentActivity;
  final DashboardActivityTrend activityTrend;
  final ValueChanged<int> onMenuSelected;

  /// Reloads everything; used by pull-to-refresh and the "Try again" links.
  final Future<void> Function() onRefresh;

  /// False until the first metrics load succeeds; figures show "—" meanwhile.
  final bool metricsLoaded;

  /// The metrics load failed before any figures were loaded.
  final bool metricsFailed;

  /// The last events/activity load failed.
  final bool feedsFailed;

  /// Tracer, employment, program, survey and Program Insights figures; null
  /// until the first load finishes.
  final DashboardInsights? insights;

  /// The last insights load failed.
  final bool insightsFailed;

  /// Signed-in admin's display name; the greeting omits it when null.
  final String? adminName;

  /// When the figures last finished loading; null before the first load.
  final DateTime? lastUpdated;

  /// Fixed clock for tests; defaults to the current time.
  final DateTime? now;

  /// Content width needed for the no-scroll grid (three cards per row).
  static const double singleScreenMinWidth = 1000;
  static const double singleScreenMinHeight = 520;

  /// Days ahead covered by "Upcoming & deadlines".
  static const int agendaWindowDays = 30;

  static const _gap = AdminDensity.gridGap;
  static const _placeholder = '—';

  bool get _showInitialSkeleton =>
      isLoading && activeEvents.isEmpty && recentActivity.isEmpty;

  DateTime get _now => now ?? DateTime.now();

  String _metric(String value) => metricsLoaded ? value : _placeholder;

  String? get _metricsStatus =>
      metricsLoaded ? null : (metricsFailed ? "Couldn't load" : 'Loading…');

  String? get _insightsStatus =>
      insights != null ? null : (insightsFailed ? "Couldn't load" : 'Loading…');

  static String _pct(double? rate) =>
      rate == null ? _placeholder : '${(rate * 100).toStringAsFixed(0)}%';

  @override
  Widget build(BuildContext context) {
    if (_showInitialSkeleton) {
      return RefreshIndicator(
        color: AdminColors.primary,
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
        final singleScreen =
            constraints.maxWidth >= singleScreenMinWidth &&
            constraints.maxHeight.isFinite &&
            constraints.maxHeight >= singleScreenMinHeight;

        if (singleScreen) {
          // SizedBox gives bounded height so Column/Expanded layout works.
          // ListView (not SliverFillRemaining) keeps RefreshIndicator working.
          return RefreshIndicator(
            color: AdminColors.primary,
            onRefresh: onRefresh,
            child: ListView(
              // Let scroll wheels reach nested panels (activity, agenda).
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              children: [
                SizedBox(
                  height: constraints.maxHeight,
                  child: _buildSingleScreenLayout(
                    denseKpis: constraints.maxHeight < 800,
                  ),
                ),
              ],
            ),
          );
        }

        final twoColumn = constraints.maxWidth >= 700;
        return RefreshIndicator(
          color: AdminColors.primary,
          onRefresh: onRefresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 16),
            children: [
              _buildPageHeader(),
              const SizedBox(height: _gap),
              _buildKpiRow(dense: true),
              const SizedBox(height: _gap),
              _buildChart(),
              const SizedBox(height: _gap),
              _pair(
                twoColumn,
                _buildActivityPanel(maxRows: 4),
                _buildAgendaPanel(maxRows: 5),
              ),
              const SizedBox(height: _gap),
              _pair(twoColumn, _buildProgramsPanel(), _buildSurveysPanel()),
            ],
          ),
        );
      },
    );
  }

  Widget _pair(bool sideBySide, Widget a, Widget b) {
    if (!sideBySide) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          a,
          const SizedBox(height: _gap),
          b,
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: a),
        const SizedBox(width: _gap),
        Expanded(child: b),
      ],
    );
  }

  Widget _buildSingleScreenLayout({required bool denseKpis}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildPageHeader(),
        const SizedBox(height: _gap),
        _buildKpiRow(dense: denseKpis),
        const SizedBox(height: _gap),
        Expanded(
          child: LayoutBuilder(
            builder: (context, box) {
              final bottomHeight = bottomRowHeight(box.maxHeight - _gap);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(flex: 2, child: _buildChart(expand: true)),
                        const SizedBox(width: _gap),
                        Expanded(child: _buildActivityPanel(expand: true)),
                      ],
                    ),
                  ),
                  const SizedBox(height: _gap),
                  SizedBox(
                    height: bottomHeight,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: _buildProgramsPanel(expand: true)),
                        const SizedBox(width: _gap),
                        Expanded(child: _buildSurveysPanel(expand: true)),
                        const SizedBox(width: _gap),
                        Expanded(child: _buildAgendaPanel(expand: true)),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  /// Bottom card row: ~45% of the two lower rows, 200–260px, never more than
  /// half; extra height on tall screens goes to the chart and activity list.
  @visibleForTesting
  static double bottomRowHeight(double rowsHeight) {
    final preferred = (rowsHeight * 0.45).clamp(200.0, 260.0);
    return preferred < rowsHeight * 0.5 ? preferred : rowsHeight * 0.5;
  }

  /// "Good morning, Ana" — first name only; time of day from [now].
  @visibleForTesting
  static String greeting(DateTime now, String? name) {
    final part = now.hour < 12
        ? 'morning'
        : now.hour < 18
        ? 'afternoon'
        : 'evening';
    final first = name?.trim().split(RegExp(r'\s+')).first ?? '';
    return first.isEmpty ? 'Good $part' : 'Good $part, $first';
  }

  Widget _buildPageHeader() {
    return AdminPageHeader(
      title: greeting(_now, adminName),
      subtitle:
          'Dashboard overview · ${DateFormat('EEEE, MMMM d').format(_now)}',
      actions: [
        Builder(
          builder: (context) => OutlinedButton.icon(
            onPressed: () => showAlumniCardVerifyDialog(context),
            icon: const Icon(Icons.qr_code_scanner_rounded, size: 16),
            label: const Text('Verify card'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AdminColors.primary,
              backgroundColor: AdminColors.surface,
              side: const BorderSide(color: AdminColors.border),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: const Size(0, 32),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AdminSurfaces.radiusSm),
              ),
              textStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        DashboardLiveIndicator(updatedAt: lastUpdated),
      ],
    );
  }

  Widget _buildKpiRow({required bool dense}) {
    final m = metrics;
    final i = insights;
    final insightsStatus = _insightsStatus;
    final cards = [
      AdminKpiCard(
        label: 'Alumni registered',
        value: _metric(_pct(m.rosterTotal == 0 ? null : m.registrationRate)),
        caption:
            _metricsStatus ??
            '${m.registeredOnRoster} of ${m.rosterTotal} on the roster',
        icon: Icons.how_to_reg_outlined,
        palette: AdminAccents.blue,
        dense: dense,
        onTap: () => onMenuSelected(2),
      ),
      AdminKpiCard(
        label: 'Tracer response',
        value: i == null ? _placeholder : _pct(i.tracerRate),
        caption:
            insightsStatus ??
            '${i!.tracerResponded} of ${i.registered} registered alumni',
        pill: _tracerPill(i),
        icon: Icons.school_outlined,
        palette: AdminAccents.gold,
        dense: dense,
        onTap: () => onMenuSelected(9),
      ),
      AdminKpiCard(
        label: 'Employment rate',
        value: i == null ? _placeholder : _pct(i.employmentRate),
        caption:
            insightsStatus ??
            (i!.employmentRecords == 0
                ? 'No employment information yet'
                : '${i.employed} of ${i.employmentRecords} with employment '
                      'info'),
        icon: Icons.work_outline,
        palette: AdminAccents.blue,
        dense: dense,
        onTap: () => onMenuSelected(9),
      ),
      AdminKpiCard(
        label: 'Program Insights findings',
        value: i?.findingsActive?.toString() ?? _placeholder,
        caption:
            insightsStatus ??
            (i!.insightsAvailable
                ? '${i.findingsOpen} open · ${i.findingsInProgress} in progress'
                : "Couldn't load"),
        pill: _insightsPill(i),
        icon: Icons.lightbulb_outline,
        palette: AdminAccents.gold,
        dense: dense,
        onTap: () => onMenuSelected(15),
      ),
    ];

    Widget row(List<Widget> items) => IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(width: _gap),
            Expanded(child: items[i]),
          ],
        ],
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= AdminDensity.statsFourColMin) {
          return row(cards);
        }
        return Column(
          children: [
            row(cards.sublist(0, 2)),
            const SizedBox(height: _gap),
            row(cards.sublist(2)),
          ],
        );
      },
    );
  }

  AdminKpiPill? _tracerPill(DashboardInsights? i) {
    if (i == null) return null;
    if (i.currentTracerTitle == null) {
      return const AdminKpiPill('No tracer open');
    }
    final close = i.currentTracerCloseAt;
    if (close == null || close.isBefore(_now)) return null;
    final soon = close.difference(_now).inDays < 7;
    return AdminKpiPill(
      'Closes ${DateFormat('MMM d').format(close)}',
      tone: soon ? AdminTone.warning : AdminTone.neutral,
    );
  }

  AdminKpiPill? _insightsPill(DashboardInsights? i) {
    if (i == null || !i.insightsAvailable) return null;
    final overdue = i.actionsOverdue ?? 0;
    if (overdue > 0) {
      return AdminKpiPill('$overdue overdue', tone: AdminTone.danger);
    }
    final critical = i.findingsCritical ?? 0;
    if (critical > 0) {
      return AdminKpiPill('$critical critical', tone: AdminTone.warning);
    }
    return null;
  }

  Widget _buildChart({bool expand = false}) {
    return DashboardEngagementTrendChart(
      trend: activityTrend,
      isLoading: isLoading,
      failed: feedsFailed,
      onRetry: () => onRefresh(),
      expand: expand,
      chartHeight: 220,
      onViewReports: () => onMenuSelected(9),
    );
  }

  Widget? _insightsStateView() {
    if (insights != null) return null;
    if (insightsFailed) {
      return AdminStateView.error(
        title: "Couldn't load figures",
        onRetry: () => onRefresh(),
        compact: true,
      );
    }
    return const AdminStateView.loading(compact: true);
  }

  Widget _buildProgramsPanel({bool expand = false}) {
    final programs = insights?.programs ?? const <DashboardProgramStat>[];
    final Widget body;
    final state = _insightsStateView();
    if (state != null) {
      body = state;
    } else if (programs.isEmpty) {
      body = const AdminStateView.empty(
        title: 'No alumni on the roster yet',
        icon: Icons.school_outlined,
        compact: true,
      );
    } else {
      final rows = [for (final p in programs) _programRow(p)];
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _programHeaderRow(),
          if (expand)
            Expanded(
              child: ListView(padding: EdgeInsets.zero, children: rows),
            )
          else
            ...rows.take(6),
        ],
      );
    }

    return DashboardPanel(
      expandBody: expand,
      title: 'Programs at a glance',
      icon: Icons.account_tree_outlined,
      accent: AdminAccents.blue,
      trailing: DashboardViewAllButton(
        onPressed: () => onMenuSelected(9),
        semanticsLabel: 'View program figures in Reports',
      ),
      child: body,
    );
  }

  static const _programNumberWidths = (56.0, 78.0, 56.0);

  Widget _programHeaderRow() {
    const style = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      color: AdminColors.textMuted,
      letterSpacing: 0.2,
    );
    Widget cell(String text, double width) => SizedBox(
      width: width,
      child: Text(text, style: style, textAlign: TextAlign.right),
    );
    return ExcludeSemantics(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          children: [
            const Expanded(child: Text('PROGRAM', style: style)),
            cell('ALUMNI', _programNumberWidths.$1),
            cell('REGISTERED', _programNumberWidths.$2),
            cell('TRACER', _programNumberWidths.$3),
          ],
        ),
      ),
    );
  }

  Widget _programRow(DashboardProgramStat p) {
    const numberStyle = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: AdminColors.textPrimary,
    );
    Widget cell(String text, double width) => SizedBox(
      width: width,
      child: Text(text, style: numberStyle, textAlign: TextAlign.right),
    );
    Widget rateCell(double? rate, double width, AdminAccent accent) => SizedBox(
      width: width,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(_pct(rate), style: numberStyle, textAlign: TextAlign.right),
          const SizedBox(height: 3),
          SizedBox(
            width: 44,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: (rate ?? 0).clamp(0.0, 1.0),
                minHeight: 3,
                color: accent.color,
                backgroundColor: accent.tint,
              ),
            ),
          ),
        ],
      ),
    );
    final tracer = _pct(p.tracerRate);
    return Semantics(
      container: true,
      label:
          '${p.program}: ${p.alumni} alumni, '
          '${_pct(p.registrationRate)} registered, $tracer tracer response',
      excludeSemantics: true,
      child: SizedBox(
        height: 34,
        child: Row(
          children: [
            Expanded(
              child: Text(
                p.program,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AdminText.cardTitle,
              ),
            ),
            cell('${p.alumni}', _programNumberWidths.$1),
            rateCell(
              p.registrationRate,
              _programNumberWidths.$2,
              AdminAccents.blue,
            ),
            rateCell(p.tracerRate, _programNumberWidths.$3, AdminAccents.gold),
          ],
        ),
      ),
    );
  }

  Widget _buildSurveysPanel({bool expand = false}) {
    final Widget body;
    final state = _insightsStateView();
    if (state != null) {
      body = state;
    } else {
      final s = insights!.otherSurveys;
      final tiles = <(String, String, IconData, AdminAccent)>[
        (
          'Published',
          '${s.published}',
          Icons.campaign_outlined,
          AdminAccents.blue,
        ),
        ('Drafts', '${s.drafts}', Icons.edit_note, AdminAccents.gold),
        (
          'Response rate',
          _pct(s.responseRate),
          Icons.percent,
          AdminAccents.blue,
        ),
        (
          'Responses',
          '${s.submitted} of ${s.assigned}',
          Icons.inbox_outlined,
          AdminAccents.gold,
        ),
      ];
      final grid = LayoutBuilder(
        builder: (context, constraints) {
          const spacing = 6.0;
          final cellWidth = (constraints.maxWidth - spacing) / 2;
          return Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: [
              for (final (label, value, icon, accent) in tiles)
                SizedBox(
                  width: cellWidth,
                  child: DashboardStatTile(
                    label: label,
                    value: value,
                    icon: icon,
                    accent: accent,
                    showIcon: cellWidth >= 180,
                    onTap: () => onMenuSelected(10),
                  ),
                ),
              if (s.lowestTitle != null)
                DashboardStatTile(
                  label: 'Lowest: ${s.lowestTitle}',
                  value: _pct(s.lowestRate),
                  icon: Icons.trending_down,
                  accent: AdminAccents.gold,
                  onTap: () => onMenuSelected(10),
                ),
            ],
          );
        },
      );
      body = expand ? SingleChildScrollView(child: grid) : grid;
    }

    return DashboardPanel(
      expandBody: expand,
      title: 'Other surveys',
      icon: Icons.poll_outlined,
      accent: AdminAccents.gold,
      trailing: DashboardViewAllButton(
        onPressed: () => onMenuSelected(10),
        semanticsLabel: 'View all surveys',
      ),
      child: body,
    );
  }

  Widget _buildActivityPanel({bool expand = false, int maxRows = 8}) {
    final Widget body;
    if (feedsFailed && recentActivity.isEmpty) {
      body = AdminStateView.error(
        title: "Couldn't load recent activity",
        onRetry: () => onRefresh(),
        compact: true,
      );
    } else if (recentActivity.isEmpty) {
      body = const AdminStateView.empty(
        title: 'No activity yet',
        icon: Icons.history,
        compact: true,
      );
    } else if (expand) {
      body = ListView.builder(
        padding: EdgeInsets.zero,
        itemCount: recentActivity.length,
        itemBuilder: (context, i) => _activityRow(recentActivity[i]),
      );
    } else {
      body = Column(
        children: recentActivity.take(maxRows).map(_activityRow).toList(),
      );
    }

    return DashboardPanel(
      expandBody: expand,
      title: 'Recent activity',
      icon: Icons.history,
      accent: AdminAccents.blue,
      trailing: DashboardViewAllButton(
        onPressed: () => onMenuSelected(7),
        semanticsLabel: 'View all activity',
      ),
      child: body,
    );
  }

  Widget _buildAgendaPanel({bool expand = false, int maxRows = 8}) {
    final items = buildDashboardAgenda(
      events: feedsFailed ? const [] : activeEvents,
      deadlines: insights?.deadlines ?? const [],
      now: _now,
      windowDays: agendaWindowDays,
    );
    final missing = [
      if (feedsFailed) 'events',
      if (insightsFailed && insights == null) 'survey, job and insight dates',
    ];

    final Widget list;
    if (items.isEmpty) {
      if (missing.length == 2) {
        list = AdminStateView.error(
          title: "Couldn't load dates",
          onRetry: () => onRefresh(),
          compact: true,
        );
      } else if (insights == null && !insightsFailed) {
        list = const AdminStateView.loading(compact: true);
      } else {
        list = const AdminStateView.empty(
          title: 'Nothing due in the next 30 days',
          icon: Icons.event_available_outlined,
          compact: true,
        );
      }
    } else if (expand) {
      list = ListView.builder(
        padding: EdgeInsets.zero,
        itemCount: items.length,
        itemBuilder: (context, i) => _agendaRow(items[i]),
      );
    } else {
      list = Column(children: items.take(maxRows).map(_agendaRow).toList());
    }

    final showNote = missing.isNotEmpty && items.isNotEmpty;
    final Widget body = showNote
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (expand) Expanded(child: list) else list,
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  "Couldn't load ${missing.join(' or ')}.",
                  style: AdminText.caption.copyWith(color: AdminColors.danger),
                ),
              ),
            ],
          )
        : list;

    return DashboardPanel(
      expandBody: expand,
      title: 'Upcoming & deadlines',
      icon: Icons.event_note_outlined,
      accent: AdminAccents.gold,
      trailing: Text('Next $agendaWindowDays days', style: AdminText.caption),
      child: body,
    );
  }

  static IconData _agendaIcon(DashboardAgendaKind kind) => switch (kind) {
    DashboardAgendaKind.event => Icons.event,
    DashboardAgendaKind.eventRegistration => Icons.how_to_reg_outlined,
    DashboardAgendaKind.survey => Icons.poll_outlined,
    DashboardAgendaKind.tracer => Icons.school_outlined,
    DashboardAgendaKind.job => Icons.work_outline,
    DashboardAgendaKind.insightDue => Icons.flag_outlined,
    DashboardAgendaKind.insightReview => Icons.update,
  };

  static AdminAccent agendaAccent(DashboardAgendaKind kind) => switch (kind) {
    DashboardAgendaKind.event ||
    DashboardAgendaKind.eventRegistration => AdminAccents.blue,
    DashboardAgendaKind.survey => AdminAccents.sky,
    DashboardAgendaKind.tracer => AdminAccents.gold,
    DashboardAgendaKind.job => AdminAccents.orange,
    DashboardAgendaKind.insightDue ||
    DashboardAgendaKind.insightReview => AdminAccents.midBlue,
  };

  /// Activity dot colour by action: removals red, additions green, sign-in
  /// and password events sky, exports gold, everything else navy.
  @visibleForTesting
  static Color activityColor(String action) {
    final a = action.toUpperCase();
    bool has(List<String> words) => words.any(a.contains);
    if (has(['DELETE', 'REMOVE', 'DEACTIVAT', 'ARCHIV'])) {
      return AdminColors.danger;
    }
    if (has(['CREATE', 'REGISTER', 'IMPORT', 'SUBMIT', 'COMPLETE', 'ADD'])) {
      return AdminColors.success;
    }
    if (has(['LOGIN', 'LOGOUT', 'PASSWORD'])) return AdminAccents.sky.color;
    if (has(['EXPORT'])) return AdminAccents.gold.color;
    return AdminAccents.blue.color;
  }

  Widget _agendaRow(DashboardAgendaItem item) {
    final dateLabel = DateFormat('MMM d').format(item.date);
    final detail = item.overdue
        ? 'Overdue since $dateLabel · ${item.detail}'
        : item.detail;
    final accent = agendaAccent(item.kind);
    final fg = item.overdue ? AdminColors.danger : accent.onTint;
    final bg = item.overdue ? AdminColors.dangerBg : accent.tint;
    return Semantics(
      button: true,
      label: '${item.title}, $detail, $dateLabel',
      excludeSemantics: true,
      child: InkWell(
        onTap: () => onMenuSelected(item.menuIndex),
        borderRadius: BorderRadius.circular(AdminSurfaces.radiusSm),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Container(
                width: 44,
                padding: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(AdminSurfaces.radiusSm),
                  border: Border.all(
                    color: fg.withValues(alpha: 0.18),
                    width: 1,
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      DateFormat('MMM').format(item.date).toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: fg,
                        letterSpacing: 0.4,
                      ),
                    ),
                    Text(
                      DateFormat('d').format(item.date),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: fg,
                        height: 1.15,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AdminColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          _agendaIcon(item.kind),
                          size: 13,
                          color: item.overdue
                              ? AdminColors.danger
                              : AdminColors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            detail,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AdminText.caption.copyWith(
                              color: item.overdue
                                  ? AdminColors.danger
                                  : AdminColors.textSecondary,
                            ),
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
      ),
    );
  }

  Widget _activityRow(AuditLog log) {
    final color = activityColor(log.action);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 5),
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.35),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ],
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
                color: AdminColors.textPrimary,
                height: 1.35,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            DateFormat('MMM d').format(log.timestamp),
            style: AdminText.caption,
          ),
        ],
      ),
    );
  }
}
