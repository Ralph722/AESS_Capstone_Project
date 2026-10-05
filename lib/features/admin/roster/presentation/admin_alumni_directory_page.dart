import 'dart:async';

import 'package:flutter/material.dart';
import 'package:alumni_system/core/constants/course_constants.dart';
import 'package:alumni_system/features/admin/roster/models/alumni_member_model.dart';
import 'package:alumni_system/features/admin/roster/data/alumni_member_service.dart';
import 'package:alumni_system/features/admin/roster/presentation/admin_alumni_member_detail_page.dart';
import 'package:alumni_system/features/admin/roster/data/alumni_roster_import_service.dart';
import 'package:alumni_system/core/services/audit_service.dart';
import 'package:alumni_system/features/admin/roster/widgets/alumni_directory_ui.dart';
import 'package:alumni_system/features/admin/roster/widgets/admin_alumni_directory_dialogs.dart';
import 'package:alumni_system/features/admin/dashboard/widgets/admin_instant_content.dart';
import 'package:alumni_system/shared/widgets/admin/admin_data_table.dart';
import 'package:alumni_system/shared/widgets/admin/admin_density.dart';
import 'package:alumni_system/shared/widgets/admin/admin_pagination.dart';
import 'package:alumni_system/shared/widgets/admin/admin_surface.dart';
import 'package:alumni_system/shared/widgets/admin/admin_form_layout.dart';
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
  final _auditService = AuditService();
  final _searchController = TextEditingController();
  Timer? _searchDebounce;

  List<AlumniMember> _allMembers = [];
  List<AlumniMember> _displayed = [];
  bool _isLoading = false;

  String? _courseFilter;
  String? _batchFilter;
  AlumniRegistrationFilter _registrationFilter = AlumniRegistrationFilter.all;
  AlumniActiveFilter _activeFilter = AlumniActiveFilter.all;
  AlumniDirectorySort _sort = AlumniDirectorySort.nameAsc;
  AlumniMember? _selectedMember;
  bool _exportingChedBatch = false;
  int _page = 0;
  int _pageSize = 25;

  int _registeredCount = 0;
  int _notRegisteredCount = 0;
  int _activeAlumniCount = 0;
  int _profileUpdatesCount = 0;

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
    const activeWindow = Duration(days: 30);
    for (final m in _allMembers) {
      if (m.isDeactivated) continue;
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
    if (firstLoad) setState(() => _isLoading = true);
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
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showSnack('Error loading roster: $e', isError: true);
    }
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
      hideDeactivated: true,
    );
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
          title: const Text('Building CHED GTS ZIP'),
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
      _showSnack('CHED GTS batch export failed: $e', isError: true);
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
        backgroundColor: isError
            ? const Color(0xFFFF6B6B)
            : const Color(0xFF4CAF50),
      ),
    );
  }

  Future<void> _showAddOrEditDialog({AlumniMember? existing}) async {
    final nameController = TextEditingController(
      text: existing?.fullName ?? '',
    );
    final idController = TextEditingController(text: existing?.studentId ?? '');
    final yearController = TextEditingController(
      text: existing?.effectiveBatchYear ?? '',
    );
    String? selectedCourse = existing != null && existing.course.isNotEmpty
        ? CourseConstants.normalize(existing.course)
        : CourseConstants.courses.first;

    final saved = await showAdminDialogSurface<bool>(
      context: context,
      maxWidth: kAdminDialogSm,
      child: StatefulBuilder(
        builder: (ctx, setDialogState) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AdminDirectoryTheme.navy.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      existing == null
                          ? Icons.person_add_alt_1
                          : Icons.edit_outlined,
                      color: AdminDirectoryTheme.navy,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      existing == null
                          ? 'Add to official roster'
                          : 'Edit roster entry',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AdminDirectoryTheme.navy,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Used to validate registration (name, course, and ID must match).',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: nameController,
                decoration: _dialogFieldDecoration(
                  'Full name',
                  Icons.person_outline,
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: selectedCourse,
                decoration: _dialogFieldDecoration(
                  'Course',
                  Icons.school_outlined,
                ),
                items: CourseConstants.courses
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setDialogState(() => selectedCourse = v),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: idController,
                decoration: _dialogFieldDecoration(
                  'ID number',
                  Icons.badge_outlined,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: yearController,
                keyboardType: TextInputType.number,
                decoration: _dialogFieldDecoration(
                  'Year graduated (optional)',
                  Icons.calendar_today_outlined,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: FilledButton.styleFrom(
                      backgroundColor: AdminDirectoryTheme.navy,
                      minimumSize: const Size(0, AdminDensity.buttonHeight),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    child: Text(
                      existing == null ? 'Add member' : 'Save changes',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (saved != true || !mounted) {
      nameController.dispose();
      idController.dispose();
      yearController.dispose();
      return;
    }

    try {
      if (existing == null) {
        final created = await _memberService.createMember(
          fullName: nameController.text,
          course: selectedCourse!,
          studentId: idController.text,
          yearGraduated: yearController.text,
        );
        await _auditService.logAction(
          action: 'CREATE_ROSTER_MEMBER',
          resource: 'AlumniMember',
          resourceId: created.id,
          description: 'Added roster: ${created.fullName}',
        );
        _showSnack('${created.fullName} added to roster');
      } else {
        await _memberService.updateRosterMember(
          id: existing.id,
          fullName: nameController.text,
          course: selectedCourse!,
          studentId: idController.text,
          yearGraduated: yearController.text,
        );
        await _auditService.logAction(
          action: 'UPDATE_ROSTER_MEMBER',
          resource: 'AlumniMember',
          resourceId: existing.id,
          description: 'Updated roster: ${nameController.text.trim()}',
        );
        _showSnack('Roster entry updated');
      }
      await _loadMembers();
    } on AlumniMemberDuplicateException catch (e) {
      _showSnack(e.message, isError: true);
    } catch (e) {
      _showSnack('$e', isError: true);
    } finally {
      nameController.dispose();
      idController.dispose();
      yearController.dispose();
    }
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
              title: const Text('Import issues'),
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
      _showSnack('Import failed: $e', isError: true);
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _confirmDelete(AlumniMember member) async {
    final registered = member.isRegisteredUser;
    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    registered
                        ? Icons.person_off_outlined
                        : Icons.delete_outline,
                    color: Colors.red.shade400,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      registered
                          ? 'Remove registered alumni?'
                          : 'Delete roster entry?',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AdminDirectoryTheme.navy,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                registered
                    ? 'Deactivate blocks sign-in and can be undone later. '
                          'Remove account also erases their personal details '
                          '(name, email, contact info, photo) from the portal. '
                          'Their tracer answers stay in the statistics without '
                          'identifying details, and the roster entry stays deactivated. '
                          'This cannot be undone.'
                    : 'Remove ${member.fullName} from the official roster? '
                          'They will not be able to register.',
                style: TextStyle(color: Colors.grey.shade700, height: 1.4),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancel'),
                  ),
                  if (registered) ...[
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, 'deactivate'),
                      child: const Text('Deactivate'),
                    ),
                  ],
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx, 'delete'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.red.shade600,
                    ),
                    child: Text(registered ? 'Remove account' : 'Delete'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (action == null || !mounted) return;

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
          action: action == 'deactivate' ? 'DEACTIVATE_ROSTER' : 'DELETE_ROSTER',
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
      _showSnack('$e', isError: true);
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

  InputDecoration _dialogFieldDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: AdminDirectoryTheme.navy),
      filled: true,
      fillColor: AdminDirectoryTheme.surface,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final showingDetail = _selectedMember != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
            if (!showingDetail) ...[
              DirectoryPageHeader(
                onAdd: _openAddAlumniChooser,
                onExport: _exportChedGtsPdfBatch,
                isLoading: _isLoading,
                canExport: _allMembers.isNotEmpty,
                isExporting: _exportingChedBatch,
              ),
              const SizedBox(height: AdminDirectoryTheme.space2),
              DirectoryStatsGrid(
                children: [
                  DirectoryStatCard(
                    label: 'On roster',
                    value: '${_allMembers.length}',
                    description: 'Total alumni records',
                    icon: Icons.groups_outlined,
                    accent: AdminDirectoryTheme.primary,
                  ),
                  DirectoryStatCard(
                    label: 'Registered alumni',
                    value: '$_registeredCount',
                    description: 'Signed in to the app',
                    icon: Icons.verified_outlined,
                    accent: AdminDirectoryTheme.info,
                    onTap: () => setState(() {
                      _registrationFilter = AlumniRegistrationFilter.registered;
                      _page = 0;
                      _applyFilters();
                    }),
                  ),
                  DirectoryStatCard(
                    label: 'Not registered',
                    value: '$_notRegisteredCount',
                    description: 'Awaiting app signup',
                    icon: Icons.person_add_disabled_outlined,
                    accent: AdminDirectoryTheme.warning,
                    onTap: () => setState(() {
                      _registrationFilter =
                          AlumniRegistrationFilter.notRegistered;
                      _page = 0;
                      _applyFilters();
                    }),
                  ),
                  DirectoryStatCard(
                    label: 'Active (30d)',
                    value: '$_activeAlumniCount',
                    description: 'Recently active users',
                    icon: Icons.online_prediction_outlined,
                    accent: AdminDirectoryTheme.success,
                    onTap: () => setState(() {
                      _activeFilter = AlumniActiveFilter.active30;
                      _page = 0;
                      _applyFilters();
                    }),
                  ),
                  if (_profileUpdatesCount > 0)
                    DirectoryStatCard(
                      label: 'Profile updates',
                      value: '$_profileUpdatesCount',
                      description: 'Pending admin review',
                      icon: Icons.notifications_active_outlined,
                      accent: AdminDirectoryTheme.warning,
                    ),
                ],
              ),
              const SizedBox(height: AdminDirectoryTheme.space2),
              DirectoryToolbarCard(
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
                isLoading: _isLoading,
                onRefresh: _loadMembers,
                hasActiveFilters: _hasActiveFilters,
                onResetFilters: _clearFilters,
                filters: _buildFilterControls(),
                activeFilterChips: _buildActiveFilterChips(),
              ),
              const SizedBox(height: 8),
              DirectoryResultsBar(
                message: _resultsMessage(),
                pendingReviewCount: _profileUpdatesCount,
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

  String _resultsMessage() {
    if (_isLoading) return 'Loading roster…';
    return 'Showing ${_displayed.length} of ${_allMembers.where((m) => !m.isDeactivated).length} alumni';
  }

  Widget _buildFilterControls() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        // Prefer a single compact row of fixed-width fields on desktop.
        final fieldWidth = width >= 1100
            ? 148.0
            : width >= 820
            ? 136.0
            : width >= 560
            ? (width - AdminDirectoryTheme.space1) / 2
            : double.infinity;

        return Wrap(
          spacing: 6,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            DirectoryFilterField<String?>(
              label: 'Course',
              value: _courseFilter,
              width: fieldWidth == double.infinity ? null : fieldWidth,
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
              width: fieldWidth == double.infinity ? null : fieldWidth,
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
              width: fieldWidth == double.infinity ? null : fieldWidth,
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
              width: fieldWidth == double.infinity ? null : fieldWidth,
              items: const [
                DropdownMenuItem(
                  value: AlumniActiveFilter.all,
                  child: Text('All activity'),
                ),
                DropdownMenuItem(
                  value: AlumniActiveFilter.active7,
                  child: Text('Active ≤7 days'),
                ),
                DropdownMenuItem(
                  value: AlumniActiveFilter.active30,
                  child: Text('Active ≤30 days'),
                ),
                DropdownMenuItem(
                  value: AlumniActiveFilter.active90,
                  child: Text('Active ≤90 days'),
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
            DirectoryFilterField<AlumniDirectorySort>(
              label: 'Sort',
              value: _sort,
              width: fieldWidth == double.infinity ? null : fieldWidth,
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
            ),
          ],
        );
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
        empty = DirectoryEmptyState(
          icon: Icons.groups_outlined,
          title: 'No alumni on the roster yet',
          subtitle:
              'Add members one at a time or import an Excel file with columns: Full Name, Course, ID Number, and optionally Year Graduated.',
          primaryLabel: 'Add Alumni',
          primaryAction: _openAddAlumniChooser,
        );
      } else {
        empty = DirectoryEmptyState(
          icon: Icons.search_off,
          title: 'No matches',
          subtitle: 'Try adjusting your search or filters.',
          primaryLabel: 'Clear filters',
          primaryAction: _hasActiveFilters ? _clearFilters : null,
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
                      onTap: () => _selectMember(member),
                      onEdit: () => _showAddOrEditDialog(existing: member),
                      onDelete: () => _confirmDelete(member),
                      onReactivate: member.isDeactivated
                          ? () async {
                              await _memberService.reactivateMember(member.id);
                              _showSnack('${member.fullName} reactivated');
                              await _loadMembers();
                            }
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
                      onTap: () => _selectMember(member),
                      onEdit: () => _showAddOrEditDialog(existing: member),
                      onDelete: () => _confirmDelete(member),
                      onReactivate: member.isDeactivated
                          ? () async {
                              await _memberService.reactivateMember(member.id);
                              _showSnack('${member.fullName} reactivated');
                              await _loadMembers();
                            }
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
