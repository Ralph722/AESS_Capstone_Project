import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:alumni_system/core/constants/course_constants.dart';
import 'package:alumni_system/core/constants/gts_constants.dart';
import 'package:alumni_system/core/constants/philippine_location_constants.dart';
import 'package:alumni_system/features/alumni/tracer/models/tracer_profile_model.dart';
import 'package:alumni_system/features/contact_verification/data/contact_verification_service.dart';
import 'package:alumni_system/shared/widgets/onboarding/onboarding_ui.dart';
import 'package:alumni_system/shared/widgets/user/portal_menu.dart';
import 'package:alumni_system/shared/widgets/user/portal_theme.dart';

/// Mutable GTS live-profile field state — shared by onboarding and Profile screen.
class GtsProfileFormState {
  GtsProfileFormState() {
    displayNameController = TextEditingController();
    addressController = TextEditingController();
    emailController = TextEditingController();
    contactEmailController = TextEditingController();
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

  /// Contact email (separate from the login email); only shown when
  /// [GtsProfileFormFields.showContactEmail] is on.
  late final TextEditingController contactEmailController;
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

  /// Once a graduation year is on file only the alumni office can change it.
  bool yearLocked = false;

  /// Name as loaded from the verified record. Name is read-only in this
  /// form; only the Tracer marriage flow may change it (server RPC).
  String savedDisplayName = '';

  /// Contacts as saved when the profile was loaded.
  String savedContactEmail = '';
  String savedMobile = '';

  String savedContact(ContactChannel channel) => switch (channel) {
    ContactChannel.email => savedContactEmail,
    ContactChannel.mobile => savedMobile,
  };

  String currentContact(ContactChannel channel) => switch (channel) {
    ContactChannel.email => contactEmailController.text.trim(),
    ContactChannel.mobile => mobileController.text.trim(),
  };

  /// Whether [channel] was edited away from the saved value (formatting
  /// alone does not count; a cleared field is caught by validation).
  bool contactChanged(ContactChannel channel) {
    final now = currentContact(channel);
    return now.isNotEmpty &&
        !ContactNormalizer.same(channel, now, savedContact(channel));
  }

  void dispose() {
    displayNameController.dispose();
    addressController.dispose();
    emailController.dispose();
    contactEmailController.dispose();
    telephoneController.dispose();
    mobileController.dispose();
    provinceController.dispose();
    collegeController.dispose();
    yearGraduatedController.dispose();
    honorsController.dispose();
  }

  void applyFromProfile(TracerProfile profile) {
    displayNameController.text = profile.displayName;
    savedDisplayName = profile.displayName.trim();
    addressController.text = profile.address;
    emailController.text = profile.email;
    contactEmailController.text = profile.preferredEmail;
    savedContactEmail = profile.preferredEmail;
    telephoneController.text = profile.telephoneNumber;
    mobileController.text = profile.mobileNumber;
    savedMobile = profile.mobileNumber;
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
    yearLocked = profile.yearGraduated.trim().isNotEmpty;

    _loaded = _snapshot();
    // The college field falls back to a default, which is not "on record".
    if (profile.collegeUniversity.isEmpty) _loaded.remove('collegeUniversity');
  }

  /// Required-field values as loaded from the saved record.
  Map<String, String> _loaded = const {};

  Map<String, String> _snapshot() => {
    for (final e in completionPayload().entries)
      e.key: e.value?.toString().trim() ?? '',
  };

  /// Whether [key] still holds the non-empty value loaded from the record.
  bool isFromRecord(String key) {
    final loaded = _loaded[key];
    if (loaded == null || loaded.isEmpty) return false;
    return _snapshot()[key] == loaded;
  }

  List<String> missingRequiredKeys() =>
      TracerProfile.missingRequiredKeys(completionPayload());

  /// Filled required fields in [section] (for "3 of 4" counters).
  int filledInSection(GtsFormSection section) {
    final missing = missingRequiredKeys().toSet();
    return section.requiredKeys.where((k) => !missing.contains(k)).length;
  }

  TracerProfile toTracerProfile({required String uid, required String email}) {
    final resolvedEmail = emailController.text.trim().isNotEmpty
        ? emailController.text.trim()
        : email;
    return TracerProfile(
      uid: uid,
      email: resolvedEmail,
      // Never persist a form-edited name; renames go through the RPC.
      displayName: savedDisplayName.isNotEmpty
          ? savedDisplayName
          : displayNameController.text.trim(),
      studentId: studentId,
      program: program,
      batchYear: yearGraduatedController.text.trim(),
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

/// Field groups for rendering the GTS form one step at a time.
enum GtsFormSection {
  /// Name, sex, civil status, birthday.
  personal(['displayName', 'gender', 'civilStatus', 'birthDate']),

  /// Address, email, phone numbers, region, province, residence.
  contact([
    'address',
    'email',
    'telephoneNumber',
    'mobileNumber',
    'regionOfOrigin',
    'province',
    'locationOfResidence',
  ]),

  /// Degree, college, year graduated, honors (+ employment status).
  education([
    'program',
    'collegeUniversity',
    'yearGraduated',
    'employmentStatus',
  ]);

  const GtsFormSection(this.requiredKeys);

  /// Keys from [TracerProfile.requiredFieldKeys] collected in this section.
  final List<String> requiredKeys;
}

/// GTS Section A + B item 12 form fields with exact CHED labels.
class GtsProfileFormFields extends StatelessWidget {
  const GtsProfileFormFields({
    super.key,
    required this.state,
    required this.onChanged,
    this.emailReadOnly = false,
    this.showEmploymentStatus = false,
    this.enabled = true,
    this.chedStyleLabels = true,
    this.section,
    this.showContactEmail = false,
    this.contactFooter,
  });

  final GtsProfileFormState state;
  final VoidCallback onChanged;
  final bool emailReadOnly;

  /// Full-form mode: the email field becomes "Login email" and an editable
  /// contact email follows it. A changed contact email or mobile number must
  /// be valid so it can be verified.
  final bool showContactEmail;

  /// Full-form mode: shown under the contact email and mobile fields
  /// (verification status).
  final Widget? Function(ContactChannel channel)? contactFooter;
  final bool showEmploymentStatus;
  final bool enabled;

  /// When set, renders only that group's fields as a flat column (no section
  /// cards) so the caller can supply its own chrome.
  final GtsFormSection? section;

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
    final only = section;
    if (only != null) {
      // Single-section (step) mode: office-managed values are locked rows and
      // every required field — including birthday and employment — validates
      // inline so the step can block until it is complete.
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: switch (only) {
          GtsFormSection.personal => [
            _nameField(),
            _sexField(),
            _civilStatusField(),
            _requiredBirthdayField(context),
          ],
          GtsFormSection.contact => [
            _addressField(),
            if (emailReadOnly)
              _lockedRow(
                icon: Icons.email_outlined,
                label: GtsConstants.labelEmail,
                value: state.emailController.text.trim(),
                caption: 'From your account',
              )
            else
              _emailField(),
            _telephoneField(),
            _mobileField(),
            _regionField(),
            _provinceField(context),
            _residenceField(),
          ],
          GtsFormSection.education => [
            _lockedProgramRow(),
            _collegeField(),
            if (state.yearLocked)
              _lockedRow(
                icon: Icons.calendar_today_outlined,
                label: GtsConstants.labelYearGraduated,
                value: state.yearGraduatedController.text.trim(),
                caption: 'Contact the alumni office to change this',
              )
            else
              _yearGraduatedField(),
            _honorsField(),
            if (showEmploymentStatus) ...[
              Padding(
                padding: const EdgeInsets.only(
                  top: OnboardingSpacing.xs,
                  bottom: OnboardingSpacing.sm,
                ),
                child: Text(
                  _req(GtsConstants.labelEmploymentStatus),
                  style: PortalTheme.cardTitle,
                ),
              ),
              _requiredEmploymentField(),
            ],
          ],
        },
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OnboardingSectionGroup(
          title: chedStyleLabels
              ? 'A. General Information'
              : 'General information',
          icon: Icons.person_outline,
          children: [
            _nameField(),
            _addressField(),
            if (showContactEmail) ...[
              _contactEmailField(),
              ?contactFooter?.call(ContactChannel.email),
            ] else
              _emailField(),
            _telephoneField(),
            _mobileField(),
            ?contactFooter?.call(ContactChannel.mobile),
            _civilStatusField(),
            _sexField(),
            _birthdayField(context),
            _regionField(),
            _provinceField(context),
            _residenceField(),
          ],
        ),
        OnboardingSectionGroup(
          title: chedStyleLabels
              ? 'B. Educational Background — Item 12'
              : 'Educational background',
          icon: Icons.school_outlined,
          children: [
            _programField(),
            _collegeField(),
            _yearGraduatedField(),
            _honorsField(),
          ],
        ),
        if (showEmploymentStatus)
          OnboardingSectionGroup(
            title: _req(GtsConstants.labelEmploymentStatus),
            icon: Icons.work_outline,
            children: [_employmentField()],
          ),
      ],
    );
  }

  /// Step mode only: reassures that an untouched value came from the record.
  String? _recordHint(String key) => section != null && state.isFromRecord(key)
      ? 'From your alumni record'
      : null;

  Widget _nameField() => _text(
    controller: state.displayNameController,
    label: _req(GtsConstants.labelName),
    icon: Icons.person_outline,
    // Locked once a verified name is on file (empty record can still fill it).
    readOnly: state.savedDisplayName.isNotEmpty,
    helperText: state.savedDisplayName.isNotEmpty
        ? 'Verified at registration'
        : _recordHint('displayName'),
  );

  Widget _addressField() => _text(
    controller: state.addressController,
    label: _req(GtsConstants.labelPermanentAddress),
    icon: Icons.home_outlined,
    maxLines: 2,
    helperText: _recordHint('address'),
  );

  Widget _emailField() => _text(
    controller: state.emailController,
    label: showContactEmail ? 'Login email' : _req(GtsConstants.labelEmail),
    icon: showContactEmail ? Icons.lock_outline : Icons.email_outlined,
    readOnly: emailReadOnly,
    helperText: showContactEmail
        ? 'Used to sign in'
        : emailReadOnly
        ? 'From your account'
        : null,
    keyboard: TextInputType.emailAddress,
  );

  Widget _contactEmailField() => _text(
    controller: state.contactEmailController,
    label: _req(GtsConstants.labelEmail),
    icon: Icons.email_outlined,
    keyboard: TextInputType.emailAddress,
    helperText:
        'This is also how you sign in. Changing it needs a one-time code.',
    validator: (v) => _contactError(ContactChannel.email, v),
  );

  /// Required; a changed value must be one that can be verified.
  String? _contactError(ContactChannel channel, String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Required';
    if (showContactEmail &&
        state.contactChanged(channel) &&
        ContactNormalizer.normalize(channel, v) == null) {
      return ContactNormalizer.invalidMessage(channel);
    }
    return null;
  }

  Widget _telephoneField() => _text(
    controller: state.telephoneController,
    label: _req(GtsConstants.labelTelephone),
    icon: Icons.phone_outlined,
    keyboard: TextInputType.phone,
    helperText: _recordHint('telephoneNumber'),
  );

  Widget _mobileField() => _text(
    controller: state.mobileController,
    label: _req(GtsConstants.labelMobile),
    icon: Icons.smartphone_outlined,
    keyboard: TextInputType.phone,
    helperText: _recordHint('mobileNumber'),
    validator: (v) => _contactError(ContactChannel.mobile, v),
  );

  Widget _civilStatusField() => _dropdown(
    label: _req(GtsConstants.labelCivilStatus),
    value: state.civilStatus,
    items: GtsConstants.civilStatuses,
    icon: Icons.favorite_outline,
    helperText: _recordHint('civilStatus'),
    onChanged: (v) {
      state.civilStatus = v ?? '';
      onChanged();
    },
  );

  Widget _sexField() => _dropdown(
    label: _req(GtsConstants.labelSex),
    value: state.gender,
    items: GtsConstants.sexOptions,
    icon: Icons.wc_outlined,
    helperText: _recordHint('gender'),
    onChanged: (v) {
      state.gender = v ?? '';
      onChanged();
    },
  );

  Widget _birthdayField(BuildContext context) => OnboardingDateTile(
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
  );

  Widget _regionField() => _dropdown(
    label: _req(GtsConstants.labelRegionOfOrigin),
    value: state.regionOfOrigin,
    items: PhilippineLocationConstants.regions,
    icon: Icons.map_outlined,
    helperText: _recordHint('regionOfOrigin'),
    onChanged: (v) {
      final region = v ?? '';
      state.regionOfOrigin = region;
      final allowed = PhilippineLocationConstants.provincesForRegion(region);
      if (state.provinceController.text.isNotEmpty &&
          !allowed.contains(state.provinceController.text)) {
        state.provinceController.clear();
      }
      onChanged();
    },
  );

  Widget _residenceField() => _dropdown(
    label: _req(GtsConstants.labelLocationOfResidence),
    value: state.locationOfResidence,
    items: GtsConstants.locationOfResidenceOptions,
    icon: Icons.location_city_outlined,
    helperText: _recordHint('locationOfResidence'),
    onChanged: (v) {
      state.locationOfResidence = v ?? '';
      onChanged();
    },
  );

  Widget _programField() => Padding(
    padding: const EdgeInsets.only(bottom: OnboardingSpacing.fieldGap),
    child: TextFormField(
      key: ValueKey<String>('program|${state.program}'),
      initialValue: state.program,
      readOnly: true,
      enabled: enabled,
      style: _fieldStyle,
      decoration: onboardingFieldDecoration(
        label: GtsConstants.labelDegreeSpecialization,
        hint: 'Not set yet',
        icon: Icons.menu_book_outlined,
        readOnly: true,
        helperText: 'Set by the alumni office',
      ),
    ),
  );

  Widget _collegeField() => _text(
    controller: state.collegeController,
    label: _req(GtsConstants.labelCollegeUniversity),
    icon: Icons.school_outlined,
    minLines: 1,
    maxLines: 4,
    helperText: _recordHint('collegeUniversity'),
  );

  Widget _yearGraduatedField() => _text(
    controller: state.yearGraduatedController,
    label: _req(GtsConstants.labelYearGraduated),
    icon: Icons.calendar_today_outlined,
    hint: 'e.g. 2024',
    keyboard: TextInputType.number,
    readOnly: state.yearLocked,
    helperText: state.yearLocked
        ? 'Contact the alumni office to change this'
        : null,
  );

  Widget _honorsField() => _text(
    controller: state.honorsController,
    label: GtsConstants.labelHonorsAwards,
    icon: Icons.emoji_events_outlined,
    required: false,
  );

  Widget _employmentField() => OnboardingGtsEmploymentStatus(
    value: state.employmentStatus,
    enabled: enabled,
    onChanged: (v) {
      state.employmentStatus = v;
      onChanged();
    },
  );

  Widget _requiredBirthdayField(BuildContext context) {
    return FormField<DateTime>(
      initialValue: state.birthDate,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      validator: (_) => state.birthDate == null ? 'Required' : null,
      builder: (field) => OnboardingDateTile(
        label: _req(GtsConstants.labelBirthday),
        valueText: state.birthDate != null
            ? DateFormat.yMMMd().format(state.birthDate!)
            : 'Tap to choose date',
        hasValue: state.birthDate != null,
        enabled: enabled,
        errorText: field.errorText,
        onTap: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: state.birthDate ?? DateTime(2000),
            firstDate: DateTime(1950),
            lastDate: DateTime.now(),
          );
          if (picked != null) {
            state.birthDate = picked;
            field.didChange(picked);
            onChanged();
          }
        },
      ),
    );
  }

  Widget _requiredEmploymentField() {
    return FormField<String>(
      initialValue: state.employmentStatus,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      validator: (_) =>
          state.employmentStatus.trim().isEmpty ? 'Choose one' : null,
      builder: (field) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OnboardingGtsEmploymentStatus(
            value: state.employmentStatus,
            enabled: enabled,
            onChanged: (v) {
              state.employmentStatus = v;
              field.didChange(v);
              onChanged();
            },
          ),
          if (field.hasError) _fieldError(field.errorText!),
        ],
      ),
    );
  }

  /// Degree is set by the alumni office; an empty one blocks the step with
  /// an explanation instead of an unfixable "Required".
  Widget _lockedProgramRow() {
    final program = state.program.trim();
    return FormField<String>(
      initialValue: program,
      validator: (_) => state.program.trim().isEmpty
          ? 'Your degree hasn’t been added yet. Contact the alumni office '
                'to continue.'
          : null,
      builder: (field) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _lockedRow(
            icon: Icons.menu_book_outlined,
            label: GtsConstants.labelDegreeSpecialization,
            value: program.isEmpty ? 'Not set yet' : program,
            caption: 'Set by the alumni office',
            padBottom: !field.hasError,
          ),
          if (field.hasError) _fieldError(field.errorText!),
        ],
      ),
    );
  }

  Widget _fieldError(String message) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        14,
        OnboardingSpacing.xs,
        14,
        OnboardingSpacing.fieldGap,
      ),
      child: Text(
        message,
        style: PortalTheme.meta.copyWith(color: PortalTheme.danger),
      ),
    );
  }

  /// Read-only value shown as a summary row rather than a disabled input.
  Widget _lockedRow({
    required IconData icon,
    required String label,
    required String value,
    required String caption,
    bool padBottom = true,
  }) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: padBottom ? OnboardingSpacing.fieldGap : 0,
      ),
      child: Semantics(
        label: '$label: $value. $caption',
        child: ExcludeSemantics(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: PortalTheme.surfaceMuted,
              borderRadius: BorderRadius.circular(PortalTheme.radiusMd),
              border: Border.all(color: PortalTheme.border),
            ),
            child: Row(
              children: [
                Icon(icon, size: 20, color: PortalTheme.navy),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: PortalTheme.meta),
                      const SizedBox(height: 2),
                      Text(
                        value,
                        style: PortalTheme.body.copyWith(
                          fontWeight: FontWeight.w600,
                          color: PortalTheme.navy,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(caption, style: PortalTheme.caption),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.lock_outline_rounded,
                  size: 18,
                  color: PortalTheme.textMuted,
                ),
              ],
            ),
          ),
        ),
      ),
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
    FormFieldValidator<String>? validator,
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
        validator:
            validator ??
            (required
                ? (v) => v == null || v.trim().isEmpty ? 'Required' : null
                : null),
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
    String? helperText,
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
        decoration: onboardingFieldDecoration(
          label: label,
          icon: icon,
          helperText: helperText,
        ),
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
            final radius = BorderRadius.circular(PortalTheme.radiusMd);
            final card = Semantics(
              button: true,
              selected: selected,
              child: Material(
                color: selected
                    ? PortalTheme.navy.withValues(alpha: 0.06)
                    : PortalTheme.card,
                borderRadius: radius,
                child: InkWell(
                  onTap: enabled ? () => onChanged(status) : null,
                  borderRadius: radius,
                  child: AnimatedContainer(
                    duration: PortalTheme.fast,
                    width: narrow ? double.infinity : null,
                    padding: const EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: 10,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: radius,
                      border: Border.all(
                        color: selected ? PortalTheme.navy : PortalTheme.border,
                        width: selected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          selected
                              ? Icons.check_circle_rounded
                              : _iconFor(status),
                          size: 18,
                          color: selected
                              ? PortalTheme.navy
                              : PortalTheme.textSecondary,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            status,
                            textAlign: TextAlign.center,
                            style: PortalTheme.button.copyWith(
                              fontSize: 13,
                              color: selected
                                  ? PortalTheme.navy
                                  : PortalTheme.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
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
