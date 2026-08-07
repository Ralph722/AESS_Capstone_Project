/// Snapshot metrics for the admin dashboard home screen.
class AdminDashboardMetrics {
  const AdminDashboardMetrics({
    this.rosterTotal = 0,
    this.registeredOnRoster = 0,
    this.tracerCompleteCount = 0,
    this.employmentSubmissions = 0,
    this.pendingSurveyAssignments = 0,
    this.totalSurveyAssignments = 0,
    this.totalSurveyResponses = 0,
    this.publishedSurveys = 0,
    this.totalEvents = 0,
    this.activeEventsCount = 0,
    this.archivedEventsCount = 0,
    this.upcomingEventsCount = 0,
    this.portalAccounts = 0,
    this.totalJobs = 0,
    this.activeJobs = 0,
    this.unreadMessages = 0,
    this.publishedAnnouncements = 0,
    this.forumTopics = 0,
    this.openFeedback = 0,
  });

  final int rosterTotal;
  final int registeredOnRoster;
  final int tracerCompleteCount;
  final int employmentSubmissions;

  final int pendingSurveyAssignments;
  final int totalSurveyAssignments;
  final int totalSurveyResponses;
  final int publishedSurveys;

  final int totalEvents;
  final int activeEventsCount;
  final int archivedEventsCount;
  final int upcomingEventsCount;

  final int portalAccounts;
  final int totalJobs;
  final int activeJobs;

  final int unreadMessages;
  final int publishedAnnouncements;
  final int forumTopics;
  final int openFeedback;

  int get unclaimedRoster => rosterTotal - registeredOnRoster;

  int get registeredWithoutTracer =>
      (registeredOnRoster - tracerCompleteCount).clamp(0, registeredOnRoster);

  double get registrationRate =>
      rosterTotal == 0 ? 0 : registeredOnRoster / rosterTotal;

  double get tracerCompletionRate => registeredOnRoster == 0
      ? 0
      : tracerCompleteCount / registeredOnRoster;

  double get surveyResponseRate => totalSurveyAssignments == 0
      ? 0
      : totalSurveyResponses / totalSurveyAssignments;

  int get attentionCount =>
      unreadMessages +
      pendingSurveyAssignments +
      openFeedback +
      registeredWithoutTracer;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AdminDashboardMetrics &&
        other.rosterTotal == rosterTotal &&
        other.registeredOnRoster == registeredOnRoster &&
        other.tracerCompleteCount == tracerCompleteCount &&
        other.employmentSubmissions == employmentSubmissions &&
        other.pendingSurveyAssignments == pendingSurveyAssignments &&
        other.totalSurveyAssignments == totalSurveyAssignments &&
        other.totalSurveyResponses == totalSurveyResponses &&
        other.publishedSurveys == publishedSurveys &&
        other.totalEvents == totalEvents &&
        other.activeEventsCount == activeEventsCount &&
        other.archivedEventsCount == archivedEventsCount &&
        other.upcomingEventsCount == upcomingEventsCount &&
        other.portalAccounts == portalAccounts &&
        other.totalJobs == totalJobs &&
        other.activeJobs == activeJobs &&
        other.unreadMessages == unreadMessages &&
        other.publishedAnnouncements == publishedAnnouncements &&
        other.forumTopics == forumTopics &&
        other.openFeedback == openFeedback;
  }

  @override
  int get hashCode => Object.hashAll([
        rosterTotal,
        registeredOnRoster,
        tracerCompleteCount,
        employmentSubmissions,
        pendingSurveyAssignments,
        totalSurveyAssignments,
        totalSurveyResponses,
        publishedSurveys,
        totalEvents,
        activeEventsCount,
        archivedEventsCount,
        upcomingEventsCount,
        portalAccounts,
        totalJobs,
        activeJobs,
        unreadMessages,
        publishedAnnouncements,
        forumTopics,
        openFeedback,
      ]);
}
