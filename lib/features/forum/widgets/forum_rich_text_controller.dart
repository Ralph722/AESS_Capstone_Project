import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:alumni_system/features/forum/widgets/forum_formatted_text.dart';
import 'package:alumni_system/shared/widgets/user/portal_theme.dart';

/// Inline styles tracked per character by [ForumRichTextController].
abstract final class ForumInline {
  static const bold = 1;
  static const italic = 2;
}

/// Text controller for the forum composer that shows bold, italic and links
/// as styled text while typing (no visible `**` markers).
///
/// Styles are kept per character next to the plain [text]. [markdown]
/// converts them to the markup read by [ForumFormattedText] for saving, and
/// [loadMarkdown] does the reverse. Line prefixes (`- `, `1. `, `> `) stay in
/// the plain text and are drawn as bullets, numbers and a quote bar.
class ForumRichTextController extends TextEditingController {
  ForumRichTextController();

  List<int> _flags = [];
  List<String?> _links = [];

  /// Styles for the next typed text, set by [toggle] with nothing selected.
  int? _pending;

  static final _bulletPrefix = RegExp(r'^\s*[-*•]\s+');
  static final _numberPrefix = RegExp(r'^\s*\d{1,3}[.)]\s+');
  static final _quotePrefix = RegExp(r'^\s*>\s?');
  static final _edgeSpace = RegExp(r'^(\s*)(.*?)(\s*)$', dotAll: true);

  /// Any list or quote prefix at the start of a line.
  static final anyLinePrefix = RegExp(r'^\s*(?:[-*•]\s+|\d{1,3}[.)]\s+|>\s?)');

  // ---------------------------------------------------------------------------
  // Editing
  // ---------------------------------------------------------------------------

  @override
  set value(TextEditingValue newValue) {
    final old = super.value;
    if (newValue.text != old.text) {
      _applyEdit(old.text, newValue.text, old.selection);
    } else if (newValue.selection != old.selection) {
      _pending = null;
    }
    super.value = newValue;
  }

  void _sync() {
    if (_flags.length == text.length) return;
    _flags = List.filled(text.length, 0, growable: true);
    _links = List.filled(text.length, null, growable: true);
  }

  void _applyEdit(String oldText, String newText, TextSelection oldSel) {
    if (_flags.length != oldText.length) {
      _flags = List.filled(oldText.length, 0, growable: true);
      _links = List.filled(oldText.length, null, growable: true);
    }

    // Changed region: old [start, oldEnd) became new [start, newEnd).
    int start;
    int oldEnd;
    int newEnd;
    final fromSelection = _editAtSelection(oldText, newText, oldSel);
    if (fromSelection != null) {
      (start, oldEnd, newEnd) = fromSelection;
    } else {
      start = 0;
      final maxStart = math.min(oldText.length, newText.length);
      while (start < maxStart &&
          oldText.codeUnitAt(start) == newText.codeUnitAt(start)) {
        start++;
      }
      var suffix = 0;
      while (suffix < oldText.length - start &&
          suffix < newText.length - start &&
          oldText.codeUnitAt(oldText.length - 1 - suffix) ==
              newText.codeUnitAt(newText.length - 1 - suffix)) {
        suffix++;
      }
      oldEnd = oldText.length - suffix;
      newEnd = newText.length - suffix;
    }

    final int inherit;
    if (_pending != null) {
      inherit = _pending!;
    } else if (oldEnd > start) {
      inherit = _flags[start];
    } else if (start > 0 && oldText[start - 1] != '\n') {
      inherit = _flags[start - 1];
    } else {
      inherit = 0;
    }

    final inserted = newEnd - start;
    _flags = [
      ..._flags.sublist(0, start),
      for (var i = 0; i < inserted; i++)
        newText[start + i] == '\n' ? 0 : inherit,
      ..._flags.sublist(oldEnd),
    ];
    _links = [
      ..._links.sublist(0, start),
      ...List<String?>.filled(inserted, null),
      ..._links.sublist(oldEnd),
    ];
    _pending = null;
  }

  /// The edit as an insertion at the old caret, when it fits. Resolves
  /// ambiguous diffs such as typing "l" inside "hello".
  (int, int, int)? _editAtSelection(
    String oldText,
    String newText,
    TextSelection sel,
  ) {
    if (!sel.isValid || !sel.isCollapsed || sel.end > oldText.length) {
      return null;
    }
    final caret = sel.start;
    final newEnd = newText.length - (oldText.length - caret);
    if (newEnd < caret) return null;
    if (!newText.startsWith(oldText.substring(0, caret))) return null;
    if (!newText.endsWith(oldText.substring(caret))) return null;
    return (caret, caret, newEnd);
  }

  /// Replaces [start, end) with [replacement] as one edit, so styles outside
  /// the range are kept.
  void replaceRange(int start, int end, String replacement) {
    value = TextEditingValue(
      text: text.replaceRange(start, end, replacement),
      selection: TextSelection.collapsed(offset: start + replacement.length),
    );
  }

  TextSelection get _safeSelection => selection.isValid
      ? selection
      : TextSelection.collapsed(offset: text.length);

  int _typingFlags(int caret) {
    if (_pending != null) return _pending!;
    if (caret > 0 && caret <= text.length && text[caret - 1] != '\n') {
      return _flags[caret - 1];
    }
    return 0;
  }

  /// Whether [style] applies to the selection, or to the next typed text.
  bool isActive(int style) {
    _sync();
    final sel = _safeSelection;
    if (sel.isCollapsed) return _typingFlags(sel.start) & style != 0;
    var any = false;
    for (var i = sel.start; i < sel.end; i++) {
      if (text[i] == '\n') continue;
      any = true;
      if (_flags[i] & style == 0) return false;
    }
    return any;
  }

  /// Bold / italic on the selection, or for the next typed text.
  void toggle(int style) {
    _sync();
    final sel = _safeSelection;
    if (sel.isCollapsed) {
      _pending = _typingFlags(sel.start) ^ style;
      notifyListeners();
      return;
    }
    final on = !isActive(style);
    for (var i = sel.start; i < sel.end; i++) {
      if (text[i] == '\n') continue;
      _flags[i] = on ? _flags[i] | style : _flags[i] & ~style;
    }
    notifyListeners();
  }

  /// Replaces [start, end) with [label] linked to [url].
  void insertLink({
    required int start,
    required int end,
    required String label,
    required String url,
  }) {
    replaceRange(start, end, label);
    for (var i = start; i < start + label.length; i++) {
      _links[i] = url;
    }
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Markup conversion
  // ---------------------------------------------------------------------------

  static int _prefixLength(String line) {
    for (final re in [_bulletPrefix, _numberPrefix, _quotePrefix]) {
      final m = re.firstMatch(line);
      if (m != null) return m.end;
    }
    return 0;
  }

  /// The text with styles written as markup, for saving.
  String get markdown {
    _sync();
    final out = StringBuffer();
    var lineStart = 0;
    while (true) {
      var lineEnd = text.indexOf('\n', lineStart);
      final last = lineEnd == -1;
      if (last) lineEnd = text.length;
      final pre = _prefixLength(text.substring(lineStart, lineEnd));
      out.write(text.substring(lineStart, lineStart + pre));

      var i = lineStart + pre;
      while (i < lineEnd) {
        var j = i + 1;
        while (j < lineEnd &&
            _flags[j] == _flags[i] &&
            _links[j] == _links[i]) {
          j++;
        }
        out.write(_markup(text.substring(i, j), _flags[i], _links[i]));
        i = j;
      }

      if (last) break;
      out.write('\n');
      lineStart = lineEnd + 1;
    }
    return out.toString();
  }

  static String _markup(String segment, int flags, String? link) {
    final m = _edgeSpace.firstMatch(segment)!;
    var core = m.group(2)!;
    if (core.isEmpty) return segment;
    if (link != null && core != link) core = '[$core]($link)';
    final marker = switch (flags & 3) {
      3 => '***',
      1 => '**',
      2 => '*',
      _ => '',
    };
    return '${m.group(1)}$marker$core$marker${m.group(3)}';
  }

  /// Replaces the content with saved markup, shown as styled text.
  void loadMarkdown(String source) {
    final buf = StringBuffer();
    final flags = <int>[];
    final links = <String?>[];

    void add(String s, int f, String? link) {
      buf.write(s);
      flags.addAll(List.filled(s.length, f));
      links.addAll(List<String?>.filled(s.length, link));
    }

    void parse(String s, int f, String? link) {
      var start = 0;
      for (final m in ForumFormattedText.inlinePattern.allMatches(s)) {
        if (m.start > start) add(s.substring(start, m.start), f, link);
        if (m.group(1) != null) {
          parse(m.group(1)!, f | ForumInline.bold | ForumInline.italic, link);
        } else if (m.group(2) != null) {
          parse(m.group(2)!, f | ForumInline.bold, link);
        } else if (m.group(3) != null) {
          parse(m.group(3)!, f | ForumInline.italic, link);
        } else {
          parse(m.group(4)!, f, m.group(5));
        }
        start = m.end;
      }
      if (start < s.length) add(s.substring(start), f, link);
    }

    final lines = source.replaceAll('\r\n', '\n').split('\n');
    for (var i = 0; i < lines.length; i++) {
      if (i > 0) add('\n', 0, null);
      final pre = _prefixLength(lines[i]);
      add(lines[i].substring(0, pre), 0, null);
      parse(lines[i].substring(pre), 0, null);
    }

    _flags = flags;
    _links = links;
    _pending = null;
    final plain = buf.toString();
    super.value = TextEditingValue(
      text: plain,
      selection: TextSelection.collapsed(offset: plain.length),
    );
  }

  // ---------------------------------------------------------------------------
  // Display
  // ---------------------------------------------------------------------------

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    _sync();
    final base = style ?? const TextStyle();
    if (text.isEmpty) return TextSpan(style: base, text: '');

    final composing = withComposing && value.isComposingRangeValid
        ? value.composing
        : TextRange.empty;
    bool inComposing(int i) =>
        composing.isValid && i >= composing.start && i < composing.end;

    final markerStyle = base.copyWith(
      color: PortalTheme.navy,
      fontWeight: FontWeight.w700,
    );
    final spans = <InlineSpan>[];
    var lineStart = 0;
    while (true) {
      var lineEnd = text.indexOf('\n', lineStart);
      final last = lineEnd == -1;
      if (last) lineEnd = text.length;
      final line = text.substring(lineStart, lineEnd);

      var lineStyle = base;
      final bullet = _bulletPrefix.firstMatch(line);
      final number = bullet == null ? _numberPrefix.firstMatch(line) : null;
      final quote = bullet == null && number == null
          ? _quotePrefix.firstMatch(line)
          : null;
      var pre = 0;
      if (bullet != null) {
        pre = bullet.end;
        // Same length as the typed prefix so the caret stays in place.
        spans.add(
          TextSpan(
            text: line.substring(0, pre).replaceFirst(RegExp('[-*]'), '•'),
            style: markerStyle,
          ),
        );
      } else if (number != null) {
        pre = number.end;
        spans.add(TextSpan(text: line.substring(0, pre), style: markerStyle));
      } else if (quote != null) {
        pre = quote.end;
        spans.add(
          TextSpan(
            text: line.substring(0, pre).replaceFirst('>', '|'),
            style: markerStyle.copyWith(fontWeight: FontWeight.w900),
          ),
        );
        lineStyle = base.copyWith(
          color: PortalTheme.textSecondary,
          fontStyle: FontStyle.italic,
        );
      }

      var i = lineStart + pre;
      while (i < lineEnd) {
        var j = i + 1;
        while (j < lineEnd &&
            _flags[j] == _flags[i] &&
            _links[j] == _links[i] &&
            inComposing(j) == inComposing(i)) {
          j++;
        }
        var s = lineStyle;
        if (_flags[i] & ForumInline.bold != 0) {
          s = s.copyWith(fontWeight: FontWeight.w700);
        }
        if (_flags[i] & ForumInline.italic != 0) {
          s = s.copyWith(fontStyle: FontStyle.italic);
        }
        if (_links[i] != null) {
          s = s.copyWith(
            color: const Color(0xFF2563EB),
            decoration: TextDecoration.underline,
            decorationColor: const Color(0xFF2563EB),
          );
        }
        if (inComposing(i)) {
          s = s.copyWith(decoration: TextDecoration.underline);
        }
        spans.add(TextSpan(text: text.substring(i, j), style: s));
        i = j;
      }

      if (last) break;
      spans.add(TextSpan(text: '\n', style: base));
      lineStart = lineEnd + 1;
    }
    return TextSpan(style: base, children: spans);
  }
}
