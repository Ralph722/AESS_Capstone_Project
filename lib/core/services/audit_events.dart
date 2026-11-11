/// Canonical audit action names, modules, and categories for AESS activity logs.
///
/// Keep action strings stable — admin filters, dashboard accents, and member
/// timelines key off these values.
abstract final class AuditActions {
  // Auth / account
  static const login = 'LOGIN';
  static const logout = 'LOGOUT';
  static const register = 'REGISTER';
  static const passwordChange = 'PASSWORD_CHANGE';
  static const passwordReset = 'PASSWORD_RESET';
  static const loginEmailChange = 'LOGIN_EMAIL_CHANGE';
  static const completeOnboarding = 'COMPLETE_ONBOARDING';
  static const roleChange = 'ROLE_CHANGE';
  static const unauthorizedAccess = 'UNAUTHORIZED_ACCESS';

  // Alumni / roster / profile
  static const createRosterMember = 'CREATE_ROSTER_MEMBER';
  static const updateRosterMember = 'UPDATE_ROSTER_MEMBER';
  static const importRoster = 'IMPORT_ROSTER';
  static const deactivateRoster = 'DEACTIVATE_ROSTER';
  static const deleteRoster = 'DELETE_ROSTER';
  static const reactivateRoster = 'REACTIVATE_ROSTER';
  static const removeAlumniAccount = 'REMOVE_ALUMNI_ACCOUNT';
  static const profileUpdate = 'PROFILE_UPDATE';
  static const nameChange = 'NAME_CHANGE';

  // Feedback
  static const submitFeedback = 'SUBMIT_FEEDBACK';
  static const updateFeedbackStatus = 'UPDATE_FEEDBACK_STATUS';
  static const respondToFeedback = 'RESPOND_TO_FEEDBACK';

  // Surveys / GTS
  static const createSurvey = 'CREATE_SURVEY';
  static const updateSurvey = 'UPDATE_SURVEY';
  static const duplicateSurvey = 'DUPLICATE_SURVEY';
  static const publishSurvey = 'PUBLISH_SURVEY';
  static const closeSurvey = 'CLOSE_SURVEY';
  static const archiveSurvey = 'ARCHIVE_SURVEY';
  static const restoreSurvey = 'RESTORE_SURVEY';
  static const deleteSurvey = 'DELETE_SURVEY';
  static const submitSurveyResponse = 'SUBMIT_SURVEY_RESPONSE';
  static const sendSurveyReminders = 'SEND_SURVEY_REMINDERS';
  static const exportSurvey = 'EXPORT_SURVEY';
  static const exportChedGtsPdf = 'EXPORT_CHED_GTS_PDF';
  static const exportChedGtsPdfBatch = 'EXPORT_CHED_GTS_PDF_BATCH';
  static const exportIndividualInfoPdf = 'EXPORT_INDIVIDUAL_INFO_PDF';
  static const exportIndividualInfoPdfBatch =
      'EXPORT_INDIVIDUAL_INFO_PDF_BATCH';

  // Events
  static const createEvent = 'CREATE_EVENT';
  static const updateEvent = 'UPDATE_EVENT';
  static const publishEvent = 'PUBLISH_EVENT';
  static const cancelEvent = 'CANCEL_EVENT';
  static const archiveEvent = 'ARCHIVE_EVENT';
  static const restoreEvent = 'RESTORE_EVENT';
  static const deleteEvent = 'DELETE_EVENT';
  static const eventRsvp = 'EVENT_RSVP';
  static const eventRsvpClear = 'EVENT_RSVP_CLEAR';

  // Jobs
  static const createJob = 'CREATE_JOB';
  static const updateJob = 'UPDATE_JOB';
  static const deleteJob = 'DELETE_JOB';
  static const restoreJob = 'RESTORE_JOB';
  static const expireJob = 'EXPIRE_JOB';

  // Announcements
  static const createAnnouncement = 'CREATE_ANNOUNCEMENT';
  static const updateAnnouncement = 'UPDATE_ANNOUNCEMENT';
  static const publishAnnouncement = 'PUBLISH_ANNOUNCEMENT';
  static const archiveAnnouncement = 'ARCHIVE_ANNOUNCEMENT';
  static const restoreAnnouncement = 'RESTORE_ANNOUNCEMENT';
  static const deleteAnnouncement = 'DELETE_ANNOUNCEMENT';

  // Forum (selective)
  static const forumReport = 'FORUM_REPORT';
  static const forumModerate = 'FORUM_MODERATE';

  // Reports
  static const exportReport = 'EXPORT_REPORT';
  static const exportAuditLogs = 'EXPORT_AUDIT_LOGS';

  // Admin profile
  static const updateAdminProfile = 'UPDATE_ADMIN_PROFILE';

  // DSS (existing)
  static const dssRuleUpdate = 'DSS_RULE_UPDATE';
  static const dssFlagStatus = 'DSS_FLAG_STATUS';
  static const dssFlagImpact = 'DSS_FLAG_IMPACT';
  static const dssFlagPlan = 'DSS_FLAG_PLAN';
  static const dssFlagEvidence = 'DSS_FLAG_EVIDENCE';
  static const dssFlagEvidenceRemoved = 'DSS_FLAG_EVIDENCE_REMOVED';
  static const dssIntervention = 'DSS_INTERVENTION';
  static const dssInterventionDecision = 'DSS_INTERVENTION_DECISION';
}

abstract final class AuditModules {
  static const auth = 'auth';
  static const alumni = 'alumni';
  static const profile = 'profile';
  static const surveys = 'surveys';
  static const events = 'events';
  static const jobs = 'jobs';
  static const forum = 'forum';
  static const feedback = 'feedback';
  static const announcements = 'announcements';
  static const reports = 'reports';
  static const administration = 'administration';
  static const dss = 'dss';
  static const notifications = 'notifications';
  static const system = 'system';
  static const archives = 'archives';
}

abstract final class AuditCategories {
  /// Everyday meaningful application activity.
  static const activity = 'activity';

  /// Security-relevant / sensitive administrative operations.
  static const security = 'security';
}

abstract final class AuditActorTypes {
  static const admin = 'admin';
  static const alumni = 'alumni';
  static const system = 'system';
}

abstract final class AuditStatus {
  static const success = 'SUCCESS';
  static const failed = 'FAILED';
  static const rejected = 'REJECTED';
}

/// Query filters for server-side audit log listing.
class AuditLogQuery {
  const AuditLogQuery({
    this.limit = 50,
    this.offset = 0,
    this.search,
    this.action,
    this.resource,
    this.module,
    this.category,
    this.status,
    this.actorType,
    this.userRole,
    this.startDate,
    this.endDate,
  });

  final int limit;
  final int offset;
  final String? search;
  final String? action;
  final String? resource;
  final String? module;
  final String? category;
  final String? status;
  final String? actorType;
  final String? userRole;
  final DateTime? startDate;
  final DateTime? endDate;

  AuditLogQuery copyWith({
    int? limit,
    int? offset,
    String? search,
    String? action,
    String? resource,
    String? module,
    String? category,
    String? status,
    String? actorType,
    String? userRole,
    DateTime? startDate,
    DateTime? endDate,
    bool clearSearch = false,
    bool clearAction = false,
    bool clearResource = false,
    bool clearModule = false,
    bool clearCategory = false,
    bool clearStatus = false,
    bool clearActorType = false,
    bool clearUserRole = false,
    bool clearStartDate = false,
    bool clearEndDate = false,
  }) {
    return AuditLogQuery(
      limit: limit ?? this.limit,
      offset: offset ?? this.offset,
      search: clearSearch ? null : (search ?? this.search),
      action: clearAction ? null : (action ?? this.action),
      resource: clearResource ? null : (resource ?? this.resource),
      module: clearModule ? null : (module ?? this.module),
      category: clearCategory ? null : (category ?? this.category),
      status: clearStatus ? null : (status ?? this.status),
      actorType: clearActorType ? null : (actorType ?? this.actorType),
      userRole: clearUserRole ? null : (userRole ?? this.userRole),
      startDate: clearStartDate ? null : (startDate ?? this.startDate),
      endDate: clearEndDate ? null : (endDate ?? this.endDate),
    );
  }
}

/// Aggregated counts for the Activity Logs overview cards.
class AuditLogStats {
  const AuditLogStats({
    required this.total,
    required this.today,
    required this.adminActions,
    required this.securityEvents,
    required this.failed,
    required this.systemEvents,
  });

  final int total;
  final int today;
  final int adminActions;
  final int securityEvents;
  final int failed;
  final int systemEvents;

  static const empty = AuditLogStats(
    total: 0,
    today: 0,
    adminActions: 0,
    securityEvents: 0,
    failed: 0,
    systemEvents: 0,
  );
}
