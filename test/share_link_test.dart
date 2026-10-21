import 'package:flutter_test/flutter_test.dart';
import 'package:alumni_system/features/events/models/event_model.dart';
import 'package:alumni_system/features/forum/data/forum_service.dart';
import 'package:alumni_system/features/forum/models/forum_model.dart';
import 'package:alumni_system/features/jobs/models/job_posting_model.dart';
import 'package:alumni_system/features/share/share_destination.dart';
import 'package:alumni_system/features/share/shareable_content.dart';
import 'package:alumni_system/features/surveys/models/survey_model.dart';

const _id = '123e4567-e89b-42d3-a456-426614174000';

Survey _survey({
  SurveyStatus status = SurveyStatus.published,
  bool builtin = false,
  bool archived = false,
}) {
  return Survey(
    id: _id,
    title: 'Tracer 2026',
    description: '',
    status: status,
    createdBy: 'admin',
    createdAt: DateTime(2026, 1, 1),
    kind: builtin ? 'ched_gts_builtin' : null,
    archived: archived,
  );
}

void main() {
  group('ShareLinkParser', () {
    test('parses tracer and survey canonical URLs', () {
      expect(
        ShareLinkParser.parse(
          Uri.parse('https://ustp-aess.web.app/tracer/$_id'),
        ),
        const ShareDestination(type: ShareResourceType.tracer, surveyId: _id),
      );
      expect(
        ShareLinkParser.parse(
          Uri.parse('https://ustp-aess.firebaseapp.com/surveys/$_id?ref=fb'),
        ),
        const ShareDestination(
          type: ShareResourceType.customSurvey,
          surveyId: _id,
        ),
      );
    });

    test('rejects foreign hosts, http, bad ids and unknown paths', () {
      expect(
        ShareLinkParser.parse(Uri.parse('https://evil.example/surveys/$_id')),
        isNull,
      );
      expect(
        ShareLinkParser.parse(
          Uri.parse('http://ustp-aess.web.app/surveys/$_id'),
        ),
        isNull,
      );
      expect(
        ShareLinkParser.parse(
          Uri.parse('https://ustp-aess.web.app/surveys/not-a-uuid'),
        ),
        isNull,
      );
      expect(
        ShareLinkParser.parse(
          Uri.parse('https://ustp-aess.web.app/announcements/$_id'),
        ),
        isNull,
      );
      expect(
        ShareLinkParser.parse(
          Uri.parse('https://ustp-aess.web.app/surveys/$_id/extra'),
        ),
        isNull,
      );
      expect(
        ShareLinkParser.parse(
          Uri.parse('https://ustp-aess.web.app/?verify=abc'),
        ),
        isNull,
      );
      expect(ShareLinkParser.parse(null), isNull);
    });
  });

  group('canonical URLs are stable', () {
    test('same survey always produces the same URL', () {
      final a = ShareableContent.fromSurvey(_survey());
      final b = ShareableContent.fromSurvey(_survey());
      expect(a.canonicalUrl, b.canonicalUrl);
      expect(a.canonicalUrl, 'https://ustp-aess.web.app/surveys/$_id');
    });

    test('builtin GTS uses /tracer/', () {
      expect(
        ShareableContent.fromSurvey(_survey(builtin: true)).canonicalUrl,
        'https://ustp-aess.web.app/tracer/$_id',
      );
    });
  });

  group('events', () {
    AlumniEvent event({bool cancelled = false, String status = 'Active'}) {
      return AlumniEvent(
        id: _id,
        theme: 'Homecoming',
        batchYear: '2024',
        date: DateTime(2026, 12, 5),
        venue: 'USTP Gym',
        status: status,
        comments: 0,
        cancelled: cancelled,
      );
    }

    test('parses canonical event URLs', () {
      expect(
        ShareLinkParser.parse(
          Uri.parse('https://ustp-aess.web.app/events/$_id'),
        ),
        const ShareDestination(type: ShareResourceType.event, surveyId: _id),
      );
      expect(
        ShareableContent.fromEvent(event()).canonicalUrl,
        'https://ustp-aess.web.app/events/$_id',
      );
    });

    test('only active events are shareable', () {
      expect(ShareableContent.fromEvent(event()).isShareable, isTrue);
      expect(
        ShareableContent.fromEvent(event(cancelled: true)).isShareable,
        isFalse,
      );
      expect(
        ShareableContent.fromEvent(event(status: 'Archived')).isShareable,
        isFalse,
      );
    });
  });

  group('jobs', () {
    JobPosting job({required DateTime deadline, String status = 'active'}) {
      return JobPosting(
        id: _id,
        companyName: 'Acme',
        companyLogo: '',
        jobTitle: 'Engineer',
        jobType: 'Full-time',
        location: 'CDO',
        salaryRange: '',
        description: '',
        requirements: const [],
        benefits: const [],
        postedDate: DateTime(2026, 1, 1),
        applicationDeadline: deadline,
        contactEmail: '',
        applicationMethod: '',
        isActive: true,
        views: 0,
        applications: 0,
        adminId: 'admin',
        isRemote: false,
        experienceLevel: '',
        status: status,
      );
    }

    test('parses canonical job URLs', () {
      expect(
        ShareLinkParser.parse(Uri.parse('https://ustp-aess.web.app/jobs/$_id')),
        const ShareDestination(type: ShareResourceType.job, surveyId: _id),
      );
      expect(
        ShareableContent.fromJob(
          job(deadline: DateTime(2099, 1, 1)),
        ).canonicalUrl,
        'https://ustp-aess.web.app/jobs/$_id',
      );
    });

    test('only active, unexpired jobs are shareable', () {
      expect(
        ShareableContent.fromJob(
          job(deadline: DateTime(2099, 1, 1)),
        ).isShareable,
        isTrue,
      );
      expect(
        ShareableContent.fromJob(
          job(deadline: DateTime(2020, 1, 1)),
        ).isShareable,
        isFalse,
      );
      expect(
        ShareableContent.fromJob(
          job(deadline: DateTime(2099, 1, 1), status: 'archived'),
        ).isShareable,
        isFalse,
      );
    });
  });

  group('forum topics', () {
    ForumTopic topic() => ForumTopic(
      id: _id,
      title: 'Job hunting tips',
      body: '...',
      authorUid: 'u1',
      authorName: 'Alum',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

    test('parses canonical community URLs', () {
      expect(
        ShareLinkParser.parse(
          Uri.parse('https://ustp-aess.web.app/community/$_id'),
        ),
        const ShareDestination(
          type: ShareResourceType.forumTopic,
          surveyId: _id,
        ),
      );
      expect(
        ShareableContent.fromTopic(topic()).canonicalUrl,
        'https://ustp-aess.web.app/community/$_id',
      );
      // The legacy forum deep link now produces the canonical URL too.
      expect(
        ForumService.topicDeepLink(_id),
        'https://ustp-aess.web.app/community/$_id',
      );
    });
  });

  group('shareability', () {
    test('only published, non-archived surveys are shareable', () {
      expect(ShareableContent.fromSurvey(_survey()).isShareable, isTrue);
      expect(
        ShareableContent.fromSurvey(
          _survey(status: SurveyStatus.draft),
        ).isShareable,
        isFalse,
      );
      expect(
        ShareableContent.fromSurvey(
          _survey(status: SurveyStatus.closed),
        ).isShareable,
        isFalse,
      );
      expect(
        ShareableContent.fromSurvey(_survey(archived: true)).isShareable,
        isFalse,
      );
    });
  });
}
