import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:alumni_system/core/services/app_session.dart';
import 'package:alumni_system/features/forum/data/forum_refresh_bus.dart';

/// Bookmarks for forum topics — mirrors favorite_jobs pattern.
class ForumBookmarkService {
  ForumBookmarkService({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  Future<void> addBookmark(String topicId) async {
    final userId = AppSession.requireUserId();
    await _supabase.from('forum_bookmarks').upsert({
      'user_id': userId,
      'topic_id': topicId,
    });
    ForumRefreshBus.notify();
  }

  Future<void> removeBookmark(String topicId) async {
    final userId = AppSession.requireUserId();
    await _supabase
        .from('forum_bookmarks')
        .delete()
        .eq('user_id', userId)
        .eq('topic_id', topicId);
    ForumRefreshBus.notify();
  }

  Future<void> toggleBookmark(String topicId, bool currentlyBookmarked) async {
    if (currentlyBookmarked) {
      await removeBookmark(topicId);
    } else {
      await addBookmark(topicId);
    }
  }

  Future<bool> isBookmarked(String topicId) async {
    final userId = AppSession.userId;
    if (userId == null) return false;
    final row = await _supabase
        .from('forum_bookmarks')
        .select('topic_id')
        .eq('user_id', userId)
        .eq('topic_id', topicId)
        .maybeSingle();
    return row != null;
  }

  Future<Set<String>> getBookmarkedTopicIds() async {
    final userId = AppSession.userId;
    if (userId == null) return {};
    final rows = await _supabase
        .from('forum_bookmarks')
        .select('topic_id')
        .eq('user_id', userId);
    return rows
        .map((r) => r['topic_id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();
  }

  Stream<Set<String>> watchBookmarkedTopicIds() {
    final controller = StreamController<Set<String>>();
    Timer? pollTimer;
    StreamSubscription<void>? refreshSub;

    Future<void> emit() async {
      try {
        final ids = await getBookmarkedTopicIds();
        if (!controller.isClosed) controller.add(ids);
      } catch (_) {
        if (!controller.isClosed) controller.add({});
      }
    }

    controller.onListen = () async {
      await emit();
      refreshSub = ForumRefreshBus.stream.listen((_) => emit());
      pollTimer = Timer.periodic(const Duration(seconds: 10), (_) => emit());
    };
    controller.onCancel = () async {
      pollTimer?.cancel();
      await refreshSub?.cancel();
    };

    return controller.stream;
  }
}
