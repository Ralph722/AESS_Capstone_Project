import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:alumni_system/core/services/app_session.dart';
import 'package:alumni_system/core/services/audit_service.dart';
import 'package:alumni_system/core/utils/app_image.dart';
import 'package:alumni_system/core/utils/avatar_image_prepare.dart';
import 'package:alumni_system/features/admin/roster/data/alumni_member_service.dart';
import 'package:alumni_system/features/alumni/profile/data/profile_change_diff.dart';
import 'package:alumni_system/features/alumni/profile/data/user_profile_events.dart';
import 'package:alumni_system/features/alumni/profile/data/user_profile_service.dart';
import 'package:alumni_system/features/alumni/profile/presentation/avatar_crop_dialog.dart';
import 'package:alumni_system/features/alumni/tracer/models/tracer_profile_model.dart';
import 'package:alumni_system/features/contact_verification/data/contact_verification_service.dart';
import 'package:alumni_system/features/contact_verification/presentation/contact_verify_sheet.dart';
import 'package:alumni_system/features/messages/data/image_storage_service.dart';
import 'package:alumni_system/shared/widgets/gts/gts_profile_form.dart';
import 'package:alumni_system/shared/widgets/onboarding/onboarding_ui.dart';
import 'package:alumni_system/shared/widgets/user/portal_breakpoints.dart';
import 'package:alumni_system/shared/widgets/user/portal_headers.dart';
import 'package:alumni_system/shared/widgets/user/portal_skeletons.dart';
import 'package:alumni_system/shared/widgets/user/portal_states.dart';
import 'package:alumni_system/shared/widgets/user/portal_theme.dart';

/// Full GTS / alumni profile fields — opened from the Profile hub menu.
class ProfileInformationScreen extends StatefulWidget {
  const ProfileInformationScreen({super.key});

  @override
  State<ProfileInformationScreen> createState() =>
      _ProfileInformationScreenState();
}

class _ProfileInformationScreenState extends State<ProfileInformationScreen> {
  final _auditService = AuditService();
  final _userProfileService = UserProfileService();
  final _imagePicker = ImagePicker();
  final _imageStorage = ImageStorageService();
  final _supabase = Supabase.instance.client;
  final _profileFormKey = GlobalKey<FormState>();
  final _formState = GtsProfileFormState();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isUploadingImage = false;
  bool _dirty = false;
  String? _profileImageUrl;
  StreamSubscription<void>? _profileFieldsSub;

  /// Saved profile, for the contact verification status lines.
  TracerProfile? _profile;

  @override
  void initState() {
    super.initState();
    _profileFieldsSub = UserProfileEvents.onProfileFieldsChanged.listen((_) {
      if (mounted) _load();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  @override
  void dispose() {
    _profileFieldsSub?.cancel();
    _formState.dispose();
    super.dispose();
  }

  void _markDirty() {
    if (_isLoading || _dirty) return;
    setState(() => _dirty = true);
  }

  Future<bool> _confirmLeave() async {
    if (!_dirty) return true;
    final choice = await showDialog<_LeaveChoice>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Unsaved changes'),
        content: const Text(
          'You have unsaved changes to your profile. Would you like to save them before leaving?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, _LeaveChoice.discard),
            style: TextButton.styleFrom(
              foregroundColor: PortalTheme.danger,
            ),
            child: const Text('Discard'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, _LeaveChoice.keepEditing),
            style: PortalTheme.ghostButton(dense: true),
            child: const Text('Keep editing'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, _LeaveChoice.saveAndLeave),
            style: PortalTheme.primaryButton(dense: true),
            child: const Text('Save & leave'),
          ),
        ],
      ),
    );

    if (choice == _LeaveChoice.discard) {
      if (mounted) setState(() => _dirty = false);
      return true;
    } else if (choice == _LeaveChoice.saveAndLeave) {
      final saved = await _save();
      return saved;
    }
    return false;
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final userId = AppSession.userId;
      if (userId == null) return;
      final profile = await _userProfileService.getTracerProfile(userId);
      final row = await _supabase
          .from('users')
          .select('profile_image_base64')
          .eq('id', userId)
          .maybeSingle();
      _profile = profile;
      if (profile != null) {
        _formState.applyFromProfile(profile);
      }
      if (_formState.emailController.text.isEmpty) {
        _formState.emailController.text = AppSession.email ?? '';
      }
      if (mounted) {
        setState(() {
          _profileImageUrl = row?['profile_image_base64'] as String?;
          _dirty = false;
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage() async {
    if (!mounted || _isUploadingImage) return;
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 95,
        maxWidth: 2048,
      );
      if (image == null || !mounted) return;
      final rawBytes = await image.readAsBytes();
      if (rawBytes.length > ImageStorageService.maxSourceBytes) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Image is too large. Please choose a file under 12 MB.',
              ),
            ),
          );
        }
        return;
      }
      if (!mounted) return;
      final croppedBytes = await AvatarCropDialog.show(context, rawBytes);
      if (croppedBytes == null || !mounted) return;
      await _uploadProfileImage(croppedBytes);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(
          SnackBar(content: Text(portalFriendlyError(e))),
        );
      }
    }
  }

  Future<void> _uploadProfileImage(Uint8List rawBytes) async {
    if (!mounted) return;
    setState(() => _isUploadingImage = true);
    try {
      final userId = AppSession.userId;
      if (userId == null) return;

      final prepared = await AvatarImagePrepare.toSquareJpeg(rawBytes);
      final uploadedImageUrl = await _imageStorage.uploadProfileImage(
        userId: userId,
        bytes: prepared,
      );

      AppImage.clearDecodedCache();

      await _supabase
          .from('users')
          .update({
            'profile_image_base64': uploadedImageUrl,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', userId);
      await AlumniMemberService().mirrorProfileImageForAuthUid(
        userId,
        uploadedImageUrl,
      );

      UserProfileEvents.notifyAvatarChanged(uploadedImageUrl);

      await _auditService.logAction(
        action: 'PROFILE_UPDATE',
        resource: 'Profile',
        resourceId: userId,
        description: 'Updated profile photo',
        changes: profilePhotoChange('profile'),
        status: 'SUCCESS',
      );

      if (mounted) {
        setState(() => _profileImageUrl = uploadedImageUrl);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile photo updated'),
            backgroundColor: PortalTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: ${portalFriendlyError(e)}'),
            backgroundColor: PortalTheme.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  Future<bool> _save() async {
    if (!_profileFormKey.currentState!.validate()) return false;
    final userId = AppSession.userId;
    if (userId == null) return false;

    final changes = [
      for (final c in ContactChannel.values)
        if (_formState.contactChanged(c))
          ContactChange(
            channel: c,
            original: _formState.savedContact(c),
            value: _formState.currentContact(c),
          ),
    ];

    setState(() => _isSaving = true);
    try {
      // Contacts are saved only after verification (sheet below).
      final profile = _formState
          .toTracerProfile(uid: userId, email: AppSession.email ?? '')
          .copyWith(mobileNumber: _formState.savedMobile);
      await _userProfileService.saveTracerProfile(profile);
      if (!mounted) return true;
      if (changes.isEmpty) {
        setState(() => _dirty = false);
        _snack('Profile updated successfully!');
        return true;
      }
      setState(() => _isSaving = false);
      final saved = await showContactVerifySheet(
        context,
        changes: changes,
        message:
            'Your other changes are saved. Confirm your new contact details '
            'are yours with a one-time code so the alumni office can reach '
            'you.',
      );
      if (!mounted) return true;
      await _load();
      final unsaved = [
        for (final c in changes)
          if (!saved.containsKey(c.channel)) c.channel,
      ];
      _snack(
        unsaved.isEmpty
            ? (saved.containsKey(ContactChannel.email)
                  ? 'Profile updated. From now on, sign in with '
                        '${saved[ContactChannel.email]}.'
                  : 'Profile updated successfully!')
            : 'Your other changes were saved. ${_unsavedSentence(unsaved)}',
        error: unsaved.isNotEmpty,
      );
      return unsaved.isEmpty;
    } catch (e) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving profile: ${portalFriendlyError(e)}'),
          backgroundColor: PortalTheme.danger,
        ),
      );
      return false;
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  static String _unsavedSentence(List<ContactChannel> unsaved) {
    if (unsaved.length > 1) {
      return "Your email address and mobile number weren't changed because "
          "they weren't verified.";
    }
    return unsaved.single == ContactChannel.email
        ? "Your email address wasn't changed because it wasn't verified."
        : "Your mobile number wasn't changed because it wasn't verified.";
  }

  void _snack(String message, {bool error = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: error ? PortalTheme.warning : PortalTheme.success,
        ),
      );
  }

  /// Verifies a saved contact that was never checked (no edit needed).
  Future<void> _verifySaved(ContactChannel channel) async {
    final value = _formState.savedContact(channel);
    final saved = await showContactVerifySheet(
      context,
      changes: [ContactChange(channel: channel, original: value, value: value)],
    );
    if (saved.isEmpty || !mounted) return;
    final userId = AppSession.userId;
    if (userId == null) return;
    try {
      final profile = await _userProfileService.getTracerProfile(userId);
      if (mounted) setState(() => _profile = profile);
    } catch (_) {}
  }

  Widget? _contactFooter(ContactChannel channel) {
    final profile = _profile;
    if (profile == null) return null;
    final isEmail = channel == ContactChannel.email;

    if (_formState.contactChanged(channel)) {
      return _ContactStatusLine(
        icon: Icons.pending_outlined,
        color: PortalTheme.warning,
        text: isEmail
            ? "Needs verification. We'll email you a code when you save. "
                  'That address will become how you sign in.'
            : "Needs verification. You'll confirm it with a code when you "
                  'save.',
      );
    }
    if (_formState.savedContact(channel).trim().isEmpty) return null;

    if (isEmail) {
      return profile.contactEmailVerified
          ? const _ContactStatusLine(
              icon: Icons.verified_rounded,
              color: PortalTheme.success,
              text: 'Verified',
            )
          : _ContactStatusLine(
              icon: Icons.info_outline_rounded,
              color: PortalTheme.textSecondary,
              text: 'Not verified',
              onVerify: _isSaving ? null : () => _verifySaved(channel),
            );
    }
    if (profile.mobileVerified) {
      return const _ContactStatusLine(
        icon: Icons.verified_rounded,
        color: PortalTheme.success,
        text: 'Verified by text message',
      );
    }
    if (profile.mobileDemoConfirmed) {
      return const _ContactStatusLine(
        icon: Icons.check_circle_outline_rounded,
        color: PortalTheme.success,
        text: 'Confirmed with a demo code. Text message check coming soon.',
      );
    }
    return _ContactStatusLine(
      icon: Icons.info_outline_rounded,
      color: PortalTheme.textSecondary,
      text: 'Not verified',
      onVerify: _isSaving ? null : () => _verifySaved(channel),
    );
  }

  @override
  Widget build(BuildContext context) {
    const hPad = 16.0;

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || !_dirty) return;
        final discard = await _confirmLeave();
        if (!discard || !mounted) return;
        if (!context.mounted) return;
        Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: const PortalAppBar(
          title: 'Profile information',
          automaticallyImplyLeading: true,
        ),
        bottomNavigationBar: _buildDirtyBar(),
        body: PortalContentFrame(
          child: _isLoading
              ? const ProfileSkeleton()
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(hPad, 12, hPad, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildPhotoHeader(),
                      if (_dirty) ...[
                        const SizedBox(height: PortalTheme.space3),
                        const PortalChip(
                          label: 'Unsaved changes',
                          tone: PortalChipTone.gold,
                          icon: Icons.edit_note,
                        ),
                      ],
                      const SizedBox(height: PortalTheme.space4),
                      Form(
                        key: _profileFormKey,
                        child: GtsProfileFormFields(
                          state: _formState,
                          emailReadOnly: true,
                          demographicReadOnly: true,
                          showContactEmail: true,
                          contactFooter: _contactFooter,
                          showEmploymentStatus: false,
                          chedStyleLabels: false,
                          enabled: !_isSaving,
                          onChanged: () {
                            _markDirty();
                            setState(() {});
                          },
                        ),
                      ),
                      const SizedBox(height: PortalTheme.space3),
                      FilledButton(
                        onPressed: _isSaving ? null : _save,
                        style: PortalTheme.primaryButton(),
                        child: _isSaving
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Save profile'),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget? _buildDirtyBar() {
    if (!_dirty) return null;
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        10,
        16,
        10 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, -3),
          ),
        ],
        border: const Border(
          top: BorderSide(color: PortalTheme.border),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(
                        Icons.edit_note_rounded,
                        size: 20,
                        color: PortalTheme.navy,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Unsaved changes',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: PortalTheme.navy,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Remember to save your profile edits',
                    style: PortalTheme.caption.copyWith(
                      color: PortalTheme.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed: _isSaving ? null : () => _save(),
              style: PortalTheme.primaryButton(dense: true),
              icon: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check_rounded, size: 18),
              label: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: PortalTheme.space3),
      child: Column(
        children: [
          _buildAvatarRing(),
          const SizedBox(height: PortalTheme.space2),
          Text(
            'Tap photo to update',
            style: PortalTheme.caption.copyWith(
              color: PortalTheme.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarRing() {
    final provider = _profileImageUrl == null
        ? null
        : AppImage.provider(_profileImageUrl);

    return GestureDetector(
      onTap: _pickImage,
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: PortalTheme.surfaceMuted,
              border: Border.all(color: PortalTheme.gold, width: 3),
              boxShadow: PortalTheme.softShadow,
              image: _isUploadingImage || provider == null
                  ? null
                  : DecorationImage(
                      image: provider,
                      fit: BoxFit.cover,
                      filterQuality: FilterQuality.high,
                    ),
            ),
            clipBehavior: Clip.antiAlias,
            child: _isUploadingImage
                ? const Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: PortalTheme.navy,
                    ),
                  )
                : provider == null
                ? Icon(
                    Icons.person_rounded,
                    size: 56,
                    color: PortalTheme.navy.withValues(alpha: 0.35),
                  )
                : null,
          ),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: PortalTheme.navy,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: const Icon(
              Icons.camera_alt_rounded,
              color: Colors.white,
              size: 18,
            ),
          ),
        ],
      ),
    );
  }
}

/// Verification status under the contact email / mobile field.
class _ContactStatusLine extends StatelessWidget {
  const _ContactStatusLine({
    required this.icon,
    required this.color,
    required this.text,
    this.onVerify,
  });

  final IconData icon;
  final Color color;
  final String text;
  final VoidCallback? onVerify;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 4, OnboardingSpacing.fieldGap),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: PortalTheme.meta.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (onVerify != null)
            TextButton(
              onPressed: onVerify,
              style: PortalTheme.ghostButton(dense: true),
              child: const Text('Verify'),
            ),
        ],
      ),
    );
  }
}

enum _LeaveChoice { discard, keepEditing, saveAndLeave }
