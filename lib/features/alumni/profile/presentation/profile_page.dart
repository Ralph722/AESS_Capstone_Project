import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:alumni_system/features/auth/presentation/auth_gate.dart';
import 'package:alumni_system/features/admin/roster/data/alumni_member_service.dart';
import 'package:alumni_system/core/services/app_session.dart';
import 'package:alumni_system/features/messages/data/image_storage_service.dart';
import 'package:alumni_system/features/alumni/profile/data/user_profile_events.dart';
import 'package:alumni_system/core/utils/app_image.dart';
import 'package:alumni_system/core/utils/avatar_image_prepare.dart';
import 'package:alumni_system/core/services/audit_service.dart';
import 'package:alumni_system/features/auth/data/auth_service.dart';
import 'package:alumni_system/features/alumni/tracer/models/tracer_profile_model.dart';
import 'package:alumni_system/features/alumni/profile/data/user_profile_service.dart';
import 'package:alumni_system/features/feedback/presentation/user_feedback_list_page.dart';
import 'package:alumni_system/features/surveys/presentation/user_surveys_page.dart';
import 'package:alumni_system/features/messages/presentation/user_messages_page.dart';
import 'package:alumni_system/features/ai/presentation/ai_assistant_page.dart';
import 'package:alumni_system/shared/widgets/gts/gts_profile_form.dart';
import 'package:alumni_system/shared/widgets/user/portal_skeletons.dart';
import 'package:alumni_system/shared/widgets/user/portal_states.dart';
import 'package:alumni_system/shared/widgets/user/portal_theme.dart';
import 'package:alumni_system/shared/widgets/user/portal_headers.dart';
import 'package:alumni_system/shared/widgets/user/portal_breakpoints.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => ProfileScreenState();
}

class ProfileScreenState extends State<ProfileScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final SupabaseClient _supabase = Supabase.instance.client;
  final ImagePicker _imagePicker = ImagePicker();
  final AuditService _auditService = AuditService();
  final AuthService _authService = AuthService();
  final ImageStorageService _imageStorage = ImageStorageService();
  final UserProfileService _userProfileService = UserProfileService();
  final _profileFormKey = GlobalKey<FormState>();
  final _formState = GtsProfileFormState();
  final _formSectionKey = GlobalKey();

  bool _isLoading = false;
  bool _isSaving = false;
  bool _isUploadingImage = false;
  bool _dirty = false;
  String? _profileImageUrl;
  Uint8List? _selectedImageBytes;
  StreamSubscription<void>? _profileFieldsSub;

  bool get hasUnsavedChanges => _dirty;

  void _markDirty() {
    if (_isLoading || _dirty) return;
    setState(() => _dirty = true);
  }

  Future<bool> confirmLeave() async {
    if (!_dirty) return true;
    final discard = await confirmDiscardChanges(context);
    if (discard && mounted) setState(() => _dirty = false);
    return discard;
  }

  @override
  void initState() {
    super.initState();
    _profileFieldsSub = UserProfileEvents.onProfileFieldsChanged.listen((_) {
      if (mounted) _loadUserData();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadUserData();
    });
  }

  @override
  void dispose() {
    _profileFieldsSub?.cancel();
    _formState.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
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

  Future<void> _saveProfile() async {
    if (!_profileFormKey.currentState!.validate()) return;

    final userId = AppSession.userId;
    if (userId == null) return;

    setState(() => _isSaving = true);
    try {
      final profile = _formState.toTracerProfile(
        uid: userId,
        email: AppSession.email ?? '',
      );
      await _userProfileService.saveTracerProfile(profile);

      await _auditService.logAction(
        action: 'UPDATE',
        resource: 'Profile',
        resourceId: userId,
        description: 'User updated live GTS profile',
        status: 'SUCCESS',
      );

      if (mounted) {
        setState(() => _dirty = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Profile updated successfully!'),
            backgroundColor: PortalTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving profile: ${portalFriendlyError(e)}'),
            backgroundColor: PortalTheme.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _pickImage() async {
    if (!mounted) return;
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 95,
        maxWidth: 2048,
      );
      if (image == null || !mounted) return;

      final rawBytes = await image.readAsBytes();
      if (!mounted) return;
      setState(() {
        _selectedImageBytes = rawBytes;
      });
      await _uploadProfileImage();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error picking image: $e')));
      }
    }
  }

  Future<void> _uploadProfileImage() async {
    if (!mounted) return;
    setState(() => _isUploadingImage = true);

    try {
      final userId = AppSession.userId;
      if (userId == null) return;

      final imageBytes = _selectedImageBytes;
      if (imageBytes == null) return;

      final prepared = await AvatarImagePrepare.toSquareJpeg(imageBytes);

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
      if (mounted) {
        setState(() {
          _profileImageUrl = uploadedImageUrl;
          _selectedImageBytes = null;
        });
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

  void _scrollToForm() {
    final ctx = _formSectionKey.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: PortalTheme.normal,
      curve: PortalTheme.ease,
      alignment: 0.05,
    );
  }

  String get _displayName {
    final trimmed = _formState.displayNameController.text.trim();
    return trimmed.isEmpty ? (AppSession.email ?? 'Alumni') : trimmed;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final completion = TracerProfile.computeCompletion(
      _formState.completionPayload(),
    );
    final hPad = PortalBreakpoints.pagePadding(
      PortalBreakpoints.widthOf(context),
    ).horizontal / 2;

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || !_dirty) return;
        final discard = await confirmLeave();
        if (!discard || !mounted) return;
        if (!context.mounted) return;
        Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: PortalTheme.pageBg,
        appBar: PortalAppBar(
          title: 'Profile',
          centerTitle: true,
          automaticallyImplyLeading: false,
          actions: [
            if (!_isLoading)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: PortalChip(
                  label: '${completion.toStringAsFixed(0)}% complete',
                  tone: completion >= 100
                      ? PortalChipTone.success
                      : PortalChipTone.gold,
                  icon: completion >= 100
                      ? Icons.check_circle_outline
                      : Icons.pending_outlined,
                ),
              ),
          ],
        ),
        body: _isLoading
            ? const ProfileSkeleton()
            : PortalContentFrame(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(hPad, 0, hPad, 100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: PortalTheme.space3),
                      _buildIdentityHero(completion),
                      const SizedBox(height: PortalTheme.space4),
                      KeyedSubtree(
                        key: _formSectionKey,
                        child: _buildProfileFormSection(),
                      ),
                      const SizedBox(height: PortalTheme.space3),
                      FilledButton(
                        onPressed: _isSaving ? null : _saveProfile,
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
                      const SizedBox(height: PortalTheme.space5),
                      _buildAccountSection(),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildIdentityHero(double completion) {
    final program = _formState.program.trim();
    final year = _formState.yearGraduatedController.text.trim().isNotEmpty
        ? _formState.yearGraduatedController.text.trim()
        : _formState.batchYear.trim();
    final employment = _formState.employmentStatus.trim();
    final college = _formState.collegeController.text.trim();

    return Container(
      decoration: BoxDecoration(
        color: PortalTheme.card,
        borderRadius: BorderRadius.circular(PortalTheme.radiusXl),
        boxShadow: PortalTheme.cardShadow,
        border: Border.all(color: PortalTheme.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            height: 72,
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: PortalTheme.heroGradient,
            ),
          ),
          Transform.translate(
            offset: const Offset(0, -44),
            child: Column(
              children: [
                _buildAvatarRing(),
                const SizedBox(height: PortalTheme.space2),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      Text(
                        _displayName,
                        textAlign: TextAlign.center,
                        style: PortalTheme.sectionTitle.copyWith(
                          fontSize: 22,
                          color: PortalTheme.navy,
                        ),
                      ),
                      if (program.isNotEmpty || year.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          [
                            if (program.isNotEmpty) program,
                            if (year.isNotEmpty) 'Batch $year',
                          ].join(' · '),
                          textAlign: TextAlign.center,
                          style: PortalTheme.bodySecondary,
                        ),
                      ],
                      if (employment.isNotEmpty || college.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          [
                            if (employment.isNotEmpty) employment,
                            if (college.isNotEmpty) college,
                          ].join(' · '),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: PortalTheme.meta,
                        ),
                      ],
                      const SizedBox(height: PortalTheme.space2),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          PortalChip(
                            label: completion >= 100
                                ? 'Profile complete'
                                : 'Verified alumni',
                            tone: completion >= 100
                                ? PortalChipTone.success
                                : PortalChipTone.brand,
                            icon: Icons.verified_outlined,
                          ),
                          if (_dirty)
                            const PortalChip(
                              label: 'Unsaved changes',
                              tone: PortalChipTone.warning,
                              icon: Icons.edit_note,
                            ),
                        ],
                      ),
                      const SizedBox(height: PortalTheme.space2),
                      TextButton.icon(
                        onPressed: _scrollToForm,
                        style: PortalTheme.ghostButton(dense: true),
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: const Text('Edit profile details'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
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
            width: 96,
            height: 96,
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
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : provider == null
                    ? Icon(
                        Icons.person_rounded,
                        size: 48,
                        color: PortalTheme.navy.withValues(alpha: 0.35),
                      )
                    : null,
          ),
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: PortalTheme.navy,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: const Icon(
              Icons.camera_alt_rounded,
              color: Colors.white,
              size: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileFormSection() {
    return Container(
      padding: const EdgeInsets.all(PortalTheme.space4),
      decoration: BoxDecoration(
        color: PortalTheme.card,
        borderRadius: BorderRadius.circular(PortalTheme.radiusLg),
        border: Border.all(color: PortalTheme.border),
        boxShadow: PortalTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PortalSectionHeader(
            title: 'Profile information',
            subtitle:
                'CHED GTS demographics, education, and employment. Updates your live alumni record.',
          ),
          const SizedBox(height: PortalTheme.space3),
          Form(
            key: _profileFormKey,
            child: GtsProfileFormFields(
              state: _formState,
              emailReadOnly: true,
              showEmploymentStatus: true,
              enabled: !_isSaving,
              onChanged: () {
                _markDirty();
                setState(() {});
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: PortalTheme.space2),
          child: Text('Account', style: PortalTheme.cardTitle),
        ),
        Container(
          decoration: BoxDecoration(
            color: PortalTheme.card,
            borderRadius: BorderRadius.circular(PortalTheme.radiusLg),
            border: Border.all(color: PortalTheme.border),
            boxShadow: PortalTheme.softShadow,
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              _PortalAccountRow(
                icon: Icons.poll_outlined,
                iconColor: PortalTheme.sky,
                title: 'My Surveys',
                subtitle: 'Complete tracer and alumni surveys',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const UserSurveysScreen(),
                    ),
                  );
                },
              ),
              const _PortalAccountDivider(),
              _PortalAccountRow(
                icon: Icons.support_agent_outlined,
                iconColor: PortalTheme.navyMid,
                title: 'Support messages',
                subtitle: 'Chat with the alumni office',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          const UserMessagesScreen(isTabActive: true),
                    ),
                  );
                },
              ),
              const _PortalAccountDivider(),
              _PortalAccountRow(
                icon: Icons.feedback_outlined,
                iconColor: PortalTheme.amber,
                title: 'Feedback',
                subtitle: 'Share bugs, ideas, or issues',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const UserFeedbackListScreen(),
                    ),
                  );
                },
              ),
              const _PortalAccountDivider(),
              _PortalAccountRow(
                icon: Icons.auto_awesome,
                iconColor: PortalTheme.gold,
                title: 'AI Help',
                subtitle: 'Ask questions about the portal',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AiAssistantScreen(
                        isAdmin: false,
                        userDisplayName:
                            _formState.displayNameController.text,
                      ),
                    ),
                  );
                },
              ),
              const _PortalAccountDivider(),
              _PortalAccountRow(
                icon: Icons.logout_rounded,
                iconColor: PortalTheme.danger,
                title: 'Logout',
                subtitle: 'Sign out of your account',
                titleColor: PortalTheme.danger,
                onTap: () async {
                  final userId = AppSession.userId;
                  if (userId != null) {
                    await _auditService.logAction(
                      action: 'LOGOUT',
                      resource: 'User',
                      resourceId: userId,
                      description: 'User logged out: ${AppSession.email}',
                      status: 'SUCCESS',
                    );
                  }
                  await _authService.logout();
                  if (!mounted) return;
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const AuthGate()),
                    (route) => false,
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PortalAccountDivider extends StatelessWidget {
  const _PortalAccountDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      indent: 68,
      color: PortalTheme.border.withValues(alpha: 0.8),
    );
  }
}

class _PortalAccountRow extends StatelessWidget {
  const _PortalAccountRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.titleColor,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color? titleColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: PortalTheme.space3,
            vertical: PortalTheme.space2 + 2,
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(PortalTheme.radiusMd),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: PortalTheme.space2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: PortalTheme.cardTitle.copyWith(
                        fontSize: 15,
                        color: titleColor ?? PortalTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(subtitle, style: PortalTheme.caption),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: PortalTheme.textMuted,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
