import 'package:flutter/material.dart';
import 'package:alumni_system/shared/widgets/user/portal_skeletons.dart';
import 'package:alumni_system/shared/widgets/user/skeleton.dart';
import 'package:alumni_system/shared/widgets/admin/admin_density.dart';
import 'package:alumni_system/shared/widgets/admin/admin_theme.dart';

export 'package:alumni_system/shared/widgets/user/portal_skeletons.dart'
    show
        CommentListSkeleton,
        JobListSkeleton,
        MessageListSkeleton,
        PortalCardListSkeleton,
        PortalDetailSkeleton,
        SurveyFormSkeleton;

/// Admin dashboard home — title row, KPI row, chart/activity row, card row.
class AdminDashboardHomeSkeleton extends StatelessWidget {
  const AdminDashboardHomeSkeleton({super.key});

  static const _chip = BorderRadius.all(Radius.circular(8));

  @override
  Widget build(BuildContext context) {
    return ShimmerScope(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final kpiColumns = width >= 900
              ? 4
              : width >= 560
              ? 2
              : 1;
          final bottomColumns = width >= 700 ? 3 : 1;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(
                height: 44,
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Skeleton(width: 200, height: 20),
                          SizedBox(height: 6),
                          Skeleton(width: 220, height: 12),
                        ],
                      ),
                    ),
                    SizedBox(width: 12),
                    Skeleton(width: 108, height: 36, borderRadius: _chip),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _kpiRow(kpiColumns),
              const SizedBox(height: 12),
              if (width >= 700)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 2, child: _panelBox(height: 240)),
                    const SizedBox(width: 12),
                    Expanded(child: _panelBox(height: 240)),
                  ],
                )
              else ...[
                _panelBox(height: 200),
                const SizedBox(height: 12),
                _panelBox(height: 200),
              ],
              const SizedBox(height: 12),
              _bottomRow(bottomColumns),
            ],
          );
        },
      ),
    );
  }

  Widget _kpiRow(int columns) {
    final tiles = List.generate(4, (_) => _kpiBox());
    if (columns == 1) {
      return Column(
        children: [
          for (var i = 0; i < tiles.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            tiles[i],
          ],
        ],
      );
    }
    final rows = <Widget>[];
    for (var start = 0; start < tiles.length; start += columns) {
      final end = (start + columns).clamp(0, tiles.length);
      rows.add(
        Row(
          children: [
            for (var i = start; i < end; i++) ...[
              if (i > start) const SizedBox(width: 12),
              Expanded(child: tiles[i]),
            ],
          ],
        ),
      );
      if (end < tiles.length) rows.add(const SizedBox(height: 12));
    }
    return Column(children: rows);
  }

  Widget _kpiBox() {
    return Container(
      height: 118,
      padding: const EdgeInsets.all(12),
      decoration: AdminSurfaces.card(),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Skeleton(width: 32, height: 32, borderRadius: _chip),
              SizedBox(width: 10),
              Expanded(child: Skeleton(width: double.infinity, height: 10)),
            ],
          ),
          SizedBox(height: 10),
          Skeleton(width: 54, height: 22),
          SizedBox(height: 8),
          Skeleton(width: double.infinity, height: 10),
          Spacer(),
          Skeleton(width: double.infinity, height: 4),
        ],
      ),
    );
  }

  Widget _bottomRow(int columns) {
    if (columns == 1) {
      return Column(
        children: [
          _panelBox(height: 200),
          const SizedBox(height: 12),
          _panelBox(height: 200),
          const SizedBox(height: 12),
          _panelBox(height: 200),
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _panelBox(height: 200)),
        const SizedBox(width: 12),
        Expanded(child: _panelBox(height: 200)),
        const SizedBox(width: 12),
        Expanded(child: _panelBox(height: 200)),
      ],
    );
  }

  Widget _panelBox({required double height}) {
    return Container(
      height: height,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: AdminSurfaces.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Skeleton(width: 28, height: 28, borderRadius: _chip),
              SizedBox(width: 10),
              Skeleton(width: 110, height: 12),
              Spacer(),
              Skeleton(width: 44, height: 16, borderRadius: _chip),
            ],
          ),
          const SizedBox(height: 16),
          for (var i = 0; i < 3; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            const Row(
              children: [
                Skeleton(width: 26, height: 26, borderRadius: _chip),
                SizedBox(width: 10),
                Expanded(child: Skeleton(width: double.infinity, height: 10)),
                SizedBox(width: 10),
                Skeleton(width: 36, height: 10),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Alumni directory member rows.
class AdminDirectoryListSkeleton extends StatelessWidget {
  const AdminDirectoryListSkeleton({super.key, this.count = 6});

  final int count;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bounded = constraints.maxHeight.isFinite;
        return ShimmerScope(
          child: ListView.separated(
            shrinkWrap: !bounded,
            physics: bounded
                ? const AlwaysScrollableScrollPhysics()
                : const NeverScrollableScrollPhysics(),
            itemCount: count,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, __) => Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: const Row(
            children: [
              Skeleton(
                width: 48,
                height: 48,
                borderRadius: BorderRadius.all(Radius.circular(24)),
              ),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Skeleton(width: 180, height: 16),
                    SizedBox(height: 8),
                    Skeleton(width: 140, height: 12),
                    SizedBox(height: 6),
                    Skeleton(width: 200, height: 12),
                  ],
                ),
              ),
              Skeleton(width: 72, height: 28, borderRadius: BorderRadius.all(Radius.circular(14))),
            ],
          ),
        ),
          ),
        );
      },
    );
  }
}

/// Admin events management list area (matches [AdminEventListCard] zones).
class AdminEventsListSkeleton extends StatelessWidget {
  const AdminEventsListSkeleton({super.key, this.count = 5});

  final int count;

  @override
  Widget build(BuildContext context) {
    return ShimmerScope(
      child: ListView.separated(
        padding: const EdgeInsets.only(bottom: 16),
        itemCount: count,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          return Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: AdminSurfaces.card(),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 900;
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Skeleton(
                      width: 88,
                      height: 60,
                      borderRadius: BorderRadius.all(Radius.circular(8)),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FractionallySizedBox(
                            widthFactor: 0.58,
                            child: Skeleton(height: 14),
                          ),
                          SizedBox(height: 8),
                          Row(
                            children: [
                              Skeleton(width: 68, height: 18),
                              SizedBox(width: 6),
                              Skeleton(width: 78, height: 18),
                            ],
                          ),
                          SizedBox(height: 8),
                          FractionallySizedBox(
                            widthFactor: 0.72,
                            child: Skeleton(height: 11),
                          ),
                        ],
                      ),
                    ),
                    if (wide) ...[
                      const SizedBox(width: 24),
                      const SizedBox(
                        width: 200,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Skeleton(width: 88, height: 10),
                            SizedBox(height: 8),
                            Skeleton(width: 120, height: 13),
                            SizedBox(height: 8),
                            Skeleton(height: 4),
                          ],
                        ),
                      ),
                      const SizedBox(width: 36),
                    ],
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }
}

/// Admin Announcements list skeleton mirroring [AnnouncementListCard] zones.
class AdminAnnouncementsListSkeleton extends StatelessWidget {
  const AdminAnnouncementsListSkeleton({super.key, this.count = 5});

  final int count;

  @override
  Widget build(BuildContext context) {
    return ShimmerScope(
      child: ListView.separated(
        padding: const EdgeInsets.only(bottom: 16),
        itemCount: count,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          return Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: AdminSurfaces.card(),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 900;
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Skeleton(
                      width: 40,
                      height: 40,
                      borderRadius: BorderRadius.all(Radius.circular(8)),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FractionallySizedBox(
                            widthFactor: 0.52,
                            child: Skeleton(height: 14),
                          ),
                          SizedBox(height: 8),
                          Row(
                            children: [
                              Skeleton(width: 72, height: 18),
                              SizedBox(width: 6),
                              Skeleton(width: 74, height: 18),
                            ],
                          ),
                          SizedBox(height: 8),
                          FractionallySizedBox(
                            widthFactor: 0.78,
                            child: Skeleton(height: 11),
                          ),
                        ],
                      ),
                    ),
                    if (wide) ...[
                      const SizedBox(width: 24),
                      const SizedBox(
                        width: 205,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Skeleton(width: 112, height: 10),
                            SizedBox(height: 8),
                            Skeleton(width: 140, height: 13),
                            SizedBox(height: 6),
                            Skeleton(width: 96, height: 11),
                          ],
                        ),
                      ),
                      const SizedBox(width: 20),
                      const SizedBox(
                        width: 175,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Skeleton(width: 100, height: 10),
                            SizedBox(height: 8),
                            Skeleton(width: 120, height: 13),
                            SizedBox(height: 6),
                            Skeleton(width: 110, height: 11),
                          ],
                        ),
                      ),
                      const SizedBox(width: 32),
                    ],
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }
}

/// Admin Forum list skeleton mirroring [AdminForumTopicCard] zones.
class AdminForumListSkeleton extends StatelessWidget {
  const AdminForumListSkeleton({super.key, this.count = 5});

  final int count;

  @override
  Widget build(BuildContext context) {
    return ShimmerScope(
      child: ListView.separated(
        padding: const EdgeInsets.only(bottom: 16),
        itemCount: count,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          return Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: AdminSurfaces.card(),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 900;
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Skeleton(
                      width: 40,
                      height: 40,
                      borderRadius: BorderRadius.all(Radius.circular(20)),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FractionallySizedBox(
                            widthFactor: 0.56,
                            child: Skeleton(height: 14),
                          ),
                          SizedBox(height: 8),
                          Row(
                            children: [
                              Skeleton(width: 72, height: 18),
                              SizedBox(width: 6),
                              Skeleton(width: 68, height: 18),
                            ],
                          ),
                          SizedBox(height: 8),
                          FractionallySizedBox(
                            widthFactor: 0.45,
                            child: Skeleton(height: 11),
                          ),
                        ],
                      ),
                    ),
                    if (wide) ...[
                      const SizedBox(width: 24),
                      const SizedBox(
                        width: 195,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Skeleton(width: 120, height: 10),
                            SizedBox(height: 8),
                            Skeleton(width: 112, height: 13),
                            SizedBox(height: 6),
                            Skeleton(width: 98, height: 11),
                          ],
                        ),
                      ),
                      const SizedBox(width: 32),
                    ],
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }
}

/// Admin Job Postings list skeleton mirroring [AdminJobCard] zones.
class AdminJobsListSkeleton extends StatelessWidget {
  const AdminJobsListSkeleton({super.key, this.count = 5});

  final int count;

  @override
  Widget build(BuildContext context) {
    return ShimmerScope(
      child: ListView.separated(
        padding: const EdgeInsets.only(bottom: 16),
        itemCount: count,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          return Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: AdminSurfaces.card(),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 900;
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Skeleton(
                      width: 40,
                      height: 40,
                      borderRadius: BorderRadius.all(Radius.circular(8)),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FractionallySizedBox(
                            widthFactor: 0.52,
                            child: Skeleton(height: 14),
                          ),
                          SizedBox(height: 8),
                          Row(
                            children: [
                              Skeleton(width: 58, height: 18),
                              SizedBox(width: 6),
                              Skeleton(width: 68, height: 18),
                            ],
                          ),
                          SizedBox(height: 8),
                          FractionallySizedBox(
                            widthFactor: 0.48,
                            child: Skeleton(height: 11),
                          ),
                        ],
                      ),
                    ),
                    if (wide) ...[
                      const SizedBox(width: 24),
                      const SizedBox(
                        width: 205,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Skeleton(width: 126, height: 10),
                            SizedBox(height: 8),
                            Skeleton(width: 136, height: 13),
                            SizedBox(height: 6),
                            Skeleton(width: 108, height: 11),
                          ],
                        ),
                      ),
                      const SizedBox(width: 32),
                    ],
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }
}

/// Reports & analytics full-page load (Column — safe inside [SingleChildScrollView]).
class AdminReportsSkeleton extends StatelessWidget {
  const AdminReportsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerScope(
      child: Padding(
        padding: const EdgeInsets.only(bottom: AdminDensity.space4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: AdminDensity.buttonHeight,
              child: const Row(
                children: [
                  Skeleton(width: 190, height: 22),
                  Spacer(),
                  Skeleton(width: 92, height: 36),
                  SizedBox(width: 8),
                  Skeleton(width: 96, height: 36),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Container(
              height: 46,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: AdminColors.card,
                borderRadius: BorderRadius.circular(AdminSurfaces.radiusMd),
                border: Border.all(color: AdminColors.border),
              ),
              child: const Row(
                children: [
                  Skeleton(width: 78, height: 14),
                  SizedBox(width: 24),
                  Skeleton(width: 64, height: 14),
                  SizedBox(width: 24),
                  Skeleton(width: 68, height: 14),
                  SizedBox(width: 24),
                  Skeleton(width: 84, height: 14),
                ],
              ),
            ),
            const SizedBox(height: AdminDensity.space2),
            LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 1000;
                final medium = !wide && constraints.maxWidth >= 640;
                if (wide) {
                  return Row(
                    children: [
                      for (var i = 0; i < 4; i++) ...[
                        if (i > 0) const SizedBox(width: AdminDensity.space2),
                        Expanded(child: _reportsStatTile()),
                      ],
                    ],
                  );
                }
                if (medium) {
                  return Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: _reportsStatTile()),
                          const SizedBox(width: AdminDensity.space2),
                          Expanded(child: _reportsStatTile()),
                        ],
                      ),
                      const SizedBox(height: AdminDensity.space2),
                      Row(
                        children: [
                          Expanded(child: _reportsStatTile()),
                          const SizedBox(width: AdminDensity.space2),
                          Expanded(child: _reportsStatTile()),
                        ],
                      ),
                    ],
                  );
                }
                return Column(
                  children: List.generate(
                    4,
                    (i) => Padding(
                      padding: EdgeInsets.only(
                        bottom: i < 3 ? AdminDensity.space2 : 0,
                      ),
                      child: _reportsStatTile(),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: AdminDensity.space2),
            LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 1000;
                if (!wide) {
                  return Column(
                    children: [
                      _reportsChartCardSkeleton(),
                      const SizedBox(height: AdminDensity.space2),
                      _reportsChartCardSkeleton(),
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(flex: 11, child: _reportsChartCardSkeleton()),
                    const SizedBox(width: AdminDensity.space2),
                    Expanded(flex: 7, child: _reportsChartCardSkeleton()),
                    const SizedBox(width: AdminDensity.space2),
                    Expanded(flex: 6, child: _reportsChartCardSkeleton()),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  static Widget _reportsStatTile() {
    return Container(
      height: 152,
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(
        color: AdminColors.card,
        borderRadius: BorderRadius.circular(AdminSurfaces.radiusMd),
        border: Border.all(color: AdminColors.border),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Skeleton(
                width: 26,
                height: 26,
                borderRadius: BorderRadius.all(Radius.circular(7)),
              ),
              SizedBox(width: 8),
              Skeleton(width: 84, height: 11),
            ],
          ),
          SizedBox(height: 10),
          Row(
            children: [
              Skeleton(width: 64, height: 24),
              SizedBox(width: 8),
              Skeleton(width: 58, height: 18),
            ],
          ),
          Spacer(),
          Skeleton(height: 11),
          SizedBox(height: 6),
          FractionallySizedBox(widthFactor: 0.78, child: Skeleton(height: 11)),
        ],
      ),
    );
  }

  static Widget _reportsChartCardSkeleton() {
    return Container(
      height: 288,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: AdminColors.card,
        borderRadius: BorderRadius.circular(AdminSurfaces.radiusMd),
        border: Border.all(color: AdminColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Skeleton(width: 150, height: 14),
          const SizedBox(height: 6),
          const Skeleton(width: 190, height: 11),
          const SizedBox(height: 16),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AdminColors.surface,
                borderRadius: BorderRadius.circular(AdminSurfaces.radiusSm),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Activity log table rows.
class AdminActivityLogSkeleton extends StatelessWidget {
  const AdminActivityLogSkeleton({super.key, this.count = 8});

  final int count;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final bounded = constraints.maxHeight.isFinite;
        final metricCols = width >= 780 ? 4 : (width >= 480 ? 2 : 1);
        final rowsList = ListView.separated(
          shrinkWrap: !bounded,
          physics: bounded
              ? const AlwaysScrollableScrollPhysics()
              : const NeverScrollableScrollPhysics(),
          itemCount: count,
          separatorBuilder: (_, __) =>
              const Divider(height: 1, color: AdminColors.border),
          itemBuilder: (_, __) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                if (width >= 720) ...[
                  const Skeleton(width: 84, height: 12),
                  const SizedBox(width: 16),
                ],
                const Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FractionallySizedBox(
                        widthFactor: 0.72,
                        child: Skeleton(height: 13),
                      ),
                      SizedBox(height: 6),
                      Skeleton(width: 56, height: 10),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                if (width >= 720) ...[
                  const Expanded(
                    flex: 2,
                    child: FractionallySizedBox(
                      widthFactor: 0.68,
                      child: Skeleton(height: 13),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                const Skeleton(
                  width: 66,
                  height: 22,
                  borderRadius: BorderRadius.all(Radius.circular(6)),
                ),
              ],
            ),
          ),
        );

        final tableCard = Container(
          decoration: AdminSurfaces.card(),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: bounded ? MainAxisSize.max : MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 11,
                ),
                decoration: const BoxDecoration(
                  color: AdminColors.background,
                  border: Border(bottom: BorderSide(color: AdminColors.border)),
                ),
                child: const Row(
                  children: [
                    Skeleton(width: 96, height: 11),
                    Spacer(),
                    Skeleton(width: 64, height: 11),
                  ],
                ),
              ),
              if (bounded) Expanded(child: rowsList) else rowsList,
            ],
          ),
        );

        final metricsWidget = metricCols == 4
            ? Row(
                children: [
                  for (var i = 0; i < 4; i++) ...[
                    if (i > 0) const SizedBox(width: 10),
                    const Expanded(child: _ActivityMetricSkeletonTile()),
                  ],
                ],
              )
            : Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (var i = 0; i < 4; i++)
                    SizedBox(
                      width: (width - 10 * (metricCols - 1)) / metricCols,
                      child: const _ActivityMetricSkeletonTile(),
                    ),
                ],
              );

        return ShimmerScope(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: bounded ? MainAxisSize.max : MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: AdminSurfaces.card(),
                child: Row(
                  children: [
                    const Skeleton(width: 140, height: 20),
                    const Spacer(),
                    if (width >= 520) ...[
                      const Skeleton(
                        width: 88,
                        height: 34,
                        borderRadius: BorderRadius.all(Radius.circular(8)),
                      ),
                      const SizedBox(width: 8),
                    ],
                    const Skeleton(
                      width: 104,
                      height: 34,
                      borderRadius: BorderRadius.all(Radius.circular(8)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              metricsWidget,
              const SizedBox(height: 8),
              Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: AdminSurfaces.card(),
                child: const Row(
                  children: [
                    Expanded(child: Skeleton(height: 16)),
                    SizedBox(width: 12),
                    Skeleton(width: 84, height: 28),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              if (bounded) Expanded(child: tableCard) else tableCard,
            ],
          ),
        );
      },
    );
  }
}

class _ActivityMetricSkeletonTile extends StatelessWidget {
  const _ActivityMetricSkeletonTile();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: AdminSurfaces.card(),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Skeleton(
                width: 28,
                height: 28,
                borderRadius: BorderRadius.all(Radius.circular(6)),
              ),
              Skeleton(width: 32, height: 18),
            ],
          ),
          Skeleton(width: 64, height: 11),
        ],
      ),
    );
  }
}

/// Editor / detail form pages.
class AdminFormEditorSkeleton extends StatelessWidget {
  const AdminFormEditorSkeleton({super.key, this.fieldCount = 5});

  final int fieldCount;

  @override
  Widget build(BuildContext context) {
    return SurveyFormSkeleton(); // same field blocks pattern
  }
}

/// Admin messages — conversations column.
class AdminMessagesLayoutSkeleton extends StatelessWidget {
  const AdminMessagesLayoutSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 2,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: const MessageListSkeleton(count: 8),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 3,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: ShimmerScope(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Skeleton(width: 140, height: 18),
                    const SizedBox(height: 20),
                    ...List.generate(
                      5,
                      (i) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Align(
                          alignment: i.isEven
                              ? Alignment.centerLeft
                              : Alignment.centerRight,
                          child: Skeleton(
                            width: i.isEven ? 200 : 160,
                            height: 40,
                            borderRadius: const BorderRadius.all(Radius.circular(12)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Survey responses overview blocks (Column — safe inside parent [Column]).
class AdminSurveyResponsesSkeleton extends StatelessWidget {
  const AdminSurveyResponsesSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const SurveyResponsesWorkspaceSkeleton();
  }
}

/// Full View Responses workspace shimmer: stats, chart, profile cards.
class SurveyResponsesWorkspaceSkeleton extends StatelessWidget {
  const SurveyResponsesWorkspaceSkeleton({
    super.key,
    this.listMode = false,
  });

  /// When true, shows list/profile card skeletons (Pending / Submitted).
  final bool listMode;

  const SurveyResponsesWorkspaceSkeleton.overview({super.key})
      : listMode = false;

  const SurveyResponsesWorkspaceSkeleton.list({super.key})
      : listMode = true;

  @override
  Widget build(BuildContext context) {
    return ShimmerScope(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          if (!listMode) ...[
            const _SkeletonSectionTitle(),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: List.generate(
                4,
                (_) => Container(
                  width: 140,
                  height: 72,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Skeleton(width: 48, height: 20),
                      SizedBox(height: 10),
                      Skeleton(width: 80, height: 10),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const _SkeletonCard(height: 120),
            const SizedBox(height: 12),
            const _SkeletonCard(height: 88),
            const SizedBox(height: 16),
            const _SkeletonSectionTitle(width: 100),
            const SizedBox(height: 10),
            const _SkeletonChartCard(),
            const SizedBox(height: 12),
            const _SkeletonChartCard(),
          ] else ...[
            const _SkeletonToolbar(),
            const SizedBox(height: 12),
            ...List.generate(
              5,
              (i) => Padding(
                padding: EdgeInsets.only(bottom: i < 4 ? 10 : 0),
                child: const _SkeletonProfileCard(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SkeletonSectionTitle extends StatelessWidget {
  const _SkeletonSectionTitle({this.width = 140});
  final double width;

  @override
  Widget build(BuildContext context) {
    return Skeleton(width: width, height: 14);
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard({required this.height});
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      padding: const EdgeInsets.all(14),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Skeleton(width: 160, height: 12),
          SizedBox(height: 10),
          Skeleton(width: double.infinity, height: 10),
          SizedBox(height: 8),
          Skeleton(width: 220, height: 10),
        ],
      ),
    );
  }
}

class _SkeletonChartCard extends StatelessWidget {
  const _SkeletonChartCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 160,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      padding: const EdgeInsets.all(14),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Skeleton(width: 120, height: 12),
          SizedBox(height: 16),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(child: Skeleton(height: 40)),
                SizedBox(width: 8),
                Expanded(child: Skeleton(height: 70)),
                SizedBox(width: 8),
                Expanded(child: Skeleton(height: 55)),
                SizedBox(width: 8),
                Expanded(child: Skeleton(height: 90)),
                SizedBox(width: 8),
                Expanded(child: Skeleton(height: 48)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SkeletonToolbar extends StatelessWidget {
  const _SkeletonToolbar();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Skeleton(height: 48),
        const SizedBox(height: 10),
        Row(
          children: [
            Skeleton(
              width: 88,
              height: 32,
              borderRadius: BorderRadius.circular(16),
            ),
            const SizedBox(width: 8),
            Skeleton(
              width: 72,
              height: 32,
              borderRadius: BorderRadius.circular(16),
            ),
            const SizedBox(width: 8),
            Skeleton(
              width: 96,
              height: 32,
              borderRadius: BorderRadius.circular(16),
            ),
          ],
        ),
      ],
    );
  }
}

class _SkeletonProfileCard extends StatelessWidget {
  const _SkeletonProfileCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Skeleton(
            width: 20,
            height: 20,
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(width: 10),
          Skeleton(
            width: 44,
            height: 44,
            borderRadius: BorderRadius.circular(22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Skeleton(width: 160, height: 12),
                const SizedBox(height: 8),
                const Skeleton(width: 200, height: 10),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    Skeleton(
                      width: 72,
                      height: 22,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    Skeleton(
                      width: 64,
                      height: 22,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    Skeleton(
                      width: 88,
                      height: 22,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Alumni member detail profile.
class AdminMemberDetailSkeleton extends StatelessWidget {
  const AdminMemberDetailSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const PortalDetailSkeleton();
  }
}
