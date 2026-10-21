import 'dart:async';

import 'package:flutter/material.dart';
import 'package:alumni_system/core/services/app_session.dart';
import 'package:alumni_system/core/services/audit_service.dart';
import 'package:alumni_system/features/alumni/card/data/alumni_card_service.dart';
import 'package:alumni_system/features/alumni/card/models/alumni_card_data.dart';
import 'package:alumni_system/features/alumni/card/presentation/alumni_digital_card.dart';
import 'package:alumni_system/features/alumni/profile/data/user_profile_events.dart';
import 'package:alumni_system/features/alumni/profile/presentation/change_password_page.dart';
import 'package:alumni_system/features/alumni/profile/presentation/profile_information_page.dart';
import 'package:alumni_system/features/auth/data/auth_service.dart';
import 'package:alumni_system/features/auth/presentation/auth_gate.dart';
import 'package:alumni_system/features/shell/presentation/main_navigation.dart';
import 'package:alumni_system/features/feedback/presentation/user_feedback_list_page.dart';
import 'package:alumni_system/features/messages/presentation/user_messages_page.dart';
import 'package:alumni_system/features/notifications/presentation/notifications_page.dart';
import 'package:alumni_system/features/surveys/presentation/user_surveys_page.dart';
import 'package:alumni_system/shared/widgets/user/portal_breakpoints.dart';
import 'package:alumni_system/shared/widgets/user/portal_floating.dart';
import 'package:alumni_system/shared/widgets/user/portal_headers.dart';
import 'package:alumni_system/shared/widgets/user/portal_skeletons.dart';
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

  final AuditService _auditService = AuditService();
  final AuthService _authService = AuthService();
  final AlumniCardService _cardService = AlumniCardService();

  AlumniCardLoadResult? _cardResult;
  var _cardLoading = true;
  var _showingCardBack = false;
  StreamSubscription<void>? _profileFieldsSub;
  StreamSubscription<String?>? _avatarSub;

  /// Hub no longer hosts the editable form; discard prompts live on that screen.
  bool get hasUnsavedChanges => false;

  Future<bool> confirmLeave() async => true;

  @override
  void initState() {
    super.initState();
    _profileFieldsSub = UserProfileEvents.onProfileFieldsChanged.listen((_) {
      if (mounted) _loadHubData();
    });
    _avatarSub = UserProfileEvents.onAvatarChanged.listen((_) {
      if (mounted) _loadCard();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadHubData();
    });
  }

  @override
  void dispose() {
    _profileFieldsSub?.cancel();
    _avatarSub?.cancel();
    super.dispose();
  }

  Future<void> _loadHubData() async {
    if (!mounted) return;
    await _loadCard();
  }

  Future<void> _loadCard() async {
    if (!mounted) return;
    setState(() => _cardLoading = true);
    try {
      final result = await _cardService.loadForCurrentUser();
      if (!mounted) return;
      setState(() {
        _cardResult = result;
        _cardLoading = false;
        if (result.status != AlumniCardStatus.ready) {
          _showingCardBack = false;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _cardResult = const AlumniCardLoadResult.unmatched();
        _cardLoading = false;
        _showingCardBack = false;
      });
    }
  }

  Future<void> _openProfileInformation() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProfileInformationScreen()),
    );
    if (mounted) await _loadHubData();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    const hPad = 16.0;

    return Scaffold(
      backgroundColor: PortalTheme.pageBg,
      appBar: const PortalAppBar(
        title: 'Profile',
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: PortalContentFrame(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            hPad,
            0,
            hPad,
            PortalFloating.bottomClearance(context),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: PortalTheme.space4),
              _buildDigitalCardSection(),
              const SizedBox(height: PortalTheme.space5),
              _buildAccountSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDigitalCardSection() {
    // Digital ID only — no white card chrome around it.
    return Column(
      children: [
        if (_cardLoading)
          const AlumniCardSkeleton(
            maxWidth: kAlumniCardMaxWidth,
            aspectRatio: kAlumniCardAspectRatio,
          )
        else
          _buildCardBody(),
        const SizedBox(height: PortalTheme.space2),
        Text(
          _cardHint,
          style: PortalTheme.caption.copyWith(
            color: PortalTheme.textMuted,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  String get _cardHint {
    final result = _cardResult;
    if (_cardLoading) return 'Loading your card…';
    if (result == null || result.status == AlumniCardStatus.unmatched) {
      return 'Available after the Alumni Office confirms your record';
    }
    if (result.status == AlumniCardStatus.deactivated) {
      return 'Contact the Alumni Office for help';
    }
    return 'Tap card to switch sides';
  }

  Widget _buildCardBody() {
    final result = _cardResult;
    if (result == null || result.status == AlumniCardStatus.unmatched) {
      return _CardUnavailable(
        icon: Icons.badge_outlined,
        title: 'Card not ready yet',
        message:
            'Your digital alumni card will appear here once the Alumni '
            'Office confirms your record.',
      );
    }
    if (result.status == AlumniCardStatus.deactivated) {
      return const _CardUnavailable(
        icon: Icons.block_rounded,
        title: 'Card unavailable',
        message:
            'This alumni account is deactivated. Contact the Alumni Office '
            'if you need help.',
      );
    }

    final data = result.data!;
    return Column(
      children: [
        if (result.offline) ...[
          Text(
            'Saved copy · QR needs internet',
            style: PortalTheme.caption.copyWith(
              color: PortalTheme.warning,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
        ],
        AlumniDigitalCard(
          data: data,
          showBack: _showingCardBack,
          offline: result.offline,
          // IndexedStack keeps Profile alive off-tab; don't mint codes then.
          tokensEnabled:
              MainNavigationState.active?.isProfileTabActive ?? true,
          onFlip: (back) => setState(() => _showingCardBack = back),
        ),
      ],
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
            borderRadius: BorderRadius.circular(PortalTheme.radius2xl),
            border: Border.all(color: PortalTheme.borderStrong),
            boxShadow: PortalTheme.softShadow,
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              _PortalAccountRow(
                icon: Icons.badge_outlined,
                iconColor: PortalTheme.navy,
                title: 'Profile information',
                subtitle: 'View and update your details',
                onTap: _openProfileInformation,
              ),
              const _PortalAccountDivider(),
              _PortalAccountRow(
                icon: Icons.poll_outlined,
                iconColor: PortalTheme.navy,
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
                iconColor: PortalTheme.navy,
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
                iconColor: PortalTheme.navy,
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
                icon: Icons.lock_outline_rounded,
                iconColor: PortalTheme.navy,
                title: 'Change password',
                subtitle: 'Update your sign-in password',
                onTap: () => showChangePasswordDialog(context),
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
                  // Cold-start sessions keep AuthGate as ancestor; let it
                  // swap to LoginScreen. Avoid stacking a second AuthGate
                  // (that race shows a red error screen after push opens).
                  if (context.findAncestorWidgetOfExactType<AuthGate>() !=
                      null) {
                    return;
                  }
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

class _CardUnavailable extends StatelessWidget {
  const _CardUnavailable({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: kAlumniCardMaxWidth),
        child: AspectRatio(
          aspectRatio: kAlumniCardAspectRatio,
          child: Container(
            decoration: BoxDecoration(
              color: PortalTheme.surfaceMuted,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: PortalTheme.border),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 36,
                  color: PortalTheme.navy.withValues(alpha: 0.55),
                ),
                const SizedBox(height: 10),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: PortalTheme.cardTitle.copyWith(fontSize: 15),
                ),
                const SizedBox(height: 6),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: PortalTheme.caption.copyWith(height: 1.35),
                ),
              ],
            ),
          ),
        ),
      ),
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
                  color: iconColor.withValues(alpha: 0.08),
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
