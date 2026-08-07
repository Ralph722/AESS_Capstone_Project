import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:alumni_system/features/admin/ched_gts_pdf_export/ched_gts_pdf_export.dart';
import 'package:alumni_system/features/admin/roster/models/alumni_member_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ChedGtsPdfBatchExportService.uniqueEntryName', () {
    test('dedupes colliding PDF names', () {
      final used = <String>{};
      expect(
        ChedGtsPdfBatchExportService.uniqueEntryName('GTS-Jane.pdf', used),
        'GTS-Jane.pdf',
      );
      expect(
        ChedGtsPdfBatchExportService.uniqueEntryName('GTS-Jane.pdf', used),
        'GTS-Jane-2.pdf',
      );
      expect(
        ChedGtsPdfBatchExportService.uniqueEntryName('GTS-Jane.pdf', used),
        'GTS-Jane-3.pdf',
      );
    });
  });

  group('ZIP packaging', () {
    test('ZipEncoder packs multiple PDF-like entries', () {
      final archive = Archive();
      final a = Uint8List.fromList([1, 2, 3, 4]);
      final b = Uint8List.fromList([5, 6, 7, 8, 9]);
      archive.addFile(ArchiveFile('one.pdf', a.length, a));
      archive.addFile(ArchiveFile('two.pdf', b.length, b));

      final encoded = ZipEncoder().encode(archive);
      expect(encoded, isNotNull);
      expect(encoded!.length, greaterThan(20));

      final decoded = ZipDecoder().decodeBytes(encoded);
      expect(decoded.files.map((f) => f.name), containsAll(['one.pdf', 'two.pdf']));
      expect(decoded.findFile('one.pdf')!.content as List<int>, a);
      expect(decoded.findFile('two.pdf')!.content as List<int>, b);
    });
  });

  group('ChedGtsPdfBatchExportService.buildZip caps', () {
    test('rejects selections above maxBatchSize before fill', () async {
      final members = List.generate(
        ChedGtsPdfExportLimits.maxBatchSize + 1,
        (i) => AlumniMember(
          id: 'm$i',
          fullName: 'Person $i',
          course: 'BSIT',
          studentId: 'S$i',
          batchYear: '2024',
          isRegisteredUser: true,
          authUid: 'u$i',
        ),
      );

      expect(
        () => ChedGtsPdfBatchExportService.ensureWithinBatchLimit(members.length),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('${ChedGtsPdfExportLimits.maxBatchSize}'),
          ),
        ),
      );

      await expectLater(
        ChedGtsPdfBatchExportService().buildZip(members: members),
        throwsA(isA<StateError>()),
      );
    });
  });
}
