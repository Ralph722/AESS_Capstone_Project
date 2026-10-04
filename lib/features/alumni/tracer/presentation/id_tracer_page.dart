import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:alumni_system/core/utils/local_id.dart';
import 'package:alumni_system/core/services/app_session.dart';
import 'package:alumni_system/features/alumni/tracer/data/id_tracer_service.dart';
import 'package:alumni_system/features/alumni/tracer/models/id_tracer_model.dart';
import 'package:alumni_system/core/services/audit_service.dart';
import 'package:alumni_system/features/alumni/profile/data/user_profile_service.dart';
import 'package:alumni_system/shared/widgets/tracer/demographic_tracer_tab.dart';
import 'package:alumni_system/shared/widgets/onboarding/onboarding_ui.dart';
import 'package:alumni_system/shared/widgets/user/portal_menu.dart';
import 'package:alumni_system/shared/widgets/user/portal_skeletons.dart';
import 'package:alumni_system/shared/widgets/user/portal_theme.dart';
import 'package:intl/intl.dart';

/// Unified alumni tracer: demographics + employment (Phase 5).
class IdTracerScreen extends StatefulWidget {
  const IdTracerScreen({
    super.key,
    this.initialTab = 0,
    this.embeddedInNav = true,
  });

  /// 0 = demographics, 1 = employment
  final int initialTab;

  /// When false (opened from Profile/Home), shows a back button.
  final bool embeddedInNav;

  @override
  State<IdTracerScreen> createState() => _IdTracerScreenState();
}

class _IdTracerScreenState extends State<IdTracerScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late TabController _tabController;
  final IdTracerService _idTracerService = IdTracerService();
  final UserProfileService _profileService = UserProfileService();
  final AuditService _auditService = AuditService();
  final SupabaseClient _supabase = Supabase.instance.client;

  bool _isLoading = false;
  bool _isLoadingEmployment = false;
  bool _employmentTabLoaded = false;
  EmploymentRecord? _existingRecord;
  bool _demographicComplete = false;
  bool _employmentComplete = false;

  String _employmentStatus = 'Employed';
  final _monthsUnemployedController = TextEditingController();
  final _emailController = TextEditingController();
  final _contactNumberController = TextEditingController();
  final _schoolIdController = TextEditingController();

  // Enhanced fields
  final _companyNameController = TextEditingController();
  final _positionController = TextEditingController();
  final _industryController = TextEditingController();
  final _salaryRangeController = TextEditingController();
  final _cityController = TextEditingController();
  final _provinceController = TextEditingController();
  final _countryController = TextEditingController();

  String? _employmentType;
  DateTime? _startDate;

  final List<String> _employmentTypes = [
    'Full-time',
    'Part-time',
    'Contract',
    'Freelance',
    'Self-employed',
  ];

  @override
  void initState() {
    super.initState();
    final tab = widget.initialTab.clamp(0, 1);
    _tabController = TabController(length: 2, vsync: this, initialIndex: tab);
    _tabController.addListener(_onTracerTabChanged);
    _loadUserData();
    _loadCompletionState();
    if (tab == 1) {
      _ensureEmploymentLoaded();
    }
  }

  void _onTracerTabChanged() {
    if (_tabController.indexIsChanging) return;
    if (_tabController.index == 1) {
      _ensureEmploymentLoaded();
    }
  }

  void _ensureEmploymentLoaded() {
    if (_employmentTabLoaded) return;
    _employmentTabLoaded = true;
    _loadExistingRecord();
  }

  int get _overallCompletionPercent {
    var completion = 0;
    if (_demographicComplete) completion += 50;
    if (_employmentComplete) completion += 50;
    return completion;
  }

  Future<void> _loadCompletionState() async {
    final userId = AppSession.userId;
    if (userId == null) return;
    try {
      final profile = await _profileService.getTracerProfile(userId);
      if (!mounted) return;
      setState(() {
        _demographicComplete = profile?.isComplete == true;
      });
    } catch (_) {}
  }

  Future<void> _loadUserData() async {
    final userId = AppSession.userId;
    if (userId != null) {
      setState(() {
        _emailController.text = AppSession.email ?? '';
      });

      // Try to get user data from Supabase
      try {
        final row = await _supabase
            .from('users')
            .select()
            .eq('id', userId)
            .maybeSingle();
        if (row != null) {
          setState(() {
            if ((row['contact_number'] as String?)?.isNotEmpty == true) {
              _contactNumberController.text = row['contact_number'];
            }
            if ((row['student_id'] as String?)?.isNotEmpty == true) {
              _schoolIdController.text = row['student_id'];
            }
          });
        }
      } catch (_) {}
    }
  }

  Future<void> _loadExistingRecord() async {
    try {
      setState(() => _isLoadingEmployment = true);
      final record = await _idTracerService.getCurrentUserRecord();

      if (record != null && mounted) {
        setState(() {
          _existingRecord = record;
          _employmentComplete = true;
          _employmentStatus = record.employmentStatus;
          _monthsUnemployedController.text =
              record.monthsUnemployed?.toString() ?? '';
          _emailController.text = record.userEmail;
          _contactNumberController.text = record.contactNumber;
          _schoolIdController.text = record.schoolId;
          _companyNameController.text = record.companyName ?? '';
          _positionController.text = record.position ?? '';
          _industryController.text = record.industry ?? '';
          _employmentType = record.employmentType;
          _startDate = record.startDate;
          _salaryRangeController.text = record.salaryRange ?? '';
          _cityController.text = record.city ?? '';
          _provinceController.text = record.province ?? '';
          _countryController.text = record.country ?? '';
        });
      }
      if (record == null && mounted) {
        setState(() => _employmentComplete = false);
      }
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() => _isLoadingEmployment = false);
      }
    }
  }

  void _disposeEmploymentControllers() {
    _monthsUnemployedController.dispose();
    _emailController.dispose();
    _contactNumberController.dispose();
    _schoolIdController.dispose();
    _companyNameController.dispose();
    _positionController.dispose();
    _industryController.dispose();
    _salaryRangeController.dispose();
    _cityController.dispose();
    _provinceController.dispose();
    _countryController.dispose();
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTracerTabChanged);
    _tabController.dispose();
    _disposeEmploymentControllers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OnboardingTheme.surface,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [OnboardingTheme.navy, OnboardingTheme.navyLight],
            ),
          ),
        ),
        foregroundColor: Colors.white,
        automaticallyImplyLeading: !widget.embeddedInNav,
        title: AnimatedBuilder(
          animation: _tabController,
          builder: (context, _) {
            final tab = _tabController.index;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Alumni Tracer',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
                Text(
                  tab == 0 ? 'Demographic profile' : 'Employment record',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.85),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            );
          },
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _CompletionBadge(
              percentage: _overallCompletionPercent,
              demographicDone: _demographicComplete,
              employmentDone: _employmentComplete,
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: OnboardingTheme.gold,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          dividerColor: Colors.white24,
          tabs: const [
            Tab(text: 'Demographics'),
            Tab(text: 'Employment'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          DemographicTracerTab(onSaved: _loadCompletionState),
          _isLoadingEmployment
              ? const TracerFormSkeleton(fieldCount: 7)
              : _buildEmploymentTab(),
        ],
      ),
    );
  }

  Widget _buildEmploymentTab() {
    return Form(
      key: _formKey,
      child: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                margin: const EdgeInsets.only(bottom: 20),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      OnboardingTheme.navy.withValues(alpha: 0.95),
                      OnboardingTheme.navyLight.withValues(alpha: 0.92),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: OnboardingTheme.navy.withValues(alpha: 0.18),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.work_outline_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Employment tracker',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Keep your employment status updated so the alumni tracer stays accurate and useful for your batch.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.92),
                        fontSize: 13,
                        height: 1.35,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              // Info banner if existing record
              if (_existingRecord != null) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: OnboardingTheme.gold.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: OnboardingTheme.navy.withValues(alpha: 0.18),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        color: OnboardingTheme.navy,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'You have a previous submission. Saving again will replace your existing record.',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade900,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              OnboardingFormCard(
                title: 'Employment status',
                subtitle: 'Tell us whether you are currently employed or not.',
                icon: Icons.work_history_outlined,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    OnboardingEmploymentToggle(
                      value: _employmentStatus,
                      enabled: !_isLoading,
                      onChanged: (v) {
                        setState(() {
                          _employmentStatus = v;
                          if (v == 'Unemployed') {
                            _companyNameController.clear();
                            _positionController.clear();
                            _industryController.clear();
                            _employmentType = null;
                            _startDate = null;
                            _salaryRangeController.clear();
                          }
                        });
                      },
                    ),
                    if (_employmentStatus == 'Unemployed') ...[
                      const SizedBox(height: 20),
                      _buildTextField(
                        controller: _monthsUnemployedController,
                        label: 'Months unemployed *',
                        icon: Icons.calendar_today_outlined,
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter months unemployed';
                          }
                          if (int.tryParse(value) == null) {
                            return 'Please enter a valid number';
                          }
                          return null;
                        },
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),

              if (_employmentStatus == 'Employed') ...[
                OnboardingFormCard(
                  title: 'Employment details',
                  subtitle:
                      'Current job information (optional fields may be left blank).',
                  icon: Icons.business_center_outlined,
                  child: Column(
                    children: [
                      _buildTextField(
                        controller: _companyNameController,
                        label: 'Company name',
                        icon: Icons.business,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _positionController,
                        label: 'Position / job title',
                        icon: Icons.work_outline,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _industryController,
                        label: 'Industry',
                        icon: Icons.domain,
                      ),
                      const SizedBox(height: 16),
                      _buildDropdownField(
                        label: 'Employment type',
                        icon: Icons.schedule_outlined,
                        value: _employmentType,
                        items: _employmentTypes,
                        onChanged: (value) {
                          setState(() {
                            _employmentType = value;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      OnboardingDateTile(
                        label: 'Start date',
                        valueText: _startDate != null
                            ? DateFormat.yMMMd().format(_startDate!)
                            : 'Tap to select',
                        enabled: !_isLoading,
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: _startDate ?? DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime.now(),
                            builder: (context, child) {
                              return Theme(
                                data: Theme.of(context).copyWith(
                                  colorScheme: const ColorScheme.light(
                                    primary: OnboardingTheme.navy,
                                    onPrimary: Colors.white,
                                    onSurface: Colors.black,
                                  ),
                                ),
                                child: child!,
                              );
                            },
                          );
                          if (date != null) {
                            setState(() {
                              _startDate = date;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _salaryRangeController,
                        label: 'Salary range (optional)',
                        icon: Icons.attach_money,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                OnboardingFormCard(
                  title: 'Location',
                  subtitle: 'Where you work (if applicable).',
                  icon: Icons.location_on_outlined,
                  child: Column(
                    children: [
                      _buildTextField(
                        controller: _cityController,
                        label: 'City',
                        icon: Icons.location_city,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _provinceController,
                        label: 'Province',
                        icon: Icons.map,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _countryController,
                        label: 'Country',
                        icon: Icons.public,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              OnboardingFormCard(
                title: 'Contact on record',
                subtitle:
                    'Used to verify your submission. Fields marked * are required.',
                icon: Icons.contact_mail_outlined,
                child: Column(
                  children: [
                    _buildTextField(
                      controller: _emailController,
                      label: 'Email address *',
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your email';
                        }
                        if (!value.contains('@')) {
                          return 'Please enter a valid email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _contactNumberController,
                      label: 'Contact number *',
                      icon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your contact number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _schoolIdController,
                      label: 'School ID number *',
                      icon: Icons.badge_outlined,
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your school ID';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: _isLoading ? null : _handleSubmit,
                      style: FilledButton.styleFrom(
                        backgroundColor: OnboardingTheme.navy,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 2,
                        shadowColor: OnboardingTheme.navy.withValues(
                          alpha: 0.35,
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Submit record',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(width: 8),
                                Icon(Icons.send_rounded, size: 20),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton(
                    onPressed: _isLoading ? null : _handleClear,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: OnboardingTheme.navy,
                      side: BorderSide(color: Colors.grey.shade400),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Clear',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final userId = AppSession.userId;
    if (userId == null) {
      _showError('Please log in to submit your employment record.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final record = EmploymentRecord(
        id: _existingRecord?.id ?? LocalId.generate(),
        userId: userId,
        userName:
            AppSession.currentUser?.userMetadata?['display_name'] as String? ??
            'Unknown',
        userEmail: _emailController.text.trim(),
        schoolId: _schoolIdController.text.trim(),
        employmentStatus: _employmentStatus,
        monthsUnemployed:
            _employmentStatus == 'Unemployed' &&
                _monthsUnemployedController.text.isNotEmpty
            ? int.tryParse(_monthsUnemployedController.text)
            : null,
        companyName:
            _employmentStatus == 'Employed' &&
                _companyNameController.text.isNotEmpty
            ? _companyNameController.text.trim()
            : null,
        position:
            _employmentStatus == 'Employed' &&
                _positionController.text.isNotEmpty
            ? _positionController.text.trim()
            : null,
        industry:
            _employmentStatus == 'Employed' &&
                _industryController.text.isNotEmpty
            ? _industryController.text.trim()
            : null,
        employmentType: _employmentStatus == 'Employed'
            ? _employmentType
            : null,
        startDate: _employmentStatus == 'Employed' ? _startDate : null,
        salaryRange:
            _employmentStatus == 'Employed' &&
                _salaryRangeController.text.isNotEmpty
            ? _salaryRangeController.text.trim()
            : null,
        city: _cityController.text.isNotEmpty
            ? _cityController.text.trim()
            : null,
        province: _provinceController.text.isNotEmpty
            ? _provinceController.text.trim()
            : null,
        country: _countryController.text.isNotEmpty
            ? _countryController.text.trim()
            : null,
        contactNumber: _contactNumberController.text.trim(),
        submittedAt: _existingRecord?.submittedAt ?? DateTime.now(),
        lastUpdated: DateTime.now(),
        verifiedBy: _existingRecord?.verifiedBy,
        verifiedAt: _existingRecord?.verifiedAt,
        verificationStatus: _existingRecord?.verificationStatus ?? 'Pending',
        notes: _existingRecord?.notes,
      );

      await _idTracerService.submitEmploymentRecord(record);

      // Log the action
      await _auditService.logAction(
        action: _existingRecord != null
            ? 'UPDATE_EMPLOYMENT_RECORD'
            : 'SUBMIT_EMPLOYMENT_RECORD',
        resource: 'EmploymentRecord',
        resourceId: record.id,
        description:
            '${_existingRecord != null ? 'Updated' : 'Submitted'} employment record: ${record.employmentStatus}',
        status: 'SUCCESS',
      );

      if (mounted) {
        _showSuccess(
          'Employment record ${_existingRecord != null ? 'updated' : 'submitted'} successfully!',
        );
        await _loadExistingRecord();
        _employmentComplete = true;
        await _loadCompletionState();
      }
    } catch (e) {
      if (mounted) {
        _showError('Error submitting record: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _handleClear() {
    setState(() {
      _monthsUnemployedController.clear();
      _companyNameController.clear();
      _positionController.clear();
      _industryController.clear();
      _employmentType = null;
      _startDate = null;
      _salaryRangeController.clear();
      _cityController.clear();
      _provinceController.clear();
      _countryController.clear();
      _employmentStatus = 'Employed';
    });
    _formKey.currentState?.reset();
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: OnboardingTheme.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 0),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        validator: validator,
        style: const TextStyle(fontSize: 16),
        decoration: onboardingFieldDecoration(label: label, icon: icon),
      ),
    );
  }

  Widget _buildDropdownField({
    required String label,
    required IconData icon,
    required String? value,
    required List<String> items,
    required Function(String?) onChanged,
  }) {
    final selected = value != null && items.contains(value) ? value : null;
    return DropdownButtonFormField<String>(
      key: ValueKey<String?>('$label|$selected'),
      initialValue: selected,
      borderRadius: PortalMenu.dropdownRadius,
      dropdownColor: PortalTheme.card,
      icon: const Icon(Icons.arrow_drop_down, color: OnboardingTheme.navy),
      decoration: onboardingFieldDecoration(label: label, icon: icon),
      items: items.map((item) {
        return DropdownMenuItem<String>(value: item, child: Text(item));
      }).toList(),
      onChanged: onChanged,
    );
  }
}

class _CompletionBadge extends StatelessWidget {
  const _CompletionBadge({
    required this.percentage,
    required this.demographicDone,
    required this.employmentDone,
  });

  final int percentage;
  final bool demographicDone;
  final bool employmentDone;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 112),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: 0.18),
              Colors.white.withValues(alpha: 0.08),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.insights_outlined,
                    size: 11,
                    color: Colors.white70,
                  ),
                  const SizedBox(width: 3),
                  const Text(
                    'Progress',
                    style: TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w600,
                      fontSize: 9.5,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '$percentage%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: (percentage / 100).clamp(0.0, 1.0),
                minHeight: 4,
                backgroundColor: Colors.white24,
                color: OnboardingTheme.gold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
