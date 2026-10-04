import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:alumni_system/features/feedback/models/feedback_model.dart';
import 'package:alumni_system/features/admin/feedback/presentation/admin_feedback_detail_page.dart';
import 'package:alumni_system/features/feedback/data/feedback_service.dart';
import 'package:alumni_system/features/admin/roster/widgets/alumni_directory_ui.dart';
import 'package:alumni_system/shared/widgets/admin/admin_skeletons.dart';

class AdminFeedbackScreen extends StatefulWidget {
  const AdminFeedbackScreen({super.key});

  @override
  State<AdminFeedbackScreen> createState() => _AdminFeedbackScreenState();
}

class _AdminFeedbackScreenState extends State<AdminFeedbackScreen> {
  static const Color _navy = Color(0xFF090A4F);

  final _service = FeedbackService();
  FeedbackStatus? _statusFilter;
  FeedbackCategory? _categoryFilter;

  Color _statusColor(FeedbackStatus status) {
    switch (status) {
      case FeedbackStatus.submitted:
        return Colors.blue;
      case FeedbackStatus.inReview:
        return Colors.orange;
      case FeedbackStatus.resolved:
        return Colors.green;
      case FeedbackStatus.closed:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Text(
              'Feedback',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: _navy,
              ),
            ),
            const Spacer(),
            StreamBuilder<int>(
              stream: _service.watchOpenFeedbackCount(),
              builder: (context, snapshot) {
                final open = snapshot.data ?? 0;
                if (open == 0) return const SizedBox.shrink();
                return Container(
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$open open',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.orange,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            DirectoryToolbarFilterChip(
              label: 'All statuses',
              selected: _statusFilter == null,
              onSelected: (_) => setState(() => _statusFilter = null),
            ),
            ...FeedbackStatus.values.map(
              (s) => DirectoryToolbarFilterChip(
                label: s.label,
                selected: _statusFilter == s,
                onSelected: (_) => setState(() => _statusFilter = s),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            DirectoryToolbarFilterChip(
              label: 'All categories',
              selected: _categoryFilter == null,
              onSelected: (_) => setState(() => _categoryFilter = null),
            ),
            ...FeedbackCategory.values.map(
              (c) => DirectoryToolbarFilterChip(
                label: c.label,
                selected: _categoryFilter == c,
                onSelected: (_) => setState(() => _categoryFilter = c),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: StreamBuilder<List<FeedbackSubmission>>(
            stream: _service.watchAllFeedback(
              statusFilter: _statusFilter,
              categoryFilter: _categoryFilter,
            ),
            builder: (context, snapshot) {
              final waiting =
                  snapshot.connectionState == ConnectionState.waiting;
              final items = snapshot.data ?? [];
              if (waiting && items.isEmpty) {
                return const PortalCardListSkeleton();
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              if (items.isEmpty) {
                return const Center(child: Text('No feedback submissions yet.'));
              }

              return ListView.builder(
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  final date = DateFormat('MMM d, yyyy').format(item.createdAt);
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                AdminFeedbackDetailScreen(feedbackId: item.id),
                          ),
                        );
                      },
                      leading: CircleAvatar(
                        backgroundColor:
                            _statusColor(item.status).withValues(alpha: 0.15),
                        child: Icon(
                          Icons.feedback_outlined,
                          color: _statusColor(item.status),
                        ),
                      ),
                      title: Text(
                        item.userName,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${item.category.label} • ${item.status.label}'),
                          Text(
                            item.subject?.isNotEmpty == true ? item.subject! : item.message,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            date,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                      trailing: item.isOpen
                          ? const Icon(Icons.circle, size: 10, color: Colors.orange)
                          : null,
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

