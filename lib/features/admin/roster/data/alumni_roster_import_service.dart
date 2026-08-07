import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:excel/excel.dart';
import 'package:xml/xml.dart';

import 'package:alumni_system/core/constants/course_constants.dart';
import 'package:alumni_system/features/admin/roster/data/alumni_member_service.dart';

class RosterImportRow {
  RosterImportRow({
    required this.rowNumber,
    required this.fullName,
    required this.course,
    required this.studentId,
  });

  final int rowNumber;
  final String fullName;
  final String course;
  final String studentId;
}

class RosterImportResult {
  RosterImportResult({
    this.imported = 0,
    this.skipped = 0,
    this.errors = const [],
  });

  int imported;
  int skipped;
  final List<String> errors;
}

class AlumniRosterImportService {
  AlumniRosterImportService({AlumniMemberService? memberService})
      : _memberService = memberService ?? AlumniMemberService();

  final AlumniMemberService _memberService;

  /// Parses roster rows from an `.xlsx` workbook (ZIP + XML).
  ///
  /// Uses a direct ZIP/XML reader so files from Excel, LibreOffice, WPS, etc.
  /// work even when relationship paths use a leading `/` (breaks `excel` 3.0).
  List<RosterImportRow> parseExcelBytes(List<int> bytes) =>
      parseRosterExcelBytes(bytes);

  static List<RosterImportRow> parseRosterExcelBytes(List<int> bytes) {
    if (bytes.length < 4 || bytes[0] != 0x50 || bytes[1] != 0x4B) {
      throw FormatException(
        'Not a valid .xlsx file. Save as Excel Workbook (.xlsx), not .xls or .csv.',
      );
    }

    try {
      return _parseXlsxArchive(bytes);
    } on FormatException {
      rethrow;
    } catch (e) {
      // Fallback for workbooks created by this app (relative worksheet paths).
      try {
        return _parseWithExcelPackage(bytes);
      } catch (_) {
        throw FormatException(
          'Could not read the Excel file. Use columns: Full Name, Course, ID Number. ($e)',
        );
      }
    }
  }

  static List<RosterImportRow> _parseWithExcelPackage(List<int> bytes) {
    final excel = Excel.decodeBytes(bytes);
    if (excel.tables.isEmpty) {
      throw FormatException('Excel file has no sheets.');
    }

    final sheet = excel.tables.values.first;
    if (sheet.maxRows == 0) {
      throw FormatException('Sheet is empty.');
    }

    int? nameCol;
    int? courseCol;
    int? idCol;
    int dataStartRow = 0;

    for (var r = 0; r < sheet.maxRows && r < 10; r++) {
      for (var c = 0; c < sheet.maxColumns; c++) {
        final text = _packageCellText(
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r)),
        ).toLowerCase();
        if (text.contains('full') && text.contains('name')) nameCol = c;
        if (text == 'name' || text == 'fullname') nameCol ??= c;
        if (text.contains('course') || text.contains('program')) courseCol = c;
        if (text.contains('id') &&
            (text.contains('number') || text.contains('no') || text == 'id')) {
          idCol = c;
        }
      }
      if (nameCol != null && courseCol != null && idCol != null) {
        dataStartRow = r + 1;
        break;
      }
    }

    if (nameCol == null || courseCol == null || idCol == null) {
      nameCol ??= 0;
      courseCol ??= 1;
      idCol ??= 2;
      dataStartRow = 1;
    }

    return _rowsFromGrid(
      _gridFromExcelSheet(sheet, nameCol, courseCol, idCol, dataStartRow),
    );
  }

  static List<List<String>> _gridFromExcelSheet(
    Sheet sheet,
    int nameCol,
    int courseCol,
    int idCol,
    int dataStartRow,
  ) {
    final grid = <List<String>>[];
    for (var r = dataStartRow; r < sheet.maxRows; r++) {
      grid.add([
        _packageCellText(
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: nameCol, rowIndex: r)),
        ),
        _packageCellText(
          sheet.cell(
            CellIndex.indexByColumnRow(columnIndex: courseCol, rowIndex: r),
          ),
        ),
        _packageCellText(
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: idCol, rowIndex: r)),
        ),
      ]);
    }
    return grid;
  }

  static String _packageCellText(Data cell) {
    final v = cell.value;
    if (v == null) return '';
    return v.toString().trim();
  }

  static List<RosterImportRow> _parseXlsxArchive(List<int> bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);
    final sheetPath = _resolveFirstWorksheetPath(archive);
    if (sheetPath == null) {
      throw FormatException('Excel file has no worksheet.');
    }

    final file = archive.findFile(sheetPath);
    if (file == null) {
      throw FormatException('Worksheet not found in file: $sheetPath');
    }

    file.decompress();
    final doc = XmlDocument.parse(utf8.decode(file.content));
    final sheetData = doc.findAllElements('sheetData').firstOrNull;
    if (sheetData == null) {
      throw FormatException('Worksheet has no data.');
    }

    final sharedStrings = _readSharedStrings(archive);
    final grid = _gridFromSheetData(sheetData, sharedStrings);
    if (grid.isEmpty) {
      throw FormatException('Sheet is empty.');
    }

    final header = _detectHeaderColumns(grid);
    return _rowsFromGrid(
      grid.sublist(header.dataStartIndex).map((row) {
        return [
          _cellAt(row, header.nameCol),
          _cellAt(row, header.courseCol),
          _cellAt(row, header.idCol),
        ];
      }).toList(),
      rowOffset: header.dataStartIndex + 1,
    );
  }

  static String? _resolveFirstWorksheetPath(Archive archive) {
    final rels = archive.findFile('xl/_rels/workbook.xml.rels');
    if (rels != null) {
      rels.decompress();
      final doc = XmlDocument.parse(utf8.decode(rels.content));
      for (final rel in doc.findAllElements('Relationship')) {
        final type = rel.getAttribute('Type') ?? '';
        if (!type.contains('worksheet')) continue;
        final target = rel.getAttribute('Target');
        if (target != null && target.isNotEmpty) {
          return _normalizeArchivePath(target);
        }
      }
    }
    if (archive.findFile('xl/worksheets/sheet1.xml') != null) {
      return 'xl/worksheets/sheet1.xml';
    }
    return null;
  }

  /// Normalizes OOXML targets like `/xl/worksheets/sheet1.xml` or `worksheets/sheet1.xml`.
  static String _normalizeArchivePath(String target) {
    var path = target.replaceAll('\\', '/');
    if (path.startsWith('/')) path = path.substring(1);
    if (!path.startsWith('xl/')) path = 'xl/$path';
    return path;
  }

  static List<String> _readSharedStrings(Archive archive) {
    final file = archive.findFile('xl/sharedStrings.xml');
    if (file == null) return [];

    file.decompress();
    final doc = XmlDocument.parse(utf8.decode(file.content));
    return doc.findAllElements('si').map((si) {
      return si.findAllElements('t').map((t) => t.innerText).join();
    }).toList();
  }

  static List<List<String>> _gridFromSheetData(
    XmlElement sheetData,
    List<String> sharedStrings,
  ) {
    final grid = <List<String>>[];

    for (final row in sheetData.findElements('row')) {
      final cells = row.findElements('c');
      if (cells.isEmpty) continue;

      var maxCol = -1;
      final values = <int, String>{};
      var sequentialCol = 0;

      for (final cell in cells) {
        final ref = cell.getAttribute('r');
        final col = ref != null ? _columnIndexFromCellRef(ref) : sequentialCol;
        if (col < 0) {
          sequentialCol++;
          continue;
        }
        values[col] = _xlsxCellText(cell, sharedStrings);
        if (col > maxCol) maxCol = col;
        if (ref == null) sequentialCol = col + 1;
      }

      if (maxCol < 0) continue;

      final rowValues = List<String>.filled(maxCol + 1, '');
      for (var c = 0; c <= maxCol; c++) {
        rowValues[c] = values[c] ?? '';
      }
      grid.add(rowValues);
    }

    return grid;
  }

  static String _xlsxCellText(XmlElement cell, List<String> sharedStrings) {
    final type = cell.getAttribute('t');
    switch (type) {
      case 'inlineStr':
        return cell.findAllElements('t').map((t) => t.innerText).join().trim();
      case 's':
        final v = cell.findElements('v').firstOrNull;
        if (v == null) return '';
        final idx = int.tryParse(v.innerText.trim()) ?? -1;
        if (idx >= 0 && idx < sharedStrings.length) {
          return sharedStrings[idx].trim();
        }
        return '';
      case 'b':
        final v = cell.findElements('v').firstOrNull;
        return v?.innerText.trim() == '1' ? 'TRUE' : 'FALSE';
      default:
        final v = cell.findElements('v').firstOrNull;
        return v?.innerText.trim() ?? '';
    }
  }

  static int _columnIndexFromCellRef(String ref) {
    final match = RegExp(r'^([A-Za-z]+)').firstMatch(ref);
    if (match == null) return -1;
    final letters = match.group(1)!.toUpperCase();
    var col = 0;
    for (var i = 0; i < letters.length; i++) {
      col = col * 26 + (letters.codeUnitAt(i) - 64);
    }
    return col - 1;
  }

  static ({int nameCol, int courseCol, int idCol, int dataStartIndex})
      _detectHeaderColumns(
    List<List<String>> grid,
  ) {
    int? nameCol;
    int? courseCol;
    int? idCol;
    var dataStartIndex = 0;

    for (var r = 0; r < grid.length && r < 10; r++) {
      final row = grid[r];
      for (var c = 0; c < row.length; c++) {
        final text = row[c].toLowerCase();
        if (text.contains('full') && text.contains('name')) nameCol = c;
        if (text == 'name' || text == 'fullname') nameCol ??= c;
        if (text.contains('course') || text.contains('program')) courseCol = c;
        if (text.contains('id') &&
            (text.contains('number') || text.contains('no') || text == 'id')) {
          idCol = c;
        }
      }
      if (nameCol != null && courseCol != null && idCol != null) {
        dataStartIndex = r + 1;
        break;
      }
    }

    return (
      nameCol: nameCol ?? 0,
      courseCol: courseCol ?? 1,
      idCol: idCol ?? 2,
      dataStartIndex: dataStartIndex == 0 &&
              nameCol == null &&
              courseCol == null &&
              idCol == null
          ? 1
          : dataStartIndex,
    );
  }

  static String _cellAt(List<String> row, int col) {
    if (col < 0 || col >= row.length) return '';
    return row[col].trim();
  }

  static List<RosterImportRow> _rowsFromGrid(
    List<List<String>> dataRows, {
    int rowOffset = 1,
  }) {
    final rows = <RosterImportRow>[];
    for (var i = 0; i < dataRows.length; i++) {
      final parts = dataRows[i];
      final name = parts.isNotEmpty ? parts[0] : '';
      final course = parts.length > 1 ? parts[1] : '';
      final id = parts.length > 2 ? parts[2] : '';

      if (name.isEmpty && course.isEmpty && id.isEmpty) continue;

      rows.add(
        RosterImportRow(
          rowNumber: rowOffset + i,
          fullName: name,
          course: course,
          studentId: id,
        ),
      );
    }
    return rows;
  }

  Future<RosterImportResult> importRows(List<RosterImportRow> rows) async {
    final result = RosterImportResult();
    final existingKeys = await _memberService.existingStudentCourseKeys();

    for (final row in rows) {
      final prog = CourseConstants.normalize(row.course);
      if (row.fullName.trim().isEmpty || row.studentId.trim().isEmpty) {
        result.errors.add('Row ${row.rowNumber}: missing name or ID number.');
        result.skipped++;
        continue;
      }
      if (prog == null || !CourseConstants.isValid(prog)) {
        result.errors.add(
          'Row ${row.rowNumber}: invalid course "${row.course}".',
        );
        result.skipped++;
        continue;
      }

      final normalizedSid = AlumniMemberService.normalizeStudentId(row.studentId);
      final key = AlumniMemberService.studentCourseKey(normalizedSid, prog);
      if (existingKeys.contains(key)) {
        result.skipped++;
        continue;
      }

      try {
        await _memberService.createMember(
          fullName: row.fullName,
          course: prog,
          studentId: row.studentId,
          skipDuplicateCheck: true,
        );
        existingKeys.add(key);
        result.imported++;
      } on AlumniMemberDuplicateException {
        existingKeys.add(key);
        result.skipped++;
      } catch (e) {
        result.errors.add('Row ${row.rowNumber}: $e');
        result.skipped++;
      }
    }

    return result;
  }
}
