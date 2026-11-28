import 'dart:math' as math;

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:alumni_system/core/utils/pdf_safe_text.dart';
import 'package:alumni_system/features/admin/reports/application/gts_report_chart.dart';
import 'package:alumni_system/features/admin/reports/models/gts_report_config.dart';

/// PDF drawing of [GtsChartData]. Vertical and horizontal bars match the
/// on-screen chart type; lines and donuts/pies use the pdf chart widgets.
abstract final class GtsReportPdfChart {
  /// Bar charts come back one bar row/column group per widget so a long chart
  /// can continue on the next page.
  static List<pw.Widget> build(GtsChartData data) {
    final pieOrDonut =
        data.type == GtsChartType.donut || data.type == GtsChartType.pie;
    final chart = switch (data.type) {
      GtsChartType.donut => _donut(data),
      GtsChartType.pie => _donut(data, pie: true),
      GtsChartType.line when data.labels.length > 1 => _line(data),
      GtsChartType.stackedBar => _stacked(data),
      GtsChartType.bar || GtsChartType.groupedBar => _verticalBars(data),
      _ => _bars(data),
    };
    final legendNames = pieOrDonut
        ? [
            for (var i = 0; i < data.labels.length; i++)
              '${data.labels[i]} (${data.format(data.series.first.values[i])})',
          ]
        : [for (final s in data.series) s.name];
    return [
      ...chart,
      if (data.series.length > 1 || pieOrDonut) ...[
        pw.SizedBox(height: 8),
        if (pieOrDonut)
          pw.Center(child: _legend(legendNames))
        else
          _legend(legendNames),
      ],
      if (data.hasHiddenValues)
        pw.Padding(
          padding: const pw.EdgeInsets.only(top: 4),
          child: pw.Text(
            'Groups with too few answers are left out of the chart '
            '("Not enough data").',
            style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
          ),
        ),
      if (data.omittedNote case final note?)
        pw.Padding(
          padding: const pw.EdgeInsets.only(top: 4),
          child: pw.Text(
            _safe(note),
            style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
          ),
        ),
    ];
  }

  static PdfColor _color(int i) => PdfColor.fromInt(gtsChartColor(i));

  static String _safe(String s) => PdfSafeText.sanitize(s);

  static double _max(GtsChartData data) => data.isPercent
      ? math.max(100, (data.maxValue / 10).ceil() * 10.0)
      : math.max(4, (data.maxValue / 4).ceil() * 4.0);

  static pw.Widget _legend(List<String> names) => pw.Wrap(
    spacing: 10,
    runSpacing: 3,
    children: [
      for (var i = 0; i < names.length; i++)
        pw.Row(
          mainAxisSize: pw.MainAxisSize.min,
          children: [
            pw.Container(width: 7, height: 7, color: _color(i)),
            pw.SizedBox(width: 3),
            pw.Text(_safe(names[i]), style: const pw.TextStyle(fontSize: 7)),
          ],
        ),
    ],
  );

  /// A bar of [fraction] (0-1) of the available width.
  static pw.Widget _bar(double fraction, PdfColor color, double height) {
    final f = (fraction.clamp(0.0, 1.0) * 1000).round();
    if (f == 0) return pw.SizedBox(height: height);
    return pw.Row(
      children: [
        pw.Expanded(
          flex: f,
          child: pw.Container(height: height, color: color),
        ),
        if (f < 1000) pw.Expanded(flex: 1000 - f, child: pw.SizedBox()),
      ],
    );
  }

  /// Horizontal bars (best for long category labels).
  static List<pw.Widget> _bars(GtsChartData data) {
    final max = _max(data);
    final single = data.series.length == 1;
    return [
      for (var i = 0; i < data.labels.length; i++)
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 2),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.SizedBox(
                width: 150,
                child: pw.Text(
                  _safe(data.labels[i]),
                  style: const pw.TextStyle(fontSize: 8),
                ),
              ),
              pw.SizedBox(width: 6),
              pw.Expanded(
                child: pw.Column(
                  children: [
                    for (var s = 0; s < data.series.length; s++)
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 0.5),
                        child: pw.Row(
                          children: [
                            pw.Expanded(
                              child: _bar(
                                (data.series[s].values[i] ?? 0) / max,
                                single ? _color(0) : _color(s),
                                single ? 9 : 6,
                              ),
                            ),
                            pw.SizedBox(
                              width: 58,
                              child: pw.Text(
                                _safe(data.format(data.series[s].values[i])),
                                textAlign: pw.TextAlign.right,
                                style: const pw.TextStyle(fontSize: 7),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
    ];
  }

  /// Vertical column bars matching on-screen [GtsChartType.bar].
  static List<pw.Widget> _verticalBars(GtsChartData data) {
    final max = _max(data);
    const chartHeight = 200.0;
    final single = data.series.length == 1;
    final barWidth = single
        ? 28.0
        : math.max(6.0, 28.0 / data.series.length);

    return [
      pw.SizedBox(
        height: chartHeight + 48,
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            for (var i = 0; i < data.labels.length; i++)
              pw.Expanded(
                child: pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 3),
                  child: pw.Column(
                    mainAxisAlignment: pw.MainAxisAlignment.end,
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.center,
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          for (var s = 0; s < data.series.length; s++) ...[
                            if (s > 0) pw.SizedBox(width: 2),
                            pw.Column(
                              mainAxisSize: pw.MainAxisSize.min,
                              children: [
                                pw.Text(
                                  _safe(
                                    data.format(data.series[s].values[i]),
                                  ),
                                  style: const pw.TextStyle(fontSize: 6.5),
                                  textAlign: pw.TextAlign.center,
                                ),
                                pw.SizedBox(height: 2),
                                pw.Container(
                                  width: barWidth,
                                  height: math.max(
                                    2,
                                    ((data.series[s].values[i] ?? 0) / max) *
                                        chartHeight,
                                  ),
                                  color: single ? _color(i) : _color(s),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                      pw.SizedBox(height: 6),
                      pw.Text(
                        _safe(data.labels[i]),
                        style: const pw.TextStyle(fontSize: 7),
                        textAlign: pw.TextAlign.center,
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    ];
  }

  static List<pw.Widget> _stacked(GtsChartData data) {
    double sum(int i) =>
        data.series.fold<double>(0, (s, x) => s + (x.values[i] ?? 0));
    final widest = [
      for (var i = 0; i < data.labels.length; i++) sum(i),
    ].fold<double>(data.isPercent ? 100 : 1, math.max);
    return [
      for (var i = 0; i < data.labels.length; i++)
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 2),
          child: pw.Row(
            children: [
              pw.SizedBox(
                width: 150,
                child: pw.Text(
                  _safe(data.labels[i]),
                  style: const pw.TextStyle(fontSize: 8),
                ),
              ),
              pw.SizedBox(width: 6),
              pw.Expanded(
                child: sum(i) == 0
                    ? pw.Text(
                        'Not enough data',
                        style: const pw.TextStyle(
                          fontSize: 7,
                          color: PdfColors.grey600,
                        ),
                      )
                    : pw.Row(
                        children: [
                          for (var s = 0; s < data.series.length; s++)
                            if ((data.series[s].values[i] ?? 0) > 0)
                              pw.Expanded(
                                flex: (data.series[s].values[i]! * 10)
                                    .round()
                                    .clamp(1, 1 << 30),
                                child: pw.Container(
                                  height: 10,
                                  color: _color(s),
                                ),
                              ),
                          if (widest - sum(i) > 0.05)
                            pw.Expanded(
                              flex: ((widest - sum(i)) * 10).round().clamp(
                                1,
                                1 << 30,
                              ),
                              child: pw.SizedBox(),
                            ),
                        ],
                      ),
              ),
            ],
          ),
        ),
    ];
  }

  static List<pw.Widget> _line(GtsChartData data) {
    final max = _max(data);
    final ticks = [for (var i = 0; i <= 4; i++) max * i / 4];
    final datasets = <pw.Dataset>[
      for (var s = 0; s < data.series.length; s++)
        if (data.series[s].values.any((v) => v != null))
          pw.LineDataSet(
            legend: _safe(data.series[s].name),
            color: _color(s),
            pointSize: 2,
            lineWidth: 1.5,
            data: [
              for (var i = 0; i < data.labels.length; i++)
                if (data.series[s].values[i] case final v?)
                  pw.PointChartValue(i.toDouble(), v),
            ],
          ),
    ];
    if (datasets.isEmpty) return _bars(data);
    return [
      pw.SizedBox(
        height: 200,
        child: pw.Chart(
          grid: pw.CartesianGrid(
            xAxis: pw.FixedAxis.fromStrings(
              [for (final l in data.labels) _safe(l)],
              marginStart: 20,
              marginEnd: 20,
              ticks: true,
              textStyle: const pw.TextStyle(fontSize: 7),
            ),
            yAxis: pw.FixedAxis(
              ticks,
              format: (v) => data.isPercent ? '${v.round()}%' : '${v.round()}',
              divisions: true,
              divisionsColor: PdfColors.grey300,
              textStyle: const pw.TextStyle(fontSize: 7),
            ),
          ),
          datasets: datasets,
        ),
      ),
    ];
  }

  static List<pw.Widget> _donut(GtsChartData data, {bool pie = false}) {
    final values = data.series.first.values;
    final total = values.fold<double>(0, (s, v) => s + (v ?? 0));
    const size = 220.0;
    final datasets = <pw.Dataset>[
      for (var i = 0; i < values.length; i++)
        if ((values[i] ?? 0) > 0)
          pw.PieDataSet(
            value: values[i]!,
            color: _color(i),
            innerRadius: pie ? 0 : 48,
            // Slice label (percent), matching the on-screen preview.
            legend: total == 0 || values[i]! / total < 0.06
                ? null
                : _safe(data.format(values[i])),
            legendPosition: total == 0 || values[i]! / total < 0.06
                ? pw.PieLegendPosition.none
                : pw.PieLegendPosition.inside,
            legendStyle: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: i == 3 || i == 5 ? PdfColors.grey800 : PdfColors.white,
            ),
            legendAlign: pw.TextAlign.center,
          ),
    ];
    if (datasets.isEmpty) return _bars(data);
    return [
      pw.Center(
        child: pw.SizedBox(
          height: size,
          width: size,
          child: pw.Chart(grid: pw.PieGrid(), datasets: datasets),
        ),
      ),
    ];
  }
}
