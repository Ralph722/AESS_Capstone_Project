import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:alumni_system/core/services/app_session.dart';
import 'package:alumni_system/core/services/audit_service.dart';
import 'package:alumni_system/core/utils/app_image.dart';
import 'package:alumni_system/features/alumni/profile/data/user_profile_events.dart';
import 'package:alumni_system/features/alumni/tracer/models/tracer_profile_model.dart';
import 'package:alumni_system/features/messages/data/image_storage_service.dart';
import 'package:alumni_system/features/onboarding/data/onboarding_service.dart';
import 'package:alumni_system/features/alumni/profile/data/user_profile_service.dart';
import 'package:alumni_system/features/shell/presentation/main_navigation.dart';
import 'package:alumni_system/shared/widgets/gts/gts_profile_form.dart';
import 'package:alumni_system/shared/widgets/onboarding/onboarding_ui.dart';

/// Mandatory onboarding: GTS profile + optional photo.
class AlumniOnboardingScreen extends StatefulWidget {
  const AlumniOnboardingScreen({super.key});

  @override
  State<AlumniOnboardingScreen> createState() => _AlumniOnboardingScreenState();
}

class _AlumniOnboardingScreenState extends State<AlumniOnboardingScreen> {
  static const _stepLabels = ['Welcome', 'Profile', 'Photo', 'Done'];

  final _profileFormKey = GlobalKey<FormState>();
  final _profileService = UserProfileService();
  final _onboardingService = OnboardingService();
  final _auditService = AuditService();
  final _imageStorage = ImageStorageService();
  final _imagePicker = ImagePicker();
  final _formState = GtsProfileFormState();

  int _step = 0;
  bool _finishing = false;
  String? _profileImageUrl;
  File? _selectedImage;
  Uint8List? _selectedImageBytes;

  /// Background work started while navigating — awaited only on final finish.
  Future<void> _pendingSave = Future.value();

  @override
  void initState() {
    super.initState();
    unawaited(_loadInitialData());
  }

  Future<void> _loadInitialData() async {
    final userId = AppSession.userId;
    if (userId == null) return;

    _formState.emailController.text = AppSession.email ?? '';

    final boot = await _profileService.getOnboardingBootstrap(uid: userId);
    if (!mounted) return;

    if (boot.profile != null) {
      _formState.applyFromProfile(boot.profile!);
      if (_formState.emailController.text.isEmpty) {
        _formState.emailController.text = boot.profile!.email;
      }
    }

    setState(() => _profileImageUrl = boot.imageUrl);
  }

  void _goToStep(int step) {
    if (_step == step) return;
    setState(() => _step = step);
  }

  void _queueBackground(Future<void> work) {
    _pendingSave = _pendingSave.then((_) => work).catchError((Object e) {
      // Surface later if finish still needs it; don't block navigation.
      debugPrint('Onboarding background save error: $e');
    });
  }

  void _saveProfileAndNext() {
    if (!_profileFormKey.currentState!.validate()) return;

    if (_formState.employmentStatus.isEmpty) {
      _snack('Select your employment status.', isError: true);
      return;
    }

    final completion = TracerProfile.computeCompletion(
      _formState.completionPayload(),
    );
    if (completion < 100) {
      _snack(
        'Please complete all required profile fields (${completion.toStringAsFixed(0)}% done).',
        isError: true,
      );
      return;
    }

    final userId = AppSession.userId;
    if (userId == null) return;

    final profile = _formState.toTracerProfile(
      uid: userId,
      email: AppSession.email ?? '',
    );

    // Navigate first — persist in the background.
    _goToStep(2);
    _queueBackground(
      _profileService.saveTracerProfile(profile, syncRoster: false),
    );
  }

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
        if (!mounted) return;
        setState(() {
          _selectedImageBytes = bytes;
          _selectedImage = null;
        });
      } else {
        setState(() {
          _selectedImage = File(image.path);
          _selectedImageBytes = null;
        });
      }
    } catch (e) {
      _snack('Could not pick image: $e', isError: true);
    }
  }

  void _continueFromPhoto({required bool skipUpload}) {
    final userId = AppSession.userId;
    if (userId == null) return;

    final bytes = _selectedImageBytes;
    final file = _selectedImage;
    final shouldUpload = !skipUpload && (bytes != null || file != null);

    // Navigate first — upload / roster sync in the background.
    _goToStep(3);

    _queueBackground(() async {
      if (shouldUpload) {
        var imageBytes = bytes;
        imageBytes ??= await file!.readAsBytes();
        final url = await _imageStorage.uploadProfileImage(
          userId: userId,
          bytes: imageBytes,
        );
        await _profileService.saveProfileImageUrl(uid: userId, imageUrl: url);
        UserProfileEvents.notifyAvatarChanged(url);
        if (mounted) setState(() => _profileImageUrl = url);
      }
      await _profileService.syncRosterFromSavedProfile(userId);
    }());
  }

  Future<void> _finishOnboarding() async {
    final userId = AppSession.userId;
    if (userId == null) return;

    setState(() => _finishing = true);
    try {
      // Flush any queued profile/photo work, then mark onboarding complete.
      await _pendingSave;
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
      // Skip AlumniHomeGate re-check — we just marked onboarding complete.
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainNavigation()),
      );
    } catch (e) {
      _snack('Could not finish setup: $e', isError: true);
      if (mounted) setState(() => _finishing = false);
    }
  }

  void _snack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : OnboardingTheme.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  String get _appBarTitle {
    switch (_step) {
      case 0:
        return 'Welcome';
      case 1:
        return 'Your profile';
      case 2:
        return 'Profile photo';
      default:
        return 'All set';
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _step == 0,
      child: Scaffold(
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
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _appBarTitle,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
              Text(
                'Step ${_step + 1} of ${_stepLabels.length}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.85),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          automaticallyImplyLeading: _step > 0,
          leading: _step > 0
              ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  tooltip: 'Previous step',
                  onPressed: _finishing
                      ? null
                      : () =>
                          _goToStep((_step - 1).clamp(0, _stepLabels.length - 1)),
                )
              : null,
        ),
        body: Column(
          children: [
            OnboardingStepStrip(currentIndex: _step, labels: _stepLabels),
            Expanded(
              child: IndexedStack(
                index: _step,
                sizing: StackFit.expand,
                children: [
                  _introStep(),
                  _profileStep(),
                  _photoStep(),
                  _completeStep(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _introStep() {
    return OnboardingStepLayout(
      centerShortContent: true,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: OnboardingTheme.navy.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.school_rounded,
                size: 36,
                color: OnboardingTheme.navy,
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Welcome to the Alumni Portal',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: OnboardingTheme.navy,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Complete your Graduate Tracer Study profile so we can keep your record accurate for CHED reporting.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              height: 1.45,
              color: OnboardingTheme.muted,
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: OnboardingTheme.gold.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Takes about 2–3 minutes',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: OnboardingTheme.navy,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: OnboardingTheme.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: OnboardingTheme.border),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'What you’ll do',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: OnboardingTheme.navy,
                  ),
                ),
                SizedBox(height: 12),
                OnboardingIntroBullet(
                  stepNumber: 1,
                  icon: Icons.person_outline,
                  title: 'Profile & employment',
                  subtitle:
                      'CHED GTS Section A, educational attainment, and employment status.',
                ),
                OnboardingIntroBullet(
                  stepNumber: 2,
                  icon: Icons.photo_camera_outlined,
                  title: 'Profile photo (optional)',
                  subtitle: 'Help classmates and admins recognize you.',
                ),
                OnboardingIntroBullet(
                  stepNumber: 3,
                  icon: Icons.check_circle_outline,
                  title: 'Enter the portal',
                  subtitle:
                      'You can update your profile anytime. Tracer surveys appear when published.',
                ),
              ],
            ),
          ),
        ],
      ),
      bottomBar: OnboardingBottomBar(
        primary: OnboardingPrimaryButton(
          label: 'Get started',
          onPressed: () => _goToStep(1),
        ),
      ),
    );
  }

  Widget _profileStep() {
    return OnboardingStepLayout(
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Graduate Tracer profile',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: OnboardingTheme.navy,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Use exact information from the CHED GTS form. Fields marked * are required.',
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: OnboardingTheme.muted,
            ),
          ),
          const SizedBox(height: 16),
          Form(
            key: _profileFormKey,
            child: GtsProfileFormFields(
              state: _formState,
              emailReadOnly: true,
              showEmploymentStatus: true,
              showProgress: true,
              enabled: !_finishing,
              onChanged: () => setState(() {}),
            ),
          ),
        ],
      ),
      bottomBar: OnboardingBottomBar(
        primary: OnboardingPrimaryButton(
          label: 'Save & continue',
          onPressed: _finishing ? null : _saveProfileAndNext,
        ),
      ),
    );
  }

  Widget _photoStep() {
    final hasLocalPreview =
        _selectedImageBytes != null || _selectedImage != null;
    final hasRemoteImage =
        _profileImageUrl != null && _profileImageUrl!.trim().isNotEmpty;

    return OnboardingStepLayout(
      centerShortContent: true,
      content: Column(
        children: [
          const Text(
            'Add a profile photo',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: OnboardingTheme.navy,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Optional — you can change this later from your profile.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: OnboardingTheme.muted,
            ),
          ),
          const SizedBox(height: 28),
          GestureDetector(
            onTap: _finishing ? null : _pickImage,
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxWidth: 340),
              padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
              decoration: BoxDecoration(
                color: OnboardingTheme.card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: OnboardingTheme.navy.withValues(alpha: 0.25),
                  width: 1.5,
                ),
              ),
              child: Column(
                children: [
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          color: OnboardingTheme.surface,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: OnboardingTheme.navy,
                            width: 3,
                          ),
                        ),
                        child: ClipOval(
                          child: _buildPhotoPreview(
                            hasLocalPreview: hasLocalPreview,
                            hasRemoteImage: hasRemoteImage,
                          ),
                        ),
                      ),
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: OnboardingTheme.navy,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    hasLocalPreview || hasRemoteImage
                        ? 'Tap to change photo'
                        : 'Tap to upload a photo',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: OnboardingTheme.navy,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'JPG or PNG · max recommended 5 MB',
                    style: TextStyle(
                      fontSize: 12,
                      color: OnboardingTheme.muted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomBar: OnboardingBottomBar(
        primary: OnboardingPrimaryButton(
          label: hasLocalPreview ? 'Upload & continue' : 'Continue',
          onPressed: _finishing
              ? null
              : () => _continueFromPhoto(skipUpload: !hasLocalPreview),
        ),
        secondary: TextButton(
          onPressed:
              _finishing ? null : () => _continueFromPhoto(skipUpload: true),
          style: TextButton.styleFrom(
            foregroundColor: OnboardingTheme.muted,
          ),
          child: const Text('Skip for now'),
        ),
      ),
    );
  }

  Widget _buildPhotoPreview({
    required bool hasLocalPreview,
    required bool hasRemoteImage,
  }) {
    if (_selectedImageBytes != null) {
      return Image.memory(
        _selectedImageBytes!,
        width: 140,
        height: 140,
        fit: BoxFit.cover,
      );
    }
    if (_selectedImage != null) {
      return Image.file(
        _selectedImage!,
        width: 140,
        height: 140,
        fit: BoxFit.cover,
      );
    }
    if (hasRemoteImage) {
      return AppImage.widget(
        _profileImageUrl!,
        width: 140,
        height: 140,
        fit: BoxFit.cover,
      );
    }
    return const Icon(Icons.person_outline, size: 64, color: OnboardingTheme.muted);
  }

  Widget _completeStep() {
    return OnboardingStepLayout(
      centerShortContent: true,
      content: Column(
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: OnboardingTheme.success.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_rounded,
              size: 52,
              color: OnboardingTheme.success,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'You’re all set!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: OnboardingTheme.navy,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Your Graduate Tracer profile is saved. When your school publishes a tracer survey, it will appear under the Tracer tab.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: OnboardingTheme.muted,
            ),
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: OnboardingTheme.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: OnboardingTheme.border),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, size: 18, color: OnboardingTheme.navy),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'You can update your profile anytime from the Profile tab.',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      color: OnboardingTheme.navy,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomBar: OnboardingBottomBar(
        primary: OnboardingPrimaryButton(
          label: 'Enter alumni portal',
          onPressed: _finishing ? null : _finishOnboarding,
          loading: _finishing,
          showTrailingArrow: false,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _formState.dispose();
    super.dispose();
  }
}
