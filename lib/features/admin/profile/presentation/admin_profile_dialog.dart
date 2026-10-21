import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:alumni_system/features/admin/profile/data/admin_profile_service.dart';
import 'package:alumni_system/features/admin/profile/presentation/admin_profile_avatar.dart';
import 'package:alumni_system/features/auth/presentation/auth_shell.dart';
import 'package:alumni_system/shared/widgets/admin/admin_theme.dart';
import 'package:alumni_system/shared/widgets/user/portal_menu.dart';
import 'package:alumni_system/shared/widgets/user/portal_theme.dart';

/// Picks raw image bytes; null when the admin cancels.
typedef AdminPhotoPicker = Future<Uint8List?> Function();

Future<Uint8List?> _pickFromGallery() async {
  final file = await ImagePicker().pickImage(
    source: ImageSource.gallery,
    imageQuality: 95,
    maxWidth: 2048,
  );
  return file?.readAsBytes();
}

/// Edit the admin's display name and profile photo. Pops `true` once saved.
class AdminProfileDialog extends StatefulWidget {
  const AdminProfileDialog({
    super.key,
    required this.controller,
    this.pickPhoto = _pickFromGallery,
  });

  final AdminProfileController controller;
  final AdminPhotoPicker pickPhoto;

  @override
  State<AdminProfileDialog> createState() => _AdminProfileDialogState();
}

class _AdminProfileDialogState extends State<AdminProfileDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final AdminProfile _initial;

  Uint8List? _newPhoto;
  bool _removePhoto = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initial = widget.controller.value;
    _name = TextEditingController(text: _initial.name)
      ..addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  bool get _hasPhoto =>
      _newPhoto != null || (_initial.hasAvatar && !_removePhoto);

  bool get _dirty =>
      _newPhoto != null ||
      _removePhoto ||
      AdminProfile.normalizeName(_name.text) != _initial.name;

  Future<void> _choosePhoto() async {
    try {
      final bytes = await widget.pickPhoto();
      if (bytes == null || bytes.isEmpty || !mounted) return;
      setState(() {
        _newPhoto = bytes;
        _removePhoto = false;
        _error = null;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _error = "Couldn't open that image. Try another one.");
      }
    }
  }

  void _clearPhoto() {
    setState(() {
      _newPhoto = null;
      _removePhoto = _initial.hasAvatar;
      _error = null;
    });
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.controller.save(
        name: _name.text,
        photo: _newPhoto,
        removePhoto: _removePhoto,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = "Couldn't save your profile. Check your connection and try "
            'again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      shape: PortalMenu.dialogShape,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(PortalTheme.space5),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(
                  header: true,
                  child: const Text('Edit profile', style: PortalTheme.pageTitle),
                ),
                const SizedBox(height: 4),
                Text(
                  'Alumni see this name and photo in messages and event '
                  'replies.',
                  style: PortalTheme.bodySecondary.copyWith(height: 1.4),
                ),
                const SizedBox(height: PortalTheme.space4),
                _buildPhotoRow(),
                const SizedBox(height: PortalTheme.space4),
                TextFormField(
                  controller: _name,
                  enabled: !_saving,
                  maxLength: AdminProfile.maxNameLength,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.done,
                  validator: AdminProfile.validateName,
                  onFieldSubmitted: (_) => _save(),
                  decoration: authFieldDecoration(
                    label: 'Display name',
                    icon: Icons.person_outline,
                  ),
                ),
                const SizedBox(height: PortalTheme.space2),
                _buildReadOnlyRow(),
                if (_error != null) ...[
                  const SizedBox(height: PortalTheme.space3),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      _error!,
                      style: PortalTheme.bodySecondary.copyWith(
                        color: PortalTheme.danger,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: PortalTheme.space5),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _saving
                          ? null
                          : () => Navigator.of(context).pop(false),
                      style: PortalTheme.ghostButton(dense: true),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: PortalTheme.space1),
                    FilledButton(
                      onPressed: _saving || !_dirty ? null : _save,
                      style: PortalTheme.primaryButton(dense: true),
                      child: _saving
                          ? const SizedBox.square(
                              dimension: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Save changes'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoRow() {
    return Row(
      children: [
        Semantics(
          image: true,
          label: _hasPhoto ? 'Profile photo' : 'No profile photo',
          child: AdminProfileAvatar(
            profile: _initial.copyWithName(_name.text),
            size: 72,
            photoBytes: _newPhoto,
            showStoredPhoto: !_removePhoto,
          ),
        ),
        const SizedBox(width: PortalTheme.space3),
        Expanded(
          child: Wrap(
            spacing: PortalTheme.space1,
            runSpacing: PortalTheme.space1,
            children: [
              OutlinedButton.icon(
                onPressed: _saving ? null : _choosePhoto,
                style: PortalTheme.secondaryButton(dense: true),
                icon: const Icon(Icons.photo_camera_outlined, size: 18),
                label: Text(_hasPhoto ? 'Change photo' : 'Upload photo'),
              ),
              if (_hasPhoto)
                TextButton(
                  onPressed: _saving ? null : _clearPhoto,
                  style: PortalTheme.ghostButton(dense: true).copyWith(
                    foregroundColor: const WidgetStatePropertyAll(
                      PortalTheme.danger,
                    ),
                  ),
                  child: const Text('Remove photo'),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReadOnlyRow() {
    return Row(
      children: [
        const Icon(
          Icons.mail_outline,
          size: 18,
          color: AdminColors.textSecondary,
        ),
        const SizedBox(width: PortalTheme.space1),
        Expanded(
          child: Text(
            _initial.email,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: PortalTheme.bodySecondary,
          ),
        ),
        const SizedBox(width: PortalTheme.space1),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AdminColors.accent.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(999),
          ),
          child: const Text(
            'Administrator',
            style: TextStyle(
              color: AdminColors.primary,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }
}
