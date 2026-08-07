import 'dart:math' as math;

import 'package:syncfusion_flutter_pdf/pdf.dart';

/// Result of fitting a string into an AcroForm text widget rectangle.
class ChedGtsPdfTextFitResult {
  const ChedGtsPdfTextFitResult({
    required this.fontSize,
    required this.multiline,
    required this.fits,
    required this.lineCount,
    this.overflowDetail,
  });

  /// Chosen Helvetica size (never below [ChedGtsPdfTextFit.minimumFontSize]).
  final double fontSize;

  /// Whether the field should render as multiline (word wrap).
  final bool multiline;

  /// True when the complete answer fits at [fontSize] without clipping.
  final bool fits;

  final int lineCount;

  /// Present when [fits] is false — for export notes / debugging.
  final String? overflowDetail;
}

/// Intelligent text fitting for official CHED GTS AcroForm text widgets.
///
/// Does not alter template geometry. Shrinks Helvetica within
/// [[minimumFontSize], [preferredFontSize]] and enables wrapping only when
/// the existing field height can hold more than one line.
abstract final class ChedGtsPdfTextFit {
  /// Template default appearance is roughly 9 pt Helvetica.
  static const double preferredFontSize = 9.0;

  /// Smallest size still reasonably readable in print.
  static const double minimumFontSize = 5.5;

  static const double _hPad = 4.0;
  static const double _vPad = 2.0;
  static const double _lineHeightFactor = 1.12;

  /// Enable wrap when usable height can hold ~1.5 lines at preferred size.
  static const double multilineMinUsableHeight = 18.0;

  static ChedGtsPdfTextFitResult fit({
    required String text,
    required double width,
    required double height,
    bool templateMultiline = false,
  }) {
    final value = text;
    if (value.isEmpty) {
      return const ChedGtsPdfTextFitResult(
        fontSize: preferredFontSize,
        multiline: false,
        fits: true,
        lineCount: 0,
      );
    }

    final usableW = math.max(1.0, width - _hPad);
    final usableH = math.max(1.0, height - _vPad);
    final allowMultiline =
        templateMultiline || usableH >= multilineMinUsableHeight;

    for (var size = preferredFontSize;
        size >= minimumFontSize - 0.001;
        size = _nextSize(size)) {
      final font = PdfStandardFont(PdfFontFamily.helvetica, size);
      if (allowMultiline) {
        final lines = wrapLines(value, font, usableW);
        final needed = lines.length * font.height * _lineHeightFactor;
        if (needed <= usableH + 0.5) {
          return ChedGtsPdfTextFitResult(
            fontSize: size,
            multiline: lines.length > 1 || templateMultiline,
            fits: true,
            lineCount: lines.length,
          );
        }
      } else {
        final measured = font.measureString(value);
        if (measured.width <= usableW && measured.height <= usableH + 0.5) {
          return ChedGtsPdfTextFitResult(
            fontSize: size,
            multiline: false,
            fits: true,
            lineCount: 1,
          );
        }
      }
    }

    // Graceful fallback: keep the full value at the minimum readable size.
    final font = PdfStandardFont(PdfFontFamily.helvetica, minimumFontSize);
    if (allowMultiline) {
      final lines = wrapLines(value, font, usableW);
      final needed = lines.length * font.height * _lineHeightFactor;
      final fits = needed <= usableH + 0.5;
      return ChedGtsPdfTextFitResult(
        fontSize: minimumFontSize,
        multiline: true,
        fits: fits,
        lineCount: lines.length,
        overflowDetail: fits
            ? null
            : 'needs ~${needed.toStringAsFixed(1)}pt height '
                'in ${usableH.toStringAsFixed(1)}pt '
                '(${lines.length} lines, ${value.length} chars)',
      );
    }

    final measured = font.measureString(value);
    final fits =
        measured.width <= usableW && measured.height <= usableH + 0.5;
    return ChedGtsPdfTextFitResult(
      fontSize: minimumFontSize,
      multiline: false,
      fits: fits,
      lineCount: 1,
      overflowDetail: fits
          ? null
          : 'needs ~${measured.width.toStringAsFixed(1)}pt width '
              'in ${usableW.toStringAsFixed(1)}pt '
              '(${value.length} chars)',
    );
  }

  /// Word-wrap [text] so each line measures ≤ [maxWidth].
  ///
  /// Oversized tokens are split by character so no data is dropped.
  static List<String> wrapLines(String text, PdfFont font, double maxWidth) {
    final paragraphs = text.replaceAll('\r\n', '\n').split('\n');
    final lines = <String>[];
    for (final paragraph in paragraphs) {
      if (paragraph.isEmpty) {
        lines.add('');
        continue;
      }
      final words = paragraph.split(RegExp(r'\s+'));
      var current = StringBuffer();
      for (final word in words) {
        if (word.isEmpty) continue;
        final candidate =
            current.isEmpty ? word : '${current.toString()} $word';
        if (font.measureString(candidate).width <= maxWidth) {
          current
            ..clear()
            ..write(candidate);
          continue;
        }
        if (current.isNotEmpty) {
          lines.add(current.toString());
          current.clear();
        }
        if (font.measureString(word).width <= maxWidth) {
          current.write(word);
        } else {
          lines.addAll(_breakToken(word, font, maxWidth));
        }
      }
      if (current.isNotEmpty) {
        lines.add(current.toString());
      }
    }
    return lines.isEmpty ? <String>[''] : lines;
  }

  static List<String> _breakToken(String token, PdfFont font, double maxWidth) {
    final out = <String>[];
    var buf = StringBuffer();
    for (final rune in token.runes) {
      final ch = String.fromCharCode(rune);
      final next = '${buf.toString()}$ch';
      if (buf.isNotEmpty && font.measureString(next).width > maxWidth) {
        out.add(buf.toString());
        buf = StringBuffer(ch);
      } else {
        buf.write(ch);
      }
    }
    if (buf.isNotEmpty) out.add(buf.toString());
    return out;
  }

  static double _nextSize(double size) {
    if (size <= minimumFontSize) return minimumFontSize - 1;
    final next = size - 0.25;
    return next < minimumFontSize ? minimumFontSize : next;
  }
}
