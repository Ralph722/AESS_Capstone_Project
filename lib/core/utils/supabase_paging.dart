/// Reads every row of a query page by page so PostgREST's `max_rows` cap
/// cannot silently truncate the result.
///
/// [fetch] must apply a deterministic order (ending on a unique column)
/// before `.range(from, to)`. Paging stops on the first empty page rather
/// than a short one, so a server cap smaller than [pageSize] still returns
/// every row.
Future<List<Map<String, dynamic>>> fetchAllPages(
  Future<List<Map<String, dynamic>>> Function(int from, int to) fetch, {
  int pageSize = 1000,
}) async {
  final out = <Map<String, dynamic>>[];
  var from = 0;
  while (true) {
    final rows = await fetch(from, from + pageSize - 1);
    if (rows.isEmpty) break;
    out.addAll(rows);
    from += rows.length;
  }
  return out;
}
