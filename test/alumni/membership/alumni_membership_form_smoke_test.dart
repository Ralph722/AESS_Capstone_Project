import 'package:alumni_system/core/services/audit_events.dart';
import 'package:alumni_system/features/admin/ched_gts_pdf_export/ched_gts_answer_assembler.dart';
import 'package:alumni_system/features/admin/ched_gts_pdf_export/individual_info_sheet_pdf.dart';
import 'package:alumni_system/features/alumni/tracer/models/tracer_profile_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('audit action is distinct from admin export', () {
    expect(AuditActions.downloadMembershipForm, 'DOWNLOAD_MEMBERSHIP_FORM');
    expect(
      AuditActions.downloadMembershipForm,
      isNot(AuditActions.exportIndividualInfoPdf),
    );
  });

  test('live-profile assemble + Membership Form PDF is non-empty', () async {
    final profile = TracerProfile(
      uid: 'user-1',
      email: 'alex@example.com',
      displayName: 'Alex Rivera',
      studentId: '2024001',
      program: 'BSIT',
      batchYear: '2024',
      yearGraduated: '2024',
      gender: 'Male',
      mobileNumber: '09170001111',
      province: 'Misamis Occidental',
      collegeUniversity: 'USTP Oroquieta',
    );

    final assembled = ChedGtsAnswerAssembler.assemble(
      profile: profile,
      fillGapsFromProfile: true,
    );

    expect(assembled.source, ChedGtsAnswerSource.liveProfileFallback);
    expect(assembled.hasAnswers, isTrue);

    final bytes = await IndividualInfoSheetPdf.build(
      answers: assembled.answers,
      alumniName: profile.displayName,
      generatedAt: DateTime(2026, 11, 14),
    );

    expect(bytes.length, greaterThan(1000));
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });
}
