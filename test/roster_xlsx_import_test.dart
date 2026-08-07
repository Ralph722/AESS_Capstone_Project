import 'dart:io';

import 'package:alumni_system/features/admin/roster/data/alumni_roster_import_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parse fake_students.xlsx with inline strings', () {
    final path = r'c:\Users\Acer Laptop\Downloads\fake_students.xlsx';
    if (!File(path).existsSync()) {
      return;
    }

    final bytes = File(path).readAsBytesSync();
    final rows = AlumniRosterImportService.parseRosterExcelBytes(bytes);

    expect(rows.length, greaterThan(0));
    expect(rows.first.fullName, isNotEmpty);
    expect(rows.first.course, isNotEmpty);
    expect(rows.first.studentId, isNotEmpty);

    final names = rows.map((r) => r.fullName).toList();
    expect(names, contains('Alyssa Mae Santos'));
  });
}
