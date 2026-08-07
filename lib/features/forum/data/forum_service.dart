import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:alumni_system/core/utils/local_id.dart';
import 'package:alumni_system/features/forum/models/forum_model.dart';
import 'package:alumni_system/features/forum/models/forum_filters.dart';
import 'package:alumni_system/features/alumni/tracer/models/tracer_profile_model.dart';
import 'package:alumni_system/core/services/app_session.dart';
import 'package:alumni_system/features/forum/data/forum_bookmark_service.dart';
import 'package:alumni_system/features/forum/data/forum_refresh_bus.dart';
import 'package:alumni_system/features/notifications/data/notification_service.dart';
import 'package:alumni_system/features/notifications/models/notification_model.dart';

/// Forum data access — Supabase only.
class ForumService {
  ForumService({
    SupabaseClient? supabase,
    ForumBookmarkService? bookmarks,
  })  : _supabase = supabase ?? Supabase.instance.client,
        _bookmarks = bookmarks ?? ForumBookmarkService(supabase: supabase);

  final SupabaseClient _supabase;
  final ForumBookmarkService _bookmarks;

  static Stream<void> get topicsChangedStream => ForumRefreshBus.stream;

  static void notifyTopicsChanged() => ForumRefreshBus.notify();

  static const int titleMaxLength = 120;
  static const int bodyMaxLength = 8000;

  static String topicDeepLink(String topicId) => 'aess://forum/topic/$topicId';

  Future<({String name, String program, String batch})> _authorInfo(
    String userId,
  ) async {
    final row = await _supabase
        .from('users')
        .select()
        .eq('id', userId)
        .maybeSingle();
    final profile =
        row != null ? TracerProfile.fromSupabaseRow(row) : null;
    final name = profile?.displayName.isNotEmpty == true
        ? profile!.displayName
        : (AppSession.email ?? 'Alumni');
    final batch = (profile?.batchYear.trim().isNotEmpty == true)
        ? profile!.batchYear.trim()
        : (profile?.yearGraduated.trim() ?? '');
    return (name: name, program: profile?.program ?? '', batch: batch);
  }

  // ---------------------------------------------------------------------------
  // Tags
  // ---------------------------------------------------------------------------

  Future<List<ForumTag>> fetchTags() async {
    final rows = await _supabase
        .from('forum_tags')
        .select()
        .order('sort_order', ascending: true);
    return rows.map(ForumTag.fromSupabaseRow).toList();
  }

  Future<void> _setTopicTags(String topicId, List<String> tagIds) async {
    await _supabase.from('forum_topic_tags').delete().eq('topic_id', topicId);
    if (tagIds.isEmpty) return;
    await _supabase.from('forum_topic_tags').insert(
          tagIds
              .map((id) => {'topic_id': topicId, 'tag_id': id})
              .toList(),
        );
  }

  // ---------------------------------------------------------------------------
  // Drafts (local)
  // ---------------------------------------------------------------------------

  String _draftKey(String userId) => 'forum_topic_draft_$userId';

  Future<void> saveDraft({
    required String title,
    required String body,
    List<String> tagIds = const [],
    bool asAnnouncement = false,
  }) async {
    final userId = AppSession.userId;
    if (userId == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _draftKey(userId),
      jsonEncode({
        'title': title,
        'body': body,
        'tagIds': tagIds,
        'asAnnouncement': asAnnouncement,
        'savedAt': DateTime.now().toIso8601String(),
      }),
    );
  }

  Future<Map<String, dynamic>?> loadDraft() async {
    final userId = AppSession.userId;
    if (userId == null) return null;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_draftKey(userId));
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = jsonDecode(raw);
      if (map is Map<String, dynamic>) return map;
    } catch (_) {}
    return null;
  }

  Future<void> clearDraft() async {
    final userId = AppSession.userId;
    if (userId == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_draftKey(userId));
  }

  // ---------------------------------------------------------------------------
  // Streams (compat)
  // ---------------------------------------------------------------------------

  Stream<List<ForumTopic>> watchTopics() {
    final controller = StreamController<List<ForumTopic>>();
    Timer? pollTimer;
    StreamSubscription<void>? refreshSub;

    Future<void> emit() async {
      try {
        final page = await fetchTopics(const ForumTopicQuery(pageSize: 20));
        if (!controller.isClosed) controller.add(page.topics);
      } catch (_) {
        if (!controller.isClosed) controller.add(const []);
      }
    }

    controller.onListen = () async {
      await emit();
      refreshSub = ForumRefreshBus.stream.listen((_) => emit());
      // Event-bus refresh is primary; poll is a light safety net only.
      pollTimer = Timer.periodic(const Duration(seconds: 30), (_) => emit());
    };

    controller.onCancel = () async {
      pollTimer?.cancel();
      await refreshSub?.cancel();
    };

    return controller.stream;
  }

  Future<ForumTopic?> getTopic(String topicId) async {
    final row = await _supabase
        .from('forum_topics')
        .select('*, forum_topic_tags(forum_tags(*))')
        .eq('id', topicId)
        .maybeSingle();
    if (row == null) return null;
    final bookmarked = await _bookmarks.isBookmarked(topicId);
    final topic = ForumTopic.fromSupabaseRow(
      row,
      isBookmarked: bookmarked,
    );
    final avatars = await _authorAvatars([topic.authorUid]);
    final url = avatars[topic.authorUid];
    return url == null ? topic : topic.copyWith(authorAvatarUrl: url);
  }

  Stream<ForumTopic?> watchTopic(String topicId) {
    final controller = StreamController<ForumTopic?>();
    StreamSubscription<List<Map<String, dynamic>>>? realtimeSub;
    StreamSubscription<void>? refreshSub;
    Timer? pollTimer;

    Future<void> emit() async {
      try {
        final topic = await getTopic(topicId);
        if (!controller.isClosed) controller.add(topic);
      } catch (_) {
        if (!controller.isClosed) controller.add(null);
      }
    }

    Future<void> startPolling() async {
      pollTimer?.cancel();
      pollTimer = Timer.periodic(const Duration(seconds: 12), (_) => emit());
    }

    controller.onListen = () async {
      await emit();
      refreshSub = ForumRefreshBus.stream.listen((_) => emit());
      try {
        realtimeSub = _supabase
            .from('forum_topics')
            .stream(primaryKey: ['id'])
            .eq('id', topicId)
            .listen(
              (_) => emit(),
              onError: (_) => startPolling(),
            );
      } catch (_) {
        await startPolling();
      }
    };

    controller.onCancel = () async {
      pollTimer?.cancel();
      await refreshSub?.cancel();
      await realtimeSub?.cancel();
    };

    return controller.stream;
  }

  Stream<List<ForumPost>> watchPosts(String topicId) {
    final controller = StreamController<List<ForumPost>>();
    StreamSubscription<List<Map<String, dynamic>>>? realtimeSub;
    StreamSubscription<void>? refreshSub;
    Timer? pollTimer;

    Future<void> emit() async {
      try {
        final posts = await getPosts(topicId);
        if (!controller.isClosed) controller.add(posts);
      } catch (_) {
        if (!controller.isClosed) controller.add(const []);
      }
    }

    Future<void> startPolling() async {
      pollTimer?.cancel();
      pollTimer = Timer.periodic(const Duration(seconds: 12), (_) => emit());
    }

    controller.onListen = () async {
      await emit();
      refreshSub = ForumRefreshBus.stream.listen((_) => emit());
      try {
        realtimeSub = _supabase
            .from('forum_posts')
            .stream(primaryKey: ['id'])
            .eq('topic_id', topicId)
            .listen(
              (_) => emit(),
              onError: (_) => startPolling(),
            );
      } catch (_) {
        await startPolling();
      }
    };

    controller.onCancel = () async {
      pollTimer?.cancel();
      await refreshSub?.cancel();
      await realtimeSub?.cancel();
    };

    return controller.stream;
  }

  // ---------------------------------------------------------------------------
  // Paginated fetch + filter/sort/search
  // ---------------------------------------------------------------------------

  Future<ForumTopicPage> fetchTopics(ForumTopicQuery query) async {
    final bookmarks = query.bookmarkTopicIds ??
        await _bookmarks.getBookmarkedTopicIds();
    final uid = query.authorUid ?? AppSession.userId;

    // Wider slice for client-side filters/tags, capped for alumni volumes.
    final rows = await _supabase
        .from('forum_topics')
        .select('*, forum_topic_tags(forum_tags(*))')
        .order('is_pinned', ascending: false)
        .order('created_at', ascending: false)
        .limit(200);

    final topics = rows
        .map(
          (r) => ForumTopic.fromSupabaseRow(
            r,
            isBookmarked: bookmarks.contains(r['id']?.toString()),
          ),
        )
        .toList();

    // Filter/page first, then hydrate avatars only for the visible page.
    final page = applyTopicQuery(topics, query, authorUid: uid);
    final withAvatars = await _attachAuthorAvatars(page.topics);
    return ForumTopicPage(
      topics: withAvatars,
      totalCount: page.totalCount,
      hasMore: page.hasMore,
    );
  }

  Future<List<ForumTopic>> _attachAuthorAvatars(List<ForumTopic> topics) async {
    final ids = topics
        .map((t) => t.authorUid)
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    if (ids.isEmpty) return topics;
    final avatars = await _authorAvatars(ids);
    if (avatars.isEmpty) return topics;
    return topics.map((t) {
      final url = avatars[t.authorUid];
      return url == null ? t : t.copyWith(authorAvatarUrl: url);
    }).toList();
  }

  /// Filter/sort/page an already-loaded topic list (no network).
  ForumTopicPage applyTopicQuery(
    List<ForumTopic> source,
    ForumTopicQuery query, {
    String? authorUid,
  }) {
    final uid = authorUid ?? query.authorUid ?? AppSession.userId;
    var topics = List<ForumTopic>.of(source);

    final q = query.search.trim().toLowerCase();
    if (q.isNotEmpty) {
      topics = topics.where((t) {
        final hay = [
          t.title,
          t.body,
          t.authorName,
          t.authorProgram,
          t.authorBatch,
          ...t.tags.map((tag) => tag.label),
          ...t.tags.map((tag) => tag.slug),
        ].join(' ').toLowerCase();
        return hay.contains(q);
      }).toList();
    }

    if (query.programEquals != null &&
        query.programEquals!.trim().isNotEmpty) {
      final p = query.programEquals!.trim().toLowerCase();
      topics = topics
          .where((t) => t.authorProgram.toLowerCase() == p)
          .toList();
    }

    if (query.createdFrom != null) {
      topics = topics
          .where((t) => !t.createdAt.isBefore(query.createdFrom!))
          .toList();
    }
    if (query.createdTo != null) {
      topics = topics
          .where((t) => !t.createdAt.isAfter(query.createdTo!))
          .toList();
    }

    final filters = query.filters;
    final effective = filters.isEmpty || filters.contains(ForumListFilter.all)
        ? <ForumListFilter>{ForumListFilter.all}
        : filters;

    if (!effective.contains(ForumListFilter.all)) {
      topics = topics.where((t) {
        for (final f in effective) {
          final match = switch (f) {
            ForumListFilter.all => true,
            ForumListFilter.recent => true,
            ForumListFilter.pinned => t.isPinned,
            ForumListFilter.myTopics => uid != null && t.authorUid == uid,
            ForumListFilter.solved => t.isSolved,
            ForumListFilter.unanswered => t.needsResponse,
            ForumListFilter.mostReplies => t.replyCount > 0,
            ForumListFilter.announcements => t.isAnnouncement,
            ForumListFilter.bookmarked => t.isBookmarked,
          };
          if (!match) return false;
        }
        return true;
      }).toList();
    }

    var sort = query.sort;
    if (effective.contains(ForumListFilter.mostReplies) &&
        query.sort == ForumSort.latestActivity) {
      sort = ForumSort.mostReplies;
    }
    topics = _sortTopics(topics, sort);

    final total = topics.length;
    final start = query.page * query.pageSize;
    if (start >= total) {
      return ForumTopicPage(topics: const [], totalCount: total, hasMore: false);
    }
    final end = (start + query.pageSize).clamp(0, total);
    final slice = topics.sublist(start, end);
    return ForumTopicPage(
      topics: slice,
      totalCount: total,
      hasMore: end < total,
    );
  }

  List<ForumTopic> _sortTopics(List<ForumTopic> list, ForumSort sort) {
    final copy = List<ForumTopic>.of(list);
    int pinFirst(ForumTopic a, ForumTopic b) {
      if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
      if (a.isAnnouncement != b.isAnnouncement) {
        return a.isAnnouncement ? -1 : 1;
      }
      return 0;
    }

    copy.sort((a, b) {
      final p = pinFirst(a, b);
      if (p != 0) return p;
      switch (sort) {
        case ForumSort.newest:
          return b.createdAt.compareTo(a.createdAt);
        case ForumSort.oldest:
          return a.createdAt.compareTo(b.createdAt);
        case ForumSort.latestActivity:
          final ad = a.lastReplyAt ?? a.updatedAt;
          final bd = b.lastReplyAt ?? b.updatedAt;
          return bd.compareTo(ad);
        case ForumSort.mostReplies:
          final c = b.replyCount.compareTo(a.replyCount);
          if (c != 0) return c;
          return b.createdAt.compareTo(a.createdAt);
        case ForumSort.alphabetical:
          return a.title.toLowerCase().compareTo(b.title.toLowerCase());
      }
    });
    return copy;
  }

  // ---------------------------------------------------------------------------
  // Create / edit / moderate
  // ---------------------------------------------------------------------------

  Future<String> createTopic({
    required String title,
    required String body,
    List<String> tagIds = const [],
    bool asAnnouncement = false,
  }) async {
    final trimmedTitle = title.trim();
    final trimmedBody = body.trim();
    if (trimmedTitle.isEmpty) throw Exception('Title is required');
    if (trimmedBody.isEmpty) throw Exception('Message is required');
    if (trimmedTitle.length > titleMaxLength) {
      throw Exception('Title is too long');
    }
    if (trimmedBody.length > bodyMaxLength) {
      throw Exception('Message is too long');
    }

    final userId = AppSession.requireUserId();
    final author = await _authorInfo(userId);
    final now = DateTime.now();
    final id = LocalId.generate();

    final topic = ForumTopic(
      id: id,
      title: trimmedTitle,
      body: trimmedBody,
      authorUid: userId,
      authorName: author.name,
      authorProgram: author.program,
      authorBatch: author.batch,
      createdAt: now,
      updatedAt: now,
      isAnnouncement: asAnnouncement,
      isPinned: asAnnouncement,
      isSolved: false,
    );

    try {
      await _supabase.from('forum_topics').upsert(
            topic.toSupabaseRow(authorSupabaseId: userId),
            onConflict: 'id',
          );
      await _setTopicTags(id, tagIds);
      if (asAnnouncement) {
        await _logModeration(
          topicId: id,
          action: 'announcement',
          reason: null,
        );
      }
      await clearDraft();
      notifyTopicsChanged();
      return id;
    } catch (e) {
      throw Exception('Error creating topic: $e');
    }
  }

  Future<void> editTopic({
    required String topicId,
    required String title,
    required String body,
    List<String>? tagIds,
  }) async {
    final trimmedTitle = title.trim();
    final trimmedBody = body.trim();
    if (trimmedTitle.isEmpty) throw Exception('Title is required');
    if (trimmedBody.isEmpty) throw Exception('Message is required');

    try {
      await _supabase.rpc('edit_forum_topic', params: {
        'p_topic_id': topicId,
        'p_title': trimmedTitle,
        'p_body': trimmedBody,
      });
      if (tagIds != null) {
        await _setTopicTags(topicId, tagIds);
      }
      notifyTopicsChanged();
    } catch (e) {
      throw Exception('Error editing topic: $e');
    }
  }

  Future<void> editPost({
    required String postId,
    required String body,
  }) async {
    final trimmed = body.trim();
    if (trimmed.isEmpty) throw Exception('Reply cannot be empty');
    try {
      await _supabase.rpc('edit_forum_post', params: {
        'p_post_id': postId,
        'p_body': trimmed,
      });
      notifyTopicsChanged();
    } catch (e) {
      throw Exception('Error editing reply: $e');
    }
  }

  Future<void> createPost({
    required String topicId,
    required String body,
    String? quotedPostId,
    String? quotedExcerpt,
    List<String> mentionedUserIds = const [],
  }) async {
    final userId = AppSession.requireUserId();
    final author = await _authorInfo(userId);
    final now = DateTime.now();
    final topic = await getTopic(topicId);
    if (topic == null) throw Exception('Topic not found');
    if (topic.isLocked) throw Exception('Topic is locked');

    final excerpt = (quotedExcerpt ?? '').trim();
    final post = ForumPost(
      id: LocalId.generate(),
      topicId: topicId,
      body: body.trim(),
      authorUid: userId,
      authorName: author.name,
      createdAt: now,
      quotedPostId: quotedPostId,
      quotedExcerpt: excerpt.isEmpty
          ? null
          : (excerpt.length > 280 ? '${excerpt.substring(0, 280)}…' : excerpt),
    );

    try {
      await _supabase.from('forum_posts').upsert(
            post.toSupabaseRow(
              topicSupabaseId: topicId,
              authorSupabaseId: userId,
            ),
            onConflict: 'id',
          );
      if (mentionedUserIds.isNotEmpty) {
        await _supabase.rpc('notify_forum_mentions', params: {
          'p_post_id': post.id,
          'p_mentioned_uids': mentionedUserIds,
        });
      }
      notifyTopicsChanged();
    } catch (e) {
      throw Exception('Error creating post: $e');
    }
  }

  Future<List<ForumMentionCandidate>> searchMentionUsers(String query) async {
    try {
      final rows = await _supabase.rpc(
        'search_forum_mention_users',
        params: {'p_query': query.trim()},
      );
      if (rows is! List) return const [];
      return rows
          .whereType<Map>()
          .map(
            (r) => ForumMentionCandidate(
              id: r['id']?.toString() ?? '',
              displayName: r['display_name']?.toString() ?? '',
              program: r['program']?.toString() ?? '',
            ),
          )
          .where((c) => c.id.isNotEmpty && c.displayName.isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> toggleHelpful(String postId, bool currentlyHelpful) async {
    final userId = AppSession.requireUserId();
    if (currentlyHelpful) {
      await _supabase
          .from('forum_helpful_reactions')
          .delete()
          .eq('user_id', userId)
          .eq('post_id', postId);
    } else {
      await _supabase.from('forum_helpful_reactions').upsert({
        'user_id': userId,
        'post_id': postId,
      });
    }
    notifyTopicsChanged();
  }

  Future<void> reportContent({
    required String topicId,
    String? postId,
    required String reason,
  }) async {
    final userId = AppSession.requireUserId();
    final trimmed = reason.trim();
    if (trimmed.isEmpty) throw Exception('Please provide a reason');
    await _supabase.from('forum_reports').insert({
      'reporter_uid': userId,
      'topic_id': topicId,
      if (postId != null) 'post_id': postId,
      'reason': trimmed,
      'status': 'open',
    });
  }

  Future<List<ForumReport>> getReports({String? status}) async {
    var query = _supabase
        .from('forum_reports')
        .select('*, forum_topics(title)');
    if (status != null && status.isNotEmpty) {
      query = query.eq('status', status);
    }
    final rows = await query.order('created_at', ascending: false).limit(200);
    return rows.map(ForumReport.fromSupabaseRow).toList();
  }

  Future<int> getOpenReportCount() async {
    try {
      final rows = await _supabase
          .from('forum_reports')
          .select('id')
          .eq('status', 'open');
      return rows.length;
    } catch (_) {
      return 0;
    }
  }

  Future<void> updateReportStatus(String reportId, String status) async {
    await _supabase.from('forum_reports').update({
      'status': status,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', reportId);
  }

  Future<Map<String, int>> _helpfulCounts(List<String> postIds) async {
    if (postIds.isEmpty) return {};
    final rows = await _supabase
        .from('forum_helpful_reactions')
        .select('post_id')
        .inFilter('post_id', postIds);
    final counts = <String, int>{};
    for (final row in rows) {
      final id = row['post_id']?.toString() ?? '';
      if (id.isEmpty) continue;
      counts[id] = (counts[id] ?? 0) + 1;
    }
    return counts;
  }

  Future<Set<String>> _myHelpfulPostIds(List<String> postIds) async {
    final userId = AppSession.userId;
    if (userId == null || postIds.isEmpty) return {};
    final rows = await _supabase
        .from('forum_helpful_reactions')
        .select('post_id')
        .eq('user_id', userId)
        .inFilter('post_id', postIds);
    return rows
        .map((r) => r['post_id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();
  }

  Future<void> setTopicLocked(
    String topicId,
    bool locked, {
    String? reason,
  }) async {
    final topic = await getTopic(topicId);
    await _updateTopicFlags(
      topicId,
      isLocked: locked,
      moderationReason: reason,
    );
    await _logModeration(
      topicId: topicId,
      action: locked ? 'lock' : 'unlock',
      reason: reason,
    );
    if (topic != null) {
      await _notifyTopicAuthor(
        topic: topic,
        title: locked ? 'Your discussion was locked' : 'Your discussion was unlocked',
        message: locked
            ? 'Moderators locked "${topic.title}".${reason != null && reason.trim().isNotEmpty ? ' Reason: $reason' : ''}'
            : 'Moderators unlocked "${topic.title}". You can receive replies again.',
      );
    }
  }

  Future<void> setTopicPinned(String topicId, bool pinned) async {
    final topic = await getTopic(topicId);
    await _updateTopicFlags(topicId, isPinned: pinned);
    await _logModeration(
      topicId: topicId,
      action: pinned ? 'pin' : 'unpin',
      reason: null,
    );
    if (topic != null && pinned) {
      await _notifyTopicAuthor(
        topic: topic,
        title: 'Your discussion was pinned',
        message: 'Moderators pinned "${topic.title}" in the alumni forum.',
      );
    }
  }

  Future<void> _notifyTopicAuthor({
    required ForumTopic topic,
    required String title,
    required String message,
  }) async {
    try {
      final me = AppSession.userId;
      if (me == null || me == topic.authorUid) return;
      await NotificationService().createNotification(
        userId: topic.authorUid,
        type: NotificationType.forum,
        title: title,
        message: message,
        relatedId: topic.id,
        data: {
          'topicId': topic.id,
          'target': 'forum_topic',
        },
      );
    } catch (_) {}
  }

  Future<void> setTopicSolved(String topicId, bool solved) async {
    final topic = await getTopic(topicId);
    if (topic == null) throw Exception('Topic not found');
    if (topic.isAnnouncement) {
      throw Exception('Announcements cannot be marked solved');
    }
    await _updateTopicFlags(topicId, isSolved: solved);
    await _logModeration(
      topicId: topicId,
      action: solved ? 'solved' : 'unsolved',
      reason: null,
    );
  }

  Future<void> deleteTopic(String topicId, {String? reason}) async {
    try {
      await _logModeration(
        topicId: topicId,
        action: 'delete',
        reason: reason,
      );
      await _supabase.from('forum_topics').delete().eq('id', topicId);
      notifyTopicsChanged();
    } catch (e) {
      throw Exception('Error deleting topic: $e');
    }
  }

  Future<void> deletePost(String topicId, String postId) async {
    try {
      await _supabase.from('forum_posts').delete().eq('id', postId);
      // reply_count maintained by DB trigger
      notifyTopicsChanged();
    } catch (e) {
      throw Exception('Error deleting post: $e');
    }
  }

  Future<void> _updateTopicFlags(
    String topicId, {
    bool? isLocked,
    bool? isPinned,
    bool? isSolved,
    String? moderationReason,
  }) async {
    try {
      final payload = <String, dynamic>{
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };
      if (isLocked != null) payload['is_locked'] = isLocked;
      if (isPinned != null) payload['is_pinned'] = isPinned;
      if (isSolved != null) payload['is_solved'] = isSolved;
      if (moderationReason != null) {
        payload['moderation_reason'] =
            moderationReason.trim().isEmpty ? null : moderationReason.trim();
      }
      await _supabase.from('forum_topics').update(payload).eq('id', topicId);
      notifyTopicsChanged();
    } catch (e) {
      throw Exception('Error updating topic flags: $e');
    }
  }

  Future<void> _logModeration({
    required String topicId,
    required String action,
    String? reason,
  }) async {
    try {
      final userId = AppSession.userId;
      if (userId == null) return;
      await _supabase.from('forum_moderation_events').insert({
        'topic_id': topicId,
        'actor_uid': userId,
        'action': action,
        'reason': reason,
      });
    } catch (_) {
      // Non-fatal — table may be admin-only insert; authors skip silently.
    }
  }

  Future<void> incrementViews(String topicId) async {
    try {
      await _supabase.rpc(
        'increment_forum_topic_views',
        params: {'p_topic_id': topicId},
      );
    } catch (_) {}
  }

  Future<List<ForumTopic>> getAllTopics() async {
    final page = await fetchTopics(const ForumTopicQuery(pageSize: 500));
    return page.topics;
  }

  Future<int> getTopicCount() async {
    try {
      final rows = await _supabase.from('forum_topics').select('id');
      return rows.length;
    } catch (_) {
      return 0;
    }
  }

  Future<({
    int total,
    int unanswered,
    int locked,
    int announcements,
  })> getModerationStats() async {
    final topics = await getAllTopics();
    return (
      total: topics.length,
      unanswered: topics.where((t) => t.needsResponse).length,
      locked: topics.where((t) => t.isLocked).length,
      announcements: topics.where((t) => t.isAnnouncement).length,
    );
  }

  Future<List<ForumPost>> getPosts(String topicId) => _fetchPosts(topicId);

  Future<List<ForumPost>> _fetchPosts(String topicId) async {
    final rows = await _supabase
        .from('forum_posts')
        .select()
        .eq('topic_id', topicId)
        .order('created_at', ascending: true);
    final ids = rows
        .map((r) => r['id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toList();
    final authorIds = rows
        .map((r) => r['author_uid']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    final counts = await _helpfulCounts(ids);
    final mine = await _myHelpfulPostIds(ids);
    final avatars = await _authorAvatars(authorIds);
    return rows
        .map(
          (r) {
            final authorUid = r['author_uid']?.toString() ?? '';
            return ForumPost.fromSupabaseRow(
              r,
              helpfulCount: counts[r['id']?.toString()] ?? 0,
              helpfulByMe: mine.contains(r['id']?.toString()),
              authorAvatarUrl: avatars[authorUid],
            );
          },
        )
        .toList();
  }

  Future<Map<String, String>> _authorAvatars(List<String> userIds) async {
    if (userIds.isEmpty) return {};
    try {
      final rows = await _supabase
          .from('users')
          .select('id, profile_image_base64')
          .inFilter('id', userIds);
      final out = <String, String>{};
      for (final row in rows) {
        final id = row['id']?.toString() ?? '';
        final url = (row['profile_image_base64'] as String?)?.trim() ?? '';
        if (id.isNotEmpty && url.isNotEmpty) out[id] = url;
      }
      return out;
    } catch (_) {
      return {};
    }
  }
}
