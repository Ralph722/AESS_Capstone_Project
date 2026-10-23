import 'dart:async';

import 'package:flutter/material.dart';
import 'package:alumni_system/core/constants/course_constants.dart';
import 'package:alumni_system/features/admin/roster/models/alumni_member_model.dart';
import 'package:alumni_system/features/admin/roster/data/alumni_member_service.dart';
import 'package:alumni_system/features/admin/roster/presentation/admin_alumni_member_detail_page.dart';
import 'package:alumni_system/features/admin/roster/data/alumni_roster_import_service.dart';
import 'package:alumni_system/features/surveys/data/survey_service.dart';
import 'package:alumni_system/core/services/audit_service.dart';
import 'package:alumni_system/features/admin/roster/widgets/alumni_directory_ui.dart';
import 'package:alumni_system/features/admin/roster/widgets/admin_alumni_directory_dialogs.dart';
import 'package:alumni_system/features/admin/dashboard/widgets/admin_instant_content.dart';
import 'package:alumni_system/core/constants/ustp_colors.dart';
import 'package:alumni_system/shared/widgets/admin/admin_buttons.dart';
import 'package:alumni_system/shared/widgets/admin/admin_compact_header.dart';
import 'package:alumni_system/shared/widgets/admin/admin_data_table.dart';
import 'package:alumni_system/shared/widgets/admin/admin_density.dart';
import 'package:alumni_system/shared/widgets/admin/admin_metric_ribbon.dart';
import 'package:alumni_system/shared/widgets/admin/admin_pagination.dart';
import 'package:alumni_system/shared/widgets/admin/admin_saas_tabs.dart';
import 'package:alumni_system/shared/widgets/admin/admin_saas_toolbar.dart';
import 'package:alumni_system/shared/widgets/admin/admin_state_view.dart';
import 'package:alumni_system/shared/widgets/admin/admin_theme.dart';
import 'package:alumni_system/core/utils/export_platform.dart';
import 'package:alumni_system/core/utils/web_file_upload.dart';
import 'package:alumni_system/core/utils/app_image.dart';
import 'package:alumni_system/features/admin/ched_gts_pdf_export/ched_gts_pdf_export.dart';

/// Official alumni roster — Phase 1 admin directory.
class AdminAlumniDirectoryScreen extends StatefulWidget {
  const AdminAlumniDirectoryScreen({super.key});

  @override
  State<AdminAlumniDirectoryScreen> createState() =>
      _AdminAlumniDirectoryScreenState();
}

class _AdminAlumniDirectoryScreenState extends State<AdminAlumniDirectoryScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  final _memberService = AlumniMemberService();
  final _importService = AlumniRosterImportService();
  final _surveyService = SurveyService();
  final _auditService = AuditService();
  final _searchController = TextEditingController();
  Timer? _searchDebounce;

  List<AlumniMember> _allMembers = [];
  List<AlumniMember> _displayed = [];
  bool _isLoading = false;
  bool _isRefreshing = false;

  String? _courseFilter;
  String? _batchFilter;
  AlumniRegistrationFilter _registrationFilter = AlumniRegistrationFilter.all;
  AlumniActiveFilter _activeFilter = AlumniActiveFilter.all;
  AlumniDirectorySort _sort = AlumniDirectorySort.nameAsc;

  /// Directory tab: 0 = all alumni, 1 = profile updates, 2 = deactivated.
  int _viewIndex = 0;
  AlumniMember? _selectedMember;
  bool _exportingChedBatch = false;
  int _page = 0;
  int _pageSize = 25;

  int _registeredCount = 0;
  int _notRegisteredCount = 0;
  int _activeAlumniCount = 0;
  int _profileUpdatesCount = 0;
  int _deactivatedCount = 0;

  /// CHED GTS wave progress by auth uid (directory CHED GTS column).
  Map<String, ChedGtsProgress> _chedProgress = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadMembers();
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    AppImage.clearDecodedCache();
    super.dispose();
  }

  bool get _hasActiveFilters =>
      _searchController.text.trim().isNotEmpty ||
      _courseFilter != null ||
      _batchFilter != null ||
      _registrationFilter != AlumniRegistrationFilter.all ||
      _activeFilter != AlumniActiveFilter.all;

  AlumniDirectoryView get _view => switch (_viewIndex) {
    1 => AlumniDirectoryView.updates,
    2 => AlumniDirectoryView.deactivated,
    _ => AlumniDirectoryView.all,
  };

  List<String> get _batchOptions {
    final years =
        _allMembers
            .where((m) => !m.isDeactivated)
            .map((m) => m.effectiveBatchYear)
            .where((y) => y.isNotEmpty)
            .toSet()
            .toList()
          ..sort((a, b) => b.compareTo(a));
    return years;
  }

  void _recomputeDerivedStats() {
    var registered = 0;
    var notRegistered = 0;
    var active = 0;
    var profileUpdates = 0;
    var deactivated = 0;
    const activeWindow = Duration(days: 30);
    for (final m in _allMembers) {
      if (m.isDeactivated) {
        deactivated++;
        continue;
      }
      if (m.isRegisteredUser) {
        registered++;
        if (m.isActiveWithin(activeWindow)) active++;
      } else {
        notRegistered++;
      }
      if (m.hasProfileUpdates) profileUpdates++;
    }
    _registeredCount = registered;
    _notRegisteredCount = notRegistered;
    _activeAlumniCount = active;
    _profileUpdatesCount = profileUpdates;
    _deactivatedCount = deactivated;
  }

  void _clearFilters() {
    _searchDebounce?.cancel();
    _searchController.clear();
    setState(() {
      _courseFilter = null;
      _batchFilter = null;
      _registrationFilter = AlumniRegistrationFilter.all;
      _activeFilter = AlumniActiveFilter.all;
      _page = 0;
      _applyFilters();
    });
  }

  void _onSearchChanged(String _) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() {
        _page = 0;
        _applyFilters();
      });
    });
  }

  Future<void> _loadMembers() async {
    final firstLoad = _allMembers.isEmpty;
    setState(() {
      if (firstLoad) {
        _isLoading = true;
      } else {
        _isRefreshing = true;
      }
    });
    try {
      final members = await _memberService.getAllMembers(
        includeDeactivated: true,
      );
      if (!mounted) return;
      setState(() {
        _allMembers = members;
        // Drop a selected batch that no longer exists after refresh.
        if (_batchFilter != null &&
            !_allMembers.any(
              (m) => !m.isDeactivated && m.effectiveBatchYear == _batchFilter,
            )) {
          _batchFilter = null;
        }
        _recomputeDerivedStats();
        _applyFilters();
        _isLoading = false;
        _isRefreshing = false;
        if (_selectedMember != null) {
          try {
            _selectedMember = _allMembers.firstWhere(
              (m) => m.id == _selectedMember!.id,
            );
          } catch (_) {
            _selectedMember = null;
          }
        }
      });
      unawaited(_loadChedProgress());
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isRefreshing = false;
      });
      _showSnack(
        _friendlyError(
          e,
          "Couldn't load the roster. Check your connection and try Refresh.",
        ),
        isError: true,
      );
    }
  }

  /// CHED GTS column data loads after the roster so the list paints first;
  /// cells show a dash until progress arrives.
  Future<void> _loadChedProgress() async {
    final progress = await _surveyService.getChedGtsProgressByUser();
    if (!mounted) return;
    setState(() => _chedProgress = progress);
  }

  ChedGtsProgress? _chedFor(AlumniMember member) {
    final uid = member.authUid;
    if (uid == null || uid.isEmpty) return null;
    return _chedProgress[uid];
  }

  void _applyFilters() {
    _displayed = _memberService.filterAndSort(
      members: _allMembers,
      searchQuery: _searchController.text,
      courseFilter: _courseFilter,
      batchFilter: _batchFilter,
      registrationFilter: _registrationFilter,
      activeFilter: _activeFilter,
      sort: _sort,
      view: _view,
    );
  }

  /// Service validation messages are shown as-is; wrapped technical errors
  /// ("Error …: PostgrestException…") fall back to [fallback].
  String _friendlyError(Object error, String fallback) {
    var text = error is AlumniMemberDuplicateException
        ? error.message
        : '$error';
    while (text.startsWith('Exception: ')) {
      text = text.substring('Exception: '.length);
    }
    text = text.trim();
    final technical =
        text.isEmpty ||
        text.startsWith('Error ') ||
        text.contains('Exception') ||
        text.length > 160;
    return technical ? fallback : text;
  }

  Future<void> _exportChedGtsPdfBatch() async {
    if (!requireWebExport(context)) return;
    if (_allMembers.isEmpty) {
      _showSnack('No alumni on the roster to export', isError: true);
      return;
    }

    final choice = await showChedBulkExportDialog(
      context,
      members: _allMembers,
    );
    if (choice == null || !mounted) return;

    final selected = choice.members;
    if (selected.isEmpty) {
      _showSnack('No eligible alumni match those filters', isError: true);
      return;
    }

    if (selected.length > ChedGtsPdfExportLimits.maxBatchSize) {
      _showSnack(
        ChedGtsPdfExportLimits.batchCapMessage(selected.length),
        isError: true,
      );
      return;
    }

    final flattenFields = choice.flattenFields;

    setState(() => _exportingChedBatch = true);
    final progress = ValueNotifier<(int, int, String?)>((
      0,
      selected.length,
      null,
    ));
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          shape: directoryAlertDialogShape,
          title: directoryDialogTitle('Building CHED GTS ZIP'),
          content: ValueListenableBuilder<(int, int, String?)>(
            valueListenable: progress,
            builder: (_, value, __) {
              final done = value.$1;
              final total = value.$2;
              final name = value.$3;
              final fraction = total == 0 ? 0.0 : done / total;
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LinearProgressIndicator(value: fraction.clamp(0.0, 1.0)),
                  const SizedBox(height: 12),
                  Text('$done of $total'),
                  if (name != null && name.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );

    final batch = ChedGtsPdfBatchExportService();
    try {
      final result = await batch.buildZip(
        members: selected,
        flatten: flattenFields,
        onProgress: (done, total, name) {
          progress.value = (done, total, name);
        },
      );
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      if (!mounted) return;

      final downloaded = tryDownloadBytesOnWeb(
        context,
        bytes: result.zipBytes,
        fileName: result.zipFileName,
        mimeType: 'application/zip',
      );
      if (!downloaded) return;

      await batch.logBatchSuccess(
        result: result,
        selectedCount: selected.length,
      );

      if (!mounted) return;
      final skipped = result.failures.length;
      _showSnack(
        skipped == 0
            ? 'Downloaded ZIP with ${result.successCount} CHED GTS PDF(s)'
            : 'Downloaded ZIP with ${result.successCount} PDF(s); '
                  '$skipped skipped/failed',
      );
    } catch (e) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      await batch.logBatchFailure(error: e, selectedCount: selected.length);
      if (!mounted) return;
      _showSnack(
        _friendlyError(e, 'CHED GTS export failed. Please try again.'),
        isError: true,
      );
    } finally {
      progress.dispose();
      if (mounted) setState(() => _exportingChedBatch = false);
    }
  }

  void _openAddAlumniChooser() {
    showAlumniAddChooserDialog(
      context,
      onAddManually: () => _showAddOrEditDialog(),
      onImportFile: _importExcel,
    );
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AdminColors.danger : AdminColors.success,
      ),
    );
  }

  Future<void> _showAddOrEditDialog({AlumniMember? existing}) async {
    var successMessage = '';
    await showRosterEntryDialog(
      context,
      existing: existing,
      onSubmit: (input) async {
        try {
          if (existing == null) {
            final created = await _memberService.createMember(
              fullName: input.fullName,
              course: input.course,
              studentId: input.studentId,
              yearGraduated: input.yearGraduated,
            );
            await _auditService.logAction(
              action: 'CREATE_ROSTER_MEMBER',
              resource: 'AlumniMember',
              resourceId: created.id,
              description: 'Added roster: ${created.fullName}',
            );
            successMessage = '${created.fullName} added to roster';
          } else {
            await _memberService.updateRosterMember(
              id: existing.id,
              fullName: input.fullName,
              course: input.course,
              studentId: input.studentId,
              yearGraduated: input.yearGraduated,
            );
            await _auditService.logAction(
              action: 'UPDATE_ROSTER_MEMBER',
              resource: 'AlumniMember',
              resourceId: existing.id,
              description: 'Updated roster: ${input.fullName.trim()}',
            );
            successMessage = 'Roster entry updated';
          }
          return null;
        } catch (e) {
          return _friendlyError(
            e,
            "Couldn't save the roster entry. Please try again.",
          );
        }
      },
    );
    // The dialog can be dismissed (Esc / outside tap) while a save finishes.
    if (successMessage.isEmpty || !mounted) return;
    _showSnack(successMessage);
    await _loadMembers();
  }

  Future<void> _importExcel() async {
    if (!requireWebExport(context)) return;

    final bytes = await pickFileBytesOnWeb();
    if (bytes == null || !mounted) return;

    setState(() => _isLoading = true);
    try {
      final rows = _importService.parseExcelBytes(bytes);
      if (rows.isEmpty) {
        _showSnack('No data rows found in file', isError: true);
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final result = await _importService.importRows(rows);
      await _auditService.logAction(
        action: 'IMPORT_ROSTER',
        resource: 'AlumniMember',
        resourceId: 'bulk',
        description: 'Imported ${result.imported}, skipped ${result.skipped}',
      );

      var message =
          'Imported ${result.imported} member(s). Skipped ${result.skipped}.';
      if (result.errors.isNotEmpty) {
        message += ' ${result.errors.length} issue(s) — see details.';
        if (mounted) {
          await showDialog<void>(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: directoryAlertDialogShape,
              title: directoryDialogTitle('Import issues'),
              content: SingleChildScrollView(
                child: Text(result.errors.take(20).join('\n')),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      }
      _showSnack(message, isError: result.imported == 0);
      await _loadMembers();
    } on FormatException catch (e) {
      _showSnack(e.message, isError: true);
      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      _showSnack(
        _friendlyError(
          e,
          "Import failed. Check that the file is a valid Excel roster and try again.",
        ),
        isError: true,
      );
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _confirmDelete(AlumniMember member) async {
    final registered = member.isRegisteredUser;
    final choice = await showRosterRemoveDialog(context, member: member);
    if (choice == null || !mounted) return;
    final action = choice == RosterRemoveAction.deactivate
        ? 'deactivate'
        : 'delete';

    try {
      if (action == 'deactivate') {
        await _memberService.deactivateMember(member.id);
        _showSnack('${member.fullName} deactivated');
      } else if (registered) {
        await _memberService.removeRegisteredMemberAccount(member);
        _showSnack('${member.fullName}\'s portal account was removed');
      } else {
        await _memberService.deleteMember(member.id);
        _showSnack('${member.fullName} removed from roster');
      }
      if (action == 'deactivate' || !registered) {
        await _auditService.logAction(
          action: action == 'deactivate'
              ? 'DEACTIVATE_ROSTER'
              : 'DELETE_ROSTER',
          resource: 'AlumniMember',
          resourceId: member.id,
          description: '$action: ${member.fullName}',
          userRole: 'admin',
        );
      }
      await _loadMembers();
      if (_selectedMember?.id == member.id) {
        setState(() => _selectedMember = null);
      }
    } catch (e) {
      _showSnack(
        _friendlyError(e, "Couldn't complete that action. Please try again."),
        isError: true,
      );
    }
  }

  Future<void> _reactivate(AlumniMember member) async {
    try {
      await _memberService.reactivateMember(member.id);
      await _auditService.logAction(
        action: 'REACTIVATE_ROSTER',
        resource: 'AlumniMember',
        resourceId: member.id,
        description: 'reactivate: ${member.fullName}',
        userRole: 'admin',
      );
      _showSnack('${member.fullName} reactivated');
      await _loadMembers();
    } catch (e) {
      _showSnack(
        _friendlyError(
          e,
          "Couldn't reactivate ${member.fullName}. Please try again.",
        ),
        isError: true,
      );
    }
  }

  void _selectMember(AlumniMember member) {
    setState(() => _selectedMember = member);
  }

  void _closeMemberDetail() {
    setState(() => _selectedMember = null);
  }

  void _onMemberDetailUpdated(AlumniMember updated) {
    final index = _allMembers.indexWhere((m) => m.id == updated.id);
    if (index < 0) return;
    _allMembers[index] = updated;
    final displayedIndex = _displayed.indexWhere((m) => m.id == updated.id);
    if (displayedIndex >= 0) {
      _displayed[displayedIndex] = updated;
    }
    setState(() {
      if (_selectedMember?.id == updated.id) {
        _selectedMember = updated;
      }
      _recomputeDerivedStats();
    });
  }

  Duration? _activeWindowForFilter() {
    switch (_activeFilter) {
      case AlumniActiveFilter.active7:
        return const Duration(days: 7);
      case AlumniActiveFilter.active30:
        return const Duration(days: 30);
      case AlumniActiveFilter.active90:
        return const Duration(days: 90);
      default:
        return null;
    }
  }

  bool _showActiveBadge(AlumniMember member) {
    final window = _activeWindowForFilter();
    if (window != null) {
      return member.isActiveWithin(window);
    }
    return member.isActiveWithin(const Duration(days: 30));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final showingDetail = _selectedMember != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!showingDetail) ...[
          AdminCompactHeader(
            title: 'Alumni Directory',
            actions: [
              OutlinedButton.icon(
                onPressed: _isLoading || _isRefreshing ? null : _loadMembers,
                icon: _isRefreshing
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh_rounded, size: 15),
                label: Text(_isRefreshing ? 'Refreshing…' : 'Refresh'),
                style: AdminButtonStyles.outlined(),
              ),
              Tooltip(
                message: 'Download CHED GTS PDFs as a ZIP',
                child: OutlinedButton.icon(
                  onPressed: _isLoading || _exportingChedBatch || _allMembers.isEmpty
                      ? null
                      : _exportChedGtsPdfBatch,
                  icon: _exportingChedBatch
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.picture_as_pdf_outlined, size: 15),
                  label: Text(_exportingChedBatch ? 'Exporting…' : 'Export CHED GTS'),
                  style: AdminButtonStyles.outlined(),
                ),
              ),
              FilledButton.icon(
                onPressed: _isLoading ? null : _openAddAlumniChooser,
                icon: const Icon(Icons.person_add_alt_1_outlined, size: 15),
                label: const Text('Add Alumni'),
                style: AdminButtonStyles.filled(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          AdminMetricRibbon(
            items: [
              AdminMetricRibbonItem(
                label: 'On roster',
                value: '${_allMembers.length}',
                icon: Icons.groups_outlined,
                color: AdminColors.primary,
                tooltip: _deactivatedCount > 0
                    ? 'Total alumni records, incl. $_deactivatedCount deactivated'
                    : 'Total alumni records',
                isSelected: _registrationFilter == AlumniRegistrationFilter.all &&
                    _activeFilter == AlumniActiveFilter.all &&
                    _viewIndex == 0,
                onTap: () => setState(() {
                  _registrationFilter = AlumniRegistrationFilter.all;
                  _activeFilter = AlumniActiveFilter.all;
                  _viewIndex = 0;
                  _page = 0;
                  _applyFilters();
                }),
              ),
              AdminMetricRibbonItem(
                label: 'Registered',
                value: '$_registeredCount',
                icon: Icons.verified_outlined,
                color: AdminColors.secondary,
                tooltip: 'Signed in to the portal app',
                isSelected: _registrationFilter == AlumniRegistrationFilter.registered,
                onTap: () => setState(() {
                  _registrationFilter =
                      _registrationFilter == AlumniRegistrationFilter.registered
                          ? AlumniRegistrationFilter.all
                          : AlumniRegistrationFilter.registered;
                  _page = 0;
                  _applyFilters();
                }),
              ),
              AdminMetricRibbonItem(
                label: 'Not registered',
                value: '$_notRegisteredCount',
                icon: Icons.person_add_disabled_outlined,
                color: UstpColors.orange,
                tooltip: 'Awaiting app signup',
                isSelected: _registrationFilter ==
                    AlumniRegistrationFilter.notRegistered,
                onTap: () => setState(() {
                  _registrationFilter =
                      _registrationFilter == AlumniRegistrationFilter.notRegistered
                          ? AlumniRegistrationFilter.all
                          : AlumniRegistrationFilter.notRegistered;
                  _page = 0;
                  _applyFilters();
                }),
              ),
              AdminMetricRibbonItem(
                label: 'Active (30d)',
                value: '$_activeAlumniCount',
                icon: Icons.online_prediction_outlined,
                color: AdminColors.success,
                tooltip: 'Recently active users in past 30 days',
                isSelected: _activeFilter == AlumniActiveFilter.active30,
                onTap: () => setState(() {
                  _activeFilter = _activeFilter == AlumniActiveFilter.active30
                      ? AlumniActiveFilter.all
                      : AlumniActiveFilter.active30;
                  _page = 0;
                  _applyFilters();
                }),
              ),
            ],
          ),
          const SizedBox(height: 10),
          AdminSaaSTabs(
            tabs: [
              AdminSaaSTabSpec(
                label: 'All alumni',
                icon: Icons.groups_outlined,
                isSelected: _viewIndex == 0,
                onTap: () => setState(() {
                  _viewIndex = 0;
                  _page = 0;
                  _applyFilters();
                }),
              ),
              AdminSaaSTabSpec(
                label: 'Updates',
                icon: Icons.notifications_active_outlined,
                count: _profileUpdatesCount > 0 ? _profileUpdatesCount : null,
                isSelected: _viewIndex == 1,
                onTap: () => setState(() {
                  _viewIndex = 1;
                  _page = 0;
                  _applyFilters();
                }),
              ),
              AdminSaaSTabSpec(
                label: 'Deactivated',
                icon: Icons.person_off_outlined,
                count: _deactivatedCount > 0 ? _deactivatedCount : null,
                isSelected: _viewIndex == 2,
                onTap: () => setState(() {
                  _viewIndex = 2;
                  _page = 0;
                  _applyFilters();
                }),
              ),
            ],
          ),
          const SizedBox(height: 8),
          AdminSaaSToolbar(
            searchController: _searchController,
            onSearchChanged: _onSearchChanged,
            onClearSearch: () {
              _searchDebounce?.cancel();
              _searchController.clear();
              setState(() {
                _page = 0;
                _applyFilters();
              });
            },
            searchHint: 'Search name, ID, course, email…',
            searchWidth: 270,
            filters: [
              ..._buildFilterControlsList(dense: true),
              _buildSortControl(dense: true),
            ],
            activeFilterChips: _buildActiveFilterChips(),
            hasActiveFilters: _hasActiveFilters,
            onResetFilters: _clearFilters,
          ),
          const SizedBox(height: 8),
        ],
        Expanded(child: _buildDirectoryBody()),
      ],
    );
  }

  Widget _buildDirectoryBody() {
    if (_selectedMember != null) {
      return AdminAlumniMemberDetailPanel(
        key: ValueKey(_selectedMember!.id),
        member: _selectedMember!,
        onClose: _closeMemberDetail,
        onMemberUpdated: _onMemberDetailUpdated,
      );
    }

    return _buildMemberList();
  }

  List<Widget> _buildFilterControlsList({bool dense = true}) {
    const fieldWidth = 124.0;
    return [
      DirectoryFilterField<String?>(
        label: 'Course',
        value: _courseFilter,
        dense: dense,
        width: fieldWidth,
        items: [
          const DropdownMenuItem(value: null, child: Text('All courses')),
          ...CourseConstants.courses.map(
            (c) => DropdownMenuItem(value: c, child: Text(c)),
          ),
        ],
        onChanged: (v) {
          setState(() {
            _courseFilter = v;
            _page = 0;
            _applyFilters();
          });
        },
      ),
      DirectoryFilterField<String?>(
        label: 'Batch',
        value: _batchFilter,
        dense: dense,
        width: fieldWidth,
        items: [
          const DropdownMenuItem(value: null, child: Text('All batches')),
          ..._batchOptions.map(
            (b) => DropdownMenuItem(value: b, child: Text(b)),
          ),
        ],
        onChanged: (v) {
          setState(() {
            _batchFilter = v;
            _page = 0;
            _applyFilters();
          });
        },
      ),
      DirectoryFilterField<AlumniRegistrationFilter>(
        label: 'Registration',
        value: _registrationFilter,
        dense: dense,
        width: fieldWidth,
        items: const [
          DropdownMenuItem(
            value: AlumniRegistrationFilter.all,
            child: Text('All'),
          ),
          DropdownMenuItem(
            value: AlumniRegistrationFilter.registered,
            child: Text('Registered'),
          ),
          DropdownMenuItem(
            value: AlumniRegistrationFilter.notRegistered,
            child: Text('Not registered'),
          ),
        ],
        onChanged: (v) {
          if (v == null) return;
          setState(() {
            _registrationFilter = v;
            _page = 0;
            _applyFilters();
          });
        },
      ),
      DirectoryFilterField<AlumniActiveFilter>(
        label: 'Activity',
        value: _activeFilter,
        dense: dense,
        width: fieldWidth,
        items: const [
          DropdownMenuItem(
            value: AlumniActiveFilter.all,
            child: Text('All activity'),
          ),
          DropdownMenuItem(
            value: AlumniActiveFilter.active7,
            child: Text('Active ≤7d'),
          ),
          DropdownMenuItem(
            value: AlumniActiveFilter.active30,
            child: Text('Active ≤30d'),
          ),
          DropdownMenuItem(
            value: AlumniActiveFilter.active90,
            child: Text('Active ≤90d'),
          ),
          DropdownMenuItem(
            value: AlumniActiveFilter.inactive,
            child: Text('Inactive (90d+)'),
          ),
        ],
        onChanged: (v) {
          if (v == null) return;
          setState(() {
            _activeFilter = v;
            _page = 0;
            _applyFilters();
          });
        },
      ),
    ];
  }

  Widget _buildSortControl({bool dense = true}) {
    return DirectoryFilterField<AlumniDirectorySort>(
      label: 'Sort',
      value: _sort,
      dense: dense,
      width: 128.0,
      items: const [
        DropdownMenuItem(
          value: AlumniDirectorySort.nameAsc,
          child: Text('Name A–Z'),
        ),
        DropdownMenuItem(
          value: AlumniDirectorySort.nameDesc,
          child: Text('Name Z–A'),
        ),
        DropdownMenuItem(
          value: AlumniDirectorySort.studentIdAsc,
          child: Text('ID number'),
        ),
        DropdownMenuItem(
          value: AlumniDirectorySort.courseAsc,
          child: Text('Course'),
        ),
        DropdownMenuItem(
          value: AlumniDirectorySort.createdNewest,
          child: Text('Newest added'),
        ),
        DropdownMenuItem(
          value: AlumniDirectorySort.lastActiveNewest,
          child: Text('Last active'),
        ),
      ],
      onChanged: (v) {
        if (v == null) return;
        setState(() {
          _sort = v;
          _page = 0;
          _applyFilters();
        });
      },
    );
  }

  List<Widget> _buildActiveFilterChips() {
    final chips = <Widget>[];
    final search = _searchController.text.trim();
    if (search.isNotEmpty) {
      chips.add(
        DirectoryActiveFilterChip(
          label: 'Search: $search',
          onRemoved: () {
            _searchDebounce?.cancel();
            _searchController.clear();
            setState(() {
              _page = 0;
              _applyFilters();
            });
          },
        ),
      );
    }
    if (_courseFilter != null) {
      chips.add(
        DirectoryActiveFilterChip(
          label: 'Course: $_courseFilter',
          onRemoved: () => setState(() {
            _courseFilter = null;
            _page = 0;
            _applyFilters();
          }),
        ),
      );
    }
    if (_batchFilter != null) {
      chips.add(
        DirectoryActiveFilterChip(
          label: 'Batch: $_batchFilter',
          onRemoved: () => setState(() {
            _batchFilter = null;
            _page = 0;
            _applyFilters();
          }),
        ),
      );
    }
    if (_registrationFilter != AlumniRegistrationFilter.all) {
      final label = switch (_registrationFilter) {
        AlumniRegistrationFilter.registered => 'Registered',
        AlumniRegistrationFilter.notRegistered => 'Not Registered',
        AlumniRegistrationFilter.all => 'All',
      };
      chips.add(
        DirectoryActiveFilterChip(
          label: 'Registration: $label',
          onRemoved: () => setState(() {
            _registrationFilter = AlumniRegistrationFilter.all;
            _page = 0;
            _applyFilters();
          }),
        ),
      );
    }
    if (_activeFilter != AlumniActiveFilter.all) {
      final label = switch (_activeFilter) {
        AlumniActiveFilter.active7 => 'Active ≤7 days',
        AlumniActiveFilter.active30 => 'Active ≤30 days',
        AlumniActiveFilter.active90 => 'Active ≤90 days',
        AlumniActiveFilter.inactive => 'Inactive (90d+)',
        AlumniActiveFilter.all => 'All',
      };
      chips.add(
        DirectoryActiveFilterChip(
          label: 'Activity: $label',
          onRemoved: () => setState(() {
            _activeFilter = AlumniActiveFilter.all;
            _page = 0;
            _applyFilters();
          }),
        ),
      );
    }
    return chips;
  }

  Widget _buildMemberList() {
    Widget? empty;
    if (!_isLoading && _displayed.isEmpty) {
      if (_allMembers.isEmpty) {
        empty = AdminStateView.empty(
          icon: Icons.groups_outlined,
          title: 'No alumni on the roster yet',
          message:
              'Add members one at a time or import an Excel file with columns: Full Name, Course, ID Number, and optionally Year Graduated.',
          primaryAction: AdminStateAction(
            label: 'Add Alumni',
            icon: Icons.person_add_alt_1,
            onPressed: _openAddAlumniChooser,
          ),
        );
      } else if (!_hasActiveFilters && _view == AlumniDirectoryView.updates) {
        empty = AdminStateView.empty(
          icon: Icons.done_all_outlined,
          title: 'All caught up',
          message: 'No alumni have unreviewed profile updates.',
        );
      } else if (!_hasActiveFilters &&
          _view == AlumniDirectoryView.deactivated) {
        empty = AdminStateView.empty(
          icon: Icons.person_off_outlined,
          title: 'No deactivated alumni',
          message: 'Deactivated members will appear here.',
        );
      } else {
        empty = AdminStateView.empty(
          icon: Icons.search_off,
          title: 'No matches',
          message: 'Try adjusting your search or filters.',
          primaryAction: _hasActiveFilters
              ? AdminStateAction(
                  label: 'Clear filters',
                  onPressed: _clearFilters,
                )
              : null,
        );
      }
    }

    final safePage = adminClampPage(_page, _displayed.length, _pageSize);
    final pageMembers = adminPaginate(_displayed, safePage, _pageSize);

    return AdminInstantContent(
      loading: _isLoading,
      isEmpty: _displayed.isEmpty,
      empty: empty,
      minHeight: 280,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final useTable = constraints.maxWidth >= AdminDensity.desktopSplitMin;

          final list = useTable
              ? AdminDataTable(
                  columns: kDirectoryTableColumns,
                  trailingHeader: const SizedBox.shrink(),
                  trailingWidth: 44,
                  rowCount: pageMembers.length,
                  showBorder: true,
                  rowBuilder: (context, index) {
                    final member = pageMembers[index];
                    return DirectoryMemberTableRow(
                      member: member,
                      isSelected: _selectedMember?.id == member.id,
                      showActiveBadge: _showActiveBadge(member),
                      chedProgress: _chedFor(member),
                      onTap: () => _selectMember(member),
                      onEdit: () => _showAddOrEditDialog(existing: member),
                      onDelete: () => _confirmDelete(member),
                      onReactivate: member.isDeactivated
                          ? () => _reactivate(member)
                          : null,
                    );
                  },
                )
              : ListView.separated(
                  itemCount: pageMembers.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 4),
                  itemBuilder: (context, index) {
                    final member = pageMembers[index];
                    return DirectoryMemberCard(
                      member: member,
                      isSelected: _selectedMember?.id == member.id,
                      showActiveBadge: _showActiveBadge(member),
                      chedProgress: _chedFor(member),
                      onTap: () => _selectMember(member),
                      onEdit: () => _showAddOrEditDialog(existing: member),
                      onDelete: () => _confirmDelete(member),
                      onReactivate: member.isDeactivated
                          ? () => _reactivate(member)
                          : null,
                    );
                  },
                );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: list),
              AdminPaginationBar(
                totalItems: _displayed.length,
                page: safePage,
                pageSize: _pageSize,
                onPageChanged: (p) => setState(() => _page = p),
                onPageSizeChanged: (s) => setState(() {
                  _pageSize = s;
                  _page = 0;
                }),
              ),
            ],
          );
        },
      ),
    );
  }
}
