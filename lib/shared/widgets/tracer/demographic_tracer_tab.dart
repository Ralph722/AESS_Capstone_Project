import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:alumni_system/core/constants/course_constants.dart';
import 'package:alumni_system/core/constants/program_constants.dart';
import 'package:alumni_system/features/alumni/tracer/models/tracer_profile_model.dart';
import 'package:alumni_system/core/services/app_session.dart';
import 'package:alumni_system/features/alumni/profile/data/user_profile_service.dart';
import 'package:alumni_system/shared/widgets/onboarding/onboarding_ui.dart';
import 'package:alumni_system/shared/widgets/user/portal_menu.dart';
import 'package:alumni_system/shared/widgets/user/portal_skeletons.dart';
import 'package:alumni_system/shared/widgets/user/portal_theme.dart';

/// Demographic (ID Tracer) fields — editable, saved to `users/{uid}`.
class DemographicTracerTab extends StatefulWidget {
  const DemographicTracerTab({super.key, this.onSaved});

  final VoidCallback? onSaved;

  @override
  State<DemographicTracerTab> createState() => _DemographicTracerTabState();
}

class _DemographicTracerTabState extends State<DemographicTracerTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  final _formKey = GlobalKey<FormState>();
  final _profileService = UserProfileService();

  final _nameController = TextEditingController();
  final _studentIdController = TextEditingController();
  final _batchController = TextEditingController();
  final _yearGraduatedController = TextEditingController();
  final _contactController = TextEditingController();
  final _addressController = TextEditingController();

  String _program = '';
  String _gender = '';
  String _civilStatus = '';
  DateTime? _birthDate;

  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _studentIdController.dispose();
    _batchController.dispose();
    _yearGraduatedController.dispose();
    _contactController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final userId = AppSession.userId;
    if (userId == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    final profile = await _profileService.getTracerProfile(userId);
    if (!mounted) return;

    if (profile != null) {
      _nameController.text = profile.displayName;
      _studentIdController.text = profile.studentId;
      _program = CourseConstants.normalize(profile.program) ?? profile.program;
      _batchController.text = profile.batchYear;
      _yearGraduatedController.text = profile.yearGraduated;
      _contactController.text = profile.contactNumber;
      _addressController.text = profile.address;
      _gender = profile.gender;
      _civilStatus = profile.civilStatus;
      _birthDate = profile.birthDate;
    }

    setState(() => _loading = false);
  }

  Future<void> _pickBirthDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(2000),
      firstDate: DateTime(1950),
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
    if (picked != null) setState(() => _birthDate = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_gender.isEmpty) {
      _snack('Select your gender.', isError: true);
      return;
    }

    final userId = AppSession.userId;
    if (userId == null) return;

    setState(() => _saving = true);
    try {
      final profile = TracerProfile(
        uid: userId,
        email: AppSession.email ?? '',
        displayName: _nameController.text.trim(),
        studentId: _studentIdController.text.trim(),
        program: _program,
        batchYear: _batchController.text.trim(),
        yearGraduated: _yearGraduatedController.text.trim(),
        mobileNumber: _contactController.text.trim(),
        address: _addressController.text.trim(),
        gender: _gender,
        civilStatus: _civilStatus,
        birthDate: _birthDate,
      );

      await _profileService.saveTracerProfile(profile);

      if (!mounted) return;
      final saved = await _profileService.getTracerProfile(userId);
      _snack(
        saved?.isComplete == true
            ? 'Demographic profile saved successfully.'
            : 'Demographic profile saved.',
      );
      widget.onSaved?.call();
    } catch (e) {
      _snack('Could not save: $e', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : OnboardingTheme.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_loading) {
      return const TracerFormSkeleton(fieldCount: 8);
    }

    return Form(
      key: _formKey,
      child: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _introCard(),
          const SizedBox(height: 20),
          OnboardingFormCard(
            title: 'Demographic information',
            subtitle:
                'Required for the graduate tracer study (all programs). '
                'Fields marked * are required.',
            icon: Icons.badge_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _field(
                  controller: _nameController,
                  label: 'Full name *',
                  icon: Icons.person_outline,
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Required' : null,
                ),
                _field(
                  controller: _studentIdController,
                  label: 'ID number',
                  icon: Icons.badge_outlined,
                  hint: 'Set by the alumni office',
                  readOnly: true,
                ),
                _dropdown(
                  label: 'Course',
                  value: _program.isEmpty ? null : _program,
                  items: CourseConstants.courses,
                  icon: Icons.menu_book_outlined,
                  onChanged: null,
                ),
                _field(
                  controller: _batchController,
                  label: 'Batch year *',
                  icon: Icons.calendar_today_outlined,
                  hint: 'e.g. 2024',
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Required' : null,
                ),
                _field(
                  controller: _yearGraduatedController,
                  label: 'Year graduated',
                  icon: Icons.school_outlined,
                  hint: 'Same as batch if applicable',
                ),
                _field(
                  controller: _contactController,
                  label: 'Contact number *',
                  icon: Icons.phone_outlined,
                  keyboard: TextInputType.phone,
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Required' : null,
                ),
                _field(
                  controller: _addressController,
                  label: 'Address *',
                  icon: Icons.home_outlined,
                  maxLines: 2,
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Required' : null,
                ),
                _dropdown(
                  label: 'Gender *',
                  value: _gender.isEmpty ? null : _gender,
                  items: ProgramConstants.genders,
                  icon: Icons.wc_outlined,
                  onChanged: (v) => setState(() => _gender = v ?? ''),
                ),
                _dropdown(
                  label: 'Civil status (optional)',
                  value: _civilStatus.isEmpty ? null : _civilStatus,
                  items: ProgramConstants.civilStatuses,
                  icon: Icons.favorite_outline,
                  onChanged: (v) => setState(() => _civilStatus = v ?? ''),
                ),
                OnboardingDateTile(
                  label: 'Birth date (optional)',
                  valueText: _birthDate != null
                      ? DateFormat.yMMMd().format(_birthDate!)
                      : 'Tap to choose',
                  enabled: !_saving,
                  onTap: _pickBirthDate,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: OnboardingTheme.navy,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 2,
                shadowColor: OnboardingTheme.navy.withValues(alpha: 0.35),
              ),
              child: _saving
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
                          'Save demographics',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(Icons.save_rounded, size: 20),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _introCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [OnboardingTheme.navy, OnboardingTheme.navyLight],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: OnboardingTheme.navy.withValues(alpha: 0.25),
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
              Icon(Icons.fact_check_outlined, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text(
                'Demographic profile',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Complete your personal details to unlock full tracer completion and make your profile easier to verify.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 13,
              height: 1.35,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    int maxLines = 1,
    TextInputType? keyboard,
    String? Function(String?)? validator,
    bool readOnly = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        readOnly: readOnly,
        maxLines: maxLines,
        keyboardType: keyboard,
        validator: validator,
        decoration: onboardingFieldDecoration(
          label: label,
          hint: hint,
          icon: icon,
        ),
      ),
    );
  }

  Widget _dropdown({
    required String label,
    required String? value,
    required List<String> items,
    required void Function(String?)? onChanged,
    IconData icon = Icons.list_alt_outlined,
  }) {
    final selected = value != null && items.contains(value) ? value : null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        key: ValueKey<String?>('$label|$selected'),
        initialValue: selected,
        borderRadius: PortalMenu.dropdownRadius,
        dropdownColor: PortalTheme.card,
        decoration: onboardingFieldDecoration(label: label, icon: icon),
        items: items
            .map((e) => DropdownMenuItem(value: e, child: Text(e)))
            .toList(),
        onChanged: onChanged,
      ),
    );
  }
}
