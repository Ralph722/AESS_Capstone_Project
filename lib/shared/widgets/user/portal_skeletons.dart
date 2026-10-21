import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:alumni_system/shared/widgets/user/skeleton.dart';

// ---------------------------------------------------------------------------
// Home
// ---------------------------------------------------------------------------

/// Home "Upcoming Events" slideshow placeholder (16:9 cover + dots).
class HomeEventCarouselSkeleton extends StatelessWidget {
  const HomeEventCarouselSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerScope(
      child: Column(
        children: [
          LayoutBuilder(
            builder: (context, constraints) => Skeleton(
              width: double.infinity,
              height: math.min(constraints.maxWidth * 9 / 16, 260),
              borderRadius: const BorderRadius.all(Radius.circular(16)),
            ),
          ),
          const SizedBox(height: 10),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Skeleton(width: 18, height: 6),
              SizedBox(width: 6),
              Skeleton(width: 6, height: 6),
              SizedBox(width: 6),
              Skeleton(width: 6, height: 6),
            ],
          ),
        ],
      ),
    );
  }
}

/// Home "Upcoming Events" cards — matches `_buildEventCard` on HomeScreen.
class HomeEventCardsSkeleton extends StatelessWidget {
  const HomeEventCardsSkeleton({super.key, this.count = 2});

  final int count;

  @override
  Widget build(BuildContext context) {
    return ShimmerScope(
      child: Column(
        children: List.generate(
          count,
          (i) => Padding(
            padding: EdgeInsets.only(bottom: i < count - 1 ? 12 : 0),
            child: const _HomeEventCardSkeleton(),
          ),
        ),
      ),
    );
  }
}

class _HomeEventCardSkeleton extends StatelessWidget {
  const _HomeEventCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const Row(
        children: [
          Skeleton(
            width: 60,
            height: 60,
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Skeleton(width: double.infinity, height: 16),
                SizedBox(height: 8),
                Skeleton(width: 120, height: 12),
                SizedBox(height: 8),
                Skeleton(width: 80, height: 12),
              ],
            ),
          ),
          SizedBox(width: 8),
          Skeleton(
            width: 64,
            height: 24,
            borderRadius: BorderRadius.all(Radius.circular(20)),
          ),
        ],
      ),
    );
  }
}

/// Home featured jobs — horizontal cards matching `_buildJobCard`.
class HomeJobCardsSkeleton extends StatelessWidget {
  const HomeJobCardsSkeleton({super.key, this.count = 2});

  final int count;

  @override
  Widget build(BuildContext context) {
    return ShimmerScope(
      child: SizedBox(
        height: 200,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: count,
          itemBuilder: (_, i) => Padding(
            padding: EdgeInsets.only(right: i < count - 1 ? 12 : 0),
            child: const _HomeJobCardSkeleton(),
          ),
        ),
      ),
    );
  }
}

class _HomeJobCardSkeleton extends StatelessWidget {
  const _HomeJobCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Skeleton(
                width: 40,
                height: 40,
                borderRadius: BorderRadius.all(Radius.circular(8)),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Skeleton(width: 100, height: 12),
                    SizedBox(height: 6),
                    Skeleton(width: double.infinity, height: 14),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 14),
          Row(
            children: [
              Skeleton(
                width: 64,
                height: 22,
                borderRadius: BorderRadius.all(Radius.circular(4)),
              ),
              SizedBox(width: 8),
              Skeleton(
                width: 72,
                height: 22,
                borderRadius: BorderRadius.all(Radius.circular(4)),
              ),
            ],
          ),
          Spacer(),
          Skeleton(
            width: double.infinity,
            height: 36,
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Events
// ---------------------------------------------------------------------------

/// Events tab list/grid loading placeholder.
class EventListSkeleton extends StatelessWidget {
  const EventListSkeleton({
    super.key,
    this.grid = false,
    this.count = 4,
    this.shrinkWrap = true,
  });

  final bool grid;
  final int count;

  /// False when the skeleton fills a [SliverFillRemaining] / expanded body.
  final bool shrinkWrap;

  @override
  Widget build(BuildContext context) {
    final physics = shrinkWrap
        ? const NeverScrollableScrollPhysics()
        : const AlwaysScrollableScrollPhysics();
    if (grid) {
      return ShimmerScope(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: GridView.builder(
            shrinkWrap: shrinkWrap,
            physics: physics,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 0.75,
            ),
            itemCount: count,
            itemBuilder: (_, __) => const _EventGridTileSkeleton(),
          ),
        ),
      );
    }

    return ShimmerScope(
      child: ListView.builder(
        shrinkWrap: shrinkWrap,
        physics: physics,
        padding: const EdgeInsets.all(16),
        itemCount: count,
        itemBuilder: (_, __) => const Padding(
          padding: EdgeInsets.only(bottom: 16),
          child: _EventListCardSkeleton(),
        ),
      ),
    );
  }
}

class _EventGridTileSkeleton extends StatelessWidget {
  const _EventGridTileSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Skeleton(
            height: 100,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Skeleton(width: double.infinity, height: 14),
                  SizedBox(height: 6),
                  Skeleton(width: 120, height: 12),
                  SizedBox(height: 8),
                  Skeleton(width: 90, height: 12),
                  SizedBox(height: 8),
                  Skeleton(width: 100, height: 12),
                  Spacer(),
                  Skeleton(
                    width: double.infinity,
                    height: 32,
                    borderRadius: BorderRadius.all(Radius.circular(8)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tall event card matching EventsScreen list `_buildEventCard`.
class _EventListCardSkeleton extends StatelessWidget {
  const _EventListCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 2.35,
            child: Skeleton(
              height: double.infinity,
              borderRadius: BorderRadius.zero,
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Skeleton(
                  width: 88,
                  height: 18,
                  borderRadius: BorderRadius.all(Radius.circular(6)),
                ),
                SizedBox(height: 10),
                Skeleton(width: double.infinity, height: 16),
                SizedBox(height: 8),
                Skeleton(width: 180, height: 12),
                SizedBox(height: 6),
                Skeleton(width: 140, height: 12),
                SizedBox(height: 12),
                Skeleton(width: 160, height: 12),
                SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Skeleton(
                        height: 38,
                        borderRadius: BorderRadius.all(Radius.circular(10)),
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Skeleton(
                        height: 38,
                        borderRadius: BorderRadius.all(Radius.circular(10)),
                      ),
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

// ---------------------------------------------------------------------------
// Jobs
// ---------------------------------------------------------------------------

/// Jobs tab cards matching [JobPostingCard].
class JobListSkeleton extends StatelessWidget {
  const JobListSkeleton({super.key, this.count = 5, this.shrinkWrap = false});

  final int count;
  final bool shrinkWrap;

  @override
  Widget build(BuildContext context) {
    return ShimmerScope(
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        shrinkWrap: shrinkWrap,
        physics: shrinkWrap
            ? const NeverScrollableScrollPhysics()
            : const AlwaysScrollableScrollPhysics(),
        itemCount: count,
        itemBuilder: (_, __) => const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: _JobPostingCardSkeleton(),
        ),
      ),
    );
  }
}

class _JobPostingCardSkeleton extends StatelessWidget {
  const _JobPostingCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120F172A),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Skeleton(
                width: 52,
                height: 52,
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Skeleton(width: 110, height: 12),
                    SizedBox(height: 6),
                    Skeleton(width: double.infinity, height: 16),
                    SizedBox(height: 6),
                    Skeleton(width: 56, height: 10),
                  ],
                ),
              ),
              Skeleton(
                width: 36,
                height: 36,
                borderRadius: BorderRadius.all(Radius.circular(10)),
              ),
            ],
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Skeleton(
                width: 72,
                height: 26,
                borderRadius: BorderRadius.all(Radius.circular(8)),
              ),
              SizedBox(width: 8),
              Skeleton(
                width: 64,
                height: 26,
                borderRadius: BorderRadius.all(Radius.circular(8)),
              ),
            ],
          ),
          SizedBox(height: 12),
          Skeleton(width: 120, height: 13),
          SizedBox(height: 12),
          Skeleton(width: 100, height: 11),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Messages
// ---------------------------------------------------------------------------

/// Admin conversation-list tiles (sidebar). Kept for admin screens.
class MessageListSkeleton extends StatelessWidget {
  const MessageListSkeleton({
    super.key,
    this.count = 6,
    this.shrinkWrap = false,
  });

  final int count;
  final bool shrinkWrap;

  @override
  Widget build(BuildContext context) {
    return ShimmerScope(
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        shrinkWrap: shrinkWrap,
        physics: shrinkWrap
            ? const NeverScrollableScrollPhysics()
            : const AlwaysScrollableScrollPhysics(),
        itemCount: count,
        itemBuilder: (_, __) => const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: _MessageTileSkeleton(),
        ),
      ),
    );
  }
}

class _MessageTileSkeleton extends StatelessWidget {
  const _MessageTileSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Row(
        children: [
          Skeleton(
            width: 36,
            height: 36,
            borderRadius: BorderRadius.all(Radius.circular(18)),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Skeleton(width: 140, height: 14),
                SizedBox(height: 8),
                Skeleton(width: double.infinity, height: 12),
                SizedBox(height: 6),
                Skeleton(width: 60, height: 10),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// User Messages tab — chat bubbles matching [UserMessagesScreen].
class MessageThreadSkeleton extends StatelessWidget {
  const MessageThreadSkeleton({super.key, this.count = 6});

  final int count;

  @override
  Widget build(BuildContext context) {
    final widths = <double>[0.62, 0.48, 0.70, 0.55, 0.58, 0.45];
    return ShimmerScope(
      child: ListView.builder(
        reverse: true,
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        itemCount: count,
        itemBuilder: (_, i) {
          final fromAdmin = i.isEven;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final avatarSpace = fromAdmin ? 36.0 : 0.0;
                final maxBubble = (constraints.maxWidth - avatarSpace).clamp(
                  64.0,
                  600.0,
                );
                final bubbleW = maxBubble * widths[i % widths.length];
                return Align(
                  alignment: fromAdmin
                      ? Alignment.centerLeft
                      : Alignment.centerRight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (fromAdmin) ...[
                        const Skeleton(
                          width: 28,
                          height: 28,
                          borderRadius: BorderRadius.all(Radius.circular(14)),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Skeleton(
                        width: bubbleW,
                        height: fromAdmin ? 56 : 44,
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(14),
                          topRight: const Radius.circular(14),
                          bottomLeft: Radius.circular(fromAdmin ? 4 : 14),
                          bottomRight: Radius.circular(fromAdmin ? 14 : 4),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Notifications
// ---------------------------------------------------------------------------

class NotificationListSkeleton extends StatelessWidget {
  const NotificationListSkeleton({super.key, this.count = 5});

  final int count;

  @override
  Widget build(BuildContext context) {
    return ShimmerScope(
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: count,
        itemBuilder: (_, __) => const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: _NotificationTileSkeleton(),
        ),
      ),
    );
  }
}

class _NotificationTileSkeleton extends StatelessWidget {
  const _NotificationTileSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE8EAF0)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Skeleton(
            width: 48,
            height: 48,
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Skeleton(width: double.infinity, height: 14),
                    ),
                    SizedBox(width: 8),
                    Skeleton(
                      width: 8,
                      height: 8,
                      borderRadius: BorderRadius.all(Radius.circular(4)),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Skeleton(width: double.infinity, height: 12),
                SizedBox(height: 6),
                Skeleton(width: 180, height: 12),
                SizedBox(height: 8),
                Skeleton(width: 72, height: 10),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Profile
// ---------------------------------------------------------------------------

class ProfileSkeleton extends StatelessWidget {
  const ProfileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerScope(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        child: Column(
          children: [
            const Skeleton(
              width: 120,
              height: 120,
              borderRadius: BorderRadius.all(Radius.circular(60)),
            ),
            const SizedBox(height: 10),
            const Skeleton(width: 160, height: 12),
            const SizedBox(height: 24),
            // Checklist card
            _sectionCard(
              children: const [
                Skeleton(width: 160, height: 16),
                SizedBox(height: 16),
                _IconTextRowSkeleton(),
                SizedBox(height: 12),
                _IconTextRowSkeleton(),
              ],
            ),
            const SizedBox(height: 16),
            // Info card
            _sectionCard(
              children: [
                for (var i = 0; i < 5; i++) ...[
                  if (i > 0) const SizedBox(height: 14),
                  const _InfoRowSkeleton(),
                ],
              ],
            ),
            const SizedBox(height: 16),
            // Settings card
            _sectionCard(
              children: [
                for (var i = 0; i < 6; i++) ...[
                  if (i > 0) const SizedBox(height: 4),
                  const _SettingRowSkeleton(),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  static Widget _sectionCard({required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class _IconTextRowSkeleton extends StatelessWidget {
  const _IconTextRowSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Skeleton(
          width: 22,
          height: 22,
          borderRadius: BorderRadius.all(Radius.circular(11)),
        ),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Skeleton(width: 120, height: 12),
              SizedBox(height: 6),
              Skeleton(width: 180, height: 10),
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoRowSkeleton extends StatelessWidget {
  const _InfoRowSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Skeleton(
          width: 40,
          height: 40,
          borderRadius: BorderRadius.all(Radius.circular(10)),
        ),
        SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Skeleton(width: 80, height: 10),
              SizedBox(height: 6),
              Skeleton(width: 160, height: 14),
            ],
          ),
        ),
      ],
    );
  }
}

class _SettingRowSkeleton extends StatelessWidget {
  const _SettingRowSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Skeleton(
            width: 32,
            height: 32,
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
          SizedBox(width: 14),
          Expanded(child: Skeleton(width: double.infinity, height: 14)),
          SizedBox(width: 12),
          Skeleton(
            width: 40,
            height: 22,
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
        ],
      ),
    );
  }
}

/// Notification settings — toggle rows matching the prefs screen cards.
class NotificationSettingsSkeleton extends StatelessWidget {
  const NotificationSettingsSkeleton({super.key, this.rows = 8});

  final int rows;

  @override
  Widget build(BuildContext context) {
    return ShimmerScope(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          const Skeleton(width: 120, height: 14),
          const SizedBox(height: 8),
          const Skeleton(width: 220, height: 11),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                for (var i = 0; i < rows; i++) ...[
                  if (i > 0) const Divider(height: 1),
                  const _SettingRowSkeleton(),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Home important-dates calendar placeholder (month grid + list strip).
class HomeCalendarSkeleton extends StatelessWidget {
  const HomeCalendarSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerScope(
      child: Container(
        height: 320,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          children: [
            const Row(
              children: [
                Skeleton(width: 28, height: 28),
                Spacer(),
                Skeleton(width: 120, height: 16),
                Spacer(),
                Skeleton(width: 28, height: 28),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: GridView.count(
                crossAxisCount: 7,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                children: List.generate(
                  28,
                  (_) => const Skeleton(
                    width: double.infinity,
                    height: double.infinity,
                    borderRadius: BorderRadius.all(Radius.circular(8)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Alumni digital card footprint on Profile.
class AlumniCardSkeleton extends StatelessWidget {
  const AlumniCardSkeleton({
    super.key,
    this.maxWidth = 380,
    this.aspectRatio = 1.586,
  });

  final double maxWidth;
  final double aspectRatio;

  @override
  Widget build(BuildContext context) {
    return ShimmerScope(
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: AspectRatio(
            aspectRatio: aspectRatio,
            child: const Skeleton(
              width: double.infinity,
              height: double.infinity,
              borderRadius: BorderRadius.all(Radius.circular(14)),
            ),
          ),
        ),
      ),
    );
  }
}

/// My Surveys list — mirrors survey row chips + title + CTA layout.
class SurveyListSkeleton extends StatelessWidget {
  const SurveyListSkeleton({super.key, this.count = 4});

  final int count;

  @override
  Widget build(BuildContext context) {
    return ShimmerScope(
      child: SizedBox.expand(
        child: ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
          itemCount: count,
          itemBuilder: (_, i) => Padding(
            padding: EdgeInsets.only(bottom: i < count - 1 ? 12 : 0),
            child: const _SurveyRowCardSkeleton(),
          ),
        ),
      ),
    );
  }
}

class _SurveyRowCardSkeleton extends StatelessWidget {
  const _SurveyRowCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Skeleton(
                width: 96,
                height: 24,
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
              Spacer(),
              Skeleton(
                width: 88,
                height: 24,
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
            ],
          ),
          SizedBox(height: 12),
          Skeleton(width: double.infinity, height: 16),
          SizedBox(height: 6),
          Skeleton(width: 200, height: 12),
          SizedBox(height: 6),
          Skeleton(width: 120, height: 11),
          SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: Skeleton(
              width: 96,
              height: 36,
              borderRadius: BorderRadius.all(Radius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }
}

class _FormFieldSkeleton extends StatelessWidget {
  const _FormFieldSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Skeleton(width: 100, height: 12),
        SizedBox(height: 8),
        Skeleton(
          width: double.infinity,
          height: 48,
          borderRadius: BorderRadius.all(Radius.circular(10)),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Portal lists (announcements / surveys / forum / feedback)
// ---------------------------------------------------------------------------

/// Generic avatar ListTile cards (surveys / forum). Prefer dedicated
/// skeletons when the layout differs.
class PortalCardListSkeleton extends StatelessWidget {
  const PortalCardListSkeleton({
    super.key,
    this.count = 5,
    this.shrinkWrap = false,
    this.threeLine = false,
  });

  final int count;
  final bool shrinkWrap;
  final bool threeLine;

  @override
  Widget build(BuildContext context) {
    return ShimmerScope(
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        shrinkWrap: shrinkWrap,
        physics: shrinkWrap
            ? const NeverScrollableScrollPhysics()
            : const AlwaysScrollableScrollPhysics(),
        itemCount: count,
        itemBuilder: (_, __) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _ListTileCardSkeleton(threeLine: threeLine),
        ),
      ),
    );
  }
}

class _ListTileCardSkeleton extends StatelessWidget {
  const _ListTileCardSkeleton({this.threeLine = false});

  final bool threeLine;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const Skeleton(
            width: 40,
            height: 40,
            borderRadius: BorderRadius.all(Radius.circular(20)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Skeleton(width: double.infinity, height: 16),
                const SizedBox(height: 8),
                const Skeleton(width: 140, height: 12),
                if (threeLine) ...[
                  const SizedBox(height: 6),
                  const Skeleton(width: 110, height: 12),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Skeleton(
            width: 18,
            height: 18,
            borderRadius: BorderRadius.all(Radius.circular(4)),
          ),
        ],
      ),
    );
  }
}

/// Announcements — ExpansionTile with leading icon (not avatar).
class AnnouncementListSkeleton extends StatelessWidget {
  const AnnouncementListSkeleton({super.key, this.count = 5});

  final int count;

  @override
  Widget build(BuildContext context) {
    return ShimmerScope(
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: count,
        itemBuilder: (_, __) => const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: _AnnouncementCardSkeleton(),
        ),
      ),
    );
  }
}

class _AnnouncementCardSkeleton extends StatelessWidget {
  const _AnnouncementCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const Row(
        children: [
          Skeleton(
            width: 40,
            height: 40,
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Skeleton(width: double.infinity, height: 16),
                SizedBox(height: 8),
                Skeleton(width: 120, height: 12),
              ],
            ),
          ),
          SizedBox(width: 8),
          Skeleton(
            width: 18,
            height: 18,
            borderRadius: BorderRadius.all(Radius.circular(4)),
          ),
        ],
      ),
    );
  }
}

/// Feedback list — chip row + preview text (no avatar).
class FeedbackListSkeleton extends StatelessWidget {
  const FeedbackListSkeleton({super.key, this.count = 5});

  final int count;

  @override
  Widget build(BuildContext context) {
    return ShimmerScope(
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: count,
        itemBuilder: (_, __) => const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: _FeedbackCardSkeleton(),
        ),
      ),
    );
  }
}

class _FeedbackCardSkeleton extends StatelessWidget {
  const _FeedbackCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Skeleton(
                width: 72,
                height: 22,
                borderRadius: BorderRadius.all(Radius.circular(11)),
              ),
              Spacer(),
              Skeleton(
                width: 64,
                height: 22,
                borderRadius: BorderRadius.all(Radius.circular(11)),
              ),
            ],
          ),
          SizedBox(height: 14),
          Skeleton(width: double.infinity, height: 15),
          SizedBox(height: 6),
          Skeleton(width: 200, height: 15),
          SizedBox(height: 10),
          Skeleton(width: 140, height: 12),
          SizedBox(height: 8),
          Skeleton(width: 80, height: 10),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tracer forms
// ---------------------------------------------------------------------------

class TracerFormSkeleton extends StatelessWidget {
  const TracerFormSkeleton({super.key, this.fieldCount = 6});

  final int fieldCount;

  @override
  Widget build(BuildContext context) {
    final sectionFields = (fieldCount / 2).ceil().clamp(2, 6);
    // SizedBox.expand keeps page-level placeholders full-height under
    // PortalContentFrame's Align (avoids a visible shrink before content).
    return ShimmerScope(
      child: SizedBox.expand(
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
          children: [
          // Navy intro hero
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF2A2D6B),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Skeleton(
                      width: 28,
                      height: 28,
                      borderRadius: BorderRadius.all(Radius.circular(8)),
                    ),
                    SizedBox(width: 12),
                    Skeleton(width: 160, height: 16),
                  ],
                ),
                SizedBox(height: 12),
                Skeleton(width: double.infinity, height: 12),
                SizedBox(height: 6),
                Skeleton(width: 220, height: 12),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _tracerSection(sectionFields),
          const SizedBox(height: 12),
          _tracerSection(
            fieldCount - sectionFields > 0 ? fieldCount - sectionFields : 2,
          ),
          const SizedBox(height: 20),
          const Skeleton(
            width: double.infinity,
            height: 52,
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
        ],
        ),
      ),
    );
  }

  static Widget _tracerSection(int fields) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Skeleton(
                width: 20,
                height: 20,
                borderRadius: BorderRadius.all(Radius.circular(4)),
              ),
              SizedBox(width: 10),
              Skeleton(width: 140, height: 14),
            ],
          ),
          const SizedBox(height: 8),
          const Skeleton(width: 200, height: 11),
          const SizedBox(height: 16),
          ...List.generate(
            fields.clamp(1, 8),
            (i) => Padding(
              padding: EdgeInsets.only(
                bottom: i < fields.clamp(1, 8) - 1 ? 16 : 0,
              ),
              child: const _FormFieldSkeleton(),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Survey take
// ---------------------------------------------------------------------------

class SurveyFormSkeleton extends StatelessWidget {
  const SurveyFormSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerScope(
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              children: [
                const Skeleton(width: double.infinity, height: 18),
                const SizedBox(height: 8),
                const Skeleton(width: 240, height: 12),
                const SizedBox(height: 16),
                const Skeleton(
                  width: double.infinity,
                  height: 44,
                  borderRadius: BorderRadius.all(Radius.circular(8)),
                ),
                const SizedBox(height: 24),
                for (var i = 0; i < 4; i++) ...[
                  if (i > 0) const SizedBox(height: 28),
                  const Skeleton(width: double.infinity, height: 14),
                  const SizedBox(height: 12),
                  if (i.isEven)
                    const Skeleton(
                      width: double.infinity,
                      height: 72,
                      borderRadius: BorderRadius.all(Radius.circular(8)),
                    )
                  else ...[
                    for (var r = 0; r < 3; r++) ...[
                      if (r > 0) const SizedBox(height: 10),
                      const Row(
                        children: [
                          Skeleton(
                            width: 20,
                            height: 20,
                            borderRadius: BorderRadius.all(Radius.circular(10)),
                          ),
                          SizedBox(width: 12),
                          Expanded(child: Skeleton(height: 14)),
                        ],
                      ),
                    ],
                  ],
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFE8EAF0))),
            ),
            child: const Row(
              children: [
                Expanded(
                  child: Skeleton(
                    height: 48,
                    borderRadius: BorderRadius.all(Radius.circular(10)),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Skeleton(
                    height: 48,
                    borderRadius: BorderRadius.all(Radius.circular(10)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Comments
// ---------------------------------------------------------------------------

class CommentListSkeleton extends StatelessWidget {
  const CommentListSkeleton({super.key, this.count = 4});

  final int count;

  @override
  Widget build(BuildContext context) {
    return ShimmerScope(
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: count,
        itemBuilder: (_, __) => const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: _CommentCardSkeleton(),
        ),
      ),
    );
  }
}

class _CommentCardSkeleton extends StatelessWidget {
  const _CommentCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8EAF0)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Skeleton(
                width: 32,
                height: 32,
                borderRadius: BorderRadius.all(Radius.circular(16)),
              ),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Skeleton(width: 100, height: 12),
                    SizedBox(height: 4),
                    Skeleton(width: 72, height: 10),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Skeleton(width: double.infinity, height: 12),
          SizedBox(height: 6),
          Skeleton(width: double.infinity, height: 12),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Feedback detail
// ---------------------------------------------------------------------------

class FeedbackDetailSkeleton extends StatelessWidget {
  const FeedbackDetailSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerScope(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Skeleton(
                      width: 80,
                      height: 22,
                      borderRadius: BorderRadius.all(Radius.circular(11)),
                    ),
                    Spacer(),
                    Skeleton(
                      width: 64,
                      height: 22,
                      borderRadius: BorderRadius.all(Radius.circular(11)),
                    ),
                  ],
                ),
                SizedBox(height: 14),
                Skeleton(width: double.infinity, height: 16),
                SizedBox(height: 10),
                Skeleton(width: 120, height: 12),
                SizedBox(height: 12),
                Row(
                  children: [
                    Skeleton(
                      width: 18,
                      height: 18,
                      borderRadius: BorderRadius.all(Radius.circular(2)),
                    ),
                    SizedBox(width: 6),
                    Skeleton(
                      width: 18,
                      height: 18,
                      borderRadius: BorderRadius.all(Radius.circular(2)),
                    ),
                    SizedBox(width: 6),
                    Skeleton(
                      width: 18,
                      height: 18,
                      borderRadius: BorderRadius.all(Radius.circular(2)),
                    ),
                    SizedBox(width: 6),
                    Skeleton(
                      width: 18,
                      height: 18,
                      borderRadius: BorderRadius.all(Radius.circular(2)),
                    ),
                    SizedBox(width: 6),
                    Skeleton(
                      width: 18,
                      height: 18,
                      borderRadius: BorderRadius.all(Radius.circular(2)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Skeleton(width: 110, height: 14),
                SizedBox(height: 14),
                Skeleton(width: double.infinity, height: 12),
                SizedBox(height: 8),
                Skeleton(width: double.infinity, height: 12),
                SizedBox(height: 8),
                Skeleton(width: double.infinity, height: 12),
                SizedBox(height: 8),
                Skeleton(width: 180, height: 12),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Skeleton(width: 120, height: 14),
                SizedBox(height: 14),
                Skeleton(width: double.infinity, height: 12),
                SizedBox(height: 8),
                Skeleton(width: double.infinity, height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
