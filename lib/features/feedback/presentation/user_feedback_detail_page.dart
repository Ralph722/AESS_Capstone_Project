import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:alumni_system/features/feedback/models/feedback_model.dart';
import 'package:alumni_system/features/feedback/data/feedback_service.dart';
import 'package:alumni_system/shared/widgets/user/portal_skeletons.dart';
import 'package:alumni_system/shared/widgets/user/portal_theme.dart';
import 'package:alumni_system/shared/widgets/user/portal_headers.dart';
import 'package:alumni_system/shared/widgets/user/portal_breakpoints.dart';

class UserFeedbackDetailScreen extends StatefulWidget {
  const UserFeedbackDetailScreen({super.key, required this.feedbackId});

  final String feedbackId;

  @override
  State<UserFeedbackDetailScreen> createState() =>
      _UserFeedbackDetailScreenState();
}

class _UserFeedbackDetailScreenState extends State<UserFeedbackDetailScreen> {
  final _service = FeedbackService();
  FeedbackSubmission? _item;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final item = await _service.getFeedbackById(widget.feedbackId);
      if (!mounted) return;
      setState(() {
        _item = item;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    }
  }

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
    return Scaffold(
      backgroundColor: PortalTheme.pageBg,
      appBar: const PortalAppBar(title: 'Feedback details'),
      body: PortalContentFrame(
        maxWidth: PortalBreakpoints.chatMax,
        child: _loading
            ? const FeedbackDetailSkeleton()
            : _item == null
                ? const Center(child: Text('Feedback not found.'))
                : RefreshIndicator(
                    onRefresh: _load,
                    color: PortalTheme.navy,
                    child: ListView(
                      padding: const EdgeInsets.all(PortalTheme.space4),
                      children: [
                        _MetaCard(
                          item: _item!,
                          statusTone: _statusTone(_item!.status),
                        ),
                        const SizedBox(height: PortalTheme.space3),
                        _SectionCard(
                          title: 'Your message',
                          child: Text(
                            _item!.message,
                            style: PortalTheme.body.copyWith(height: 1.5),
                          ),
                        ),
                        if (_item!.hasAdminResponse) ...[
                          const SizedBox(height: PortalTheme.space3),
                          _SectionCard(
                            title: 'Office response',
                            accent: PortalTheme.success,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (_item!.respondedByName != null)
                                  Text(
                                    _item!.respondedByName!,
                                    style: PortalTheme.meta.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: PortalTheme.textPrimary,
                                    ),
                                  ),
                                if (_item!.respondedAt != null)
                                  Text(
                                    DateFormat('MMM d, yyyy • h:mm a')
                                        .format(_item!.respondedAt!),
                                    style: PortalTheme.caption,
                                  ),
                                const SizedBox(height: PortalTheme.space2),
                                Text(
                                  _item!.adminResponse!,
                                  style: PortalTheme.body.copyWith(height: 1.5),
                                ),
                              ],
                            ),
                          ),
                        ] else
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              'No response yet. The office will review your feedback soon.',
                              style: PortalTheme.bodySecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
      ),
    );
  }
}

class _MetaCard extends StatelessWidget {
  const _MetaCard({required this.item, required this.statusTone});

  final FeedbackSubmission item;
  final PortalChipTone statusTone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(PortalTheme.space3),
      decoration: BoxDecoration(
        color: PortalTheme.card,
        borderRadius: BorderRadius.circular(PortalTheme.radiusMd),
        border: Border.all(color: PortalTheme.border),
        boxShadow: PortalTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PortalChip(label: item.category.label, tone: PortalChipTone.brand),
              const Spacer(),
              PortalChip(label: item.status.label, tone: statusTone),
            ],
          ),
          if (item.subject?.isNotEmpty == true) ...[
            const SizedBox(height: PortalTheme.space2),
            Text(
              item.subject!,
              style: PortalTheme.sectionTitle.copyWith(fontSize: 18),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            DateFormat('MMMM d, yyyy').format(item.createdAt),
            style: PortalTheme.meta,
          ),
          if (item.rating != null) ...[
            const SizedBox(height: 8),
            Row(
              children: List.generate(
                5,
                (i) => Icon(
                  i < item.rating! ? Icons.star : Icons.star_border,
                  color: PortalTheme.gold,
                  size: 20,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.child,
    this.accent,
  });

  final String title;
  final Widget child;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final color = accent ?? PortalTheme.navy;
    return Container(
      padding: const EdgeInsets.all(PortalTheme.space3),
      decoration: BoxDecoration(
        color: PortalTheme.card,
        borderRadius: BorderRadius.circular(PortalTheme.radiusMd),
        border: Border.all(color: PortalTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: PortalTheme.cardTitle.copyWith(
              fontSize: 14,
              color: color,
            ),
          ),
          const SizedBox(height: PortalTheme.space2),
          child,
        ],
      ),
    );
  }
}
