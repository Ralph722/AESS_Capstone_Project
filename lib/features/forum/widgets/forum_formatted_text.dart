import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:alumni_system/core/utils/safe_external_link.dart';
import 'package:alumni_system/shared/widgets/user/portal_theme.dart';

/// Renders forum text written with the composer toolbar's lightweight markup:
///
/// * `**bold**`, `*italic*`, `***both***`
/// * `- item` bullets, `1. item` numbered lists, `> quote` lines
/// * `[label](https://…)` links, plus bare http(s) / www. links
///
/// Text without markup renders the same as plain text. Links always open
/// through [openExternalLinkSafely].
class ForumFormattedText extends StatefulWidget {
  const ForumFormattedText(this.text, {super.key, this.style});

  final String text;
  final TextStyle? style;

  static final _bullet = RegExp(r'^\s*[-*•]\s+(.*)$');
  static final _numbered = RegExp(r'^\s*(\d{1,3})[.)]\s+(.*)$');
  static final _quote = RegExp(r'^\s*>\s?(.*)$');

  static final _inline = RegExp(
    r'\*\*\*(?=\S)(.+?)(?<=\S)\*\*\*'
    r'|\*\*(?=\S)(.+?)(?<=\S)\*\*'
    r'|\*(?=[^\s*])(.+?)(?<=[^\s*])\*'
    r'|\[([^\]\n]+)\]\(([^)\s]+)\)',
  );

  /// Matches one inline span: groups 1 bold italic, 2 bold, 3 italic,
  /// 4 + 5 link label and URL.
  static RegExp get inlinePattern => _inline;

  /// [text] with the markup removed, for excerpts and one-line previews.
  static String plain(String text) {
    final lines = text.replaceAll('\r\n', '\n').split('\n').map((line) {
      final bullet = _bullet.firstMatch(line);
      if (bullet != null) return '• ${bullet.group(1)}';
      final quote = _quote.firstMatch(line);
      if (quote != null) return quote.group(1) ?? '';
      return line;
    });
    return lines
        .join('\n')
        .replaceAllMapped(
          _inline,
          (m) => m.group(1) ?? m.group(2) ?? m.group(3) ?? m.group(4) ?? '',
        );
  }

  @override
  State<ForumFormattedText> createState() => _ForumFormattedTextState();
}

class _ForumFormattedTextState extends State<ForumFormattedText> {
  static final _autoLink = RegExp(
    '${kHttpUrlPattern.pattern}|'
    r'(\bwww\.[a-z0-9-]+(?:\.[a-z0-9-]+)+[^\s<>"{}|\\^`\[\]]*)',
    caseSensitive: false,
  );

  final List<TapGestureRecognizer> _recognizers = [];
  Widget _content = const SizedBox.shrink();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _rebuild();
  }

  @override
  void didUpdateWidget(covariant ForumFormattedText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text || oldWidget.style != widget.style) {
      _rebuild();
    }
  }

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  void _disposeRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  void _rebuild() {
    _disposeRecognizers();
    final base = DefaultTextStyle.of(context).style.merge(widget.style);
    final lineHeight = (base.fontSize ?? 14) * (base.height ?? 1.4);
    final lines = widget.text.replaceAll('\r\n', '\n').split('\n');

    final children = <Widget>[];
    final quoteLines = <String>[];

    void flushQuote() {
      if (quoteLines.isEmpty) return;
      final quoteStyle = base.copyWith(color: PortalTheme.textSecondary);
      children.add(
        Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.fromLTRB(12, 8, 10, 8),
          decoration: BoxDecoration(
            color: PortalTheme.surfaceMuted,
            borderRadius: BorderRadius.circular(8),
            border: const Border(
              left: BorderSide(color: PortalTheme.navy, width: 3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final q in quoteLines)
                q.trim().isEmpty
                    ? SizedBox(height: lineHeight * 0.5)
                    : Text.rich(TextSpan(children: _spans(q, quoteStyle))),
            ],
          ),
        ),
      );
      quoteLines.clear();
    }

    for (final line in lines) {
      final quote = ForumFormattedText._quote.firstMatch(line);
      if (quote != null) {
        quoteLines.add(quote.group(1) ?? '');
        continue;
      }
      flushQuote();

      final bullet = ForumFormattedText._bullet.firstMatch(line);
      final numbered = ForumFormattedText._numbered.firstMatch(line);
      if (bullet != null) {
        children.add(_listItem('•', bullet.group(1) ?? '', base, 18));
      } else if (numbered != null) {
        children.add(
          _listItem('${numbered.group(1)}.', numbered.group(2) ?? '', base, 26),
        );
      } else if (line.trim().isEmpty) {
        children.add(SizedBox(height: lineHeight));
      } else {
        children.add(Text.rich(TextSpan(children: _spans(line, base))));
      }
    }
    flushQuote();

    _content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }

  Widget _listItem(String marker, String text, TextStyle base, double width) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: width,
            child: Text(
              marker,
              style: base.copyWith(
                color: PortalTheme.navy,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(child: Text.rich(TextSpan(children: _spans(text, base)))),
        ],
      ),
    );
  }

  List<InlineSpan> _spans(String text, TextStyle style) {
    final spans = <InlineSpan>[];
    var start = 0;
    for (final m in ForumFormattedText._inline.allMatches(text)) {
      if (m.start > start) {
        spans.addAll(_linkify(text.substring(start, m.start), style));
      }
      if (m.group(1) != null) {
        spans.addAll(
          _spans(
            m.group(1)!,
            style.copyWith(
              fontWeight: FontWeight.w700,
              fontStyle: FontStyle.italic,
            ),
          ),
        );
      } else if (m.group(2) != null) {
        spans.addAll(
          _spans(m.group(2)!, style.copyWith(fontWeight: FontWeight.w700)),
        );
      } else if (m.group(3) != null) {
        spans.addAll(
          _spans(m.group(3)!, style.copyWith(fontStyle: FontStyle.italic)),
        );
      } else {
        spans.add(_labelledLink(m.group(4)!, m.group(5)!, m.group(0)!, style));
      }
      start = m.end;
    }
    if (start < text.length) {
      spans.addAll(_linkify(text.substring(start), style));
    }
    return spans;
  }

  TextStyle _linkStyle(TextStyle style) => style.copyWith(
    color: const Color(0xFF2563EB),
    decoration: TextDecoration.underline,
    decorationColor: const Color(0xFF2563EB),
    fontWeight: FontWeight.w600,
  );

  InlineSpan _labelledLink(
    String label,
    String rawUrl,
    String raw,
    TextStyle style,
  ) {
    final url = rawUrl.toLowerCase().startsWith('http')
        ? rawUrl
        : 'https://$rawUrl';
    if (!isSafeExternalHttpUrl(url)) return TextSpan(text: raw, style: style);
    return TextSpan(
      text: label,
      style: _linkStyle(style),
      recognizer: _recognizer(url),
    );
  }

  List<InlineSpan> _linkify(String text, TextStyle style) {
    final spans = <InlineSpan>[];
    var start = 0;
    for (final match in _autoLink.allMatches(text)) {
      if (match.start > start) {
        spans.add(
          TextSpan(text: text.substring(start, match.start), style: style),
        );
      }
      final raw = match.group(0) ?? '';
      final shown = sanitizeCapturedUrl(raw);
      final trailing = raw.length > shown.length
          ? raw.substring(shown.length)
          : '';
      final url = shown.toLowerCase().startsWith('http')
          ? shown
          : 'https://$shown';
      if (isSafeExternalHttpUrl(url)) {
        spans.add(
          TextSpan(
            text: shown,
            style: _linkStyle(style),
            recognizer: _recognizer(url),
          ),
        );
        if (trailing.isNotEmpty) {
          spans.add(TextSpan(text: trailing, style: style));
        }
      } else {
        spans.add(TextSpan(text: raw, style: style));
      }
      start = match.end;
    }
    if (start < text.length) {
      spans.add(TextSpan(text: text.substring(start), style: style));
    }
    return spans;
  }

  TapGestureRecognizer _recognizer(String url) {
    final recognizer = TapGestureRecognizer()
      ..onTap = () {
        if (!mounted) return;
        openExternalLinkSafely(context, url: url);
      };
    _recognizers.add(recognizer);
    return recognizer;
  }

  @override
  Widget build(BuildContext context) => _content;
}
