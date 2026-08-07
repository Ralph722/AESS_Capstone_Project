enum MessageInboxFilter {
  all,
  unread,
  needsReply,
  recent,
  archived, // future-ready; currently empty set
}

enum MessageInboxSort {
  newestActivity,
  unreadFirst,
  waitingLongest,
  recentlyReplied,
}

class MessageInboxQuery {
  const MessageInboxQuery({
    this.search = '',
    this.filter = MessageInboxFilter.all,
    this.sort = MessageInboxSort.newestActivity,
  });

  final String search;
  final MessageInboxFilter filter;
  final MessageInboxSort sort;

  MessageInboxQuery copyWith({
    String? search,
    MessageInboxFilter? filter,
    MessageInboxSort? sort,
  }) {
    return MessageInboxQuery(
      search: search ?? this.search,
      filter: filter ?? this.filter,
      sort: sort ?? this.sort,
    );
  }

  bool get hasActiveFilters =>
      search.trim().isNotEmpty ||
      filter != MessageInboxFilter.all ||
      sort != MessageInboxSort.newestActivity;
}

extension MessageInboxFilterLabel on MessageInboxFilter {
  String get label => switch (this) {
        MessageInboxFilter.all => 'All',
        MessageInboxFilter.unread => 'Unread',
        MessageInboxFilter.needsReply => 'Needs reply',
        MessageInboxFilter.recent => 'Recent',
        MessageInboxFilter.archived => 'Archived',
      };
}

extension MessageInboxSortLabel on MessageInboxSort {
  String get label => switch (this) {
        MessageInboxSort.newestActivity => 'Newest activity',
        MessageInboxSort.unreadFirst => 'Unread first',
        MessageInboxSort.waitingLongest => 'Waiting longest',
        MessageInboxSort.recentlyReplied => 'Recently replied',
      };
}

List<Map<String, dynamic>> applyInboxQuery(
  List<Map<String, dynamic>> source,
  MessageInboxQuery query,
) {
  final q = query.search.trim().toLowerCase();
  final now = DateTime.now();

  var list = source.where((row) {
    if (query.filter == MessageInboxFilter.archived) {
      return row['isArchived'] == true;
    }
    if (row['isArchived'] == true) return false;

    switch (query.filter) {
      case MessageInboxFilter.all:
        break;
      case MessageInboxFilter.unread:
        if (row['isRead'] == true) return false;
      case MessageInboxFilter.needsReply:
        if ((row['lastMessageFromRole'] as String?)?.toLowerCase() != 'user') {
          return false;
        }
      case MessageInboxFilter.recent:
        final ts = row['lastMessageTime'] as DateTime?;
        if (ts == null || now.difference(ts).inDays > 7) return false;
      case MessageInboxFilter.archived:
        break;
    }

    if (q.isEmpty) return true;
    final haystack = [
      row['name'],
      row['email'],
      row['program'],
      row['batch'],
      row['lastMessage'],
    ].map((e) => (e ?? '').toString().toLowerCase()).join(' ');
    return haystack.contains(q);
  }).toList();

  list.sort((a, b) {
    switch (query.sort) {
      case MessageInboxSort.newestActivity:
        return _timeOf(b).compareTo(_timeOf(a));
      case MessageInboxSort.unreadFirst:
        final aUnread = a['isRead'] == true ? 1 : 0;
        final bUnread = b['isRead'] == true ? 1 : 0;
        if (aUnread != bUnread) return aUnread.compareTo(bUnread);
        return _timeOf(b).compareTo(_timeOf(a));
      case MessageInboxSort.waitingLongest:
        final aWait = a['waitingSince'] as DateTime? ?? _timeOf(a);
        final bWait = b['waitingSince'] as DateTime? ?? _timeOf(b);
        // Older waiting first
        return aWait.compareTo(bWait);
      case MessageInboxSort.recentlyReplied:
        final aAdmin = (a['lastMessageFromRole'] as String?)?.toLowerCase() ==
            'admin';
        final bAdmin = (b['lastMessageFromRole'] as String?)?.toLowerCase() ==
            'admin';
        if (aAdmin != bAdmin) return aAdmin ? -1 : 1;
        return _timeOf(b).compareTo(_timeOf(a));
    }
  });

  return list;
}

DateTime _timeOf(Map<String, dynamic> row) =>
    (row['lastMessageTime'] as DateTime?) ??
    DateTime.fromMillisecondsSinceEpoch(0);

/// Profile snapshot shown beside the admin conversation.
class AlumniMessageProfile {
  const AlumniMessageProfile({
    required this.userId,
    required this.name,
    required this.email,
    this.program = '',
    this.batch = '',
    this.registrationLabel = 'Registered',
    this.tracerComplete = false,
    this.lastActive,
    this.avatarUrl,
  });

  final String userId;
  final String name;
  final String email;
  final String program;
  final String batch;
  final String registrationLabel;
  final bool tracerComplete;
  final DateTime? lastActive;
  final String? avatarUrl;

  factory AlumniMessageProfile.fromConversationRow(Map<String, dynamic> row) {
    return AlumniMessageProfile(
      userId: (row['messagingId'] ?? row['docId'] ?? '').toString(),
      name: (row['name'] as String?)?.trim().isNotEmpty == true
          ? row['name'] as String
          : 'Alumni',
      email: row['email'] as String? ?? '',
      program: row['program'] as String? ?? '',
      batch: row['batch'] as String? ?? '',
      registrationLabel: row['registrationLabel'] as String? ?? 'Registered',
      tracerComplete: row['tracerComplete'] == true,
      lastActive: row['lastActive'] as DateTime?,
      avatarUrl: row['avatarUrl'] as String?,
    );
  }
}
