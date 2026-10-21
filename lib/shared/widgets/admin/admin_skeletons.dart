import 'package:flutter/material.dart';
import 'package:alumni_system/shared/widgets/user/portal_skeletons.dart';
import 'package:alumni_system/shared/widgets/user/skeleton.dart';
import 'package:alumni_system/shared/widgets/admin/admin_theme.dart';

export 'package:alumni_system/shared/widgets/user/portal_skeletons.dart'
    show CommentListSkeleton, JobListSkeleton, MessageListSkeleton, PortalCardListSkeleton, SurveyFormSkeleton;

/// Admin dashboard home — title row, KPI row, chart/activity row, card row.
class AdminDashboardHomeSkeleton extends StatelessWidget {
  const AdminDashboardHomeSkeleton({super.key});

  static const _chip = BorderRadius.all(Radius.circular(8));

  @override
  Widget build(BuildContext context) {
    return ShimmerScope(
      child: Column(
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
                      Skeleton(width: 90, height: 12),
                    ],
                  ),
                ),
                Skeleton(width: 96, height: 36, borderRadius: _chip),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: List.generate(
              4,
              (i) => Expanded(
                child: Padding(
                  padding: EdgeInsets.only(left: i == 0 ? 0 : 6, right: i == 3 ? 0 : 6),
                  child: _panelBox(height: 96),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 2, child: _panelBox(height: 240)),
              const SizedBox(width: 12),
              Expanded(child: _panelBox(height: 240)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _panelBox(height: 200)),
              const SizedBox(width: 12),
              Expanded(child: _panelBox(height: 200)),
              const SizedBox(width: 12),
              Expanded(child: _panelBox(height: 200)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _panelBox({required double height}) {
    final compact = height < 100;
    return Container(
      height: height,
      padding: EdgeInsets.all(compact ? 12 : 16),
      decoration: AdminSurfaces.card(),
      child: compact
          ? const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Skeleton(width: 72, height: 10),
                SizedBox(height: 6),
                Skeleton(width: 40, height: 16),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Skeleton(width: 120, height: 12),
                SizedBox(height: height > 140 ? 10 : 6),
                const Skeleton(width: double.infinity, height: 10),
                if (height > 140) ...[
                  const SizedBox(height: 6),
                  const Skeleton(width: double.infinity, height: 10),
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

/// Admin events management list area.
class AdminEventsListSkeleton extends StatelessWidget {
  const AdminEventsListSkeleton({super.key, this.count = 4});

  final int count;

  @override
  Widget build(BuildContext context) {
    return ShimmerScope(
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: count,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                  borderRadius: BorderRadius.all(Radius.circular(8)),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Skeleton(width: double.infinity, height: 14),
                      SizedBox(height: 8),
                      Skeleton(width: 120, height: 12),
                    ],
                  ),
                ),
              ],
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
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Skeleton(width: 260, height: 26),
            const SizedBox(height: 8),
            const Skeleton(width: 360, height: 14),
            const SizedBox(height: 24),
            Container(
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Skeleton(width: 140, height: 16),
                  const SizedBox(height: 6),
                  const Skeleton(width: 220, height: 12),
                  const SizedBox(height: 16),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final narrow = constraints.maxWidth < 520;
                      if (narrow) {
                        return Column(
                          children: List.generate(
                            3,
                            (i) => Padding(
                              padding: EdgeInsets.only(bottom: i < 2 ? 12 : 0),
                              child: _reportsStatTile(),
                            ),
                          ),
                        );
                      }
                      return Row(
                        children: List.generate(
                          3,
                          (i) => Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(left: i == 0 ? 0 : 12),
                              child: _reportsStatTile(),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  const Skeleton(width: 160, height: 16),
                  const SizedBox(height: 12),
                  Container(
                    height: 180,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
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

  static Widget _reportsStatTile() {
    return Container(
      height: 72,
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      alignment: Alignment.center,
      child: const Skeleton(width: 56, height: 18),
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
        final bounded = constraints.maxHeight.isFinite;
        return ShimmerScope(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            shrinkWrap: !bounded,
            physics: bounded
                ? const AlwaysScrollableScrollPhysics()
                : const NeverScrollableScrollPhysics(),
            itemCount: count,
            itemBuilder: (_, __) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: const Row(
                  children: [
                    Skeleton(
                      width: 8,
                      height: 8,
                      borderRadius: BorderRadius.all(Radius.circular(4)),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Skeleton(width: double.infinity, height: 14),
                    ),
                    SizedBox(width: 12),
                    Skeleton(width: 72, height: 12),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Archives tab list.
class AdminArchiveListSkeleton extends StatelessWidget {
  const AdminArchiveListSkeleton({super.key, this.count = 5});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: ShimmerScope(
        child: Column(
          children: List.generate(
            count,
            (i) => Padding(
              padding: EdgeInsets.only(bottom: i < count - 1 ? 12 : 0),
              child: Container(
                height: 72,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.all(14),
                child: const Row(
                  children: [
                    Skeleton(width: 44, height: 44, borderRadius: BorderRadius.all(Radius.circular(8))),
                    SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Skeleton(width: double.infinity, height: 14),
                          SizedBox(height: 8),
                          Skeleton(width: 100, height: 12),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
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
    return const FeedbackDetailSkeleton();
  }
}
