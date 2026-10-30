import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:alumni_system/core/pdf/aess_pdf_theme.dart';
import 'package:alumni_system/core/utils/pdf_safe_text.dart';

/// One KPI metric item.
class AessKpiItem {
  const AessKpiItem({
    required this.label,
    required this.value,
    this.isHighlight = false,
  });

  final String label;
  final String value;
  final bool isHighlight;
}

/// Executive KPI dashboard grid and metric cards for AESS PDF reports.
abstract final class AessPdfKpiGrid {
  AessPdfKpiGrid._();

  /// Builds a responsive grid of metric cards.
  static pw.Widget build({
    required List<AessKpiItem> items,
    int columns = 4,
    double spacing = 6,
  }) {
    if (items.isEmpty) return pw.SizedBox();

    final rows = <pw.Widget>[];
    for (var i = 0; i < items.length; i += columns) {
      final chunk = items.sublist(
        i,
        i + columns > items.length ? items.length : i + columns,
      );

      final rowChildren = <pw.Widget>[];
      for (var c = 0; c < columns; c++) {
        if (c < chunk.length) {
          rowChildren.add(
            pw.Expanded(
              child: _buildCard(chunk[c]),
            ),
          );
        } else {
          // Empty placeholder to keep column widths even
          rowChildren.add(
            pw.Expanded(
              child: pw.SizedBox(),
            ),
          );
        }

        if (c < columns - 1) {
          rowChildren.add(pw.SizedBox(width: spacing));
        }
      }

      rows.add(
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: rowChildren,
        ),
      );

      if (i + columns < items.length) {
        rows.add(pw.SizedBox(height: spacing));
      }
    }

    return pw.Column(children: rows);
  }

  static pw.Widget _buildCard(AessKpiItem item) {
    final safeValue = PdfSafeText.sanitize(item.value);
    final safeLabel = PdfSafeText.sanitize(item.label);

    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 6),
      decoration: pw.BoxDecoration(
        color: item.isHighlight
            ? const PdfColor.fromInt(0xFFEFF6FF)
            : AessPdfTheme.cardBg,
        border: pw.Border.all(
          color: item.isHighlight
              ? AessPdfTheme.slateBlue
              : AessPdfTheme.borderColor,
          width: 0.6,
        ),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.Text(
            safeValue,
            style: item.isHighlight
                ? pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: AessPdfTheme.primaryNavy,
                  )
                : AessPdfTheme.kpiValue,
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            safeLabel,
            maxLines: 2,
            style: AessPdfTheme.kpiLabel,
          ),
        ],
      ),
    );
  }

  /// Compact 2-column or 3-column key-value summary table.
  static pw.Widget buildKeyValueTable({
    required List<(String, String)> pairs,
    double labelWidth = 180,
  }) {
    return pw.Table(
      border: pw.TableBorder(
        horizontalInside: pw.BorderSide(
          color: AessPdfTheme.borderColor,
          width: 0.5,
        ),
        bottom: pw.BorderSide(
          color: AessPdfTheme.borderColor,
          width: 0.5,
        ),
      ),
      columnWidths: {
        0: pw.FixedColumnWidth(labelWidth),
        1: const pw.FlexColumnWidth(),
      },
      children: [
        for (var i = 0; i < pairs.length; i++)
          pw.TableRow(
            decoration: pw.BoxDecoration(
              color: i.isOdd ? AessPdfTheme.zebraBg : PdfColors.white,
            ),
            children: [
              pw.Padding(
                padding: AessPdfTheme.cellPadding,
                child: pw.Text(
                  PdfSafeText.sanitize(pairs[i].$1),
                  style: AessPdfTheme.tableCellBold,
                ),
              ),
              pw.Padding(
                padding: AessPdfTheme.cellPadding,
                child: pw.Text(
                  PdfSafeText.sanitize(pairs[i].$2),
                  style: AessPdfTheme.tableCell,
                ),
              ),
            ],
          ),
      ],
    );
  }
}

