import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:alumni_system/core/utils/safe_external_link.dart';

/// Plain text that auto-detects http(s) and "www." links and opens them
/// safely (confirmation dialog + external browser).
class SafeLinkText extends StatefulWidget {
  const SafeLinkText(
    this.text, {
    super.key,
    this.style,
    this.linkStyle,
    this.maxLines,
    this.overflow = TextOverflow.clip,
    this.textAlign = TextAlign.start,
  });

  final String text;
  final TextStyle? style;
  final TextStyle? linkStyle;
  final int? maxLines;
  final TextOverflow overflow;
  final TextAlign textAlign;

  @override
  State<SafeLinkText> createState() => _SafeLinkTextState();
}

class _SafeLinkTextState extends State<SafeLinkText> {
  static final _linkPattern = RegExp(
    '${kHttpUrlPattern.pattern}|'
    r'(\bwww\.[a-z0-9-]+(?:\.[a-z0-9-]+)+[^\s<>"{}|\\^`\[\]]*)',
    caseSensitive: false,
  );

  final List<TapGestureRecognizer> _recognizers = [];
  late List<InlineSpan> _spans;

  @override
  void initState() {
    super.initState();
    _spans = const [];
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _rebuildSpans();
  }

  @override
  void didUpdateWidget(covariant SafeLinkText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text ||
        oldWidget.style != widget.style ||
        oldWidget.linkStyle != widget.linkStyle) {
      _rebuildSpans();
    }
  }

  @override
  void dispose() {
    for (final r in _recognizers) {
      r.dispose();
    }
    super.dispose();
  }

  void _rebuildSpans() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();

    final base = widget.style ?? DefaultTextStyle.of(context).style;
    final linkStyle = widget.linkStyle ??
        base.copyWith(
          color: const Color(0xFF2563EB),
          decoration: TextDecoration.underline,
          decorationColor: const Color(0xFF2563EB),
          fontWeight: FontWeight.w600,
        );

    final text = widget.text;
    if (text.isEmpty) {
      _spans = [TextSpan(text: '', style: base)];
      return;
    }

    final spans = <InlineSpan>[];
    var start = 0;
    for (final match in _linkPattern.allMatches(text)) {
      if (match.start > start) {
        spans.add(
          TextSpan(text: text.substring(start, match.start), style: base),
        );
      }

      final raw = match.group(0) ?? '';
      final shown = sanitizeCapturedUrl(raw);
      final trailing =
          raw.length > shown.length ? raw.substring(shown.length) : '';
      final url = shown.toLowerCase().startsWith('http')
          ? shown
          : 'https://$shown';

      if (isSafeExternalHttpUrl(url)) {
        final recognizer = TapGestureRecognizer()
          ..onTap = () {
            if (!mounted) return;
            openExternalLinkSafely(context, url: url);
          };
        _recognizers.add(recognizer);
        spans.add(
          TextSpan(text: shown, style: linkStyle, recognizer: recognizer),
        );
        if (trailing.isNotEmpty) {
          spans.add(TextSpan(text: trailing, style: base));
        }
      } else {
        spans.add(TextSpan(text: raw, style: base));
      }

      start = match.end;
    }

    if (start < text.length) {
      spans.add(TextSpan(text: text.substring(start), style: base));
    }
    if (spans.isEmpty) {
      spans.add(TextSpan(text: text, style: base));
    }
    _spans = spans;
  }

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(children: _spans),
      maxLines: widget.maxLines,
      overflow: widget.overflow,
      textAlign: widget.textAlign,
    );
  }
}
