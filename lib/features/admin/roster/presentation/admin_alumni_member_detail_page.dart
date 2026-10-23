import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:alumni_system/features/admin/roster/models/alumni_member_model.dart';
import 'package:alumni_system/core/constants/gts_constants.dart';
import 'package:alumni_system/core/utils/export_platform.dart';
import 'package:alumni_system/features/admin/ched_gts_pdf_export/ched_gts_pdf_export.dart';
import 'package:alumni_system/features/surveys/data/survey_service.dart';
import 'package:alumni_system/features/surveys/models/survey_model.dart';
import 'package:alumni_system/features/surveys/ched_gts/ched_gts_form.dart';
import 'package:alumni_system/features/admin/roster/widgets/alumni_directory_ui.dart';
import 'package:alumni_system/shared/widgets/admin/admin_buttons.dart';
import 'package:alumni_system/shared/widgets/admin/admin_confirm_dialog.dart';
import 'package:alumni_system/shared/widgets/admin/admin_state_view.dart';
import 'package:alumni_system/shared/widgets/admin/admin_surface.dart';
import 'package:alumni_system/shared/widgets/admin/admin_tab_bar.dart';
import 'package:alumni_system/shared/widgets/admin/admin_theme.dart';
import 'package:alumni_system/features/admin/roster/data/alumni_directory_detail_service.dart';
import 'package:alumni_system/features/admin/activity/models/audit_log_model.dart';

/// Inline admin panel: demographics, employment, and activity for one member.
class AdminAlumniMemberDetailPanel extends StatefulWidget {
  const AdminAlumniMemberDetailPanel({
    super.key,
    required this.member,
    required this.onClose,
    required this.onMemberUpdated,
  });

  final AlumniMember member;
  final VoidCallback onClose;
  final ValueChanged<AlumniMember> onMemberUpdated;

  @override
  State<AdminAlumniMemberDetailPanel> createState() =>
      _AdminAlumniMemberDetailPanelState();
}

class _AdminAlumniMemberDetailPanelState
    extends State<AdminAlumniMemberDetailPanel>
    with SingleTickerProviderStateMixin {
  final _detailService = AlumniDirectoryDetailService();
  final _surveyService = SurveyService();
  final _chedPdfExport = ChedGtsPdfPersonExportService();
  late TabController _tabs;
  late AlumniMember _member;

  AlumniDirectoryDetail? _detail;
  bool _loading = false;
  bool _exportingChedPdf = false;
  String? _error;
  final Map<String, Future<Survey?>> _surveyFutures = {};
  final Map<String, Future<List<SurveyQuestion>>> _questionsFutures = {};
  static final _submittedFormat = DateFormat.yMMMd().add_jm();

  /// Row cap of `AuditService.getRelatedAuditLogs`.
  static const _activityLogLimit = 100;

  /// Below this header width the export button shows its icon only.
  static const _compactHeaderWidth = 700.0;

  // CHED accent, shared with the Surveys and Reports screens.
  static const _chedAccent = Color(0xFFC2410C);
  static const _chedBorder = Color(0xFFFDBA74);
  static const _chedTint = Color(0xFFFFF7ED);

  @override
  void initState() {
    super.initState();
    _member = widget.member;
    _tabs = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void didUpdateWidget(covariant AdminAlumniMemberDetailPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.member.id != widget.member.id) {
      _member = widget.member;
      _detail = null;
      _error = null;
      _surveyFutures.clear();
      _questionsFutures.clear();
      _load();
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final detail = await _detailService.loadDetail(_member);
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _member = detail.roster;
        _loading = false;
      });

      // Defer write-on-read so the panel paints before the view is recorded.
      // Viewing no longer clears the profile-update flag.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _recordViewed(detail.roster);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _recordViewed(AlumniMember roster) async {
    try {
      final viewed = await _detailService.recordAdminViewed(roster);
      if (!mounted) return;
      final updated = viewed.copyWith(
        tracerProfileComplete: roster.tracerProfileComplete,
      );
      setState(() => _member = updated);
      widget.onMemberUpdated(updated);
    } catch (_) {}
  }

  bool _markingReviewed = false;

  Future<void> _markReviewed() async {
    if (_markingReviewed) return;
    setState(() => _markingReviewed = true);
    try {
      final reviewed = await _detailService.markProfileReviewed(_member);
      if (!mounted) return;
      final updated = reviewed.copyWith(
        tracerProfileComplete: _member.tracerProfileComplete,
      );
      setState(() {
        _member = updated;
        _markingReviewed = false;
      });
      widget.onMemberUpdated(updated);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updates marked as reviewed')),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _markingReviewed = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not mark as reviewed. Try again.'),
        ),
      );
    }
  }

  /// Profile fields touched by the latest unreviewed change, used for the
  /// "changed" markers in Profile info. Empty once reviewed.
  Set<String> get _unreviewedChangedFields {
    if (!_member.hasProfileUpdates) return const {};
    final logs = _detail?.activityLogs ?? const <AuditLog>[];
    final keys = <String>{};
    DateTime? latestProfileUpdateAt;
    for (final log in logs) {
      if (log.action != 'PROFILE_UPDATE') continue;
      final fields = log.changes?['fields'];
      if (fields is Map) {
        keys.addAll(fields.keys.map((k) => k.toString()));
      }
      latestProfileUpdateAt = log.timestamp;
      break;
    }
    for (final log in logs) {
      if (log.action != 'NAME_CHANGE') continue;
      if (latestProfileUpdateAt == null ||
          !log.timestamp.isBefore(latestProfileUpdateAt)) {
        keys.add('displayName');
      }
      break;
    }
    return keys;
  }

  Future<Survey?> _cachedSurvey(String surveyId) {
    return _surveyFutures.putIfAbsent(
      surveyId,
      () => _surveyService.getSurvey(surveyId),
    );
  }

  Future<List<SurveyQuestion>> _cachedQuestions(String surveyId) {
    return _questionsFutures.putIfAbsent(
      surveyId,
      () => _surveyService.getQuestions(surveyId),
    );
  }

  void _retryQuestions(String surveyId) {
    setState(() => _questionsFutures.remove(surveyId));
  }

  double? get _tracerCompletion => _detail?.tracer?.completionPercent;

  List<SurveyResponseWithMeta> get _chedWaves =>
      ChedGtsPdfPersonExportService.chedWaves(_detail?.tracerResponses ?? []);

  /// Export controls are shown for linked, registered members once loaded;
  /// they stay visible (disabled) during a refresh.
  bool get _canShowChedPdfExport =>
      _error == null &&
      _detail != null &&
      _member.isRegisteredUser &&
      (_member.authUid?.isNotEmpty ?? false);

  bool get _canOfferChedPdfExport => _canShowChedPdfExport && !_loading;

  Future<void> _onExportChedGtsPdfPressed({String? surveyId}) async {
    if (!_canOfferChedPdfExport || _exportingChedPdf) return;
    if (!requireWebExport(context)) return;

    final waves = _chedWaves;
    String? chosenSurveyId = surveyId;

    if (chosenSurveyId == null) {
      if (waves.length >= 2) {
        final picked = await showAdminOptionPicker<String>(
          context: context,
          title: 'Choose CHED GTS wave',
          options: [
            for (final wave in waves)
              AdminPickerOption(
                value: wave.response.surveyId,
                label: _chedWaveLabel(wave),
                icon: Icons.picture_as_pdf_outlined,
              ),
            AdminPickerOption(
              value: '__live__',
              label: 'Live profile only (no survey snapshot)',
              icon: Icons.person_outline,
            ),
          ],
        );
        if (picked == null || !mounted) return;
        if (picked == '__live__') {
          await _runChedPdfExport(surveyId: null, forceLiveOnly: true);
          return;
        }
        chosenSurveyId = picked;
      } else if (waves.length == 1) {
        chosenSurveyId = waves.first.response.surveyId;
      } else {
        final proceed = await showAdminConfirmDialog(
          context,
          title: 'No CHED submission',
          message:
              'This alumni has no submitted CHED GTS response yet. '
              'Export using their live profile and employment data instead?',
          confirmLabel: 'Export live profile',
          icon: Icons.picture_as_pdf_outlined,
        );
        if (!proceed || !mounted) return;
      }
    }

    await _runChedPdfExport(surveyId: chosenSurveyId);
  }

  /// Ask Fillable vs Print-Ready; returns null if cancelled.
  Future<bool?> _pickChedPdfExportMode() {
    return showAdminOptionPicker<bool>(
      context: context,
      title: 'Export CHED GTS PDF',
      options: const [
        AdminPickerOption(
          value: true,
          label: 'Print-Ready PDF',
          icon: Icons.print_outlined,
          selected: true,
        ),
        AdminPickerOption(
          value: false,
          label: 'Fillable PDF',
          icon: Icons.edit_note_outlined,
        ),
      ],
    );
  }

  String _chedWaveLabel(SurveyResponseWithMeta wave) {
    final when = wave.response.submittedAt;
    final stamp = when == null ? 'Submitted' : _submittedFormat.format(when);
    return '${wave.surveyTitle} · $stamp';
  }

  Future<void> _runChedPdfExport({
    String? surveyId,
    bool forceLiveOnly = false,
  }) async {
    final flatten = await _pickChedPdfExportMode();
    if (flatten == null || !mounted) return;

    setState(() => _exportingChedPdf = true);
    try {
      final result = await _chedPdfExport.buildOfficialPdf(
        member: _member,
        detail: forceLiveOnly
            ? AlumniDirectoryDetail(
                roster: _member,
                tracer: _detail?.tracer,
                profileImageUrl: _detail?.profileImageUrl,
                activityCount: _detail?.activityCount ?? 0,
                tracerResponses: const [],
              )
            : _detail,
        surveyId: forceLiveOnly ? null : surveyId,
        allowLiveFallback: true,
        flatten: flatten,
      );

      if (!mounted) return;
      final downloaded = tryDownloadBytesOnWeb(
        context,
        bytes: result.bytes,
        fileName: result.fileName,
        mimeType: 'application/pdf',
      );
      if (!downloaded) return;

      await _chedPdfExport.logExportSuccess(member: _member, result: result);

      if (!mounted) return;
      final missing = result.assembled.missingRequired.length;
      final sourceNote = switch (result.assembled.source) {
        ChedGtsAnswerSource.submittedSnapshot => 'from submitted snapshot',
        ChedGtsAnswerSource.merged => 'from snapshot + live profile gaps',
        ChedGtsAnswerSource.liveProfileFallback => 'from live profile',
        ChedGtsAnswerSource.empty => '',
      };
      final modeNote = flatten ? 'print-ready' : 'fillable';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            missing > 0
                ? 'Official CHED GTS PDF downloaded ($modeNote; $sourceNote; '
                      '$missing required field(s) still blank)'
                : 'Official CHED GTS PDF downloaded ($modeNote; $sourceNote)',
          ),
          backgroundColor: AdminColors.success,
        ),
      );
    } catch (e) {
      await _chedPdfExport.logExportFailure(
        member: _member,
        error: e,
        surveyId: surveyId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Couldn't create the CHED GTS PDF. Try again."),
          backgroundColor: AdminColors.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _exportingChedPdf = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AdminSurfaces.radiusLg),
        boxShadow: AdminSurfaces.cardShadow,
      ),
      child: Material(
        color: AdminColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AdminSurfaces.radiusLg),
          side: const BorderSide(color: AdminColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: SizedBox.expand(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildPanelHeader(),
              _buildTabBar(),
              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPanelHeader() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < _compactHeaderWidth;
        final showLoaded = _error == null;
        return MemberDetailPanelHeader(
          member: _member,
          imageUrl: _detail?.profileImageUrl ?? _member.profileImageUrl,
          tracerPercent: showLoaded ? _tracerCompletion : null,
          activityCount: showLoaded ? (_detail?.activityCount ?? 0) : 0,
          onClose: widget.onClose,
          onActivityTap: () => _tabs.animateTo(2),
          actions: [
            if (_member.hasProfileUpdates) _markReviewedButton(compact),
            if (_canShowChedPdfExport) _headerExportButton(compact: compact),
            const SizedBox(width: 4),
            _refreshButton(),
          ],
        );
      },
    );
  }

  Widget _markReviewedButton(bool compact) {
    const label = 'Mark as reviewed';
    final icon = _markingReviewed
        ? const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : const Icon(Icons.done_all_outlined, size: 18);
    final onPressed = _markingReviewed ? null : _markReviewed;

    if (compact) {
      return IconButton(
        tooltip: label,
        onPressed: onPressed,
        icon: icon,
        style: IconButton.styleFrom(
          foregroundColor: AdminColors.primary,
          side: const BorderSide(color: AdminColors.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AdminSurfaces.radiusSm),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: icon,
        label: const Text(label),
        style: AdminButtonStyles.filled(),
      ),
    );
  }

  Widget _headerExportButton({required bool compact}) {
    final label = canExportFiles
        ? 'Download CHED GTS PDF'
        : 'CHED PDF (web only)';
    final onPressed = _exportingChedPdf || _loading
        ? null
        : () => _onExportChedGtsPdfPressed();
    final icon = _exportingChedPdf
        ? const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : const Icon(Icons.picture_as_pdf_outlined, size: 18);

    if (compact) {
      return IconButton(
        tooltip: label,
        onPressed: onPressed,
        icon: icon,
        style: IconButton.styleFrom(
          foregroundColor: AdminColors.textPrimary,
          side: const BorderSide(color: AdminColors.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AdminSurfaces.radiusSm),
          ),
        ),
      );
    }
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: icon,
      label: Text(label),
      style: AdminButtonStyles.outlined(),
    );
  }

  Widget _refreshButton() {
    return IconButton(
      tooltip: _loading ? 'Refreshing…' : 'Refresh',
      onPressed: _exportingChedPdf || _loading ? null : _load,
      icon: _loading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AdminColors.primary,
              ),
            )
          : const Icon(Icons.refresh, size: 20),
      style: IconButton.styleFrom(foregroundColor: AdminColors.textSecondary),
    );
  }

  Widget _buildTabBar() {
    final activityCount = _detail?.activityCount ?? 0;
    final tracerCount = _detail?.tracerResponses.length ?? 0;

    return AdminTabBar(
      controller: _tabs,
      tabs: [
        const AdminTabSpec(label: 'Profile info', icon: Icons.person_outline),
        AdminTabSpec(
          label: 'Tracer responses',
          icon: Icons.assignment_outlined,
          count: tracerCount > 0 ? tracerCount : null,
        ),
        AdminTabSpec(
          label: 'Activity logs',
          icon: Icons.history,
          count: activityCount > 0 ? activityCount : null,
        ),
      ],
    );
  }

  Widget _buildBody() {
    if (_loading && _detail == null && _error == null) {
      return const MemberDetailSkeleton();
    }

    if (_error != null) {
      return AdminStateView.error(
        title: 'Could not load member details',
        message: 'Check your connection and try again.',
        details: _error,
        onRetry: _load,
      );
    }

    return TabBarView(
      controller: _tabs,
      children: [_profileTab(), _tracerResponsesTab(), _activityLogsTab()],
    );
  }

  Widget _scrollTab(List<Widget> children) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: children,
    );
  }

  Widget _profileTab() {
    if (!_member.isRegisteredUser) {
      return _scrollTab([
        const MemberDetailNotice(
          icon: Icons.person_off_outlined,
          title: 'Not registered in the app',
          message:
              'Demographic tracer data appears after the alumni completes '
              'registration and onboarding.',
        ),
        const SizedBox(height: 16),
        MemberDetailColumns(left: [_rosterSnapshotSection()]),
      ]);
    }

    final tracer = _detail?.tracer;
    if (tracer == null) {
      return _scrollTab([
        const MemberDetailNotice(
          icon: Icons.assignment_outlined,
          title: 'No tracer profile yet',
          message:
              'The alumni has not completed demographic fields in the app.',
        ),
        const SizedBox(height: 16),
        MemberDetailColumns(left: [_rosterSnapshotSection()]),
      ]);
    }

    const notProvided = 'Not provided';
    final changed = _unreviewedChangedFields;

    final general = MemberDetailSection(
      title: 'A. General Information',
      icon: Icons.badge_outlined,
      children: [
        MemberDetailInfoRow(
          label: GtsConstants.labelName,
          value: tracer.displayName,
          icon: Icons.person_outline,
          highlight: true,
          emptyText: notProvided,
          changed: changed.contains('displayName'),
        ),
        MemberDetailInfoRow(
          label: GtsConstants.labelPermanentAddress,
          value: tracer.address,
          icon: Icons.home_outlined,
          emptyText: notProvided,
          changed: changed.contains('address'),
        ),
        MemberDetailInfoRow(
          label: GtsConstants.labelEmail,
          value: tracer.preferredEmail,
          icon: Icons.email_outlined,
          emptyText: notProvided,
          trailing: ContactVerificationBadge.email(tracer),
          changed: changed.contains('email'),
        ),
        if (!_sameEmail(tracer.preferredEmail, tracer.email))
          MemberDetailInfoRow(
            label: 'Login email',
            value: tracer.email,
            icon: Icons.lock_outline,
          ),
        MemberDetailInfoRow(
          label: GtsConstants.labelTelephone,
          value: tracer.telephoneNumber,
          icon: Icons.phone_outlined,
          emptyText: notProvided,
          changed: changed.contains('telephoneNumber'),
        ),
        MemberDetailInfoRow(
          label: GtsConstants.labelMobile,
          value: tracer.mobileNumber,
          icon: Icons.smartphone_outlined,
          emptyText: notProvided,
          trailing: ContactVerificationBadge.mobile(tracer),
          changed: changed.contains('mobileNumber'),
        ),
        MemberDetailInfoRow(
          label: GtsConstants.labelCivilStatus,
          value: tracer.civilStatus,
          icon: Icons.favorite_outline,
          emptyText: notProvided,
          changed: changed.contains('civilStatus'),
        ),
        MemberDetailInfoRow(
          label: GtsConstants.labelSex,
          value: tracer.gender,
          icon: Icons.wc_outlined,
          emptyText: notProvided,
          changed: changed.contains('gender'),
        ),
        MemberDetailInfoRow(
          label: GtsConstants.labelBirthday,
          value: tracer.birthDate != null
              ? DateFormat.yMMMd().format(tracer.birthDate!)
              : '',
          icon: Icons.cake_outlined,
          emptyText: notProvided,
          changed: changed.contains('birthDate'),
        ),
        MemberDetailInfoRow(
          label: GtsConstants.labelRegionOfOrigin,
          value: tracer.regionOfOrigin,
          icon: Icons.map_outlined,
          emptyText: notProvided,
          changed: changed.contains('regionOfOrigin'),
        ),
        MemberDetailInfoRow(
          label: GtsConstants.labelProvince,
          value: tracer.province,
          icon: Icons.location_on_outlined,
          emptyText: notProvided,
          changed: changed.contains('province'),
        ),
        MemberDetailInfoRow(
          label: GtsConstants.labelLocationOfResidence,
          value: tracer.locationOfResidence,
          icon: Icons.location_city_outlined,
          emptyText: notProvided,
          changed: changed.contains('locationOfResidence'),
        ),
      ],
    );

    final education = MemberDetailSection(
      title: 'B. Educational Background',
      icon: Icons.school_outlined,
      children: [
        MemberDetailInfoRow(
          label: GtsConstants.labelDegreeSpecialization,
          value: tracer.program,
          icon: Icons.menu_book_outlined,
          emptyText: notProvided,
          changed: changed.contains('program'),
        ),
        MemberDetailInfoRow(
          label: GtsConstants.labelCollegeUniversity,
          value: tracer.collegeUniversity,
          icon: Icons.account_balance_outlined,
          emptyText: notProvided,
          changed: changed.contains('collegeUniversity'),
        ),
        MemberDetailInfoRow(
          label: GtsConstants.labelYearGraduated,
          value: tracer.yearGraduated,
          icon: Icons.calendar_today_outlined,
          emptyText: notProvided,
          changed: changed.contains('yearGraduated'),
        ),
        if (tracer.honorsAwards.isNotEmpty)
          MemberDetailInfoRow(
            label: GtsConstants.labelHonorsAwards,
            value: tracer.honorsAwards,
            icon: Icons.emoji_events_outlined,
            changed: changed.contains('honorsAwards'),
          ),
      ],
    );

    final status = tracer.employmentStatus.trim().toLowerCase();
    final isEmployed = status == GtsConstants.employed.toLowerCase();
    final isNotEmployed = status == GtsConstants.unemployed.toLowerCase() ||
        status == GtsConstants.neverEmployed.toLowerCase();

    String reasonsText = '';
    if (isNotEmployed && tracer.notEmployedReasons.isNotEmpty) {
      final list = List<String>.from(tracer.notEmployedReasons);
      final hasOther = list.contains(GtsConstants.otherReasonSpecify);
      if (hasOther && tracer.notEmployedReasonOther.isNotEmpty) {
        final idx = list.indexOf(GtsConstants.otherReasonSpecify);
        list[idx] = 'Other: ${tracer.notEmployedReasonOther}';
      }
      reasonsText = list.join(', ');
    }

    String? snapshotCaption;
    if (tracer.employmentUpdatedAt != null || tracer.employmentSource.isNotEmpty) {
      final dateStr = tracer.employmentUpdatedAt != null
          ? DateFormat('MMM yyyy').format(tracer.employmentUpdatedAt!.toLocal())
          : null;
      final sourceStr = tracer.employmentSource == 'ched_gts'
          ? 'CHED GTS'
          : (tracer.employmentSource == 'onboarding'
              ? 'onboarding'
              : tracer.employmentSource);
      final parts = <String>[
        'Self-reported',
        if (dateStr != null) 'as of $dateStr',
        if (sourceStr.isNotEmpty) 'from $sourceStr',
      ];
      snapshotCaption = parts.join(' · ');
    }

    final employment = MemberDetailSection(
      title: GtsConstants.labelEmploymentStatus,
      icon: Icons.work_outline,
      trailing: snapshotCaption != null
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AdminColors.surface,
                borderRadius: BorderRadius.circular(AdminSurfaces.radiusSm),
                border: Border.all(color: AdminColors.border),
              ),
              child: Text(
                snapshotCaption,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AdminColors.textMuted,
                ),
              ),
            )
          : null,
      children: [
        MemberDetailInfoRow(
          label: GtsConstants.labelEmploymentStatus,
          value: tracer.employmentStatus,
          icon: Icons.work_history_outlined,
          emptyText: notProvided,
          changed: changed.contains('employmentStatus'),
        ),
        if (isEmployed) ...[
          if (tracer.employmentOccupation.isNotEmpty)
            MemberDetailInfoRow(
              label: GtsConstants.labelOccupation,
              value: tracer.employmentOccupation,
              icon: Icons.badge_outlined,
              changed: changed.contains('employmentOccupation'),
            ),
          if (tracer.employmentType.isNotEmpty)
            MemberDetailInfoRow(
              label: GtsConstants.labelEmploymentType,
              value: tracer.employmentType,
              icon: Icons.assignment_ind_outlined,
              changed: changed.contains('employmentType'),
            ),
        ],
        if (isNotEmployed && reasonsText.isNotEmpty)
          MemberDetailInfoRow(
            label: GtsConstants.labelNotEmployedReasons,
            value: reasonsText,
            icon: Icons.rule_outlined,
            changed: changed.contains('notEmployedReasons'),
          ),
      ],
    );

    return _scrollTab([
      if (!tracer.isComplete) ...[
        MemberDetailCompletenessBanner(
          percent: tracer.completionPercent,
          missingLabels: memberDetailMissingTracerLabels(tracer),
        ),
        const SizedBox(height: 16),
      ],
      MemberDetailColumns(
        left: [general],
        right: [
          education,
          employment,
          if (_rosterHasExtraFields()) _rosterSnapshotSection(),
        ],
      ),
    ]);
  }

  static bool _sameEmail(String a, String b) =>
      a.trim().toLowerCase() == b.trim().toLowerCase();

  bool _rosterHasExtraFields() {
    final m = _member;
    return (m.address != null && m.address!.isNotEmpty) ||
        (m.gender != null && m.gender!.isNotEmpty) ||
        m.effectiveBatchYear.isNotEmpty ||
        m.contactNumber.isNotEmpty;
  }

  Widget _rosterSnapshotSection() {
    final m = _member;
    return MemberDetailSection(
      title: 'Official roster record',
      icon: Icons.folder_shared_outlined,
      children: [
        MemberDetailInfoRow(label: 'Roster name', value: m.fullName),
        MemberDetailInfoRow(label: 'Course', value: m.course),
        MemberDetailInfoRow(label: 'ID number', value: m.studentId),
        if (m.effectiveBatchYear.isNotEmpty)
          MemberDetailInfoRow(label: 'Batch', value: m.effectiveBatchYear),
        if (m.contactNumber.isNotEmpty)
          MemberDetailInfoRow(label: 'Contact', value: m.contactNumber),
        if (m.address != null && m.address!.isNotEmpty)
          MemberDetailInfoRow(label: 'Address', value: m.address!),
        if (m.gender != null && m.gender!.isNotEmpty)
          MemberDetailInfoRow(label: 'Gender', value: m.gender!),
        MemberDetailInfoRow(
          label: 'Added to roster',
          value: DateFormat.yMMMd().format(m.createdAt),
        ),
      ],
    );
  }

  Widget _tracerResponsesTab() {
    if (!_member.isRegisteredUser) {
      return const AdminStateView.empty(
        icon: Icons.assignment_outlined,
        title: 'No tracer responses',
        message:
            'Survey submission history appears after the alumni registers and completes onboarding.',
      );
    }

    final responses = _detail?.tracerResponses ?? [];
    if (responses.isEmpty) {
      return const AdminStateView.empty(
        icon: Icons.assignment_outlined,
        title: 'No submitted surveys',
        message:
            'Immutable survey snapshots appear here after the alumni submits a published tracer wave.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      itemCount: responses.length,
      itemBuilder: (context, index) => _tracerResponseCard(responses[index]),
    );
  }

  bool _looksLikeChedGts(Survey? survey, Map<String, dynamic> answers) {
    if (survey?.isChedGtsBuiltin == true) return true;
    return answers.keys.any((k) => k.toString().startsWith('ched_'));
  }

  Widget? _chedWaveExportButton(String surveyId) {
    if (!_canShowChedPdfExport || !canExportFiles) return null;
    return TextButton.icon(
      onPressed: _exportingChedPdf || _loading
          ? null
          : () => _onExportChedGtsPdfPressed(surveyId: surveyId),
      icon: _exportingChedPdf
          ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.picture_as_pdf_outlined, size: 16),
      label: const Text('Download PDF'),
      style: TextButton.styleFrom(
        foregroundColor: AdminColors.primary,
        visualDensity: VisualDensity.compact,
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _readOnlyChedForm(Map<String, dynamic> answers) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: ChedGtsForm(
        answers: answers,
        onChanged: (_) {},
        readOnly: true,
        showIntro: false,
      ),
    );
  }

  Widget _tracerResponseCard(SurveyResponseWithMeta item) {
    final submitted = item.response.submittedAt;
    final answers = item.response.answers;
    final subtitle = submitted != null
        ? 'Submitted ${_submittedFormat.format(submitted)}'
        : 'Submitted';
    final isChed = _looksLikeChedGts(null, answers);
    final exportBtn = isChed
        ? _chedWaveExportButton(item.response.surveyId)
        : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AdminColors.card,
        borderRadius: BorderRadius.circular(AdminSurfaces.radiusMd),
        border: Border.all(color: isChed ? _chedBorder : AdminColors.border),
        boxShadow: AdminSurfaces.cardShadow,
      ),
      clipBehavior: Clip.antiAlias,
      // Stack (not IntrinsicHeight) so the accent bar can stretch when the
      // ExpansionTile opens without fighting layout or borderRadius rules.
      child: Stack(
        children: [
          if (isChed)
            const Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: ColoredBox(color: _chedAccent, child: SizedBox(width: 4)),
            ),
          Padding(
            padding: EdgeInsets.only(left: isChed ? 4 : 0),
            child: Theme(
              data: Theme.of(
                context,
              ).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                maintainState: false,
                tilePadding: const EdgeInsets.fromLTRB(12, 4, 8, 4),
                childrenPadding: EdgeInsets.zero,
                expandedAlignment: Alignment.topCenter,
                expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
                shape: const Border(),
                collapsedShape: const Border(),
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isChed ? _chedTint : AdminColors.primaryTint,
                    borderRadius: BorderRadius.circular(AdminSurfaces.radiusSm),
                  ),
                  child: Icon(
                    isChed ? Icons.school_outlined : Icons.assignment_outlined,
                    size: 18,
                    color: isChed ? _chedAccent : AdminColors.primary,
                  ),
                ),
                title: Text(
                  item.surveyTitle,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AdminColors.textPrimary,
                  ),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(subtitle, style: AdminText.caption),
                      if (isChed)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _chedTint,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: _chedBorder),
                          ),
                          child: const Text(
                            'Official CHED',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: _chedAccent,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                trailing: exportBtn,
                children: [
                  const Divider(height: 1, color: AdminColors.border),
                  Container(
                    color: AdminColors.background,
                    child: isChed
                        ? _readOnlyChedForm(answers)
                        : _surveySnapshotBody(item, answers),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _surveySnapshotBody(
    SurveyResponseWithMeta item,
    Map<String, dynamic> answers,
  ) {
    final surveyId = item.response.surveyId;
    return FutureBuilder<Survey?>(
      future: _cachedSurvey(surveyId),
      builder: (context, surveySnap) {
        if (!surveySnap.hasData &&
            surveySnap.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: AdminStateView.loading(compact: true),
          );
        }

        if (_looksLikeChedGts(surveySnap.data, answers)) {
          return _readOnlyChedForm(answers);
        }

        return FutureBuilder<List<SurveyQuestion>>(
          future: _cachedQuestions(surveyId),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return AdminStateView.error(
                compact: true,
                title: "Couldn't load this survey's questions.",
                details: snapshot.error.toString(),
                onRetry: () => _retryQuestions(surveyId),
              );
            }
            if (!snapshot.hasData) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: AdminStateView.loading(compact: true),
              );
            }
            return Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: MemberDetailAnswerList(
                questions: snapshot.data!,
                answers: answers,
              ),
            );
          },
        );
      },
    );
  }

  Widget _activityLogsTab() {
    final logs = _detail?.activityLogs ?? const <AuditLog>[];
    if (logs.isEmpty) {
      return const AdminStateView.empty(
        icon: Icons.history,
        title: 'No activity recorded',
        message:
            'Audit events for this alumni (registration, tracer, exports, '
            'and admin actions) will appear here.',
      );
    }

    return _scrollTab([
      MemberDetailActivityList(logs: logs, limit: _activityLogLimit),
    ]);
  }
}

/// Full-screen wrapper kept for direct navigation if needed elsewhere.
class AdminAlumniMemberDetailScreen extends StatelessWidget {
  const AdminAlumniMemberDetailScreen({super.key, required this.member});

  final AlumniMember member;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdminDirectoryTheme.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: AdminAlumniMemberDetailPanel(
            member: member,
            onClose: () => Navigator.pop(context),
            onMemberUpdated: (_) {},
          ),
        ),
      ),
    );
  }
}
