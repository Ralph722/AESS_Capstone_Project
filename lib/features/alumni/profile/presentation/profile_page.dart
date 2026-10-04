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
import 'package:alumni_system/features/alumni/profile/data/user_profile_events.dart';
import 'package:alumni_system/features/alumni/profile/data/user_profile_service.dart';
import 'package:alumni_system/features/alumni/profile/presentation/profile_information_page.dart';
import 'package:alumni_system/features/auth/data/auth_service.dart';
import 'package:alumni_system/features/auth/presentation/auth_gate.dart';
import 'package:alumni_system/features/feedback/presentation/user_feedback_list_page.dart';
import 'package:alumni_system/features/messages/data/image_storage_service.dart';
import 'package:alumni_system/features/messages/presentation/user_messages_page.dart';
import 'package:alumni_system/features/notifications/presentation/notifications_page.dart';
import 'package:alumni_system/features/surveys/presentation/user_surveys_page.dart';
import 'package:alumni_system/shared/widgets/user/portal_breakpoints.dart';
import 'package:alumni_system/shared/widgets/user/portal_headers.dart';
import 'package:alumni_system/shared/widgets/user/portal_skeletons.dart';
import 'package:alumni_system/shared/widgets/user/portal_states.dart';
import 'package:alumni_system/shared/widgets/user/portal_theme.dart';

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

  bool _isLoading = false;
  bool _isUploadingImage = false;
  String? _profileImageUrl;
  double _completion = 0;
  StreamSubscription<void>? _profileFieldsSub;

  /// Hub no longer hosts the editable form; discard prompts live on that screen.
  bool get hasUnsavedChanges => false;

  Future<bool> confirmLeave() async => true;

  @override
  void initState() {
    super.initState();
    _profileFieldsSub = UserProfileEvents.onProfileFieldsChanged.listen((_) {
      if (mounted) _loadHubData();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadHubData();
    });
  }

  @override
  void dispose() {
    _profileFieldsSub?.cancel();
    super.dispose();
  }

  Future<void> _loadHubData() async {
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

      final completion = profile?.completionPercent ?? 0.0;

      if (!mounted) return;
      setState(() {
        _profileImageUrl = row?['profile_image_base64'] as String?;
        _completion = completion;
      });
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _openProfileInformation() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProfileInformationScreen()),
    );
    if (mounted) await _loadHubData();
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
      await _uploadProfileImage(rawBytes);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
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
        action: 'UPDATE',
        resource: 'Profile',
        resourceId: userId,
        description: 'User updated profile photo',
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

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final hPad = PortalBreakpoints.pagePadding(
          PortalBreakpoints.widthOf(context),
        ).horizontal /
        2;

    return Scaffold(
      backgroundColor: PortalTheme.pageBg,
      appBar: const PortalAppBar(
        title: 'Profile',
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: _isLoading
          ? const ProfileSkeleton()
          : PortalContentFrame(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(hPad, 0, hPad, 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: PortalTheme.space4),
                    _buildPhotoCard(),
                    const SizedBox(height: PortalTheme.space5),
                    _buildAccountSection(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildPhotoCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
      decoration: BoxDecoration(
        color: PortalTheme.card,
        borderRadius: BorderRadius.circular(PortalTheme.radius2xl),
        border: Border.all(color: PortalTheme.border.withValues(alpha: 0.75)),
        boxShadow: PortalTheme.softShadow,
      ),
      child: Column(
        children: [
          _buildAvatarRing(),
          const SizedBox(height: PortalTheme.space3),
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
                    child: CircularProgressIndicator(strokeWidth: 2),
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

  Widget _buildAccountSection() {
    final completionLabel = _completion <= 0
        ? 'Edit demographics, education, and employment'
        : '${_completion.toStringAsFixed(0)}% complete — tap to edit';

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
            borderRadius: BorderRadius.circular(PortalTheme.radius2xl),
            border: Border.all(
              color: PortalTheme.border.withValues(alpha: 0.75),
            ),
            boxShadow: PortalTheme.softShadow,
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              _PortalAccountRow(
                icon: Icons.badge_outlined,
                iconColor: PortalTheme.navy,
                title: 'Profile information',
                subtitle: completionLabel,
                onTap: _openProfileInformation,
              ),
              const _PortalAccountDivider(),
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
                icon: Icons.notifications_outlined,
                iconColor: PortalTheme.navy,
                title: 'Notifications',
                subtitle: 'History and alert settings',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const NotificationsScreen(),
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
                        color: titleColor ?? PortalTheme.navy,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(subtitle, style: PortalTheme.caption),
                  ],
                ),
              ),
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: PortalTheme.navy.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.chevron_right_rounded,
                  color: PortalTheme.navy,
                  size: 18,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
