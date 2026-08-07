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
import 'package:alumni_system/shared/widgets/admin/admin_skeletons.dart';
import 'package:alumni_system/shared/widgets/admin/admin_surface.dart';
import 'package:alumni_system/shared/widgets/admin/admin_density.dart';
import 'package:alumni_system/features/admin/roster/data/alumni_directory_detail_service.dart';
import 'package:alumni_system/features/admin/activity/models/audit_log_model.dart';
import 'package:alumni_system/core/utils/app_image.dart';

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

      // Defer write-on-read so the panel paints before markAdminViewed.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _markViewed(detail.roster);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _markViewed(AlumniMember roster) async {
    try {
      final viewed = await _detailService.markAdminViewed(roster);
      if (!mounted) return;
      final updated = viewed.copyWith(
        tracerProfileComplete: roster.tracerProfileComplete,
      );
      setState(() => _member = updated);
      widget.onMemberUpdated(updated);
    } catch (_) {}
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

  double? get _tracerCompletion => _detail?.tracer?.completionPercent;

  List<SurveyResponseWithMeta> get _chedWaves =>
      ChedGtsPdfPersonExportService.chedWaves(_detail?.tracerResponses ?? []);

  bool get _canOfferChedPdfExport =>
      !_loading &&
      _error == null &&
      _detail != null &&
      _member.isRegisteredUser &&
      (_member.authUid?.isNotEmpty ?? false);

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
        final proceed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('No CHED submission'),
            content: const Text(
              'This alumni has no submitted CHED GTS response yet. '
              'Export using their live profile and employment data instead?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Export live profile'),
              ),
            ],
          ),
        );
        if (proceed != true || !mounted) return;
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
          backgroundColor: Colors.green,
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
        SnackBar(
          content: Text('CHED GTS PDF export failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _exportingChedPdf = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AdminDirectoryTheme.card,
      elevation: 8,
      shadowColor: const Color(0xFF0F172A).withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(AdminDirectoryTheme.radiusLg),
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
    );
  }

  Widget _buildPanelHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AdminDirectoryTheme.border)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            tooltip: 'Close details',
            onPressed: widget.onClose,
            style: IconButton.styleFrom(
              foregroundColor: AdminDirectoryTheme.textSecondary,
              minimumSize: const Size(
                AdminDirectoryTheme.buttonHeight,
                AdminDirectoryTheme.buttonHeight,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _member.fullName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AdminDirectoryTheme.textPrimary,
                  ),
                ),
                Text(
                  'Member details',
                  style: TextStyle(
                    fontSize: 12,
                    color: AdminDirectoryTheme.textMuted,
                  ),
                ),
              ],
            ),
          ),
          if (!_loading && _error == null) ...[
            if (_canOfferChedPdfExport)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: FilledButton.tonalIcon(
                  onPressed: _exportingChedPdf
                      ? null
                      : () => _onExportChedGtsPdfPressed(),
                  icon: _exportingChedPdf
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.picture_as_pdf_outlined, size: 18),
                  label: Text(
                    canExportFiles
                        ? 'Download auto-filled CHED PDF'
                        : 'CHED PDF (web only)',
                  ),
                  style: FilledButton.styleFrom(
                    foregroundColor: AdminDirectoryTheme.navy,
                    backgroundColor: AdminDirectoryTheme.infoBg,
                    minimumSize: const Size(0, AdminDensity.buttonHeight),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    textStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            IconButton(
              tooltip: 'Refresh',
              onPressed: _exportingChedPdf ? null : _load,
              icon: const Icon(Icons.refresh, size: 20),
              style: IconButton.styleFrom(
                foregroundColor: AdminDirectoryTheme.textSecondary,
                minimumSize: const Size(
                  AdminDirectoryTheme.buttonHeight,
                  AdminDirectoryTheme.buttonHeight,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    final activityCount = _detail?.activityCount ?? 0;
    final tracerCount = _detail?.tracerResponses.length ?? 0;

    return Material(
      color: AdminDirectoryTheme.card,
      child: TabBar(
        controller: _tabs,
        indicatorColor: AdminDirectoryTheme.primary,
        indicatorWeight: 2.5,
        labelColor: AdminDirectoryTheme.primary,
        unselectedLabelColor: AdminDirectoryTheme.textSecondary,
        labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 13,
        ),
        dividerColor: AdminDirectoryTheme.border,
        tabs: [
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.person_outline, size: 16),
                const SizedBox(width: 6),
                const Text('Profile info'),
                if (_tracerCompletion != null && _tracerCompletion! < 100) ...[
                  const SizedBox(width: 4),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: AdminDirectoryTheme.warning,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.assignment_outlined, size: 16),
                const SizedBox(width: 6),
                const Text('Tracer responses'),
                if (tracerCount > 0) ...[
                  const SizedBox(width: 6),
                  _TabCountBadge(count: tracerCount),
                ],
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.history, size: 16),
                const SizedBox(width: 6),
                const Text('Activity logs'),
                if (activityCount > 0) ...[
                  const SizedBox(width: 6),
                  _TabCountBadge(count: activityCount),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading && _detail == null && _error == null) {
      return const AdminMemberDetailSkeleton();
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
              const SizedBox(height: 12),
              const Text(
                'Could not load member details',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AdminDirectoryTheme.navy,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AdminDirectoryTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('Try again'),
                style: FilledButton.styleFrom(
                  backgroundColor: AdminDirectoryTheme.navy,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return TabBarView(
      controller: _tabs,
      children: [_profileTab(), _tracerResponsesTab(), _activityLogsTab()],
    );
  }

  Widget _profileTab() {
    if (!_member.isRegisteredUser) {
      return _scrollTab(
        MemberDetailEmptyPanel(
          icon: Icons.person_off_outlined,
          title: 'Not registered in the app',
          subtitle:
              'Demographic tracer data appears after the alumni completes '
              'registration and onboarding.',
          child: _rosterSnapshotSection(),
        ),
      );
    }

    final tracer = _detail?.tracer;
    if (tracer == null) {
      return _scrollTab(
        MemberDetailEmptyPanel(
          icon: Icons.assignment_outlined,
          title: 'No tracer profile yet',
          subtitle:
              'The alumni has not completed demographic fields in the app.',
          child: _rosterSnapshotSection(),
        ),
      );
    }

    return _scrollTab(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!tracer.isComplete)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AdminDirectoryTheme.warningBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange.shade800),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Some tracer profile fields are still missing.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.orange.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          MemberDetailSection(
            title: 'A. General Information',
            icon: Icons.badge_outlined,
            children: [
              MemberDetailInfoRow(
                label: GtsConstants.labelName,
                value: tracer.displayName,
                icon: Icons.person_outline,
                highlight: true,
              ),
              MemberDetailInfoRow(
                label: GtsConstants.labelPermanentAddress,
                value: tracer.address,
                icon: Icons.home_outlined,
              ),
              MemberDetailInfoRow(
                label: GtsConstants.labelEmail,
                value: tracer.email,
                icon: Icons.email_outlined,
              ),
              MemberDetailInfoRow(
                label: GtsConstants.labelTelephone,
                value: tracer.telephoneNumber,
                icon: Icons.phone_outlined,
              ),
              MemberDetailInfoRow(
                label: GtsConstants.labelMobile,
                value: tracer.mobileNumber,
                icon: Icons.smartphone_outlined,
              ),
              MemberDetailInfoRow(
                label: GtsConstants.labelCivilStatus,
                value: tracer.civilStatus,
                icon: Icons.favorite_outline,
              ),
              MemberDetailInfoRow(
                label: GtsConstants.labelSex,
                value: tracer.gender,
                icon: Icons.wc_outlined,
              ),
              if (tracer.birthDate != null)
                MemberDetailInfoRow(
                  label: GtsConstants.labelBirthday,
                  value: DateFormat.yMMMd().format(tracer.birthDate!),
                  icon: Icons.cake_outlined,
                ),
              MemberDetailInfoRow(
                label: GtsConstants.labelRegionOfOrigin,
                value: tracer.regionOfOrigin,
                icon: Icons.map_outlined,
              ),
              MemberDetailInfoRow(
                label: GtsConstants.labelProvince,
                value: tracer.province,
                icon: Icons.location_on_outlined,
              ),
              MemberDetailInfoRow(
                label: GtsConstants.labelLocationOfResidence,
                value: tracer.locationOfResidence,
                icon: Icons.location_city_outlined,
              ),
            ],
          ),
          const SizedBox(height: 16),
          MemberDetailSection(
            title: 'B. Educational Background',
            icon: Icons.school_outlined,
            children: [
              MemberDetailInfoRow(
                label: GtsConstants.labelDegreeSpecialization,
                value: tracer.program,
                icon: Icons.menu_book_outlined,
              ),
              MemberDetailInfoRow(
                label: GtsConstants.labelCollegeUniversity,
                value: tracer.collegeUniversity,
                icon: Icons.account_balance_outlined,
              ),
              MemberDetailInfoRow(
                label: GtsConstants.labelYearGraduated,
                value: tracer.yearGraduated,
                icon: Icons.calendar_today_outlined,
              ),
              if (tracer.honorsAwards.isNotEmpty)
                MemberDetailInfoRow(
                  label: GtsConstants.labelHonorsAwards,
                  value: tracer.honorsAwards,
                  icon: Icons.emoji_events_outlined,
                ),
            ],
          ),
          const SizedBox(height: 16),
          MemberDetailSection(
            title: GtsConstants.labelEmploymentStatus,
            icon: Icons.work_outline,
            children: [
              MemberDetailInfoRow(
                label: GtsConstants.labelEmploymentStatus,
                value: tracer.employmentStatus.isNotEmpty
                    ? tracer.employmentStatus
                    : '—',
                icon: Icons.work_history_outlined,
              ),
            ],
          ),
          if (_rosterHasExtraFields()) ...[
            const SizedBox(height: 16),
            _rosterSnapshotSection(),
          ],
        ],
      ),
    );
  }

  bool _rosterHasExtraFields() {
    final m = _member;
    return (m.address != null && m.address!.isNotEmpty) ||
        (m.gender != null && m.gender!.isNotEmpty) ||
        m.batchYear.isNotEmpty ||
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
        if (m.batchYear.isNotEmpty)
          MemberDetailInfoRow(label: 'Batch', value: m.batchYear),
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
      return _scrollTab(
        const MemberDetailEmptyPanel(
          icon: Icons.assignment_outlined,
          title: 'No tracer responses',
          subtitle:
              'Survey submission history appears after the alumni registers and completes onboarding.',
        ),
      );
    }

    final responses = _detail?.tracerResponses ?? [];
    if (responses.isEmpty) {
      return _scrollTab(
        const MemberDetailEmptyPanel(
          icon: Icons.assignment_outlined,
          title: 'No submitted surveys',
          subtitle:
              'Immutable survey snapshots appear here after the alumni submits a published tracer wave.',
        ),
      );
    }

    final showSummary = _error == null && !_loading;
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      itemCount: responses.length + (showSummary ? 1 : 0),
      itemBuilder: (context, index) {
        if (showSummary && index == 0) return _buildCompactSummary();
        final item = responses[index - (showSummary ? 1 : 0)];
        return _tracerResponseCard(item);
      },
    );
  }

  bool _looksLikeChedGts(Survey? survey, Map<String, dynamic> answers) {
    if (survey?.isChedGtsBuiltin == true) return true;
    return answers.keys.any((k) => k.toString().startsWith('ched_'));
  }

  Widget? _chedWaveExportButton(String surveyId) {
    if (!_canOfferChedPdfExport || !canExportFiles) return null;
    return TextButton.icon(
      onPressed: _exportingChedPdf
          ? null
          : () => _onExportChedGtsPdfPressed(surveyId: surveyId),
      icon: _exportingChedPdf
          ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.picture_as_pdf_outlined, size: 16),
      label: const Text('Auto-filled PDF'),
      style: TextButton.styleFrom(
        foregroundColor: AdminDirectoryTheme.navy,
        visualDensity: VisualDensity.compact,
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
    final exportBtn = isChed ? _chedWaveExportButton(item.response.surveyId) : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AdminDirectoryTheme.radiusSm),
        border: Border.all(
          color: isChed
              ? const Color(0xFFFDBA74)
              : AdminDirectoryTheme.border,
        ),
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
              child: ColoredBox(
                color: Color(0xFFC2410C),
                child: SizedBox(width: 4),
              ),
            ),
          Padding(
            padding: EdgeInsets.only(left: isChed ? 4 : 0),
            child: Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
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
              color: isChed
                  ? const Color(0xFFFFF7ED)
                  : AdminDirectoryTheme.infoBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isChed ? Icons.school_outlined : Icons.assignment_outlined,
              size: 18,
              color: isChed
                  ? const Color(0xFFC2410C)
                  : AdminDirectoryTheme.primary,
            ),
          ),
          title: Text(
            item.surveyTitle,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13.5,
              color: AdminDirectoryTheme.textPrimary,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AdminDirectoryTheme.textSecondary,
                  ),
                ),
                if (isChed)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7ED),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFFDBA74)),
                    ),
                    child: const Text(
                      'Official CHED',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFC2410C),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          trailing: exportBtn,
          children: [
            const Divider(height: 1),
            Container(
              color: const Color(0xFFF8FAFC),
              child: isChed
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                      child: ChedGtsForm(
                        answers: answers,
                        onChanged: (_) {},
                        readOnly: true,
                        showIntro: false,
                      ),
                    )
                  : FutureBuilder<Survey?>(
                      future: _cachedSurvey(item.response.surveyId),
                      builder: (context, surveySnap) {
                        if (!surveySnap.hasData &&
                            surveySnap.connectionState !=
                                ConnectionState.done) {
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(
                              child: CircularProgressIndicator(),
                            ),
                          );
                        }

                        final survey = surveySnap.data;
                        if (_looksLikeChedGts(survey, answers)) {
                          return Padding(
                            padding: const EdgeInsets.fromLTRB(
                              14,
                              12,
                              14,
                              14,
                            ),
                            child: ChedGtsForm(
                              answers: answers,
                              onChanged: (_) {},
                              readOnly: true,
                              showIntro: false,
                            ),
                          );
                        }

                        return FutureBuilder<List<SurveyQuestion>>(
                          future: _cachedQuestions(
                            item.response.surveyId,
                          ),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) {
                              return const Padding(
                                padding: EdgeInsets.all(16),
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              );
                            }
                            final questions = snapshot.data!;
                            if (questions.isEmpty) {
                              if (answers.isEmpty) {
                                return const Padding(
                                  padding: EdgeInsets.fromLTRB(
                                    14,
                                    12,
                                    14,
                                    14,
                                  ),
                                  child: Text(
                                    'No answers recorded for this response.',
                                    style: TextStyle(
                                      color: AdminDirectoryTheme
                                          .textSecondary,
                                    ),
                                  ),
                                );
                              }
                              return Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  14,
                                  12,
                                  14,
                                  14,
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: answers.entries
                                      .map(
                                        (e) => _answerBlock(
                                          label: e.key,
                                          value: _formatSurveyAnswer(
                                            e.value,
                                          ),
                                        ),
                                      )
                                      .toList(),
                                ),
                              );
                            }
                            return Padding(
                              padding: const EdgeInsets.fromLTRB(
                                14,
                                12,
                                14,
                                14,
                              ),
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.stretch,
                                children: questions
                                    .map(
                                      (q) => _answerBlock(
                                        label: q.prompt,
                                        value: _formatSurveyAnswer(
                                          answers[q.id],
                                        ),
                                      ),
                                    )
                                    .toList(),
                              ),
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _answerBlock({required String label, required String value}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AdminDirectoryTheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AdminDirectoryTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 12.5,
              color: AdminDirectoryTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              height: 1.4,
              color: AdminDirectoryTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  String _formatSurveyAnswer(dynamic answer) {
    if (answer == null) return '—';
    if (answer is List) return answer.join(', ');
    return answer.toString();
  }

  Widget _scrollTab(Widget child) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      children: [
        if (_error == null && !_loading) _buildCompactSummary(),
        child,
      ],
    );
  }

  Widget _buildCompactSummary() {
    final image = _detail?.profileImageUrl?.trim();
    final isActive =
        _member.isRegisteredUser &&
        _member.isActiveWithin(const Duration(days: 7));

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AdminDirectoryTheme.surface,
        borderRadius: BorderRadius.circular(AdminDirectoryTheme.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: const BoxDecoration(shape: BoxShape.circle),
                    child: ClipOval(
                      child: image != null && image.isNotEmpty
                          ? AppImage.widget(
                              image,
                              width: 52,
                              height: 52,
                              fit: BoxFit.cover,
                            )
                          : ColoredBox(
                              color: AdminDirectoryTheme.infoBg,
                              child: Center(
                                child: Text(
                                  _member.fullName.isNotEmpty
                                      ? _member.fullName[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: AdminDirectoryTheme.primary,
                                  ),
                                ),
                              ),
                            ),
                    ),
                  ),
                  if (isActive)
                    Positioned(
                      right: -1,
                      bottom: -1,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: AdminDirectoryTheme.success,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _member.fullName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AdminDirectoryTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_member.course} · ID ${_member.studentId}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AdminDirectoryTheme.textSecondary,
                      ),
                    ),
                    if (_member.registeredEmail?.trim().isNotEmpty == true) ...[
                      const SizedBox(height: 2),
                      Text(
                        _member.registeredEmail!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AdminDirectoryTheme.textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (_member.hasProfileUpdates)
                _InlineStatusChip(
                  label: 'Profile updated',
                  bg: AdminDirectoryTheme.warningBg,
                  fg: AdminDirectoryTheme.warning,
                ),
              if (_member.isRegisteredUser)
                _InlineStatusChip(
                  label: 'In app',
                  bg: AdminDirectoryTheme.infoBg,
                  fg: AdminDirectoryTheme.info,
                ),
              if (isActive)
                _InlineStatusChip(
                  label: 'Active · 7d',
                  bg: AdminDirectoryTheme.successBg,
                  fg: AdminDirectoryTheme.success,
                ),
              if ((_detail?.activityCount ?? 0) > 0)
                InkWell(
                  onTap: () => _tabs.animateTo(2),
                  borderRadius: BorderRadius.circular(20),
                  child: _InlineStatusChip(
                    label: '${_detail!.activityCount} activities',
                    bg: AdminDirectoryTheme.surface,
                    fg: AdminDirectoryTheme.textSecondary,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _activityLogsTab() {
    final logs = _detail?.activityLogs ?? const <AuditLog>[];
    if (logs.isEmpty) {
      return _scrollTab(
        const MemberDetailEmptyPanel(
          icon: Icons.history,
          title: 'No activity recorded',
          subtitle:
              'Audit events for this alumni (registration, tracer, exports, '
              'and admin actions) will appear here.',
        ),
      );
    }

    final format = DateFormat.yMMMd().add_jm();
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: logs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final log = logs[index];
        final ok = log.status.toUpperCase() == 'SUCCESS';
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AdminDirectoryTheme.card,
            borderRadius: BorderRadius.circular(AdminDirectoryTheme.radiusMd),
            border: Border.all(color: AdminDirectoryTheme.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: ok
                      ? AdminDirectoryTheme.successBg
                      : AdminDirectoryTheme.dangerBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  ok ? Icons.check_circle_outline : Icons.error_outline,
                  size: 18,
                  color: ok
                      ? AdminDirectoryTheme.success
                      : AdminDirectoryTheme.danger,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      log.action,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AdminDirectoryTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      log.description.isNotEmpty
                          ? log.description
                          : '${log.resource} · ${log.resourceId}',
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        color: AdminDirectoryTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Text(
                          format.format(log.timestamp),
                          style: const TextStyle(
                            fontSize: 11,
                            color: AdminDirectoryTheme.textMuted,
                          ),
                        ),
                        if (log.userName.trim().isNotEmpty)
                          Text(
                            log.userName,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AdminDirectoryTheme.textMuted,
                            ),
                          ),
                        Text(
                          log.status,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: ok
                                ? AdminDirectoryTheme.success
                                : AdminDirectoryTheme.danger,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TabCountBadge extends StatelessWidget {
  const _TabCountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AdminDirectoryTheme.infoBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$count',
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AdminDirectoryTheme.primary,
        ),
      ),
    );
  }
}

class _InlineStatusChip extends StatelessWidget {
  const _InlineStatusChip({
    required this.label,
    required this.bg,
    required this.fg,
  });

  final String label;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg),
      ),
    );
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
