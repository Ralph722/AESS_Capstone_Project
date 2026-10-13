import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:alumni_system/core/utils/supabase_paging.dart';
import 'package:alumni_system/features/admin/reports/models/gts_list_config.dart';
import 'package:alumni_system/features/admin/reports/models/gts_report_config.dart';

/// Report builder settings saved under a name, shared by every admin.
class GtsSavedReport {
  const GtsSavedReport({
    required this.id,
    required this.name,
    required this.config,
    this.updatedAt,
  });

  factory GtsSavedReport.fromRow(Map<String, dynamic> row) => GtsSavedReport(
    id: row['id'].toString(),
    name: row['name']?.toString() ?? '',
    config: row['config'] is Map
        ? Map<String, dynamic>.from(row['config'] as Map)
        : const {},
    updatedAt: DateTime.tryParse(row['updated_at']?.toString() ?? ''),
  );

  final String id;
  final String name;

  /// Settings JSON as stored ([GtsReportConfig.toJson] or
  /// [GtsListConfig.toJson]).
  final Map<String, dynamic> config;
  final DateTime? updatedAt;

  /// An alumni list rather than a summary report.
  bool get isList => GtsListConfig.isList(config);

  /// Summary settings. Throws [FormatException] for alumni lists and for
  /// settings saved by a newer app version.
  GtsReportConfig get settings {
    if (isList) {
      throw const FormatException('This saved report is an alumni list.');
    }
    return GtsReportConfig.fromJson(config);
  }

  /// Alumni list settings. Throws [FormatException] for summary reports and
  /// for lists saved by a newer app version.
  GtsListConfig get listSettings => GtsListConfig.fromJson(config);
}

/// Another saved report already uses [name] (names ignore case and spaces).
class GtsSavedReportNameTaken implements Exception {
  const GtsSavedReportNameTaken(this.name);

  final String name;
}

abstract interface class GtsSavedReportStore {
  Future<List<GtsSavedReport>> list();

  /// Creates a saved report, or replaces [id]'s name and settings.
  /// [settings] is the settings JSON, already titled [name].
  /// Throws [GtsSavedReportNameTaken] when the name is in use.
  Future<GtsSavedReport> save({
    String? id,
    required String name,
    required Map<String, dynamic> settings,
  });

  Future<void> delete(String id);
}

/// Saved reports in `report_definitions` (admins only; the database
/// records who saved them and when).
class GtsSavedReportService implements GtsSavedReportStore {
  GtsSavedReportService({SupabaseClient? supabase})
    : _supabase = supabase ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  static const _table = 'report_definitions';
  static const _columns = 'id, name, config, updated_at';

  @override
  Future<List<GtsSavedReport>> list() async {
    final rows = await fetchAllPages(
      (from, to) => _supabase
          .from(_table)
          .select(_columns)
          .order('name')
          .order('id')
          .range(from, to),
    );
    return [for (final r in rows) GtsSavedReport.fromRow(r)];
  }

  @override
  Future<GtsSavedReport> save({
    String? id,
    required String name,
    required Map<String, dynamic> settings,
  }) async {
    final trimmed = name.trim();
    final row = {'name': trimmed, 'config': settings};
    try {
      final saved = id == null
          ? await _supabase.from(_table).insert(row).select(_columns).single()
          : await _supabase
                .from(_table)
                .update(row)
                .eq('id', id)
                .select(_columns)
                .single();
      return GtsSavedReport.fromRow(saved);
    } on PostgrestException catch (e) {
      if (e.code == '23505') throw GtsSavedReportNameTaken(trimmed);
      rethrow;
    }
  }

  @override
  Future<void> delete(String id) =>
      _supabase.from(_table).delete().eq('id', id);
}
