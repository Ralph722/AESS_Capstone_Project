import 'dart:developer' as developer;
import 'dart:typed_data';

import 'package:alumni_system/features/admin/ched_gts_pdf_export/ched_gts_pdf_field_catalog.dart';
import 'package:alumni_system/features/admin/ched_gts_pdf_export/ched_gts_pdf_mapper.dart';
import 'package:alumni_system/features/admin/ched_gts_pdf_export/ched_gts_pdf_template.dart';
import 'package:alumni_system/features/admin/ched_gts_pdf_export/ched_gts_pdf_text_fit.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:syncfusion_flutter_pdf/pdf.dart';

/// Result of filling the official CHED GTS AcroForm template.
class ChedGtsPdfFillResult {
  const ChedGtsPdfFillResult({
    required this.bytes,
    required this.appliedFieldCount,
    required this.notes,
    this.mapped,
  });

  final Uint8List bytes;
  final int appliedFieldCount;
  final List<String> notes;
  final ChedGtsPdfMappedFields? mapped;
}

/// Fills [ChedGtsPdfTemplate] AcroForm fields from mapped PDF values.
///
/// Loads the active registered template, optionally validates field count,
/// sets text / choice / radio / checkbox values, and returns PDF bytes.
/// Does not download or show UI.
abstract final class ChedGtsPdfFillEngine {
  static Uint8List? _cachedTemplateBytes;
  static String? _cachedTemplateAssetPath;

  /// Fill from already-mapped PDF field values (`fullName`, `/employed`, …).
  static Future<ChedGtsPdfFillResult> fillMapped({
    required Map<String, String> values,
    Uint8List? templateBytes,
    bool flatten = false,
    bool validateFieldCount = true,
    ChedGtsPdfTemplateSpec? template,
    List<String> priorNotes = const [],
  }) async {
    final spec = template ?? ChedGtsPdfTemplate.active;
    final notes = <String>[
      ...priorNotes,
      ...ChedGtsPdfTemplate.compatibilityNotes(),
    ];
    final bytes = templateBytes ?? await loadTemplateBytes(spec: spec);
    final document = PdfDocument(inputBytes: bytes);
    var applied = 0;

    try {
      final form = document.form;
      if (validateFieldCount &&
          form.fields.count != spec.expectedFieldCount) {
        notes.add(
          'Template field count ${form.fields.count} != expected '
          '${spec.expectedFieldCount} (v${spec.schemaVersion})',
        );
      }

      // Ask viewers to rebuild field appearances when not flattening.
      if (!flatten) {
        form.setDefaultAppearance(true);
      }

      final byName = <String, PdfField>{};
      for (var i = 0; i < form.fields.count; i++) {
        final field = form.fields[i];
        final name = field.name;
        if (name == null || name.isEmpty) continue;
        byName[name] = field;
      }

      for (final entry in values.entries) {
        final field = byName[entry.key];
        if (field == null) {
          notes.add('PDF field "${entry.key}" not found on template');
          continue;
        }
        final ok = _applyValue(field, entry.value, notes);
        if (ok) applied++;
      }

      if (flatten) {
        form.flattenAllFields();
      }

      final saved = await document.save();
      return ChedGtsPdfFillResult(
        bytes: Uint8List.fromList(saved),
        appliedFieldCount: applied,
        notes: notes,
      );
    } finally {
      document.dispose();
    }
  }

  /// Map CHED `ched_*` answers then fill the official template.
  static Future<ChedGtsPdfFillResult> fillFromAnswers({
    required Map<String, dynamic> answers,
    Uint8List? templateBytes,
    bool flatten = false,
    bool validateFieldCount = true,
    ChedGtsPdfTemplateSpec? template,
  }) async {
    final mapped = ChedGtsPdfMapper.mapAnswers(answers);
    final filled = await fillMapped(
      values: mapped.values,
      templateBytes: templateBytes,
      flatten: flatten,
      validateFieldCount: validateFieldCount,
      template: template,
      priorNotes: mapped.notes,
    );
    return ChedGtsPdfFillResult(
      bytes: filled.bytes,
      appliedFieldCount: filled.appliedFieldCount,
      notes: filled.notes,
      mapped: mapped,
    );
  }

  /// Load (and cache) bytes for [spec] (defaults to the active template).
  static Future<Uint8List> loadTemplateBytes({
    ChedGtsPdfTemplateSpec? spec,
    bool forceReload = false,
  }) async {
    final target = spec ?? ChedGtsPdfTemplate.active;
    if (!forceReload &&
        _cachedTemplateBytes != null &&
        _cachedTemplateAssetPath == target.assetPath) {
      return _cachedTemplateBytes!;
    }
    final data = await rootBundle.load(target.assetPath);
    final bytes = data.buffer.asUint8List();
    _cachedTemplateBytes = bytes;
    _cachedTemplateAssetPath = target.assetPath;
    return bytes;
  }

  /// Clears the in-memory template cache (tests / hot reload).
  static void clearTemplateCache() {
    _cachedTemplateBytes = null;
    _cachedTemplateAssetPath = null;
  }

  /// Build a download-friendly file name for a single filled PDF.
  static String suggestFileName({
    String? displayName,
    String? surveyLabel,
    DateTime? when,
  }) {
    final stamp = (when ?? DateTime.now()).toIso8601String().split('T').first;
    final who = _slug(displayName?.trim().isNotEmpty == true
        ? displayName!.trim()
        : 'alumni');
    final wave = surveyLabel == null || surveyLabel.trim().isEmpty
        ? null
        : _slug(surveyLabel.trim());
    if (wave == null) return 'GTS-$who-$stamp.pdf';
    return 'GTS-$who-$wave-$stamp.pdf';
  }

  static bool _applyValue(
    PdfField field,
    String raw,
    List<String> notes,
  ) {
    final value = raw.trim();
    if (value.isEmpty) return false;

    if (field is PdfTextBoxField) {
      _applyTextBox(field, value, notes);
      return true;
    }

    if (field is PdfComboBoxField) {
      // Choice fields use the visible option string (no leading slash).
      final match = _matchCombo(field, value);
      if (match == null) {
        notes.add(
          'No combo option for "${field.name}" matching "$value"',
        );
        return false;
      }
      field.selectedValue = match;
      return true;
    }

    if (field is PdfCheckBoxField) {
      final on = _isCheckboxOn(value, field.name);
      field.isChecked = on;
      return on;
    }

    if (field is PdfRadioButtonListField) {
      final match = _matchRadio(field, value);
      if (match == null) {
        notes.add(
          'No radio option for "${field.name}" matching "$value"',
        );
        return false;
      }
      field.selectedValue = match;
      return true;
    }

    notes.add(
      'Unsupported field type ${field.runtimeType} for "${field.name}"',
    );
    return false;
  }

  /// Writes the complete [value] into [field], clearing MaxLen caps and
  /// shrinking / wrapping Helvetica so the answer stays visible in-bounds.
  static void _applyTextBox(
    PdfTextBoxField field,
    String value,
    List<String> notes,
  ) {
    // Template widgets ship MaxLen=100; never silently drop longer answers.
    if (field.maxLength > 0 && value.length > field.maxLength) {
      notes.add(
        'Cleared MaxLen ${field.maxLength} on "${field.name}" '
        '(answer is ${value.length} chars)',
      );
    }
    if (field.maxLength != 0) {
      field.maxLength = 0;
    }

    final bounds = field.bounds;
    final fit = ChedGtsPdfTextFit.fit(
      text: value,
      width: bounds.width,
      height: bounds.height,
      templateMultiline: field.multiline,
    );

    if (fit.multiline && !field.multiline) {
      field.multiline = true;
    }

    field.font = PdfStandardFont(
      PdfFontFamily.helvetica,
      fit.fontSize,
    );
    // Prefer non-scrolling appearance once we have sized the text; keep
    // scrolling only as a viewer fallback when the answer still overflows.
    field.scrollable = !fit.fits;

    // Always store the complete answer — never truncate for layout.
    field.text = value;

    if (!fit.fits) {
      final detail = fit.overflowDetail ?? 'overflow at min font';
      final note =
          'OVERFLOW "${field.name}": $detail — value preserved in full '
          '(${value.length} chars)';
      notes.add(note);
      developer.log(
        note,
        name: 'ChedGtsPdfFillEngine',
        level: 900,
      );
      developer.log(
        'OVERFLOW value for "${field.name}": $value',
        name: 'ChedGtsPdfFillEngine',
        level: 900,
      );
    }
  }

  static bool _isCheckboxOn(String value, String? fieldName) {
    final v = value.trim();
    if (v == '/Off' || v.toLowerCase() == 'off' || v == 'false') {
      return false;
    }
    final def = fieldName == null
        ? null
        : ChedGtsPdfFieldCatalog.byName[fieldName];
    final on = def?.checkboxOn ?? '/Yes';
    if (v == on || v == 'Yes' || v == '/Yes' || v.toLowerCase() == 'true') {
      return true;
    }
    // Any non-off value from the mapper means checked.
    return v.isNotEmpty;
  }

  static String? _matchCombo(PdfComboBoxField field, String value) {
    for (var i = 0; i < field.items.count; i++) {
      final text = field.items[i].text;
      if (text == value) return text;
    }
    final lower = value.toLowerCase();
    for (var i = 0; i < field.items.count; i++) {
      final text = field.items[i].text;
      if (text.toLowerCase() == lower) return text;
    }
    return null;
  }

  /// Match mapper export (`/single`, `/<1mo`) to Syncfusion item values
  /// (`single`, `#3c1mo`).
  static String? _matchRadio(PdfRadioButtonListField field, String value) {
    final candidates = _radioCandidates(value);
    for (var i = 0; i < field.items.count; i++) {
      final itemValue = field.items[i].value;
      if (candidates.contains(itemValue)) return itemValue;
    }
    // Normalized compare (strip #HH escapes / leading slash).
    final wanted = candidates.map(_normalizeRadioToken).toSet();
    for (var i = 0; i < field.items.count; i++) {
      final itemValue = field.items[i].value;
      if (wanted.contains(_normalizeRadioToken(itemValue))) {
        return itemValue;
      }
    }
    return null;
  }

  static Set<String> _radioCandidates(String raw) {
    final out = <String>{};
    var v = raw.trim();
    if (v.isEmpty) return out;
    out.add(v);
    if (v.startsWith('/')) {
      v = v.substring(1);
      out.add(v);
    }
    // PDF name encoding: '<' → '#3C' / '#3c'
    if (v.contains('<')) {
      out.add(v.replaceAll('<', '#3c'));
      out.add(v.replaceAll('<', '#3C'));
    }
    return out;
  }

  static String _normalizeRadioToken(String raw) {
    var s = raw.trim();
    if (s.startsWith('/')) s = s.substring(1);
    // Decode #HH hex escapes used in PDF names.
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (s[i] == '#' && i + 2 < s.length) {
        final hex = s.substring(i + 1, i + 3);
        final code = int.tryParse(hex, radix: 16);
        if (code != null) {
          buf.writeCharCode(code);
          i += 2;
          continue;
        }
      }
      buf.write(s[i]);
    }
    return buf.toString().toLowerCase();
  }

  static String _slug(String input) {
    final cleaned = input
        .replaceAll(RegExp(r'[^\w\s\-]+'), '')
        .trim()
        .replaceAll(RegExp(r'\s+'), '-');
    if (cleaned.isEmpty) return 'alumni';
    return cleaned.length > 48 ? cleaned.substring(0, 48) : cleaned;
  }
}
