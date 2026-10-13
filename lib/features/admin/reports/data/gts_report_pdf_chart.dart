import 'dart:math' as math;

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:alumni_system/core/utils/pdf_safe_text.dart';
import 'package:alumni_system/features/admin/reports/application/gts_report_chart.dart';
import 'package:alumni_system/features/admin/reports/models/gts_report_config.dart';

/// PDF drawing of [GtsChartData]. Bars are drawn horizontally so long CHED
/// answers stay readable on paper; lines and donuts use the pdf charts.
abstract final class GtsReportPdfChart {
  /// Bar charts come back one bar row per widget, so a long chart can
  /// continue on the next page.
  static List<pw.Widget> build(GtsChartData data) {
    final chart = switch (data.type) {
      GtsChartType.donut => _donut(data),
      GtsChartType.line when data.labels.length > 1 => _line(data),
      GtsChartType.stackedBar => _stacked(data),
      _ => _bars(data),
    };
    final legendNames = data.type == GtsChartType.donut
        ? [
            for (var i = 0; i < data.labels.length; i++)
              '${data.labels[i]} (${data.format(data.series.first.values[i])})',
          ]
        : [for (final s in data.series) s.name];
    return [
      ...chart,
      if (data.series.length > 1 || data.type == GtsChartType.donut) ...[
        pw.SizedBox(height: 6),
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
      ? math.min(100, math.max(10, (data.maxValue / 10).ceil() * 10.0))
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

  static List<pw.Widget> _donut(GtsChartData data) {
    final values = data.series.first.values;
    final datasets = <pw.Dataset>[
      for (var i = 0; i < values.length; i++)
        if ((values[i] ?? 0) > 0)
          pw.PieDataSet(
            value: values[i]!,
            color: _color(i),
            innerRadius: 35,
            legendPosition: pw.PieLegendPosition.none,
          ),
    ];
    if (datasets.isEmpty) return _bars(data);
    return [
      pw.SizedBox(
        height: 160,
        width: 160,
        child: pw.Chart(grid: pw.PieGrid(), datasets: datasets),
      ),
    ];
  }
}
