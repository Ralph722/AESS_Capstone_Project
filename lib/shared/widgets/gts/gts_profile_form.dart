import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:alumni_system/core/constants/course_constants.dart';
import 'package:alumni_system/core/constants/gts_constants.dart';
import 'package:alumni_system/core/constants/philippine_location_constants.dart';
import 'package:alumni_system/features/alumni/tracer/models/tracer_profile_model.dart';
import 'package:alumni_system/shared/widgets/onboarding/onboarding_ui.dart';
import 'package:alumni_system/shared/widgets/user/portal_menu.dart';
import 'package:alumni_system/shared/widgets/user/portal_theme.dart';

/// Mutable GTS live-profile field state — shared by onboarding and Profile screen.
class GtsProfileFormState {
  GtsProfileFormState() {
    displayNameController = TextEditingController();
    addressController = TextEditingController();
    emailController = TextEditingController();
    telephoneController = TextEditingController();
    mobileController = TextEditingController();
    provinceController = TextEditingController();
    collegeController = TextEditingController(
      text: GtsConstants.defaultCollegeUniversity,
    );
    yearGraduatedController = TextEditingController();
    honorsController = TextEditingController();
  }

  late final TextEditingController displayNameController;
  late final TextEditingController addressController;
  late final TextEditingController emailController;
  late final TextEditingController telephoneController;
  late final TextEditingController mobileController;
  late final TextEditingController provinceController;
  late final TextEditingController collegeController;
  late final TextEditingController yearGraduatedController;
  late final TextEditingController honorsController;

  String civilStatus = '';
  String gender = '';
  DateTime? birthDate;
  String regionOfOrigin = '';
  String locationOfResidence = '';
  String program = '';
  String employmentStatus = '';
  String studentId = '';
  String batchYear = '';

  void dispose() {
    displayNameController.dispose();
    addressController.dispose();
    emailController.dispose();
    telephoneController.dispose();
    mobileController.dispose();
    provinceController.dispose();
    collegeController.dispose();
    yearGraduatedController.dispose();
    honorsController.dispose();
  }

  void applyFromProfile(TracerProfile profile) {
    displayNameController.text = profile.displayName;
    addressController.text = profile.address;
    emailController.text = profile.email;
    telephoneController.text = profile.telephoneNumber;
    mobileController.text = profile.mobileNumber;
    provinceController.text = profile.province;
    collegeController.text = profile.collegeUniversity.isNotEmpty
        ? profile.collegeUniversity
        : GtsConstants.defaultCollegeUniversity;
    yearGraduatedController.text = profile.yearGraduated;
    honorsController.text = profile.honorsAwards;
    civilStatus = profile.civilStatus;
    gender = profile.gender;
    birthDate = profile.birthDate;
    regionOfOrigin = profile.regionOfOrigin;
    locationOfResidence = profile.locationOfResidence;
    program = CourseConstants.normalize(profile.program) ?? profile.program;
    employmentStatus = profile.employmentStatus;
    studentId = profile.studentId;
    batchYear = profile.batchYear;
  }

  TracerProfile toTracerProfile({required String uid, required String email}) {
    final resolvedEmail = emailController.text.trim().isNotEmpty
        ? emailController.text.trim()
        : email;
    return TracerProfile(
      uid: uid,
      email: resolvedEmail,
      displayName: displayNameController.text.trim(),
      studentId: studentId,
      program: program,
      batchYear: batchYear.isNotEmpty
          ? batchYear
          : yearGraduatedController.text.trim(),
      yearGraduated: yearGraduatedController.text.trim(),
      telephoneNumber: telephoneController.text.trim(),
      mobileNumber: mobileController.text.trim(),
      address: addressController.text.trim(),
      gender: gender,
      civilStatus: civilStatus,
      birthDate: birthDate,
      regionOfOrigin: regionOfOrigin,
      province: provinceController.text.trim(),
      locationOfResidence: locationOfResidence,
      collegeUniversity: collegeController.text.trim(),
      honorsAwards: honorsController.text.trim(),
      employmentStatus: employmentStatus,
    );
  }

  Map<String, dynamic> completionPayload({bool includeEmployment = true}) {
    final payload = {
      'displayName': displayNameController.text,
      'address': addressController.text,
      'email': emailController.text,
      'telephoneNumber': telephoneController.text,
      'mobileNumber': mobileController.text,
      'civilStatus': civilStatus,
      'gender': gender,
      'birthDate': birthDate,
      'regionOfOrigin': regionOfOrigin,
      'province': provinceController.text,
      'locationOfResidence': locationOfResidence,
      'program': program,
      'collegeUniversity': collegeController.text,
      'yearGraduated': yearGraduatedController.text,
    };
    if (includeEmployment) {
      payload['employmentStatus'] = employmentStatus;
    }
    return payload;
  }
}

/// GTS Section A + B item 12 form fields with exact CHED labels.
class GtsProfileFormFields extends StatelessWidget {
  const GtsProfileFormFields({
    super.key,
    required this.state,
    required this.onChanged,
    this.emailReadOnly = false,
    this.showEmploymentStatus = false,
    this.showProgress = false,
    this.enabled = true,
    this.chedStyleLabels = true,
  });

  final GtsProfileFormState state;
  final VoidCallback onChanged;
  final bool emailReadOnly;
  final bool showEmploymentStatus;
  final bool showProgress;
  final bool enabled;

  /// CHED paper-form headings ("A. General Information", "Item 12") and `*`
  /// on required labels. Off for the Profile screen's plainer look; required
  /// fields still validate either way.
  final bool chedStyleLabels;

  String _req(String label) => chedStyleLabels ? '$label *' : label;

  static const _fieldStyle = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w500,
    color: OnboardingTheme.navy,
  );

  @override
  Widget build(BuildContext context) {
    final payload = state.completionPayload(
      includeEmployment: showEmploymentStatus,
    );
    final filled = showEmploymentStatus
        ? TracerProfile.countFilledRequiredFields(payload)
        : TracerProfile.countFilledProfileFields(payload);
    final total = showEmploymentStatus
        ? TracerProfile.fullProfileFieldCount
        : TracerProfile.profileFieldCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showProgress)
          OnboardingProfileProgress(filled: filled, total: total),
        OnboardingSectionGroup(
          title: chedStyleLabels
              ? 'A. General Information'
              : 'General information',
          icon: Icons.person_outline,
          children: [
            _text(
              controller: state.displayNameController,
              label: _req(GtsConstants.labelName),
              icon: Icons.person_outline,
            ),
            _text(
              controller: state.addressController,
              label: _req(GtsConstants.labelPermanentAddress),
              icon: Icons.home_outlined,
              maxLines: 2,
            ),
            _text(
              controller: state.emailController,
              label: _req(GtsConstants.labelEmail),
              icon: Icons.email_outlined,
              readOnly: emailReadOnly,
              helperText: emailReadOnly ? 'From your account' : null,
              keyboard: TextInputType.emailAddress,
            ),
            _text(
              controller: state.telephoneController,
              label: _req(GtsConstants.labelTelephone),
              icon: Icons.phone_outlined,
              keyboard: TextInputType.phone,
            ),
            _text(
              controller: state.mobileController,
              label: _req(GtsConstants.labelMobile),
              icon: Icons.smartphone_outlined,
              keyboard: TextInputType.phone,
            ),
            _dropdown(
              label: _req(GtsConstants.labelCivilStatus),
              value: state.civilStatus,
              items: GtsConstants.civilStatuses,
              icon: Icons.favorite_outline,
              onChanged: (v) {
                state.civilStatus = v ?? '';
                onChanged();
              },
            ),
            _dropdown(
              label: _req(GtsConstants.labelSex),
              value: state.gender,
              items: GtsConstants.sexOptions,
              icon: Icons.wc_outlined,
              onChanged: (v) {
                state.gender = v ?? '';
                onChanged();
              },
            ),
            OnboardingDateTile(
              label: _req(GtsConstants.labelBirthday),
              valueText: state.birthDate != null
                  ? DateFormat.yMMMd().format(state.birthDate!)
                  : 'Tap to choose date',
              hasValue: state.birthDate != null,
              enabled: enabled,
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: state.birthDate ?? DateTime(2000),
                  firstDate: DateTime(1950),
                  lastDate: DateTime.now(),
                );
                if (picked != null) {
                  state.birthDate = picked;
                  onChanged();
                }
              },
            ),
            _dropdown(
              label: _req(GtsConstants.labelRegionOfOrigin),
              value: state.regionOfOrigin,
              items: PhilippineLocationConstants.regions,
              icon: Icons.map_outlined,
              onChanged: (v) {
                final region = v ?? '';
                state.regionOfOrigin = region;
                final allowed = PhilippineLocationConstants.provincesForRegion(
                  region,
                );
                if (state.provinceController.text.isNotEmpty &&
                    !allowed.contains(state.provinceController.text)) {
                  state.provinceController.clear();
                }
                onChanged();
              },
            ),
            _provinceField(context),
            _dropdown(
              label: _req(GtsConstants.labelLocationOfResidence),
              value: state.locationOfResidence,
              items: GtsConstants.locationOfResidenceOptions,
              icon: Icons.location_city_outlined,
              onChanged: (v) {
                state.locationOfResidence = v ?? '';
                onChanged();
              },
            ),
          ],
        ),
        OnboardingSectionGroup(
          title: chedStyleLabels
              ? 'B. Educational Background — Item 12'
              : 'Educational background',
          icon: Icons.school_outlined,
          children: [
            _dropdown(
              label: _req(GtsConstants.labelDegreeSpecialization),
              value: state.program.isEmpty ? null : state.program,
              items: CourseConstants.courses,
              icon: Icons.menu_book_outlined,
              onChanged: (v) {
                state.program = v ?? '';
                onChanged();
              },
            ),
            _text(
              controller: state.collegeController,
              label: _req(GtsConstants.labelCollegeUniversity),
              icon: Icons.school_outlined,
              minLines: 1,
              maxLines: 4,
            ),
            _text(
              controller: state.yearGraduatedController,
              label: _req(GtsConstants.labelYearGraduated),
              icon: Icons.calendar_today_outlined,
              hint: 'e.g. 2024',
              keyboard: TextInputType.number,
            ),
            _text(
              controller: state.honorsController,
              label: GtsConstants.labelHonorsAwards,
              icon: Icons.emoji_events_outlined,
              required: false,
            ),
          ],
        ),
        if (showEmploymentStatus)
          OnboardingSectionGroup(
            title: _req(GtsConstants.labelEmploymentStatus),
            icon: Icons.work_outline,
            children: [
              OnboardingGtsEmploymentStatus(
                value: state.employmentStatus,
                enabled: enabled,
                onChanged: (v) {
                  state.employmentStatus = v;
                  onChanged();
                },
              ),
            ],
          ),
      ],
    );
  }

  Widget _provinceField(BuildContext context) {
    final provinces = PhilippineLocationConstants.provincesForRegion(
      state.regionOfOrigin,
    );
    final value = state.provinceController.text.trim();

    return Padding(
      padding: const EdgeInsets.only(bottom: OnboardingSpacing.fieldGap),
      child: FormField<String>(
        initialValue: value.isEmpty ? null : value,
        validator: (v) {
          final current = state.provinceController.text.trim();
          return current.isEmpty ? 'Required' : null;
        },
        builder: (field) {
          return InkWell(
            onTap: !enabled
                ? null
                : () async {
                    final picked = await showProvincePicker(
                      context: context,
                      provinces: provinces,
                      selected: value.isEmpty ? null : value,
                    );
                    if (picked == null) return;
                    state.provinceController.text = picked;
                    final mapped =
                        PhilippineLocationConstants.regionForProvince(picked);
                    if (mapped != null &&
                        (state.regionOfOrigin.isEmpty ||
                            state.regionOfOrigin != mapped)) {
                      state.regionOfOrigin = mapped;
                    }
                    field.didChange(picked);
                    onChanged();
                  },
            borderRadius: BorderRadius.circular(OnboardingSpacing.inputRadius),
            child: InputDecorator(
              decoration:
                  onboardingFieldDecoration(
                    label: _req(GtsConstants.labelProvince),
                    icon: Icons.location_on_outlined,
                    hint: 'Search and select province',
                  ).copyWith(
                    errorText: field.errorText,
                    suffixIcon: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: OnboardingTheme.muted,
                    ),
                  ),
              child: Text(
                value.isEmpty ? 'Search and select province' : value,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: value.isEmpty ? FontWeight.w400 : FontWeight.w500,
                  color: value.isEmpty
                      ? OnboardingTheme.muted
                      : OnboardingTheme.navy,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _text({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int minLines = 1,
    int maxLines = 1,
    TextInputType? keyboard,
    String? hint,
    String? helperText,
    bool readOnly = false,
    bool required = true,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: OnboardingSpacing.fieldGap),
      child: TextFormField(
        controller: controller,
        minLines: minLines,
        maxLines: maxLines,
        keyboardType: keyboard,
        readOnly: readOnly,
        enabled: enabled,
        style: _fieldStyle,
        validator: required
            ? (v) => v == null || v.trim().isEmpty ? 'Required' : null
            : null,
        decoration: onboardingFieldDecoration(
          label: label,
          hint: hint,
          icon: icon,
          readOnly: readOnly,
          helperText: helperText,
        ),
      ),
    );
  }

  Widget _dropdown({
    required String label,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    IconData icon = Icons.list_alt_outlined,
    bool required = true,
  }) {
    final selected = value != null && value.isNotEmpty && items.contains(value)
        ? value
        : null;
    return Padding(
      padding: const EdgeInsets.only(bottom: OnboardingSpacing.fieldGap),
      child: DropdownButtonFormField<String>(
        key: ValueKey<String?>('$label|$selected'),
        initialValue: selected,
        style: _fieldStyle,
        isExpanded: true,
        borderRadius: PortalMenu.dropdownRadius,
        dropdownColor: PortalTheme.card,
        decoration: onboardingFieldDecoration(label: label, icon: icon),
        hint: const Text(
          'Select',
          style: TextStyle(
            color: OnboardingTheme.muted,
            fontWeight: FontWeight.w400,
          ),
        ),
        items: items
            .map(
              (e) => DropdownMenuItem(
                value: e,
                child: Text(e, overflow: TextOverflow.ellipsis),
              ),
            )
            .toList(),
        validator: required
            ? (v) => v == null || v.isEmpty ? 'Required' : null
            : null,
        onChanged: enabled ? onChanged : null,
      ),
    );
  }
}

/// Three-way employment status selector with clear selected state.
class OnboardingGtsEmploymentStatus extends StatelessWidget {
  const OnboardingGtsEmploymentStatus({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final String value;
  final ValueChanged<String> onChanged;
  final bool enabled;

  IconData _iconFor(String status) {
    if (status == GtsConstants.employed) return Icons.work_outline;
    if (status == GtsConstants.unemployed) return Icons.person_search_outlined;
    return Icons.school_outlined;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: OnboardingSpacing.fieldGap),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 420;
          final children = GtsConstants.employmentStatuses.map((status) {
            final selected = value == status;
            final card = Material(
              color: selected
                  ? OnboardingTheme.navy.withValues(alpha: 0.08)
                  : Colors.white,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                onTap: enabled ? () => onChanged(status) : null,
                borderRadius: BorderRadius.circular(14),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: narrow ? double.infinity : null,
                  padding: const EdgeInsets.symmetric(
                    vertical: 14,
                    horizontal: 10,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: selected
                          ? OnboardingTheme.navy
                          : OnboardingTheme.border,
                      width: selected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        selected ? Icons.check_circle : _iconFor(status),
                        size: 18,
                        color: selected
                            ? OnboardingTheme.navy
                            : OnboardingTheme.muted,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          status,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: selected
                                ? OnboardingTheme.navy
                                : OnboardingTheme.muted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
            return narrow
                ? Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: card,
                  )
                : Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        right: status != GtsConstants.neverEmployed ? 8 : 0,
                      ),
                      child: card,
                    ),
                  );
          }).toList();

          if (narrow) {
            return Column(children: children);
          }
          return Row(children: children);
        },
      ),
    );
  }
}
