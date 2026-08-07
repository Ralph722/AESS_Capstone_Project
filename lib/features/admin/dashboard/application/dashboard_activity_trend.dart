import 'package:alumni_system/features/admin/activity/models/audit_log_model.dart';

/// One day of portal / system activity for the dashboard chart.
class DashboardTrendPoint {
  const DashboardTrendPoint({required this.date, required this.count});

  final DateTime date;
  final int count;
}

/// Daily activity counts derived from audit logs.
class DashboardActivityTrend {
  const DashboardActivityTrend({this.points = const []});

  final List<DashboardTrendPoint> points;

  bool get isEmpty => points.every((p) => p.count == 0);

  int get maxCount {
    if (points.isEmpty) return 0;
    return points.map((p) => p.count).reduce((a, b) => a > b ? a : b);
  }

  DashboardTrendPoint? get peakPoint {
    if (points.isEmpty) return null;
    return points.reduce((a, b) => a.count >= b.count ? a : b);
  }

  /// Builds daily buckets for the last [days] (inclusive of today).
  static DashboardActivityTrend fromAuditLogs(
    List<AuditLog> logs, {
    int days = 90,
  }) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = today.subtract(Duration(days: days - 1));

    final counts = <DateTime, int>{};
    for (var i = 0; i < days; i++) {
      counts[start.add(Duration(days: i))] = 0;
    }

    for (final log in logs) {
      var ts = log.timestamp;
      if (ts.isUtc) ts = ts.toLocal();
      final day = DateTime(ts.year, ts.month, ts.day);
      if (day.isBefore(start) || day.isAfter(today)) continue;
      counts[day] = (counts[day] ?? 0) + 1;
    }

    final points = counts.entries
        .map((e) => DashboardTrendPoint(date: e.key, count: e.value))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    return DashboardActivityTrend(points: points);
  }
}
