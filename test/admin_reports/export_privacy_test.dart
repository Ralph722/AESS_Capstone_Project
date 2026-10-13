import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:alumni_system/core/utils/csv_safe.dart';
import 'package:alumni_system/features/admin/reports/data/custom_report_export_service.dart';
import 'package:alumni_system/features/admin/reports/models/custom_report_template.dart';
import 'package:alumni_system/shared/widgets/personal_data_export_dialog.dart';

CustomReportDocument _doc(CustomReportSectionId id, List<List<String>> rows) =>
    CustomReportDocument(
      title: 'Test',
      generatedAt: DateTime(2026, 10, 12),
      sections: [
        CustomReportSectionData(
          id: id,
          title: 'Section',
          headers: const ['Name', 'Note'],
          rows: rows,
        ),
      ],
    );

void main() {
  group('CsvSafe.cell', () {
    test('prefixes text that a spreadsheet would run as a formula', () {
      expect(CsvSafe.cell('=HYPERLINK("x")'), '"\'=HYPERLINK(""x"")"');
      expect(CsvSafe.cell('+cmd'), "'+cmd");
      expect(CsvSafe.cell('-cmd'), "'-cmd");
      expect(CsvSafe.cell('@SUM(A1)'), "'@SUM(A1)");
      expect(CsvSafe.cell('\tx'), "'\tx");
    });

    test('leaves numbers and ordinary text unchanged', () {
      expect(CsvSafe.cell('-0.05'), '-0.05');
      expect(CsvSafe.cell('+5'), '+5');
      expect(CsvSafe.cell('42'), '42');
      expect(CsvSafe.cell('-'), '-');
      expect(CsvSafe.cell('--'), '--');
      expect(CsvSafe.cell('Maria Santos'), 'Maria Santos');
      expect(CsvSafe.cell(''), '');
    });

    test('quotes commas, quotes and line breaks', () {
      expect(CsvSafe.cell('a,b'), '"a,b"');
      expect(CsvSafe.cell('say "hi"'), '"say ""hi"""');
      expect(CsvSafe.cell('line\nbreak'), '"line\nbreak"');
    });
  });

  group('Custom report exports', () {
    final doc = _doc(CustomReportSectionId.alumniRoster, [
      ['=1+1', '@evil'],
    ]);

    test('CSV guards formula-like cells', () {
      final csv = CustomReportExportService.toCsv(doc);
      expect(csv, contains("'=1+1,'@evil"));
      expect(csv, isNot(contains('\n=1+1')));
    });

    test('Excel keeps formula-like text as plain text', () {
      final book = Excel.decodeBytes(CustomReportExportService.toExcel(doc));
      final cells = [
        for (final sheet in book.tables.values)
          for (final row in sheet.rows)
            for (final c in row)
              if (c != null) c.value,
      ];
      expect(cells.whereType<Formula>(), isEmpty);
      expect(cells.map((v) => v.toString()), contains('=1+1'));
    });
  });

  group('Personal data', () {
    test('only roster and employment sections count as personal', () {
      expect(CustomReportExportService.personalSections, {
        CustomReportSectionId.alumniRoster,
        CustomReportSectionId.employmentRecords,
      });
    });

    test('a document is personal only when a personal section has rows', () {
      expect(
        _doc(CustomReportSectionId.alumniRoster, [
          ['Maria', ''],
        ]).containsPersonalData,
        isTrue,
      );
      expect(
        _doc(CustomReportSectionId.employmentRecords, [
          ['Maria', ''],
        ]).containsPersonalData,
        isTrue,
      );
      expect(
        _doc(CustomReportSectionId.alumniRoster, []).containsPersonalData,
        isFalse,
      );
      expect(
        _doc(CustomReportSectionId.executiveKpis, [
          ['Total', '10'],
        ]).containsPersonalData,
        isFalse,
      );
    });

    test('PDF with personal data renders', () async {
      final bytes = await CustomReportExportService.toPdf(
        _doc(CustomReportSectionId.alumniRoster, [
          ['Maria', ''],
        ]),
      );
      expect(bytes, isNotEmpty);
    });

    Future<bool? Function()> openConfirm(WidgetTester tester) async {
      bool? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async => result = await confirmPersonalDataExport(
                context,
                what: 'The roster',
              ),
              child: const Text('Export'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Export'));
      await tester.pumpAndSettle();
      expect(find.text('This file contains personal data'), findsOneWidget);
      expect(find.textContaining('RA 10173'), findsOneWidget);
      return () => result;
    }

    testWidgets('confirmation returns true on Download', (tester) async {
      final result = await openConfirm(tester);
      await tester.tap(find.text('Download'));
      await tester.pumpAndSettle();
      expect(result(), isTrue);
    });

    testWidgets('confirmation returns false on Cancel', (tester) async {
      final result = await openConfirm(tester);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(result(), isFalse);
    });
  });
}
