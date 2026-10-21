import 'package:intl/intl.dart';
import 'package:alumni_system/features/events/models/event_model.dart';
import 'package:alumni_system/features/forum/models/forum_model.dart';
import 'package:alumni_system/features/jobs/models/job_posting_model.dart';
import 'package:alumni_system/features/share/share_destination.dart';
import 'package:alumni_system/features/surveys/models/survey_model.dart';

/// Everything the share sheet and (later) other shareable features need.
/// New content types only have to produce one of these.
class ShareableContent {
  const ShareableContent({
    required this.destination,
    required this.title,
    required this.statusLabel,
    required this.audienceLabel,
    required this.isShareable,
    this.unavailableReason,
  });

  final ShareDestination destination;
  final String title;

  /// e.g. `Open now`, `Scheduled`, `Closed`.
  final String statusLabel;

  /// Who may open the link, e.g. `Assigned alumni only · sign-in required`.
  final String audienceLabel;
  final bool isShareable;
  final String? unavailableReason;

  String get canonicalUrl => destination.canonicalUri.toString();

  String get shareText {
    return switch (destination.type) {
      ShareResourceType.tracer =>
        '$title\n\nTake this Graduate Tracer Study through AESS:\n$canonicalUrl',
      ShareResourceType.customSurvey =>
        '$title\n\nTake this survey through AESS:\n$canonicalUrl',
      ShareResourceType.event =>
        '$title\n\nView this event on AESS:\n$canonicalUrl',
      ShareResourceType.job =>
        '$title\n\nView this job on AESS:\n$canonicalUrl',
      ShareResourceType.forumTopic =>
        '$title\n\nJoin this discussion on AESS:\n$canonicalUrl',
    };
  }

  factory ShareableContent.fromTopic(ForumTopic topic) {
    return ShareableContent(
      destination: ShareDestination(
        type: ShareResourceType.forumTopic,
        surveyId: topic.id,
      ),
      title: topic.title.trim().isEmpty ? 'Untitled discussion' : topic.title,
      statusLabel: topic.isLocked
          ? 'Locked · readable'
          : '${topic.replyCount} ${topic.replyCount == 1 ? 'reply' : 'replies'}',
      audienceLabel: 'Signed-in alumni',
      // Topics have no draft/hidden state: a fetchable topic is readable
      // by signed-in alumni; deleted topics no longer resolve at all.
      isShareable: true,
    );
  }

  factory ShareableContent.fromJob(JobPosting job) {
    final shareable = job.isActiveForAlumni;
    final fmt = DateFormat.yMMMd();
    final programs = job.targetPrograms.isEmpty
        ? ''
        : ' · ${job.targetPrograms.join(', ')}';
    return ShareableContent(
      destination: ShareDestination(
        type: ShareResourceType.job,
        surveyId: job.id,
      ),
      title: job.jobTitle.trim().isEmpty ? 'Untitled job' : job.jobTitle,
      statusLabel: job.isExpiredByDeadline
          ? 'Application deadline passed'
          : shareable
          ? 'Apply by ${fmt.format(job.applicationDeadline)}'
          : job.status,
      audienceLabel: 'Signed-in alumni$programs',
      isShareable: shareable,
      unavailableReason: shareable
          ? null
          : 'Only active job postings within their application deadline '
                'can be shared.',
    );
  }

  factory ShareableContent.fromEvent(AlumniEvent event) {
    final archived = event.status.trim().toLowerCase() == 'archived';
    final shareable = !event.cancelled && !archived;
    final fmt = DateFormat.yMMMd();
    final batch = event.batchYear.trim();
    return ShareableContent(
      destination: ShareDestination(
        type: ShareResourceType.event,
        surveyId: event.id,
      ),
      title: event.theme.trim().isEmpty ? 'Untitled event' : event.theme,
      statusLabel: event.cancelled
          ? 'Cancelled'
          : archived
          ? 'Archived'
          : '${fmt.format(event.date)}${event.venue.trim().isEmpty ? '' : ' · ${event.venue.trim()}'}',
      audienceLabel:
          'Signed-in alumni${batch.isEmpty ? '' : ' · Batch $batch'}',
      isShareable: shareable,
      unavailableReason: shareable
          ? null
          : 'Only active events can be shared. '
                'Cancelled or archived events cannot be shared.',
    );
  }

  factory ShareableContent.fromSurvey(Survey survey) {
    final destination = ShareDestination(
      type: survey.isChedGtsBuiltin
          ? ShareResourceType.tracer
          : ShareResourceType.customSurvey,
      surveyId: survey.id,
    );
    final shareable =
        survey.status == SurveyStatus.published && !survey.archived;
    final fmt = DateFormat.yMMMd();
    final statusLabel = !shareable
        ? (survey.archived
              ? 'Archived'
              : survey.status == SurveyStatus.closed
              ? 'Closed'
              : 'Draft')
        : survey.isOpen
        ? 'Open now'
        : survey.isNotYetOpen
        ? 'Opens ${fmt.format(survey.openAt!)}'
        : 'Window ended';
    return ShareableContent(
      destination: destination,
      title: survey.title.trim().isEmpty ? 'Untitled survey' : survey.title,
      statusLabel: statusLabel,
      audienceLabel: _audienceLabel(survey),
      isShareable: shareable,
      unavailableReason: shareable
          ? null
          : 'Only published surveys can be shared. '
                'Publish this survey first, then share its link.',
    );
  }

  static String _audienceLabel(Survey survey) {
    final programs = survey.targetPrograms.isEmpty
        ? 'All programs'
        : survey.targetPrograms.join(', ');
    final batches = survey.targetBatchYears.isEmpty
        ? 'all batches'
        : 'batches ${survey.targetBatchYears.join(', ')}';
    return 'Assigned alumni only · sign-in required · $programs · $batches';
  }
}
