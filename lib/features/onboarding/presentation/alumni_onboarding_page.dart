import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:alumni_system/core/constants/gts_constants.dart';
import 'package:alumni_system/core/services/app_session.dart';
import 'package:alumni_system/core/services/audit_service.dart';
import 'package:alumni_system/core/utils/app_image.dart';
import 'package:alumni_system/core/utils/avatar_image_prepare.dart';
import 'package:alumni_system/features/alumni/profile/data/user_profile_events.dart';
import 'package:alumni_system/features/alumni/tracer/models/tracer_profile_model.dart';
import 'package:alumni_system/features/messages/data/image_storage_service.dart';
import 'package:alumni_system/features/onboarding/data/onboarding_service.dart';
import 'package:alumni_system/features/alumni/profile/data/user_profile_service.dart';
import 'package:alumni_system/features/auth/data/auth_service.dart';
import 'package:alumni_system/features/auth/presentation/auth_gate.dart';
import 'package:alumni_system/features/auth/presentation/auth_shell.dart'
    show showAuthFeedback;
import 'package:alumni_system/features/onboarding/presentation/widgets/onboarding_chrome.dart';
import 'package:alumni_system/features/onboarding/presentation/widgets/onboarding_step_widgets.dart';
import 'package:alumni_system/features/shell/presentation/main_navigation.dart';
import 'package:alumni_system/shared/widgets/gts/gts_profile_form.dart';
import 'package:alumni_system/shared/widgets/user/portal_headers.dart';
import 'package:alumni_system/shared/widgets/user/portal_states.dart';
import 'package:alumni_system/shared/widgets/user/portal_theme.dart';

/// Mandatory onboarding: GTS profile + optional photo.
class AlumniOnboardingScreen extends StatefulWidget {
  const AlumniOnboardingScreen({super.key});

  @override
  State<AlumniOnboardingScreen> createState() => _AlumniOnboardingScreenState();
}

class _AlumniOnboardingScreenState extends State<AlumniOnboardingScreen> {
  static const _steps = <OnboardingStepInfo>[
    OnboardingStepInfo(
      label: 'Welcome',
      title: 'Welcome',
      icon: Icons.waving_hand_outlined,
      counted: false,
    ),
    OnboardingStepInfo(
      label: 'About you',
      title: 'Set up your profile',
      icon: Icons.person_outline,
    ),
    OnboardingStepInfo(
      label: 'Contact & address',
      title: 'Set up your profile',
      icon: Icons.home_outlined,
    ),
    OnboardingStepInfo(
      label: 'Education & work',
      title: 'Set up your profile',
      icon: Icons.school_outlined,
    ),
    OnboardingStepInfo(
      label: 'Profile photo',
      title: 'Set up your profile',
      icon: Icons.photo_camera_outlined,
      optional: true,
    ),
    OnboardingStepInfo(
      label: 'Review',
      title: 'Review',
      icon: Icons.fact_check_outlined,
      counted: false,
    ),
  ];

  /// Profile steps follow Welcome, in [GtsFormSection] order.
  static const _firstProfileStep = 1;
  static const _photoStepIndex = 4;
  static const _finalStepIndex = 5;

  final _sectionFormKeys = {
    for (final s in GtsFormSection.values) s: GlobalKey<FormState>(),
  };
  final _profileService = UserProfileService();
  final _onboardingService = OnboardingService();
  final _auditService = AuditService();
  final _imageStorage = ImageStorageService();
  final _imagePicker = ImagePicker();
  final _formState = GtsProfileFormState();

  int _step = 0;
  bool _forward = true;

  /// Set by an Edit link on Review: Continue then returns straight to Review.
  bool _returnToReview = false;
  bool _finishing = false;
  String? _profileImageUrl;
  File? _selectedImage;
  Uint8List? _selectedImageBytes;

  /// The form is hidden until the saved record loads: saving over a record we
  /// never read would blank office-managed fields such as the program.
  bool _loading = true;
  Object? _loadError;

  /// Background work started while navigating; each resolves to whether it
  /// succeeded and is checked again on finish.
  Future<bool>? _profileSave;
  Future<bool>? _photoUpload;

  /// The picked image the current [_photoUpload] is for, so revisiting the
  /// photo step does not upload the same image twice.
  Object? _photoUploadSource;

  @override
  void initState() {
    super.initState();
    unawaited(_loadInitialData());
  }

  Future<void> _loadInitialData() async {
    final userId = AppSession.userId;
    if (userId == null) {
      setState(() {
        _loadError = 'No active session';
        _loading = false;
      });
      return;
    }

    if (_loadError != null) {
      setState(() {
        _loading = true;
        _loadError = null;
      });
    }

    try {
      final boot = await _profileService.getOnboardingBootstrap(uid: userId);
      if (!mounted) return;

      if (boot.profile != null) {
        _formState.applyFromProfile(boot.profile!);
      }
      if (_formState.emailController.text.trim().isEmpty) {
        _formState.emailController.text = AppSession.email ?? '';
      }

      setState(() {
        _profileImageUrl = boot.imageUrl;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Onboarding bootstrap failed: $e');
      if (!mounted) return;
      setState(() {
        _loadError = e;
        _loading = false;
      });
    }
  }

  void _goToStep(int step) {
    if (_step == step) return;
    setState(() {
      _forward = step > _step;
      _step = step;
    });
  }

  void _goBack() {
    if (_finishing || _step == 0) return;
    _returnToReview = false;
    _goToStep(_step - 1);
  }

  void _editFromReview(int step) {
    _returnToReview = true;
    _goToStep(step);
  }

  Future<void> _confirmSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
          'You’ll finish setting up your profile the next time you sign in.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: PortalTheme.ghostButton(dense: true),
            child: const Text('Stay'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: PortalTheme.primaryButton(dense: true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final navigator = Navigator.of(context);
    final userId = AppSession.userId;
    if (userId != null) {
      // Before logout: the audit insert needs the session for RLS.
      await _auditService.logAction(
        action: 'LOGOUT',
        resource: 'User',
        resourceId: userId,
        description: 'User logged out during onboarding',
        status: 'SUCCESS',
      );
    }
    await AuthService().logout();
    navigator.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthGate()),
      (_) => false,
    );
  }

  /// Runs [work] after any earlier save so writes land in order.
  Future<bool> _runAfter(Future<bool>? previous, Future<void> Function() work) {
    return () async {
      if (previous != null) await previous;
      try {
        await work();
        return true;
      } catch (e) {
        debugPrint('Onboarding background save failed: $e');
        return false;
      }
    }();
  }

  int _stepFor(GtsFormSection section) => _firstProfileStep + section.index;

  void _continueFromSection(GtsFormSection section) {
    if (!_validateSection(section)) return;

    final userId = AppSession.userId;
    if (userId == null) return;

    // Save progress after every profile step so a graduate who leaves midway
    // keeps what they entered. Navigation never waits on it.
    _queueProfileSave(userId);

    if (section != GtsFormSection.education && !_returnToReview) {
      _goToStep(_stepFor(section) + 1);
      return;
    }

    // Each step validated its own fields; this catches anything that became
    // empty elsewhere so the 100% rule still holds.
    final missing = _formState.missingRequiredKeys();
    if (missing.isNotEmpty) {
      final target = GtsFormSection.values.firstWhere(
        (s) => s.requiredKeys.contains(missing.first),
        orElse: () => GtsFormSection.education,
      );
      _goToStep(_stepFor(target));
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _validateSection(target);
      });
      return;
    }
    if (_returnToReview) {
      _returnToReview = false;
      _goToStep(_finalStepIndex);
      return;
    }
    _goToStep(_photoStepIndex);
  }

  /// Validates one step's fields, scrolling to the topmost problem.
  bool _validateSection(GtsFormSection section) {
    final form = _sectionFormKeys[section]!.currentState;
    if (form == null) return false;
    final invalid = form.validateGranularly();
    if (invalid.isEmpty) return true;

    FormFieldState<Object?>? first;
    double? top;
    for (final field in invalid) {
      final box = field.context.findRenderObject();
      if (box is! RenderBox || !box.attached) continue;
      final y = box.localToGlobal(Offset.zero).dy;
      if (top == null || y < top) {
        top = y;
        first = field;
      }
    }
    if (first != null) {
      unawaited(
        Scrollable.ensureVisible(
          first.context,
          alignment: 0.15,
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : PortalTheme.normal,
          curve: PortalTheme.ease,
        ),
      );
    }

    final n = invalid.length;
    _snack(
      n == 1
          ? '1 field needs your attention.'
          : '$n fields need your attention.',
    );
    return false;
  }

  void _queueProfileSave(String userId) {
    final profile = _currentProfile(userId);
    _profileSave = _runAfter(
      _profileSave,
      () => _profileService.saveTracerProfile(
        profile,
        syncRoster: false,
        source: 'onboarding',
      ),
    );
  }

  TracerProfile _currentProfile(String userId) => _formState
      .toTracerProfile(uid: userId, email: AppSession.email ?? '')
      .copyWith(employmentSource: 'onboarding');

  Future<void> _pickImage() async {
    if (!mounted || _finishing) return;
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 50,
        maxWidth: 500,
        maxHeight: 500,
      );
      if (image == null || !mounted) return;

      if (kIsWeb) {
        final bytes = await image.readAsBytes();
        if (bytes.length > ImageStorageService.maxSourceBytes) {
          _snack('Image is too large. Please choose a file under 12 MB.');
          return;
        }
        if (!mounted) return;
        setState(() {
          _selectedImageBytes = bytes;
          _selectedImage = null;
        });
      } else {
        final file = File(image.path);
        if (await file.length() > ImageStorageService.maxSourceBytes) {
          _snack('Image is too large. Please choose a file under 12 MB.');
          return;
        }
        if (!mounted) return;
        setState(() {
          _selectedImage = file;
          _selectedImageBytes = null;
        });
      }
    } catch (e) {
      debugPrint('Onboarding image pick failed: $e');
      _snack('We couldn’t open that photo. Try a different image.');
    }
  }

  void _continueFromPhoto({required bool skipUpload}) {
    final userId = AppSession.userId;
    if (userId == null) return;

    final bytes = _selectedImageBytes;
    final file = _selectedImage;
    final Object? source = bytes ?? file;

    // Navigate first — upload in the background.
    _returnToReview = false;
    _goToStep(_finalStepIndex);

    if (skipUpload || source == null || identical(source, _photoUploadSource)) {
      return;
    }
    _photoUploadSource = source;
    _photoUpload = _runAfter(_profileSave, () async {
      final imageBytes = bytes ?? await file!.readAsBytes();
      if (imageBytes.length > ImageStorageService.maxSourceBytes) {
        throw ArgumentError('Image is too large. Please choose a file under 12 MB.');
      }
      // Same square JPEG pipeline as Profile → photo (fills circular avatar).
      final prepared = await AvatarImagePrepare.toSquareJpeg(imageBytes);
      final url = await _imageStorage.uploadProfileImage(
        userId: userId,
        bytes: prepared,
      );
      await _profileService.saveProfileImageUrl(
        uid: userId,
        imageUrl: url,
        source: 'onboarding',
      );
      UserProfileEvents.notifyAvatarChanged(url);
      if (mounted) setState(() => _profileImageUrl = url);
    });
  }

  Future<void> _finishOnboarding() async {
    final userId = AppSession.userId;
    if (userId == null) return;

    setState(() => _finishing = true);
    try {
      // The profile is required: retry a failed background save once before
      // marking onboarding complete, and stop if it still fails.
      final saved = await (_profileSave ?? Future.value(false));
      if (!saved) {
        await _profileService.saveTracerProfile(
          _currentProfile(userId),
          syncRoster: false,
          source: 'onboarding',
        );
        _profileSave = Future.value(true);
      }

      // The photo is optional, so a failed upload only warns.
      final photoUploaded = await (_photoUpload ?? Future.value(true));
      if (!photoUploaded) {
        _photoUpload = null;
        _photoUploadSource = null;
      }

      try {
        await _profileService.syncRosterFromSavedProfile(userId);
      } catch (e) {
        debugPrint('Onboarding roster sync failed: $e');
      }

      await _onboardingService.completeOnboarding(userId);

      unawaited(
        _auditService.logAction(
          action: 'COMPLETE_ONBOARDING',
          resource: 'User',
          resourceId: userId,
          description: 'Alumni completed mandatory onboarding',
        ),
      );

      if (!mounted) return;
      if (!photoUploaded) {
        _snack(
          'Your photo couldn’t be uploaded. You can add it later from your profile.',
        );
      }
      // Skip AlumniHomeGate re-check — we just marked onboarding complete.
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainNavigation()),
      );
    } catch (e) {
      debugPrint('Onboarding finish failed: $e');
      _snack(
        'We couldn’t finish setting up your account. ${portalFriendlyError(e)}',
      );
      if (mounted) setState(() => _finishing = false);
    }
  }

  void _snack(String message, {bool isError = true}) {
    if (!mounted) return;
    showAuthFeedback(context, message, error: isError);
  }

  bool get _isProfileStep =>
      _step >= _firstProfileStep && _step < _photoStepIndex;

  String get _overallFieldCount {
    final total = TracerProfile.fullProfileFieldCount;
    final filled = total - _formState.missingRequiredKeys().length;
    return '$filled of $total fields';
  }

  /// "BSIT • Batch 2024" from the loaded record, when known.
  String? get _programBatch {
    final parts = [
      if (_formState.program.trim().isNotEmpty) _formState.program.trim(),
      if (_formState.yearGraduatedController.text.trim().isNotEmpty)
        'Batch ${_formState.yearGraduatedController.text.trim()}',
    ];
    return parts.isEmpty ? null : parts.join(' • ');
  }

  @override
  Widget build(BuildContext context) {
    final wide = OnboardingLayout.isWide(MediaQuery.sizeOf(context).width);
    final ready = !_loading && _loadError == null;
    final views = ready
        ? [
            _introStep(),
            for (final section in GtsFormSection.values) _sectionStep(section),
            _photoStep(),
            _reviewStep(),
          ]
        : const <OnboardingStepView>[];

    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goBack();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: PortalAppBar(
          title: ready ? _steps[_step].title : 'Welcome',
          automaticallyImplyLeading: false,
          leading: ready && !wide && _step > 0
              ? IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  tooltip: 'Previous step',
                  onPressed: _finishing ? null : _goBack,
                )
              : null,
          actions: [
            TextButton(
              onPressed: _finishing ? null : _confirmSignOut,
              style: PortalTheme.ghostButton(dense: true).copyWith(
                foregroundColor: WidgetStateProperty.all(
                  PortalTheme.textSecondary,
                ),
              ),
              child: const Text('Sign out'),
            ),
          ],
        ),
        body: _loading
            ? const Center(
                child: CircularProgressIndicator(color: PortalTheme.navy),
              )
            : _loadError != null
            ? PortalErrorState(
                title: 'We couldn’t load your profile',
                error: _loadError,
                onRetry: _loadInitialData,
              )
            : OnboardingStepFrame(
                steps: _steps,
                currentIndex: _step,
                forward: _forward,
                panelName: _formState.displayNameController.text,
                panelBadge: _programBatch,
                progressTrailing: _isProfileStep ? _overallFieldCount : null,
                showCompactActionBar: false,
                views: views,
              ),
        bottomNavigationBar: ready && !wide
            ? OnboardingActionBar(actions: views[_step].actions, wide: false)
            : null,
      ),
    );
  }

  bool get _wide => OnboardingLayout.isWide(MediaQuery.sizeOf(context).width);

  String get _firstName =>
      onboardingFirstName(_formState.displayNameController.text);

  /// Picked photo first, then the saved one.
  ImageProvider? get _photoProvider {
    final bytes = _selectedImageBytes;
    if (bytes != null) return MemoryImage(bytes);
    final file = _selectedImage;
    if (file != null) return FileImage(file);
    return AppImage.provider(_profileImageUrl);
  }

  OnboardingStepView _introStep() {
    final wide = _wide;
    return OnboardingStepView(
      centerContent: true,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Desktop already shows the graduate's name in the side panel.
          if (wide)
            OnboardingSectionHeading(
              title: 'Welcome, $_firstName',
              subtitle:
                  'Let’s set up your Graduate Tracer profile. It keeps your '
                  'alumni record accurate for CHED reporting.',
            )
          else ...[
            OnboardingIdentityCard(
              greeting: 'Welcome to the Alumni Portal,',
              name: _firstName,
              badge: _programBatch,
              image: _photoProvider,
            ),
            const SizedBox(height: PortalTheme.space3),
            Text(
              'Let’s set up your Graduate Tracer profile. It keeps your alumni '
              'record accurate for CHED reporting.',
              style: PortalTheme.bodySecondary,
            ),
          ],
          const SizedBox(height: PortalTheme.space4),
          _maybeCard(
            wide: wide,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Your setup — about 3 minutes',
                  style: PortalTheme.cardTitle.copyWith(
                    color: PortalTheme.navy,
                  ),
                ),
                const SizedBox(height: PortalTheme.space3),
                const OnboardingRoadmap(steps: _steps),
              ],
            ),
          ),
          const SizedBox(height: PortalTheme.space3),
          Row(
            children: [
              const Icon(
                Icons.lock_outline_rounded,
                size: 16,
                color: PortalTheme.textSecondary,
              ),
              const SizedBox(width: PortalTheme.space1),
              Expanded(
                child: Text(
                  'Saved to your alumni record and used for CHED Graduate '
                  'Tracer reporting.',
                  style: PortalTheme.meta,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: OnboardingActions(
        primaryLabel: 'Get started',
        onPrimary: () => _goToStep(_firstProfileStep),
      ),
    );
  }

  /// Phones get a card; on desktop the frame is already one.
  Widget _maybeCard({required bool wide, required Widget child}) {
    if (wide) return child;
    return OnboardingContentCard(child: child);
  }

  OnboardingStepView _sectionStep(GtsFormSection section) {
    final (title, subtitle) = switch (section) {
      GtsFormSection.personal => (
        'About you',
        'As it appears on your CHED Graduate Tracer form. Fields marked * '
            'are required.',
      ),
      GtsFormSection.contact => (
        'Contact & address',
        'Where the alumni office can reach you.',
      ),
      GtsFormSection.education => (
        'Education & work',
        'Your degree and current employment status.',
      ),
    };
    final wide = OnboardingLayout.isWide(MediaQuery.sizeOf(context).width);

    final fields = Form(
      key: _sectionFormKeys[section],
      child: GtsProfileFormFields(
        state: _formState,
        section: section,
        emailReadOnly: true,
        showEmploymentStatus: true,
        enabled: !_finishing,
        onChanged: () => setState(() {}),
      ),
    );

    return OnboardingStepView(
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OnboardingSectionIntro(
            title: title,
            subtitle: subtitle,
            filled: _formState.filledInSection(section),
            total: section.requiredKeys.length,
          ),
          const SizedBox(height: PortalTheme.space3),
          // The desktop frame is already a card; phones get their own.
          if (wide)
            fields
          else
            Container(
              padding: const EdgeInsets.fromLTRB(
                PortalTheme.space3,
                PortalTheme.space4,
                PortalTheme.space3,
                PortalTheme.space1,
              ),
              decoration: BoxDecoration(
                color: PortalTheme.card,
                borderRadius: BorderRadius.circular(PortalTheme.radiusXl),
                border: Border.all(
                  color: PortalTheme.border.withValues(alpha: 0.75),
                ),
                boxShadow: PortalTheme.softShadow,
              ),
              child: fields,
            ),
          if (section == GtsFormSection.education) ...[
            const SizedBox(height: PortalTheme.space3),
            const OnboardingTip(
              icon: Icons.emoji_objects_outlined,
              message: 'Almost there — just an optional photo after this.',
            ),
          ],
        ],
      ),
      actions: OnboardingActions(
        primaryLabel: _returnToReview
            ? 'Save & review'
            : section == GtsFormSection.education
            ? 'Save & continue'
            : 'Continue',
        onPrimary: _finishing ? null : () => _continueFromSection(section),
        onBack: _goBack,
      ),
    );
  }

  OnboardingStepView _photoStep() {
    final hasLocalPreview =
        _selectedImageBytes != null || _selectedImage != null;
    final image = _photoProvider;

    return OnboardingStepView(
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const OnboardingSectionHeading(
            title: 'Add a profile photo',
            subtitle:
                'Optional — it helps classmates recognize you. You can change '
                'it later from your profile.',
          ),
          const SizedBox(height: PortalTheme.space5),
          Center(
            child: OnboardingPhotoPicker(
              image: image,
              onTap: _finishing ? null : _pickImage,
            ),
          ),
          const SizedBox(height: PortalTheme.space5),
          Text(
            'Preview on your Home screen',
            style: PortalTheme.meta.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: PortalTheme.space1),
          OnboardingIdentityCard(
            greeting: 'Welcome back,',
            name: _firstName,
            badge: _programBatch,
            image: image,
          ),
        ],
      ),
      actions: OnboardingActions(
        primaryLabel: hasLocalPreview ? 'Upload & continue' : 'Continue',
        onPrimary: _finishing
            ? null
            : () => _continueFromPhoto(skipUpload: !hasLocalPreview),
        onBack: _goBack,
        tertiaryLabel: 'Skip for now',
        onTertiary: _finishing
            ? null
            : () => _continueFromPhoto(skipUpload: true),
      ),
    );
  }

  OnboardingStepView _reviewStep() {
    final wide = _wide;
    final hasPhoto = _photoProvider != null;
    String join(List<String> parts) {
      final filled = parts.map((p) => p.trim()).where((p) => p.isNotEmpty);
      return filled.isEmpty ? 'Not filled in yet' : filled.join(' · ');
    }

    final birthDate = _formState.birthDate;
    final rows = [
      OnboardingSummaryRow(
        icon: Icons.person_outline,
        title: 'About you',
        summary: join([
          _formState.gender,
          _formState.civilStatus,
          if (birthDate != null) DateFormat.yMMMd().format(birthDate),
        ]),
        onEdit: _finishing
            ? null
            : () => _editFromReview(_stepFor(GtsFormSection.personal)),
      ),
      OnboardingSummaryRow(
        icon: Icons.home_outlined,
        title: 'Contact & address',
        summary: join([
          _formState.provinceController.text,
          _formState.mobileController.text,
        ]),
        onEdit: _finishing
            ? null
            : () => _editFromReview(_stepFor(GtsFormSection.contact)),
      ),
      OnboardingSummaryRow(
        icon: Icons.school_outlined,
        title: 'Education & work',
        summary: () {
          final parts = <String>[
            _formState.program,
            _formState.yearGraduatedController.text,
            _formState.employmentStatus,
          ];
          if (_formState.employmentStatus == GtsConstants.employed) {
            if (_formState.occupationController.text.trim().isNotEmpty) {
              parts.add(_formState.occupationController.text.trim());
            }
            if (_formState.employmentType.trim().isNotEmpty) {
              parts.add('(${_formState.employmentType.trim()})');
            }
          } else if (_formState.employmentStatus == GtsConstants.unemployed ||
              _formState.employmentStatus == GtsConstants.neverEmployed) {
            if (_formState.notEmployedReasons.isNotEmpty) {
              final first = _formState.notEmployedReasons.first;
              if (first == GtsConstants.otherReasonSpecify &&
                  _formState.reasonOtherController.text.trim().isNotEmpty) {
                parts.add(_formState.reasonOtherController.text.trim());
              } else {
                parts.add(first);
              }
            }
          }
          return join(parts);
        }(),
        onEdit: _finishing
            ? null
            : () => _editFromReview(_stepFor(GtsFormSection.education)),
      ),
      OnboardingSummaryRow(
        icon: Icons.photo_camera_outlined,
        title: 'Profile photo',
        summary: hasPhoto ? 'Added' : 'Not added — you can add one later',
        onEdit: _finishing ? null : () => _editFromReview(_photoStepIndex),
      ),
    ];

    return OnboardingStepView(
      centerContent: true,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Mounted only while visible so the animation plays on arrival.
          Center(
            child: _step == _finalStepIndex
                ? const OnboardingCelebration()
                : const SizedBox(height: 170),
          ),
          Text(
            'You’re all set, $_firstName!',
            textAlign: TextAlign.center,
            style: PortalTheme.sectionTitle.copyWith(
              color: PortalTheme.navy,
              fontSize: 24,
            ),
          ),
          const SizedBox(height: PortalTheme.space1),
          Text(
            'Check your details, then enter the portal.',
            textAlign: TextAlign.center,
            style: PortalTheme.bodySecondary,
          ),
          const SizedBox(height: PortalTheme.space4),
          _maybeCard(
            wide: wide,
            child: Column(
              children: [
                for (var i = 0; i < rows.length; i++) ...[
                  if (i > 0)
                    Divider(
                      height: 1,
                      color: PortalTheme.border.withValues(alpha: 0.75),
                    ),
                  rows[i],
                ],
              ],
            ),
          ),
          const SizedBox(height: PortalTheme.space3),
          const OnboardingTip(
            icon: Icons.info_outline_rounded,
            message:
                'Tracer surveys appear in the Tracer tab when published. You '
                'can update your profile anytime from the Profile tab.',
          ),
        ],
      ),
      actions: OnboardingActions(
        primaryLabel: 'Enter alumni portal',
        onPrimary: _finishing ? null : _finishOnboarding,
        primaryLoading: _finishing,
        showArrow: false,
        onBack: _goBack,
      ),
    );
  }

  @override
  void dispose() {
    _formState.dispose();
    super.dispose();
  }
}
