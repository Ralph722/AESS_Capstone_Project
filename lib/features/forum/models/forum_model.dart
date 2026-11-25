/// Discussion vs community job offer (alumni-submitted, admin-reviewed).
enum ForumPostKind {
  discussion,
  jobOffer;

  static const discussionValue = 'discussion';
  static const jobOfferValue = 'job_offer';

  String get wireValue => switch (this) {
    ForumPostKind.discussion => discussionValue,
    ForumPostKind.jobOffer => jobOfferValue,
  };

  String get label => switch (this) {
    ForumPostKind.discussion => 'Discussion',
    ForumPostKind.jobOffer => 'Job offer',
  };

  static ForumPostKind fromWire(String? raw) {
    switch ((raw ?? '').trim().toLowerCase()) {
      case jobOfferValue:
        return ForumPostKind.jobOffer;
      default:
        return ForumPostKind.discussion;
    }
  }
}

/// Review pipeline for [ForumPostKind.jobOffer] topics.
enum ForumReviewStatus {
  none,
  pending,
  approved,
  declined,
  withdrawn;

  static const noneValue = 'none';
  static const pendingValue = 'pending';
  static const approvedValue = 'approved';
  static const declinedValue = 'declined';
  static const withdrawnValue = 'withdrawn';

  String get wireValue => switch (this) {
    ForumReviewStatus.none => noneValue,
    ForumReviewStatus.pending => pendingValue,
    ForumReviewStatus.approved => approvedValue,
    ForumReviewStatus.declined => declinedValue,
    ForumReviewStatus.withdrawn => withdrawnValue,
  };

  String get label => switch (this) {
    ForumReviewStatus.none => '',
    ForumReviewStatus.pending => 'Awaiting review',
    ForumReviewStatus.approved => 'Approved',
    ForumReviewStatus.declined => 'Declined',
    ForumReviewStatus.withdrawn => 'Withdrawn',
  };

  bool get isAwaitingAuthorAction => this == ForumReviewStatus.pending;

  static ForumReviewStatus fromWire(String? raw) {
    switch ((raw ?? '').trim().toLowerCase()) {
      case pendingValue:
        return ForumReviewStatus.pending;
      case approvedValue:
        return ForumReviewStatus.approved;
      case declinedValue:
        return ForumReviewStatus.declined;
      case withdrawnValue:
        return ForumReviewStatus.withdrawn;
      default:
        return ForumReviewStatus.none;
    }
  }
}

/// Who can see a discussion in the alumni feed.
enum ForumTopicVisibility {
  everyone,
  program,
  programBatch;

  static const everyoneValue = 'everyone';
  static const programValue = 'program';
  static const programBatchValue = 'program_batch';

  String get wireValue => switch (this) {
    ForumTopicVisibility.everyone => everyoneValue,
    ForumTopicVisibility.program => programValue,
    ForumTopicVisibility.programBatch => programBatchValue,
  };

  String get label => switch (this) {
    ForumTopicVisibility.everyone => 'Everyone',
    ForumTopicVisibility.program => 'Same program',
    ForumTopicVisibility.programBatch => 'My program & batch',
  };

  String get shortLabel => switch (this) {
    ForumTopicVisibility.everyone => 'Everyone',
    ForumTopicVisibility.program => 'Program',
    ForumTopicVisibility.programBatch => 'Program · Batch',
  };

  String helperText({String program = '', String batch = ''}) {
    final p = program.trim().isEmpty ? 'your program' : program.trim();
    final b = batch.trim().isEmpty ? 'your batch' : batch.trim();
    return switch (this) {
      ForumTopicVisibility.everyone =>
        'Visible to all alumni in the community.',
      ForumTopicVisibility.program => 'Visible to $p alumni (all batches).',
      ForumTopicVisibility.programBatch => 'Visible to $p · Batch $b only.',
    };
  }

  static ForumTopicVisibility fromWire(String? raw) {
    switch ((raw ?? '').trim().toLowerCase()) {
      case programValue:
        return ForumTopicVisibility.program;
      case programBatchValue:
        return ForumTopicVisibility.programBatch;
      default:
        return ForumTopicVisibility.everyone;
    }
  }
}

class ForumTag {
  final String id;
  final String slug;
  final String label;
  final int sortOrder;

  const ForumTag({
    required this.id,
    required this.slug,
    required this.label,
    this.sortOrder = 0,
  });

  factory ForumTag.fromSupabaseRow(Map<String, dynamic> row) {
    return ForumTag(
      id: row['id']?.toString() ?? '',
      slug: row['slug'] as String? ?? '',
      label: row['label'] as String? ?? '',
      sortOrder: row['sort_order'] as int? ?? 0,
    );
  }
}

class ForumTopic {
  final String id;
  final String title;
  final String body;
  final String authorUid;
  final String authorName;
  final String? authorAvatarUrl;
  final String authorProgram;
  final String authorBatch;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? editedAt;
  final int replyCount;
  final DateTime? lastReplyAt;
  final bool isLocked;
  final bool isPinned;
  final bool isSolved;
  final bool isAnnouncement;
  final bool isFeatured;
  final ForumTopicVisibility visibility;
  final ForumPostKind postKind;
  final ForumReviewStatus reviewStatus;
  final String purposeLetter;
  final String coverImageUrl;
  final String companyName;
  final String applyUrl;
  final String declineReason;
  final DateTime? reviewedAt;
  final String? moderationReason;
  final int viewCount;
  final List<ForumTag> tags;
  final bool isBookmarked;

  const ForumTopic({
    required this.id,
    required this.title,
    required this.body,
    required this.authorUid,
    required this.authorName,
    this.authorAvatarUrl,
    this.authorProgram = '',
    this.authorBatch = '',
    required this.createdAt,
    required this.updatedAt,
    this.editedAt,
    this.replyCount = 0,
    this.lastReplyAt,
    this.isLocked = false,
    this.isPinned = false,
    this.isSolved = false,
    this.isAnnouncement = false,
    this.isFeatured = false,
    this.visibility = ForumTopicVisibility.everyone,
    this.postKind = ForumPostKind.discussion,
    this.reviewStatus = ForumReviewStatus.none,
    this.purposeLetter = '',
    this.coverImageUrl = '',
    this.companyName = '',
    this.applyUrl = '',
    this.declineReason = '',
    this.reviewedAt,
    this.moderationReason,
    this.viewCount = 0,
    this.tags = const [],
    this.isBookmarked = false,
  });

  bool get isJobOffer => postKind == ForumPostKind.jobOffer;

  bool get isPendingJobOffer =>
      isJobOffer && reviewStatus == ForumReviewStatus.pending;

  bool get isDeclinedJobOffer =>
      isJobOffer && reviewStatus == ForumReviewStatus.declined;

  bool get isApprovedJobOffer =>
      isJobOffer && reviewStatus == ForumReviewStatus.approved;

  /// Author/admin-only queue item (not yet public in the main feed).
  bool get isJobOfferInReviewQueue => isPendingJobOffer;

  bool get needsResponse =>
      !isAnnouncement &&
      !isJobOffer &&
      !isSolved &&
      replyCount == 0;

  /// True when the topic carries the seeded Question tag (slug or label).
  bool get hasQuestionTag => tags.any((t) {
    final slug = t.slug.trim().toLowerCase();
    final label = t.label.trim().toLowerCase();
    return slug == 'question' || label == 'question';
  });

  bool get canEditWithinWindow {
    final elapsed = DateTime.now().difference(createdAt);
    return elapsed.inMinutes < 30;
  }

  ForumTopic copyWith({
    String? title,
    String? body,
    DateTime? editedAt,
    int? replyCount,
    DateTime? lastReplyAt,
    bool? isLocked,
    bool? isPinned,
    bool? isSolved,
    bool? isAnnouncement,
    bool? isFeatured,
    ForumTopicVisibility? visibility,
    ForumPostKind? postKind,
    ForumReviewStatus? reviewStatus,
    String? purposeLetter,
    String? coverImageUrl,
    String? companyName,
    String? applyUrl,
    String? declineReason,
    DateTime? reviewedAt,
    String? moderationReason,
    List<ForumTag>? tags,
    bool? isBookmarked,
    String? authorBatch,
    String? authorAvatarUrl,
  }) {
    return ForumTopic(
      id: id,
      title: title ?? this.title,
      body: body ?? this.body,
      authorUid: authorUid,
      authorName: authorName,
      authorAvatarUrl: authorAvatarUrl ?? this.authorAvatarUrl,
      authorProgram: authorProgram,
      authorBatch: authorBatch ?? this.authorBatch,
      createdAt: createdAt,
      updatedAt: updatedAt,
      editedAt: editedAt ?? this.editedAt,
      replyCount: replyCount ?? this.replyCount,
      lastReplyAt: lastReplyAt ?? this.lastReplyAt,
      isLocked: isLocked ?? this.isLocked,
      isPinned: isPinned ?? this.isPinned,
      isSolved: isSolved ?? this.isSolved,
      isAnnouncement: isAnnouncement ?? this.isAnnouncement,
      isFeatured: isFeatured ?? this.isFeatured,
      visibility: visibility ?? this.visibility,
      postKind: postKind ?? this.postKind,
      reviewStatus: reviewStatus ?? this.reviewStatus,
      purposeLetter: purposeLetter ?? this.purposeLetter,
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
      companyName: companyName ?? this.companyName,
      applyUrl: applyUrl ?? this.applyUrl,
      declineReason: declineReason ?? this.declineReason,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      moderationReason: moderationReason ?? this.moderationReason,
      viewCount: viewCount,
      tags: tags ?? this.tags,
      isBookmarked: isBookmarked ?? this.isBookmarked,
    );
  }

  factory ForumTopic.fromSupabaseRow(
    Map<String, dynamic> row, {
    List<ForumTag> tags = const [],
    bool isBookmarked = false,
  }) {
    final rawTags = row['forum_topic_tags'];
    final parsedTags = <ForumTag>[];
    if (rawTags is List) {
      for (final entry in rawTags) {
        if (entry is Map<String, dynamic>) {
          final tag = entry['forum_tags'];
          if (tag is Map<String, dynamic>) {
            parsedTags.add(ForumTag.fromSupabaseRow(tag));
          }
        }
      }
    }

    return ForumTopic(
      id: row['id']?.toString() ?? '',
      title: row['title'] as String? ?? '',
      body: row['body'] as String? ?? '',
      authorUid: row['author_uid']?.toString() ?? '',
      authorName: row['author_name'] as String? ?? '',
      authorProgram: row['author_program'] as String? ?? '',
      authorBatch: row['author_batch'] as String? ?? '',
      createdAt: _parseDateTime(row['created_at']),
      updatedAt: _parseDateTime(row['updated_at']),
      editedAt: row['edited_at'] != null
          ? _parseDateTime(row['edited_at'])
          : null,
      replyCount: row['reply_count'] as int? ?? 0,
      lastReplyAt: row['last_reply_at'] != null
          ? _parseDateTime(row['last_reply_at'])
          : null,
      isLocked: row['is_locked'] == true,
      isPinned: row['is_pinned'] == true,
      isSolved: row['is_solved'] == true,
      isAnnouncement: row['is_announcement'] == true,
      isFeatured: row['is_featured'] == true,
      visibility: ForumTopicVisibility.fromWire(row['visibility'] as String?),
      postKind: ForumPostKind.fromWire(row['post_kind'] as String?),
      reviewStatus: ForumReviewStatus.fromWire(row['review_status'] as String?),
      purposeLetter: row['purpose_letter'] as String? ?? '',
      coverImageUrl: row['cover_image_url'] as String? ?? '',
      companyName: row['company_name'] as String? ?? '',
      applyUrl: row['apply_url'] as String? ?? '',
      declineReason: row['decline_reason'] as String? ?? '',
      reviewedAt: row['reviewed_at'] != null
          ? _parseDateTime(row['reviewed_at'])
          : null,
      moderationReason: (row['moderation_reason'] as String?)?.trim().isEmpty ==
              true
          ? null
          : row['moderation_reason'] as String?,
      viewCount: row['view_count'] as int? ?? 0,
      tags: tags.isNotEmpty ? tags : parsedTags,
      isBookmarked: isBookmarked,
      authorAvatarUrl: null,
    );
  }

  Map<String, dynamic> toSupabaseRow({required String authorSupabaseId}) {
    return {
      'id': id,
      'title': title,
      'body': body,
      'author_uid': authorSupabaseId,
      'author_name': authorName,
      'author_program': authorProgram,
      'author_batch': authorBatch,
      'reply_count': replyCount,
      'last_reply_at': lastReplyAt?.toUtc().toIso8601String(),
      'is_locked': isLocked,
      'is_pinned': isPinned,
      'is_solved': isSolved,
      'is_announcement': isAnnouncement,
      'is_featured': isFeatured,
      'visibility': visibility.wireValue,
      'post_kind': postKind.wireValue,
      'review_status': reviewStatus.wireValue,
      'purpose_letter': purposeLetter,
      'cover_image_url': coverImageUrl,
      'company_name': companyName,
      'apply_url': applyUrl,
      'decline_reason': declineReason,
      'reviewed_at': reviewedAt?.toUtc().toIso8601String(),
      'edited_at': editedAt?.toUtc().toIso8601String(),
      'moderation_reason': moderationReason,
      'view_count': viewCount,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value is DateTime) return value.toLocal();
    if (value is String && value.isNotEmpty) {
      return DateTime.parse(value).toLocal();
    }
    return DateTime.now();
  }
}

class ForumPost {
  final String id;
  final String topicId;
  final String body;
  final String authorUid;
  final String authorName;
  final String? authorAvatarUrl;
  final DateTime createdAt;
  final DateTime? editedAt;
  final String? quotedPostId;
  final String? quotedExcerpt;
  final int helpfulCount;
  final bool helpfulByMe;

  const ForumPost({
    required this.id,
    required this.topicId,
    required this.body,
    required this.authorUid,
    required this.authorName,
    this.authorAvatarUrl,
    required this.createdAt,
    this.editedAt,
    this.quotedPostId,
    this.quotedExcerpt,
    this.helpfulCount = 0,
    this.helpfulByMe = false,
  });

  bool get canEditWithinWindow {
    final elapsed = DateTime.now().difference(createdAt);
    return elapsed.inMinutes < 30;
  }

  ForumPost copyWith({
    String? body,
    DateTime? editedAt,
    int? helpfulCount,
    bool? helpfulByMe,
    String? authorAvatarUrl,
  }) {
    return ForumPost(
      id: id,
      topicId: topicId,
      body: body ?? this.body,
      authorUid: authorUid,
      authorName: authorName,
      authorAvatarUrl: authorAvatarUrl ?? this.authorAvatarUrl,
      createdAt: createdAt,
      editedAt: editedAt ?? this.editedAt,
      quotedPostId: quotedPostId,
      quotedExcerpt: quotedExcerpt,
      helpfulCount: helpfulCount ?? this.helpfulCount,
      helpfulByMe: helpfulByMe ?? this.helpfulByMe,
    );
  }

  factory ForumPost.fromSupabaseRow(
    Map<String, dynamic> row, {
    int helpfulCount = 0,
    bool helpfulByMe = false,
    String? authorAvatarUrl,
  }) {
    return ForumPost(
      id: row['id']?.toString() ?? '',
      topicId: row['topic_id']?.toString() ?? '',
      body: row['body'] as String? ?? '',
      authorUid: row['author_uid']?.toString() ?? '',
      authorName: row['author_name'] as String? ?? '',
      authorAvatarUrl: authorAvatarUrl,
      createdAt: ForumTopic._parseDateTime(row['created_at']),
      editedAt: row['edited_at'] != null
          ? ForumTopic._parseDateTime(row['edited_at'])
          : null,
      quotedPostId: row['quoted_post_id']?.toString(),
      quotedExcerpt: row['quoted_excerpt'] as String?,
      helpfulCount: helpfulCount,
      helpfulByMe: helpfulByMe,
    );
  }

  Map<String, dynamic> toSupabaseRow({
    required String topicSupabaseId,
    required String authorSupabaseId,
  }) {
    return {
      'id': id,
      'topic_id': topicSupabaseId,
      'body': body,
      'author_uid': authorSupabaseId,
      'author_name': authorName,
      if (quotedPostId != null) 'quoted_post_id': quotedPostId,
      if (quotedExcerpt != null) 'quoted_excerpt': quotedExcerpt,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': createdAt.toUtc().toIso8601String(),
    };
  }
}

class ForumMentionCandidate {
  final String id;
  final String displayName;
  final String program;

  const ForumMentionCandidate({
    required this.id,
    required this.displayName,
    this.program = '',
  });
}

class ForumReport {
  final String id;
  final String reporterUid;
  final String? topicId;
  final String? postId;
  final String reason;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? topicTitle;
  final String? reporterName;

  const ForumReport({
    required this.id,
    required this.reporterUid,
    this.topicId,
    this.postId,
    required this.reason,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.topicTitle,
    this.reporterName,
  });

  bool get isOpen => status == 'open';

  factory ForumReport.fromSupabaseRow(Map<String, dynamic> row) {
    final topic = row['forum_topics'];
    String? topicTitle;
    if (topic is Map) {
      topicTitle = topic['title']?.toString();
    }
    return ForumReport(
      id: row['id']?.toString() ?? '',
      reporterUid: row['reporter_uid']?.toString() ?? '',
      topicId: row['topic_id']?.toString(),
      postId: row['post_id']?.toString(),
      reason: row['reason'] as String? ?? '',
      status: row['status'] as String? ?? 'open',
      createdAt: ForumTopic._parseDateTime(row['created_at']),
      updatedAt: ForumTopic._parseDateTime(row['updated_at']),
      topicTitle: topicTitle,
      reporterName: row['reporter_name']?.toString(),
    );
  }
}
