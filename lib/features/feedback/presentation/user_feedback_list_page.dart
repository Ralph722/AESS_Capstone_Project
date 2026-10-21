import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:alumni_system/features/feedback/models/feedback_model.dart';
import 'package:alumni_system/features/feedback/presentation/user_feedback_detail_page.dart';
import 'package:alumni_system/features/feedback/presentation/user_feedback_submit_page.dart';
import 'package:alumni_system/features/feedback/data/feedback_service.dart';
import 'package:alumni_system/shared/widgets/user/portal_skeletons.dart';
import 'package:alumni_system/shared/widgets/user/portal_states.dart';
import 'package:alumni_system/shared/widgets/user/portal_theme.dart';
import 'package:alumni_system/shared/widgets/user/portal_headers.dart';
import 'package:alumni_system/shared/widgets/user/portal_breakpoints.dart';

class UserFeedbackListScreen extends StatelessWidget {
  const UserFeedbackListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = FeedbackService();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const PortalAppBar(title: 'My Feedback'),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openSubmit(context),
        backgroundColor: PortalTheme.navy,
        foregroundColor: PortalTheme.textOnNavy,
        icon: const Icon(Icons.add_comment_outlined),
        label: const Text('Send feedback'),
      ),
      body: PortalContentFrame(
        child: StreamBuilder<List<FeedbackSubmission>>(
          stream: service.watchMyFeedback(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const FeedbackListSkeleton();
            }
            if (snapshot.hasError) {
              return PortalErrorState(
                error: snapshot.error,
                onRetry: () {},
              );
            }

            final items = snapshot.data ?? [];
            if (items.isEmpty) {
              return PortalEmptyState(
                icon: Icons.feedback_outlined,
                title: 'No feedback yet',
                subtitle:
                    'Share bugs, ideas, or issues with the alumni office. We read every submission.',
                actionLabel: 'Send feedback',
                onAction: () => _openSubmit(context),
              );
            }

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
              children: [
                const PortalPageIntro(
                  headline: 'Your feedback',
                  body:
                      'Track submissions and read replies from the alumni office.',
                  padding: EdgeInsets.fromLTRB(4, 4, 4, 12),
                ),
                ...items.map(
                  (item) => _FeedbackCard(
                    item: item,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              UserFeedbackDetailScreen(feedbackId: item.id),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _openSubmit(BuildContext context) async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => const UserFeedbackSubmitScreen(),
      ),
    );
    if (created == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Thank you! Your feedback was submitted.'),
          backgroundColor: PortalTheme.success,
        ),
      );
    }
  }
}

class _FeedbackCard extends StatelessWidget {
  const _FeedbackCard({required this.item, required this.onTap});

  final FeedbackSubmission item;
  final VoidCallback onTap;

  PortalChipTone _statusTone(FeedbackStatus status) {
    switch (status) {
      case FeedbackStatus.submitted:
        return PortalChipTone.brand;
      case FeedbackStatus.inReview:
        return PortalChipTone.warning;
      case FeedbackStatus.resolved:
        return PortalChipTone.success;
      case FeedbackStatus.closed:
        return PortalChipTone.neutral;
    }
  }

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('MMM d, yyyy').format(item.createdAt);
    final preview =
        item.subject?.isNotEmpty == true ? item.subject! : item.message;
    final subtitle = item.hasAdminResponse
        ? 'Admin replied — tap to read'
        : item.status.label;

    return Padding(
      padding: const EdgeInsets.only(bottom: PortalTheme.space2),
      child: Material(
        color: PortalTheme.card,
        elevation: 1,
        shadowColor: PortalTheme.navy.withValues(alpha: 0.08),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PortalTheme.radius2xl),
          side: const BorderSide(color: PortalTheme.borderStrong),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(PortalTheme.space3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    PortalChip(
                      label: item.category.label,
                      tone: PortalChipTone.brand,
                    ),
                    const Spacer(),
                    PortalChip(
                      label: item.status.label,
                      tone: _statusTone(item.status),
                    ),
                  ],
                ),
                const SizedBox(height: PortalTheme.space2),
                Text(
                  preview,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: PortalTheme.cardTitle.copyWith(fontSize: 15),
                ),
                const SizedBox(height: 6),
                Text(subtitle, style: PortalTheme.meta),
                const SizedBox(height: 6),
                Text(date, style: PortalTheme.caption),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
