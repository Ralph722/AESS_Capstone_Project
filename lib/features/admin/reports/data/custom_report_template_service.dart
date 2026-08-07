import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:alumni_system/features/admin/reports/models/custom_report_template.dart';

/// Browser-local CRUD for custom report templates (SharedPreferences).
class CustomReportTemplateService {
  CustomReportTemplateService({SharedPreferences? prefs}) : _prefs = prefs;

  static const _storageKey = 'admin_custom_report_templates_v1';

  SharedPreferences? _prefs;

  Future<SharedPreferences> _ensurePrefs() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  Future<List<CustomReportTemplate>> loadAll() async {
    final prefs = await _ensurePrefs();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      final templates = <CustomReportTemplate>[];
      for (final item in decoded) {
        if (item is! Map) continue;
        final template = CustomReportTemplate.fromJson(
          Map<String, dynamic>.from(item),
        );
        if (template.id.isEmpty) continue;
        templates.add(template);
      }
      templates.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return templates;
    } catch (_) {
      return const [];
    }
  }

  Future<void> save(CustomReportTemplate template) async {
    final error = template.validate();
    if (error != null) {
      throw ArgumentError(error);
    }
    final prefs = await _ensurePrefs();
    final existing = await loadAll();
    final next = <CustomReportTemplate>[
      for (final t in existing)
        if (t.id != template.id) t,
      template,
    ]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    await prefs.setString(
      _storageKey,
      jsonEncode(next.map((t) => t.toJson()).toList()),
    );
  }

  Future<void> delete(String id) async {
    final prefs = await _ensurePrefs();
    final existing = await loadAll();
    final next = existing.where((t) => t.id != id).toList();
    await prefs.setString(
      _storageKey,
      jsonEncode(next.map((t) => t.toJson()).toList()),
    );
  }

  Future<void> clearAll() async {
    final prefs = await _ensurePrefs();
    await prefs.remove(_storageKey);
  }
}
