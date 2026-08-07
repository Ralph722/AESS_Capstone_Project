import 'package:alumni_system/features/forum/models/forum_model.dart';

/// Alumni forum list filter chips.
enum ForumListFilter {
  all,
  recent,
  pinned,
  myTopics,
  solved,
  unanswered,
  mostReplies,
  announcements,
  bookmarked,
}

extension ForumListFilterX on ForumListFilter {
  String get label => switch (this) {
        ForumListFilter.all => 'All',
        ForumListFilter.recent => 'Recent',
        ForumListFilter.pinned => 'Pinned',
        ForumListFilter.myTopics => 'My Topics',
        ForumListFilter.solved => 'Solved',
        ForumListFilter.unanswered => 'Unanswered',
        ForumListFilter.mostReplies => 'Most Replies',
        ForumListFilter.announcements => 'Announcements',
        ForumListFilter.bookmarked => 'Bookmarked',
      };
}

/// Admin / alumni sort options.
enum ForumSort {
  newest,
  oldest,
  latestActivity,
  mostReplies,
  alphabetical,
}

extension ForumSortX on ForumSort {
  String get label => switch (this) {
        ForumSort.newest => 'Newest',
        ForumSort.oldest => 'Oldest',
        ForumSort.latestActivity => 'Latest Activity',
        ForumSort.mostReplies => 'Most Replies',
        ForumSort.alphabetical => 'Alphabetical',
      };
}

class ForumTopicQuery {
  final String search;
  final Set<ForumListFilter> filters;
  final ForumSort sort;
  final int page;
  final int pageSize;
  final String? programEquals;
  final DateTime? createdFrom;
  final DateTime? createdTo;
  final Set<String>? bookmarkTopicIds;
  final String? authorUid;

  const ForumTopicQuery({
    this.search = '',
    this.filters = const {ForumListFilter.all},
    this.sort = ForumSort.latestActivity,
    this.page = 0,
    this.pageSize = 20,
    this.programEquals,
    this.createdFrom,
    this.createdTo,
    this.bookmarkTopicIds,
    this.authorUid,
  });

  ForumTopicQuery copyWith({
    String? search,
    Set<ForumListFilter>? filters,
    ForumSort? sort,
    int? page,
    int? pageSize,
    String? programEquals,
    DateTime? createdFrom,
    DateTime? createdTo,
    Set<String>? bookmarkTopicIds,
    String? authorUid,
    bool clearProgram = false,
    bool clearCreatedFrom = false,
    bool clearCreatedTo = false,
  }) {
    return ForumTopicQuery(
      search: search ?? this.search,
      filters: filters ?? this.filters,
      sort: sort ?? this.sort,
      page: page ?? this.page,
      pageSize: pageSize ?? this.pageSize,
      programEquals:
          clearProgram ? null : (programEquals ?? this.programEquals),
      createdFrom: clearCreatedFrom ? null : (createdFrom ?? this.createdFrom),
      createdTo: clearCreatedTo ? null : (createdTo ?? this.createdTo),
      bookmarkTopicIds: bookmarkTopicIds ?? this.bookmarkTopicIds,
      authorUid: authorUid ?? this.authorUid,
    );
  }
}

class ForumTopicPage {
  final List<ForumTopic> topics;
  final int totalCount;
  final bool hasMore;

  const ForumTopicPage({
    required this.topics,
    required this.totalCount,
    required this.hasMore,
  });
}
