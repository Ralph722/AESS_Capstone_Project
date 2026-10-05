import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:alumni_system/features/events/models/event_model.dart';
import 'package:alumni_system/features/jobs/models/job_posting_model.dart';
import 'package:alumni_system/features/events/data/event_service.dart';
import 'package:alumni_system/features/jobs/data/job_service.dart';
import 'package:alumni_system/features/surveys/models/survey_model.dart';
import 'package:alumni_system/features/surveys/data/survey_service.dart';
import 'package:alumni_system/shared/widgets/admin/admin_skeletons.dart';
import 'package:alumni_system/shared/widgets/admin/admin_search_field.dart';

class AdminArchivesScreen extends StatefulWidget {
  const AdminArchivesScreen({super.key});

  @override
  State<AdminArchivesScreen> createState() => _AdminArchivesScreenState();
}

class _AdminArchivesScreenState extends State<AdminArchivesScreen> {
  final EventService _eventService = EventService();
  final JobService _jobService = JobService();
  final SurveyService _surveyService = SurveyService();
  List<AlumniEvent> archivedEventsList = [];
  List<JobPosting> archivedJobs = [];
  List<Survey> archivedSurveys = [];
  int _archivesTabIndex = 0;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadArchives();
  }

  Future<void> _loadArchives() async {
    try {
      setState(() => isLoading = true);
      final events = await _eventService.getArchivedEvents();
      List<JobPosting> jobs = [];
      try {
        jobs = await _jobService.getJobsByStatus('archived');
      } catch (_) {
        jobs = [];
      }
      List<Survey> surveys = [];
      try {
        final all = await _surveyService.getAllSurveysForAdmin();
        surveys = all.where((s) => s.archived).toList();
      } catch (_) {
        surveys = [];
      }
      if (mounted) {
        setState(() {
          archivedEventsList = events;
          archivedJobs = jobs;
          archivedSurveys = surveys;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading archives: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final hasBoundedHeight =
            constraints.maxHeight.isFinite && constraints.maxHeight > 0;

        if (hasBoundedHeight) {
          return SizedBox(
            height: constraints.maxHeight,
            child: _buildArchivedContent(flexBody: true),
          );
        }

        return _buildArchivedContent(flexBody: false);
      },
    );
  }

  Future<void> _restoreEvent(String eventId) async {
    try {
      await _eventService.restoreEvent(eventId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Event restored')),
      );
      await _loadArchives();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error restoring event: $e')),
      );
    }
  }

  Future<void> _deleteEvent(String eventId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Event'),
        content: const Text(
          'Are you sure you want to permanently delete this event?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _eventService.deleteEvent(eventId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Event deleted')),
      );
      await _loadArchives();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting event: $e')),
      );
    }
  }

  Widget _buildArchivedContent({required bool flexBody}) {
    final Widget tabContent;
    switch (_archivesTabIndex) {
      case 0:
        tabContent = _buildArchivedEventsTab(scrollable: flexBody);
      case 1:
        tabContent = _buildArchivedJobsTab(scrollable: flexBody);
      default:
        tabContent = _buildArchivedSurveysTab(scrollable: flexBody);
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with Tabs
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Color(0xFF090A4F),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(
                        Icons.archive,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Archives',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Tabs
                Row(
                  children: [
                    _buildArchiveTab(
                      0,
                      'Events',
                      archivedEventsList.length,
                      Icons.event,
                    ),
                    const SizedBox(width: 12),
                    _buildArchiveTab(
                      1,
                      'Job Postings',
                      (archivedJobs.isNotEmpty) ? archivedJobs.length : 0,
                      Icons.work,
                    ),
                    const SizedBox(width: 12),
                    _buildArchiveTab(
                      2,
                      'Surveys',
                      archivedSurveys.length,
                      Icons.poll_outlined,
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Tab Content
          if (flexBody) Expanded(child: tabContent) else tabContent,
        ],
      ),
    );
  }

  Widget _buildArchiveTab(int index, String label, int count, IconData icon) {
    final isSelected = _archivesTabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _archivesTabIndex = index;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected ? const Color(0xFF090A4F) : Colors.white70,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? const Color(0xFF090A4F) : Colors.white70,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF090A4F).withOpacity(0.1)
                      : Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  count.toString(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? const Color(0xFF090A4F) : Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildArchivedEventsTab({bool scrollable = true}) {
    if (isLoading && archivedEventsList.isEmpty) {
      return const AdminArchiveListSkeleton();
    }
    if (archivedEventsList.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.event_busy, size: 64, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              Text(
                'No archived events',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: !scrollable,
      physics: scrollable
          ? null
          : const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(12),
      itemCount: archivedEventsList.length,
      itemBuilder: (context, index) {
        final event = archivedEventsList[index];
        return _buildArchivedEventCard(event);
      },
    );
  }

  Widget _buildArchivedEventCard(AlumniEvent event) {
    return AdminHoverShell(
      builder: (context, hovered) => Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: hovered
              ? const Color(0xFF090A4F).withValues(alpha: 0.25)
              : Colors.grey.shade300,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: hovered ? 0.08 : 0.03),
            blurRadius: hovered ? 10 : 4,
            offset: Offset(0, hovered ? 4 : 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.grey.shade400,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        event.theme,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF090A4F),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade400,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'Archived',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 14,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      DateFormat('MMM d, yyyy').format(event.date),
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Icon(
                      Icons.location_on,
                      size: 14,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        event.venue,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(Icons.comment, size: 14, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text(
                      '${event.comments}',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          PopupMenuButton(
            tooltip: 'Archive actions',
            icon: Icon(Icons.more_vert, color: Colors.grey.shade600),
            itemBuilder: (context) => [
              PopupMenuItem(
                child: const Row(
                  children: [
                    Icon(Icons.restore, size: 18, color: Colors.green),
                    SizedBox(width: 8),
                    Text('Restore'),
                  ],
                ),
                onTap: () => Future.delayed(
                  const Duration(milliseconds: 100),
                  () => _restoreEvent(event.id),
                ),
              ),
              PopupMenuItem(
                child: const Row(
                  children: [
                    Icon(Icons.delete, size: 18, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Delete'),
                  ],
                ),
                onTap: () => Future.delayed(
                  const Duration(milliseconds: 100),
                  () => _deleteEvent(event.id),
                ),
              ),
            ],
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildArchivedJobsTab({bool scrollable = true}) {
    if (isLoading && archivedJobs.isEmpty) {
      return const AdminArchiveListSkeleton();
    }
    if (archivedJobs.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.work_off, size: 64, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              Text(
                'No archived job postings',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: !scrollable,
      physics: scrollable
          ? null
          : const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(12),
      itemCount: archivedJobs.length,
      itemBuilder: (context, index) {
        final job = archivedJobs[index];
        return _buildArchivedJobCard(job);
      },
    );
  }

  Widget _buildArchivedJobCard(JobPosting job) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.grey.shade400,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        job.jobTitle,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF090A4F),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade400,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'Archived',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.business, size: 14, color: Colors.grey.shade600),
                    const SizedBox(width: 6),
                    Text(
                      job.companyName,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      Icons.location_on,
                      size: 14,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      job.location,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    if (job.isRemote) ...[
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Remote',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.blue.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                    const Spacer(),
                    Icon(
                      Icons.visibility,
                      size: 14,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${job.views}',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 14,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Posted: ${DateFormat('MMM d, yyyy').format(job.postedDate)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          PopupMenuButton(
            tooltip: 'Archive actions',
            icon: Icon(Icons.more_vert, color: Colors.grey.shade600),
            itemBuilder: (context) => [
              PopupMenuItem(
                child: const Row(
                  children: [
                    Icon(Icons.restore, size: 18, color: Colors.green),
                    SizedBox(width: 8),
                    Text('Restore'),
                  ],
                ),
                onTap: () => Future.delayed(
                  const Duration(milliseconds: 100),
                  () => _restoreJob(job.id),
                ),
              ),
              PopupMenuItem(
                child: const Row(
                  children: [
                    Icon(Icons.delete, size: 18, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Delete'),
                  ],
                ),
                onTap: () => Future.delayed(
                  const Duration(milliseconds: 100),
                  () => _deleteJob(job.id),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _restoreJob(String jobId) async {
    try {
      if (archivedJobs.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Job not found')));
        return;
      }
      final job = archivedJobs.firstWhere((j) => j.id == jobId);
      await _jobService.updateJobPosting(job.copyWith(status: 'active'));
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Job posting restored')));
      await _loadArchives();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error restoring job: $e')));
    }
  }

  Future<void> _deleteJob(String jobId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Job Posting'),
        content: const Text(
          'Are you sure you want to permanently delete this job posting?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _jobService.deleteJobPosting(jobId);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Job posting deleted')));
      await _loadArchives();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error deleting job: $e')));
    }
  }

  Widget _buildArchivedSurveysTab({bool scrollable = true}) {
    if (isLoading && archivedSurveys.isEmpty) {
      return const AdminArchiveListSkeleton();
    }
    if (archivedSurveys.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.poll_outlined, size: 64, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              Text(
                'No archived surveys',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final list = ListView.separated(
      shrinkWrap: !scrollable,
      physics: scrollable
          ? const AlwaysScrollableScrollPhysics()
          : const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(12),
      itemCount: archivedSurveys.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final survey = archivedSurveys[index];
        return _buildArchivedSurveyCard(survey);
      },
    );

    return scrollable ? list : list;
  }

  Widget _buildArchivedSurveyCard(Survey survey) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  survey.title.isEmpty ? 'Untitled survey' : survey.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${survey.status.name} · ${survey.responseCount} responses · '
                  'Created ${DateFormat.yMMMd().format(survey.createdAt)}',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          PopupMenuButton(
            tooltip: 'Archive actions',
            icon: Icon(Icons.more_vert, color: Colors.grey.shade600),
            itemBuilder: (context) => [
              PopupMenuItem(
                child: const Row(
                  children: [
                    Icon(Icons.restore, size: 18, color: Colors.green),
                    SizedBox(width: 8),
                    Text('Restore'),
                  ],
                ),
                onTap: () => Future.delayed(
                  const Duration(milliseconds: 100),
                  () => _restoreSurvey(survey.id),
                ),
              ),
              PopupMenuItem(
                child: const Row(
                  children: [
                    Icon(Icons.delete, size: 18, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Delete'),
                  ],
                ),
                onTap: () => Future.delayed(
                  const Duration(milliseconds: 100),
                  () => _deleteSurvey(survey.id),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _restoreSurvey(String surveyId) async {
    try {
      await _surveyService.setSurveyArchived(surveyId, archived: false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Survey restored')),
      );
      await _loadArchives();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error restoring survey: $e')),
      );
    }
  }

  Future<void> _deleteSurvey(String surveyId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Survey'),
        content: const Text(
          'Are you sure you want to permanently delete this survey?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _surveyService.deleteSurvey(surveyId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Survey deleted')),
      );
      await _loadArchives();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting survey: $e')),
      );
    }
  }
}
