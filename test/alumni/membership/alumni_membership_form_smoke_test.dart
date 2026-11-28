import 'package:alumni_system/core/services/audit_events.dart';
import 'package:alumni_system/features/admin/ched_gts_pdf_export/ched_gts_answer_assembler.dart';
import 'package:alumni_system/features/admin/ched_gts_pdf_export/individual_info_sheet_pdf.dart';
import 'package:alumni_system/features/alumni/membership/data/alumni_membership_form_service.dart';
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

  group('Profile re-download window', () {
    final downloaded = DateTime.utc(2026, 11, 1, 12);

    test('hidden when never downloaded', () {
      expect(
        AlumniMembershipFormService.isProfileDownloadAvailable(null),
        isFalse,
      );
      expect(AlumniMembershipFormService.profileDaysRemaining(null), 0);
    });

    test('available within 30 days', () {
      final now = downloaded.add(const Duration(days: 10));
      expect(
        AlumniMembershipFormService.isProfileDownloadAvailable(
          downloaded,
          now: now,
        ),
        isTrue,
      );
      expect(
        AlumniMembershipFormService.profileDaysRemaining(downloaded, now: now),
        20,
      );
    });

    test('still available on the last day', () {
      final now = downloaded.add(const Duration(days: 29, hours: 23));
      expect(
        AlumniMembershipFormService.isProfileDownloadAvailable(
          downloaded,
          now: now,
        ),
        isTrue,
      );
      expect(
        AlumniMembershipFormService.profileDaysRemaining(downloaded, now: now),
        1,
      );
    });

    test('hidden after the window ends', () {
      final now = downloaded.add(const Duration(days: 30, seconds: 1));
      expect(
        AlumniMembershipFormService.isProfileDownloadAvailable(
          downloaded,
          now: now,
        ),
        isFalse,
      );
      expect(
        AlumniMembershipFormService.profileDaysRemaining(downloaded, now: now),
        0,
      );
    });
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
