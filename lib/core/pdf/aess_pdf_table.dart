import 'package:pdf/widgets.dart' as pw;
import 'package:alumni_system/core/pdf/aess_pdf_theme.dart';
import 'package:alumni_system/core/utils/pdf_safe_text.dart';

/// Professional institutional table builder with automatic proportional column
/// distribution, zebra striping, and header repetition across page splits.
abstract final class AessPdfTable {
  AessPdfTable._();

  /// Section heading with an institutional accent rule and optional badge.
  static pw.Widget sectionHeading(
    String title, {
    String? subtitle,
    String? countBadge,
  }) {
    final safeTitle = PdfSafeText.sanitize(title);
    final safeSubtitle =
        subtitle != null ? PdfSafeText.sanitize(subtitle) : null;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Text(
              safeTitle,
              style: AessPdfTheme.sectionHeading,
            ),
            if (countBadge != null)
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 5,
                  vertical: 2,
                ),
                decoration: const pw.BoxDecoration(
                  color: AessPdfTheme.bannerBg,
                  borderRadius: pw.BorderRadius.all(pw.Radius.circular(2)),
                ),
                child: pw.Text(
                  PdfSafeText.sanitize(countBadge),
                  style: pw.TextStyle(
                    fontSize: 7,
                    fontWeight: pw.FontWeight.bold,
                    color: AessPdfTheme.secondaryNavy,
                  ),
                ),
              ),
          ],
        ),
        if (safeSubtitle != null && safeSubtitle.isNotEmpty) ...[
          pw.SizedBox(height: 2),
          pw.Text(
            safeSubtitle,
            style: AessPdfTheme.reportSubtitle,
          ),
        ],
        pw.SizedBox(height: 3),
        pw.Divider(
          color: AessPdfTheme.borderDark,
          thickness: 0.7,
          height: 0.7,
        ),
        pw.SizedBox(height: 6),
      ],
    );
  }

  /// Distinct wave header card to visually demarcate separate survey instances.
  ///
  /// Solves the "repeated questions" confusion when multiple survey waves
  /// share the same CHED GTS questionnaire.
  static pw.Widget waveHeaderCard({
    required String waveTitle,
    int? submittedCount,
    double? completionRate,
  }) {
    final safeTitle = PdfSafeText.sanitize(waveTitle);
    final countText = submittedCount != null ? ' ($submittedCount submitted' : '';
    final rateText = completionRate != null
        ? ' | ${completionRate.toStringAsFixed(1)}% completion)'
        : (submittedCount != null ? ')' : '');

    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 8, bottom: 4),
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4.5),
      decoration: const pw.BoxDecoration(
        color: AessPdfTheme.bannerBg,
        border: pw.Border(
          left: pw.BorderSide(
            color: AessPdfTheme.primaryNavy,
            width: 3.0,
          ),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Survey Wave: $safeTitle$countText$rateText',
            style: pw.TextStyle(
              fontSize: 8.5,
              fontWeight: pw.FontWeight.bold,
              color: AessPdfTheme.primaryNavy,
            ),
          ),
        ],
      ),
    );
  }

  /// Standard institutional table matching university reporting standards.
  static pw.Widget build({
    required List<String> headers,
    required List<List<String>> rows,
    Map<int, pw.TableColumnWidth>? columnWidths,
    Map<int, pw.Alignment>? cellAlignments,
    bool isCompact = false,
  }) {
    if (rows.isEmpty) {
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 6),
        child: pw.Text(
          'No records found matching criteria.',
          style: AessPdfTheme.tableCellMuted,
        ),
      );
    }

    final safeHeaders = PdfSafeText.sanitizeRow(headers);
    final safeRows = PdfSafeText.sanitizeRows(rows);

    // Auto-detect numeric columns for right alignment if not explicitly provided
    final alignments = cellAlignments ?? _autoDetectAlignments(headers, safeRows);
    final widths = columnWidths ?? _autoDetectColumnWidths(headers, safeRows);

    return pw.TableHelper.fromTextArray(
      headers: safeHeaders,
      data: safeRows,
      headerCount: 1, // Repeat headers across page boundaries!
      headerStyle: AessPdfTheme.tableHeader,
      headerDecoration: const pw.BoxDecoration(
        color: AessPdfTheme.primaryNavy,
      ),
      headerAlignment: pw.Alignment.centerLeft,
      cellStyle: isCompact
          ? AessPdfTheme.tableCell.copyWith(fontSize: 7)
          : AessPdfTheme.tableCell,
      cellAlignment: pw.Alignment.centerLeft,
      cellAlignments: alignments,
      columnWidths: widths,
      cellPadding: isCompact
          ? AessPdfTheme.cellPaddingCompact
          : AessPdfTheme.cellPadding,
      oddRowDecoration: const pw.BoxDecoration(
        color: AessPdfTheme.zebraBg,
      ),
      border: const pw.TableBorder(
        horizontalInside: pw.BorderSide(
          color: AessPdfTheme.borderColor,
          width: 0.5,
        ),
        bottom: pw.BorderSide(
          color: AessPdfTheme.borderDark,
          width: 0.8,
        ),
      ),
    );
  }

  // —— Intelligent Column Profiles ——

  /// Dedicated column widths for Survey Question Summaries (7 columns).
  ///
  /// Question and detail keep most of the width; count headers use enough
  /// flex that labels like "Not answered" stay readable.
  static const Map<int, pw.TableColumnWidth> surveyQuestionColumnWidths = {
    0: pw.FlexColumnWidth(1.3), // Survey Wave
    1: pw.FlexColumnWidth(3.6), // Question Prompt
    2: pw.FlexColumnWidth(1.0), // Type
    3: pw.FlexColumnWidth(1.1), // Answered
    4: pw.FlexColumnWidth(1.0), // Total
    5: pw.FlexColumnWidth(1.4), // Not answered
    6: pw.FlexColumnWidth(4.2), // Detail / Choice Breakdown
  };

  /// Dedicated column widths for 5-column Survey Pack Question rows.
  static const Map<int, pw.TableColumnWidth> surveyPackQuestionColumnWidths = {
    0: pw.FlexColumnWidth(4.0), // Question Prompt
    1: pw.FlexColumnWidth(1.1), // Type
    2: pw.FlexColumnWidth(1.2), // Answered
    3: pw.FlexColumnWidth(1.1), // Skipped
    4: pw.FlexColumnWidth(5.0), // Detail
  };

  /// Dedicated column widths for Employment Records (9 columns).
  static const Map<int, pw.TableColumnWidth> employmentRecordColumnWidths = {
    0: pw.FlexColumnWidth(1.8), // Name
    1: pw.FlexColumnWidth(1.0), // Course
    2: pw.FlexColumnWidth(0.8), // Batch
    3: pw.FlexColumnWidth(1.3), // Status
    4: pw.FlexColumnWidth(1.1), // Type
    5: pw.FlexColumnWidth(2.2), // Position
    6: pw.FlexColumnWidth(2.2), // Industry
    7: pw.FlexColumnWidth(1.1), // Location
    8: pw.FlexColumnWidth(1.2), // Salary
  };

  /// Dedicated column widths for Survey Summary (7 columns).
  static const Map<int, pw.TableColumnWidth> surveySummaryColumnWidths = {
    0: pw.FlexColumnWidth(2.8), // Title
    1: pw.FlexColumnWidth(1.0), // Status
    2: pw.FlexColumnWidth(1.1), // Kind
    3: pw.FlexColumnWidth(1.1), // Assigned
    4: pw.FlexColumnWidth(1.1), // Submitted
    5: pw.FlexColumnWidth(1.0), // Rate %
    6: pw.FlexColumnWidth(2.2), // Target programs
  };

  /// Dedicated column widths for CHED 3-column outcomes (Option, Count, %).
  ///
  /// Allocates most width to the option prompt so choices stay readable.
  static const Map<int, pw.TableColumnWidth> chedOutcomesColumnWidths = {
    0: pw.FlexColumnWidth(5.5), // Option label
    1: pw.FlexColumnWidth(1.1), // Count (n)
    2: pw.FlexColumnWidth(1.0), // Percent (%)
  };

  /// Dedicated column widths for Pending Alumni list (6 columns).
  static const Map<int, pw.TableColumnWidth> pendingListColumnWidths = {
    0: pw.FlexColumnWidth(2.2), // Name
    1: pw.FlexColumnWidth(3.0), // Email
    2: pw.FlexColumnWidth(1.4), // Program
    3: pw.FlexColumnWidth(0.9), // Batch
    4: pw.FlexColumnWidth(1.3), // Status
    5: pw.FlexColumnWidth(1.1), // Reminders
  };

  /// Dedicated column widths for Alumni Roster (6 columns).
  static const Map<int, pw.TableColumnWidth> alumniRosterColumnWidths = {
    0: pw.FlexColumnWidth(2.2), // Name
    1: pw.FlexColumnWidth(2.8), // Email
    2: pw.FlexColumnWidth(1.1), // Course
    3: pw.FlexColumnWidth(0.9), // Batch
    4: pw.FlexColumnWidth(1.2), // Registered
    5: pw.FlexColumnWidth(1.2), // Tracer
  };

  // —— Heuristics ——

  static Map<int, pw.Alignment> _autoDetectAlignments(
    List<String> headers,
    List<List<String>> rows,
  ) {
    final alignments = <int, pw.Alignment>{};
    for (var i = 0; i < headers.length; i++) {
      final header = headers[i].toLowerCase();
      if (header.contains('%') ||
          header.contains('rate') ||
          header.contains('count') ||
          header.contains('answered') ||
          header.contains('total') ||
          header.contains('skipped') ||
          header.contains('reminders') ||
          header == 'value') {
        alignments[i] = pw.Alignment.centerRight;
      } else if (header == 'batch' ||
          header == 'status' ||
          header == 'type' ||
          header == 'kind') {
        alignments[i] = pw.Alignment.center;
      } else {
        alignments[i] = pw.Alignment.centerLeft;
      }
    }
    return alignments;
  }

  static Map<int, pw.TableColumnWidth> _autoDetectColumnWidths(
    List<String> headers,
    List<List<String>> rows,
  ) {
    final widths = <int, pw.TableColumnWidth>{};
    for (var i = 0; i < headers.length; i++) {
      final header = headers[i].toLowerCase();
      if (header.contains('question') || header.contains('prompt')) {
        widths[i] = const pw.FlexColumnWidth(3.5);
      } else if (header.contains('detail') || header.contains('description')) {
        widths[i] = const pw.FlexColumnWidth(4.0);
      } else if (header.contains('title') || header.contains('name')) {
        widths[i] = const pw.FlexColumnWidth(2.2);
      } else if (header.contains('email')) {
        widths[i] = const pw.FlexColumnWidth(2.5);
      } else if (header == 'batch' || header == 'year') {
        widths[i] = const pw.FlexColumnWidth(0.9);
      } else if (header.contains('not answered')) {
        widths[i] = const pw.FlexColumnWidth(1.4);
      } else if (header.contains('%') || header.contains('rate')) {
        widths[i] = const pw.FlexColumnWidth(1.0);
      } else if (header.contains('answered') ||
          header == 'total' ||
          header.contains('skipped') ||
          header == 'count' ||
          header.contains('reminders') ||
          header.contains('assigned') ||
          header.contains('submitted')) {
        widths[i] = const pw.FlexColumnWidth(1.1);
      } else {
        widths[i] = const pw.FlexColumnWidth(1.2);
      }
    }
    return widths;
  }
}

