import 'dart:async';

import 'package:flutter/material.dart';
import 'package:alumni_system/core/services/app_session.dart';
import 'package:alumni_system/core/services/audit_service.dart';
import 'package:alumni_system/features/alumni/profile/data/user_profile_events.dart';
import 'package:alumni_system/features/alumni/profile/data/user_profile_service.dart';
import 'package:alumni_system/features/alumni/tracer/models/tracer_profile_model.dart';
import 'package:alumni_system/shared/widgets/gts/gts_profile_form.dart';
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
  final _profileFormKey = GlobalKey<FormState>();
  final _formState = GtsProfileFormState();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _dirty = false;
  StreamSubscription<void>? _profileFieldsSub;

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
    final discard = await confirmDiscardChanges(context);
    if (discard && mounted) setState(() => _dirty = false);
    return discard;
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final userId = AppSession.userId;
      if (userId == null) return;
      final profile = await _userProfileService.getTracerProfile(userId);
      if (profile != null) {
        _formState.applyFromProfile(profile);
      }
      if (_formState.emailController.text.isEmpty) {
        _formState.emailController.text = AppSession.email ?? '';
      }
      if (mounted) setState(() => _dirty = false);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _save() async {
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
      if (!mounted) return;
      setState(() => _dirty = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated successfully!'),
          backgroundColor: PortalTheme.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving profile: ${portalFriendlyError(e)}'),
          backgroundColor: PortalTheme.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final completion = TracerProfile.computeCompletion(
      _formState.completionPayload(),
    );
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
        backgroundColor: PortalTheme.pageBg,
        appBar: PortalAppBar(
          title: 'Profile information',
          subtitle: _isLoading
              ? null
              : '${completion.toStringAsFixed(0)}% complete',
          automaticallyImplyLeading: true,
        ),
        body: PortalContentFrame(
          child: _isLoading
              ? const ProfileSkeleton()
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(hPad, 12, hPad, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(PortalTheme.space4),
                        decoration: BoxDecoration(
                          color: PortalTheme.card,
                          borderRadius: BorderRadius.circular(
                            PortalTheme.radius2xl,
                          ),
                          border: Border.all(
                            color: PortalTheme.border.withValues(alpha: 0.75),
                          ),
                          boxShadow: PortalTheme.softShadow,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const PortalSectionHeader(
                              title: 'Your details',
                              subtitle:
                                  'CHED GTS demographics, education, and employment. Updates your live alumni record.',
                            ),
                            if (_dirty) ...[
                              const SizedBox(height: PortalTheme.space2),
                              const PortalChip(
                                label: 'Unsaved changes',
                                tone: PortalChipTone.gold,
                                icon: Icons.edit_note,
                              ),
                            ],
                            const SizedBox(height: PortalTheme.space3),
                            Form(
                              key: _profileFormKey,
                              child: GtsProfileFormFields(
                                state: _formState,
                                emailReadOnly: true,
                                showEmploymentStatus: true,
                                chedStyleLabels: false,
                                enabled: !_isSaving,
                                onChanged: () {
                                  _markDirty();
                                  setState(() {});
                                },
                              ),
                            ),
                          ],
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
}
