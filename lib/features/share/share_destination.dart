import 'package:alumni_system/features/share/share_link_config.dart';

enum ShareResourceType { tracer, customSurvey, event, job, forumTopic }

extension ShareResourceTypePath on ShareResourceType {
  String get pathSegment => switch (this) {
    ShareResourceType.tracer => 'tracer',
    ShareResourceType.customSurvey => 'surveys',
    ShareResourceType.event => 'events',
    ShareResourceType.job => 'jobs',
    ShareResourceType.forumTopic => 'community',
  };
}

/// A validated, shareable destination inside AESS.
///
/// This is a locator only — it carries no token and grants no access.
/// Eligibility is re-checked when the destination is opened.
class ShareDestination {
  const ShareDestination({required this.type, required this.surveyId});

  final ShareResourceType type;

  /// Resource id (survey id for tracer/surveys, event id for events).
  final String surveyId;

  /// Canonical path, e.g. `/tracer/<uuid>`.
  String get path => '/${type.pathSegment}/$surveyId';

  Uri get canonicalUri => Uri.parse(ShareLinkConfig.origin).replace(path: path);

  /// Existing internal route vocabulary used by NotificationRouter.
  String get notificationRoute => switch (type) {
    ShareResourceType.tracer => 'tracer/$surveyId',
    ShareResourceType.customSurvey => 'survey/$surveyId',
    ShareResourceType.event => 'event/$surveyId',
    ShareResourceType.job => 'job/$surveyId',
    ShareResourceType.forumTopic => 'forum/$surveyId',
  };

  @override
  bool operator ==(Object other) =>
      other is ShareDestination &&
      other.type == type &&
      other.surveyId == surveyId;

  @override
  int get hashCode => Object.hash(type, surveyId);

  @override
  String toString() => 'ShareDestination($path)';
}

/// Strict parser for incoming share links (deep links are untrusted input).
abstract final class ShareLinkParser {
  static final _uuid = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-'
    r'[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  static bool isUuid(String value) => _uuid.hasMatch(value);

  /// Returns null for anything that is not an AESS share link:
  /// non-HTTPS, unknown host, wrong shape, or a non-UUID id.
  /// Query parameters and fragments are never honoured.
  static ShareDestination? parse(Uri? uri) {
    if (uri == null) return null;
    if (uri.scheme != 'https') return null;
    if (!ShareLinkConfig.allowedHosts.contains(uri.host.toLowerCase())) {
      return null;
    }
    final segments = uri.pathSegments
        .where((s) => s.isNotEmpty)
        .toList(growable: false);
    if (segments.length != 2) return null;
    final id = segments[1];
    if (!isUuid(id)) return null;
    final type = switch (segments[0]) {
      'tracer' => ShareResourceType.tracer,
      'surveys' => ShareResourceType.customSurvey,
      'events' => ShareResourceType.event,
      'jobs' => ShareResourceType.job,
      'community' => ShareResourceType.forumTopic,
      _ => null,
    };
    if (type == null) return null;
    return ShareDestination(type: type, surveyId: id);
  }
}
