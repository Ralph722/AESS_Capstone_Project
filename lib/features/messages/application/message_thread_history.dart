import 'package:alumni_system/features/messages/data/message_repository.dart';

/// Pure helpers for paginated thread windows (Part 11).
///
/// Alumni lists are newest-first ([newestFirst] = true).
/// Admin lists are oldest-first ([newestFirst] = false).
abstract final class MessageThreadHistory {
  static DateTime? oldestTimestamp(Iterable<Map<String, dynamic>> messages) {
    DateTime? oldest;
    for (final m in messages) {
      final t = m['timestamp'] as DateTime?;
      if (t == null) continue;
      if (oldest == null || t.isBefore(oldest)) oldest = t;
    }
    return oldest;
  }

  static String? messageId(Map<String, dynamic> m) {
    final id = (m['docId'] ?? m['id'])?.toString();
    if (id == null || id.isEmpty) return null;
    return id;
  }

  /// Merges a live server window with previously loaded older rows.
  static List<Map<String, dynamic>> mergeWindow({
    required List<Map<String, dynamic>> serverWindow,
    required Map<String, Map<String, dynamic>> olderById,
    List<Map<String, dynamic>>? currentMessages,
    bool preserveOptimistic = false,
    bool newestFirst = true,
  }) {
    final serverById = <String, Map<String, dynamic>>{};
    for (final m in serverWindow) {
      final id = messageId(m);
      if (id == null) continue;
      serverById[id] = {
        ...m,
        'docId': id,
        if (preserveOptimistic) 'optimistic': false,
      };
      olderById.remove(id);
    }

    final combined = <String, Map<String, dynamic>>{
      ...olderById,
      ...serverById,
    };

    if (preserveOptimistic && currentMessages != null) {
      for (final m in currentMessages) {
        final id = messageId(m);
        if (id == null) continue;
        if (m['optimistic'] == true && !combined.containsKey(id)) {
          combined[id] = {...m, 'docId': id};
        }
      }
    }

    final merged = combined.values.toList();
    merged.sort((a, b) {
      final timeA = (a['timestamp'] as DateTime?) ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final timeB = (b['timestamp'] as DateTime?) ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return newestFirst ? timeB.compareTo(timeA) : timeA.compareTo(timeB);
    });
    return merged;
  }

  /// Folds an older page into [olderById] and returns the full sorted list.
  static List<Map<String, dynamic>> applyOlderPage({
    required List<Map<String, dynamic>> currentMessages,
    required Map<String, Map<String, dynamic>> olderById,
    required Iterable<Map<String, dynamic>> olderPage,
    bool newestFirst = true,
  }) {
    for (final m in olderPage) {
      final id = messageId(m);
      if (id == null) continue;
      olderById.putIfAbsent(id, () => {...m, 'docId': id, 'optimistic': false});
    }

    final byId = <String, Map<String, dynamic>>{};
    for (final m in currentMessages) {
      final id = messageId(m);
      if (id == null) continue;
      byId[id] = {...m, 'docId': id};
    }
    for (final e in olderById.entries) {
      byId.putIfAbsent(e.key, () => e.value);
    }

    final merged = byId.values.toList();
    merged.sort((a, b) {
      final timeA = (a['timestamp'] as DateTime?) ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final timeB = (b['timestamp'] as DateTime?) ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return newestFirst ? timeB.compareTo(timeA) : timeA.compareTo(timeB);
    });
    return merged;
  }

  static bool inferHasMoreHistory({
    required int windowLength,
    required bool olderEmpty,
    int pageSize = MessageRepository.threadPageSize,
  }) {
    if (windowLength < pageSize && olderEmpty) return false;
    if (windowLength >= pageSize && olderEmpty) return true;
    return true;
  }
}
