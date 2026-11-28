import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:alumni_system/core/services/app_session.dart';
import 'package:alumni_system/core/services/audit_service.dart';
import 'package:alumni_system/core/utils/alumni_pdf_delivery.dart';
import 'package:alumni_system/core/utils/app_image.dart';
import 'package:alumni_system/core/utils/avatar_image_prepare.dart';
import 'package:alumni_system/features/alumni/membership/data/alumni_membership_form_service.dart';
import 'package:alumni_system/features/alumni/profile/data/user_profile_events.dart';
import 'package:alumni_system/features/alumni/tracer/models/tracer_profile_model.dart';
import 'package:alumni_system/features/messages/data/image_storage_service.dart';
import 'package:alumni_system/features/contact_verification/data/contact_verification_service.dart';
import 'package:alumni_system/features/contact_verification/presentation/contact_verify_card.dart';
import 'package:alumni_system/features/contact_verification/presentation/ph_mobile_input_formatter.dart';
import 'package:alumni_system/features/onboarding/data/onboarding_service.dart';
import 'package:alumni_system/features/alumni/profile/data/user_profile_service.dart';
import 'package:alumni_system/features/auth/presentation/auth_shell.dart'
    show showAuthFeedback;
import 'package:alumni_system/features/onboarding/presentation/widgets/onboarding_chrome.dart';
import 'package:alumni_system/features/onboarding/presentation/widgets/onboarding_step_widgets.dart';
import 'package:alumni_system/features/shell/presentation/main_navigation.dart';
import 'package:alumni_system/shared/widgets/gts/gts_profile_form.dart';
import 'package:alumni_system/shared/widgets/user/portal_states.dart';
import 'package:alumni_system/shared/widgets/user/portal_theme.dart';

/// Mandatory onboarding: GTS profile + optional photo.
class AlumniOnboardingScreen extends StatefulWidget {
  const AlumniOnboardingScreen({super.key, this.contactService});

  /// Optional override for tests.
  final ContactVerificationService? contactService;

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
      label: 'About You',
      title: 'Set Up Your Profile',
      icon: Icons.person_outline,
    ),
    OnboardingStepInfo(
      label: 'Contact & Address',
      title: 'Set Up Your Profile',
      icon: Icons.home_outlined,
    ),
    OnboardingStepInfo(
      label: 'Verify Mobile',
      title: 'Verify Mobile',
      icon: Icons.sms_outlined,
    ),
    OnboardingStepInfo(
      label: 'Education & Work',
      title: 'Set Up Your Profile',
      icon: Icons.school_outlined,
    ),
    OnboardingStepInfo(
      label: 'Profile Photo',
      title: 'Set Up Your Profile',
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

  static const _firstProfileStep = 1;
  static const _contactStepIndex = 2;
  static const _mobileVerifyStepIndex = 3;
  static const _educationStepIndex = 4;
  static const _photoStepIndex = 5;
  static const _finalStepIndex = 6;

  final _sectionFormKeys = {
    for (final s in GtsFormSection.values) s: GlobalKey<FormState>(),
  };
  final _profileService = UserProfileService();
  final _onboardingService = OnboardingService();
  final _auditService = AuditService();
  final _membershipFormService = AlumniMembershipFormService();
  final _imageStorage = ImageStorageService();
  final _imagePicker = ImagePicker();
  final _formState = GtsProfileFormState();
  late final ContactVerificationService _contactService =
      widget.contactService ?? ContactVerificationService();

  int _step = 0;
  bool _forward = true;

  /// Set by an Edit link on Review: Continue then returns straight to Review.
  bool _finishing = false;
  String? _profileImageUrl;
  File? _selectedImage;
  Uint8List? _selectedImageBytes;

  /// Mobile shown on the confirm step (may differ briefly while editing).
  String _mobileDraft = '';

  /// Value queued/saved when entering the confirm step (restored on Skip).
  String _mobileAtVerifyEntry = '';

  bool _mobileVerified = false;
  String? _verifiedMobile;
  bool _mobileSaving = false;
  String? _mobileSaveError;

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

  bool _membershipFormBusy = false;
  /// True after a successful download this session or a prior DB timestamp.
  bool _membershipFormDownloaded = false;
  /// Explicit confirm that the alumnus saved the PDF (required with download).
  bool _membershipFormSavedConfirm = false;
  bool _acceptedPrivacy = false;

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
      final downloadedAt = await _membershipFormService.fetchDownloadedAt(
        userId,
      );
      if (!mounted) return;

      if (boot.profile != null) {
        _formState.applyFromProfile(
          boot.profile!,
          blankYearGraduated: true,
        );
        final profile = boot.profile!;
        if (profile.mobileVerified) {
          final normalized = ContactNormalizer.normalize(
            ContactChannel.mobile,
            profile.mobileNumber,
          );
          _mobileVerified = normalized != null;
          _verifiedMobile = normalized;
        }
      }
      if (_formState.emailController.text.trim().isEmpty) {
        _formState.emailController.text = AppSession.email ?? '';
      }

      setState(() {
        _profileImageUrl = boot.imageUrl;
        _membershipFormDownloaded = downloadedAt != null;
        // Returning alumni who already downloaded can confirm immediately.
        _membershipFormSavedConfirm = downloadedAt != null;
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
    // Skip the confirm-mobile step when going back if it was not offered.
    if (_step == _educationStepIndex && !_needsMobileVerifyStep) {
      _goToStep(_contactStepIndex);
      return;
    }
    if (_step == _mobileVerifyStepIndex) {
      _goToStep(_contactStepIndex);
      return;
    }
    _goToStep(_step - 1);
  }

  /// True when there is a PH/intl mobile that still needs an SMS check.
  bool get _needsMobileVerifyStep {
    final normalized = ContactNormalizer.normalize(
      ContactChannel.mobile,
      _formState.mobileController.text,
    );
    if (normalized == null) return false;
    if (_mobileVerified &&
        ContactNormalizer.same(
          ContactChannel.mobile,
          _verifiedMobile,
          normalized,
        )) {
      return false;
    }
    return true;
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

  int _stepFor(GtsFormSection section) => switch (section) {
    GtsFormSection.personal => _firstProfileStep,
    GtsFormSection.contact => _contactStepIndex,
    GtsFormSection.education => _educationStepIndex,
  };

  void _continueFromSection(GtsFormSection section) {
    if (!_validateSection(section)) return;

    final userId = AppSession.userId;
    if (userId == null) return;

    // Save progress after every profile step so a graduate who leaves midway
    // keeps what they entered. Navigation never waits on it.
    _queueProfileSave(userId);

    if (section == GtsFormSection.contact) {
      unawaited(_openMobileVerifyOrContinue());
      return;
    }

    if (section == GtsFormSection.personal) {
      _goToStep(_contactStepIndex);
      return;
    }

    // Education: each step validated its own fields; catch anything that
    // became empty elsewhere so the 100% rule still holds.
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
    _goToStep(_photoStepIndex);
  }

  Future<void> _openMobileVerifyOrContinue() async {
    if (!_needsMobileVerifyStep) {
      _continueAfterMobileVerify();
      return;
    }

    final raw = _formState.mobileController.text;
    final normalized = ContactNormalizer.normalize(ContactChannel.mobile, raw);
    if (normalized == null) {
      _snack(ContactNormalizer.invalidMessage(ContactChannel.mobile));
      return;
    }

    final confirmed = await _confirmMobileNumberSheet(
      PhMobileInputFormatter.formatDisplay(normalized),
    );
    if (!confirmed || !mounted) return;

    setState(() {
      _formState.mobileController.text =
          PhMobileInputFormatter.formatDisplay(normalized);
      _mobileAtVerifyEntry = normalized;
      _mobileDraft = normalized;
      _mobileSaveError = null;
    });
    _goToStep(_mobileVerifyStepIndex);
  }

  /// Bottom sheet confirms the number before SMS — clearer than editing on
  /// the OTP step, and keeps verification OTP-only.
  Future<bool> _confirmMobileNumberSheet(String displayNumber) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: PortalTheme.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Confirm your mobile number',
                  style: PortalTheme.cardTitle,
                ),
                const SizedBox(height: 8),
                Text(
                  'We’ll text a 6-digit code to this number. Make sure it’s '
                  'correct before continuing.',
                  style: PortalTheme.bodySecondary,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: PortalTheme.surfaceMuted,
                    borderRadius: BorderRadius.circular(PortalTheme.radiusMd),
                    border: Border.all(color: PortalTheme.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.smartphone_outlined,
                        color: PortalTheme.navy,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          displayNumber,
                          style: PortalTheme.body.copyWith(
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: PortalTheme.primaryButton(),
                  child: const Text('Yes, send the code'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  style: PortalTheme.secondaryButton(),
                  child: const Text('Edit number'),
                ),
              ],
            ),
          ),
        );
      },
    );
    return result == true;
  }

  void _continueAfterMobileVerify() {
    _goToStep(_educationStepIndex);
  }

  Future<void> _onMobileCodeVerified(String target) async {
    setState(() {
      _mobileSaving = true;
      _mobileSaveError = null;
    });
    try {
      await _contactService.saveVerified(ContactChannel.mobile, target);
      if (!mounted) return;
      setState(() {
        _mobileVerified = true;
        _verifiedMobile = target;
        _formState.mobileController.text =
            PhMobileInputFormatter.formatDisplay(target);
        _mobileDraft = target;
        _mobileAtVerifyEntry = target;
        _mobileSaving = false;
      });
      _continueAfterMobileVerify();
    } on ContactVerificationException catch (e) {
      if (!mounted) return;
      setState(() {
        _mobileSaveError = e.message;
        _mobileSaving = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _mobileSaveError =
            "Couldn't save your mobile number. Please try again.";
        _mobileSaving = false;
      });
    }
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

  bool get _canEnterPortal =>
      _membershipFormDownloaded && _membershipFormSavedConfirm && !_finishing;

  Future<void> _finishOnboarding() async {
    final userId = AppSession.userId;
    if (userId == null) return;
    if (!_membershipFormDownloaded || !_membershipFormSavedConfirm) {
      _snack(
        'Download your Membership Form and confirm you saved it before '
        'entering the portal.',
      );
      return;
    }

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
          module: 'auth',
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

  Future<AlumniMembershipFormPdf?> _buildMembershipForm() async {
    final userId = AppSession.userId;
    if (userId == null) {
      _snack('Sign in again to download your Membership Form.');
      return null;
    }

    // Review sits after section saves; wait for any in-flight profile write.
    final saved = await (_profileSave ?? Future.value(true));
    if (!saved) {
      _snack(
        'Your latest profile changes are still saving. Try again in a moment.',
      );
      return null;
    }

    final displayName = _formState.displayNameController.text.trim();
    return _membershipFormService.buildForUser(
      userId: userId,
      displayName: displayName.isEmpty ? _firstName : displayName,
    );
  }

  Future<void> _downloadMembershipForm() async {
    if (_membershipFormBusy || _finishing) return;
    setState(() => _membershipFormBusy = true);
    try {
      final pdf = await _buildMembershipForm();
      if (pdf == null || !mounted) return;
      await shareOrDownloadAlumniPdf(
        context: context,
        bytes: pdf.bytes,
        fileName: pdf.fileName,
      );
      final userId = AppSession.userId;
      if (userId != null) {
        await _membershipFormService.markDownloaded(userId);
      }
      if (!mounted) return;
      setState(() => _membershipFormDownloaded = true);
      _snack(
        kIsWeb
            ? 'Membership Form downloaded. Confirm below that you saved it.'
            : 'Use the share sheet to save your form, then confirm below.',
        isError: false,
      );
    } catch (e) {
      debugPrint('Membership Form download failed: $e');
      _snack(
        'We couldn’t prepare your Membership Form. ${portalFriendlyError(e)}',
      );
    } finally {
      if (mounted) setState(() => _membershipFormBusy = false);
    }
  }

  bool get _isProfileStep =>
      _step == _firstProfileStep ||
      _step == _contactStepIndex ||
      _step == _educationStepIndex;

  String get _overallFieldCount {
    final keys = _formState.activeRequiredKeys();
    final filled = keys.where(_formState.isRequiredKeyFilled).length;
    return '$filled of ${keys.length} fields';
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
            _sectionStep(GtsFormSection.personal),
            _sectionStep(GtsFormSection.contact),
            _mobileVerifyStep(),
            _sectionStep(GtsFormSection.education),
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
        body: SafeArea(
          bottom: false,
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: PortalTheme.navy),
                )
              : _loadError != null
              ? PortalErrorState(
                  title: 'We Couldn’t Load Your Profile',
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
              subtitle: 'Set up your Graduate Tracer profile for alumni records.',
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
              'Set up your Graduate Tracer profile for alumni records.',
              style: PortalTheme.bodySecondary,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
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
          _privacyConsentCard(),
        ],
      ),
      actions: OnboardingActions(
        primaryLabel: 'Get started',
        onPrimary: (!_acceptedPrivacy || _finishing)
            ? null
            : () => _goToStep(_firstProfileStep),
      ),
    );
  }

  Widget _privacyConsentCard() {
    final card = Container(
      padding: const EdgeInsets.all(PortalTheme.space3),
      decoration: BoxDecoration(
        color: PortalTheme.card,
        borderRadius: BorderRadius.circular(PortalTheme.radiusXl),
        border: Border.all(
          color: _acceptedPrivacy
              ? PortalTheme.navy.withValues(alpha: 0.35)
              : PortalTheme.border.withValues(alpha: 0.75),
        ),
        boxShadow: PortalTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: PortalTheme.navy.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(PortalTheme.radiusMd),
                ),
                child: const Icon(
                  Icons.privacy_tip_outlined,
                  size: 22,
                  color: PortalTheme.navy,
                ),
              ),
              const SizedBox(width: PortalTheme.space2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Privacy notice',
                      style: PortalTheme.cardTitle.copyWith(fontSize: 15),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Your details are saved to your alumni record and used '
                      'for Graduate Tracer reporting under the Data Privacy '
                      'Act of 2012 (RA 10173).',
                      style: PortalTheme.bodySecondary.copyWith(
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: PortalTheme.space3),
          Material(
            color: PortalTheme.navy.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(PortalTheme.radiusMd),
            child: InkWell(
              borderRadius: BorderRadius.circular(PortalTheme.radiusMd),
              onTap: _finishing
                  ? null
                  : () => setState(() => _acceptedPrivacy = !_acceptedPrivacy),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
                child: Row(
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: Checkbox(
                        value: _acceptedPrivacy,
                        onChanged: _finishing
                            ? null
                            : (v) =>
                                setState(() => _acceptedPrivacy = v ?? false),
                        activeColor: PortalTheme.navy,
                        checkColor: Colors.white,
                        fillColor: WidgetStateProperty.resolveWith((states) {
                          if (states.contains(WidgetState.selected)) {
                            return PortalTheme.navy;
                          }
                          return Colors.white;
                        }),
                        side: BorderSide(
                          color: PortalTheme.navy.withValues(alpha: 0.55),
                          width: 1.6,
                        ),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'I understand and agree to continue',
                        style: PortalTheme.body.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: PortalTheme.navy,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );

    return card;
  }

  /// Phones get a card; on desktop the frame is already one.
  Widget _maybeCard({required bool wide, required Widget child}) {
    if (wide) return child;
    return OnboardingContentCard(child: child);
  }

  OnboardingStepView _sectionStep(GtsFormSection section) {
    final (title, subtitle) = switch (section) {
      GtsFormSection.personal => (
        'About You',
        'Tell us your name, sex, civil status, and birthday.',
      ),
      GtsFormSection.contact => (
        'Contact & Address',
        'Where the alumni office can reach you.',
      ),
      GtsFormSection.education => (
        'Education & Work',
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
          _maybeCard(
            wide: wide,
            child: OnboardingSectionIntro(
              title: title,
              subtitle: subtitle,
              filled: _formState.filledInSection(section),
              total: _formState.activeRequiredKeys(section).length,
            ),
          ),
          const SizedBox(height: PortalTheme.space3),
          // The desktop frame is already a card; phones get their own.
          if (wide)
            fields
          else
            OnboardingContentCard(
              padding: const EdgeInsets.fromLTRB(
                PortalTheme.space3,
                PortalTheme.space4,
                PortalTheme.space3,
                PortalTheme.space1,
              ),
              child: fields,
            ),
          if (section == GtsFormSection.education) ...[
            const SizedBox(height: PortalTheme.space3),
            const OnboardingTip(
              icon: Icons.emoji_objects_outlined,
              message: 'Almost there — a profile photo is next.',
            ),
          ],
        ],
      ),
      actions: OnboardingActions(
        primaryLabel: section == GtsFormSection.education
            ? 'Save & continue'
            : 'Continue',
        onPrimary: _finishing ? null : () => _continueFromSection(section),
        onBack: _goBack,
      ),
    );
  }

  OnboardingStepView _mobileVerifyStep() {
    final draftVerified =
        _mobileVerified &&
        ContactNormalizer.same(
          ContactChannel.mobile,
          _verifiedMobile,
          _mobileDraft,
        );
    final display = PhMobileInputFormatter.formatDisplay(_mobileDraft);
    final wide = _wide;

    return OnboardingStepView(
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _maybeCard(
            wide: wide,
            child: OnboardingSectionHeading(
              title: 'Enter Verification Code',
              subtitle: display.isEmpty
                  ? 'Enter the 6-digit code we texted you. Expires in 10 minutes.'
                  : 'Code sent to $display. Expires in 10 minutes.',
            ),
          ),
          const SizedBox(height: PortalTheme.space3),
          ContactVerifyCard(
            channel: ContactChannel.mobile,
            original: _mobileAtVerifyEntry,
            value: _mobileDraft,
            displayValue: display,
            verified: draftVerified,
            enabled: !_finishing && !_mobileSaving,
            service: _contactService,
            allowEdit: false,
            autoSend: true,
            verifiedText: 'Number confirmed — continuing…',
            onValueChanged: (_) {},
            onVerified: _onMobileCodeVerified,
          ),
          if (_mobileSaving) ...[
            const SizedBox(height: PortalTheme.space3),
            const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: PortalTheme.navy,
                ),
              ),
            ),
          ],
          if (_mobileSaveError != null) ...[
            const SizedBox(height: PortalTheme.space2),
            Text(
              _mobileSaveError!,
              style: PortalTheme.meta.copyWith(
                color: PortalTheme.danger,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: PortalTheme.space3),
          const OnboardingTip(
            icon: Icons.info_outline_rounded,
            message:
                'Mobile verification is required. If the text doesn’t arrive, '
                'wait a minute and resend the code.',
          ),
        ],
      ),
      actions: OnboardingActions(
        primaryLabel: draftVerified ? 'Continue' : 'Waiting for code…',
        onPrimary: _finishing || _mobileSaving || !draftVerified
            ? null
            : _continueAfterMobileVerify,
        showArrow: draftVerified,
        onBack: _goBack,
      ),
    );
  }

  OnboardingStepView _photoStep() {
    final hasLocalPreview =
        _selectedImageBytes != null || _selectedImage != null;
    final image = _photoProvider;
    final wide = _wide;

    return OnboardingStepView(
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _maybeCard(
            wide: wide,
            child: const OnboardingSectionHeading(
              title: 'Add a Profile Photo',
              subtitle:
                  'Helps classmates recognize you. Change later anytime.',
            ),
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
        // No photo yet → primary skip; after a pick → Continue (uploads).
        primaryLabel: hasLocalPreview ? 'Continue' : 'Skip for now',
        showArrow: hasLocalPreview,
        onPrimary: _finishing
            ? null
            : () => _continueFromPhoto(skipUpload: !hasLocalPreview),
        onBack: _goBack,
      ),
    );
  }

  OnboardingStepView _reviewStep() {
    final wide = _wide;
    final downloadLabel = _membershipFormDownloaded
        ? (kIsWeb ? 'Download again' : 'Share again')
        : (kIsWeb ? 'Download PDF' : 'Share PDF');

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
            'You’re All Set, $_firstName!',
            textAlign: TextAlign.center,
            style: PortalTheme.sectionTitle.copyWith(
              color: PortalTheme.navy,
              fontSize: 24,
            ),
          ),
          const SizedBox(height: PortalTheme.space1),
          Text(
            'Download your Membership Form to finish. You can re-download '
            'from Profile for 30 days.',
            textAlign: TextAlign.center,
            style: PortalTheme.bodySecondary,
          ),
          const SizedBox(height: PortalTheme.space4),
          _maybeCard(
            wide: wide,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: PortalTheme.navy.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(
                            PortalTheme.radiusMd,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.description_outlined,
                          size: 24,
                          color: PortalTheme.navy,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Membership Form',
                              style: PortalTheme.cardTitle.copyWith(
                                fontSize: 17,
                                color: PortalTheme.navy,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Required by the Alumni Office. Download the '
                              'official USTP Alumni Association Oroquieta '
                              'Membership Form filled from your profile.',
                              style: PortalTheme.bodySecondary.copyWith(
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: (_membershipFormBusy || _finishing)
                          ? null
                          : _downloadMembershipForm,
                      style: PortalTheme.primaryButton().copyWith(
                        minimumSize: WidgetStateProperty.all(
                          const Size(0, 48),
                        ),
                      ),
                      icon: _membershipFormBusy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: Colors.white,
                              ),
                            )
                          : Icon(
                              _membershipFormDownloaded
                                  ? Icons.check_circle_outline
                                  : Icons.download_outlined,
                              size: 20,
                            ),
                      label: Text(downloadLabel),
                    ),
                  ),
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    value: _membershipFormSavedConfirm,
                    onChanged: (!_membershipFormDownloaded || _finishing)
                        ? null
                        : (v) => setState(
                            () => _membershipFormSavedConfirm = v ?? false,
                          ),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                    activeColor: PortalTheme.navy,
                    title: Text(
                      'I saved my Membership Form',
                      style: PortalTheme.body.copyWith(
                        color: _membershipFormDownloaded
                            ? PortalTheme.navy
                            : PortalTheme.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      _membershipFormDownloaded
                          ? 'Required before entering the portal'
                          : 'Download the form first',
                      style: PortalTheme.meta,
                    ),
                  ),
                ],
              ),
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
        onPrimary: _canEnterPortal ? _finishOnboarding : null,
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
