import 'dart:async';

import 'package:flutter/material.dart';
import 'package:alumni_system/core/utils/app_image.dart';
import 'package:alumni_system/features/messages/data/message_service.dart';
import 'package:alumni_system/features/messages/widgets/admin_message_ui.dart';
import 'package:alumni_system/shared/widgets/admin/admin_badge.dart';
import 'package:alumni_system/shared/widgets/admin/admin_buttons.dart';
import 'package:alumni_system/shared/widgets/admin/admin_dialogs.dart';
import 'package:alumni_system/shared/widgets/admin/admin_state_view.dart';
import 'package:alumni_system/shared/widgets/admin/admin_surface.dart';
import 'package:alumni_system/shared/widgets/admin/admin_theme.dart';

/// Picker for admin-started support threads with registered alumni.
Future<RegisteredAlumniContact?> showAdminComposeAlumniPicker({
  required BuildContext context,
  required MessageService messageService,
}) {
  return showAdminDialogSurface<RegisteredAlumniContact>(
    context: context,
    maxWidth: 460,
    child: _AdminComposeAlumniDialog(messageService: messageService),
  );
}

class _AdminComposeAlumniDialog extends StatefulWidget {
  const _AdminComposeAlumniDialog({required this.messageService});

  final MessageService messageService;

  @override
  State<_AdminComposeAlumniDialog> createState() =>
      _AdminComposeAlumniDialogState();
}

class _AdminComposeAlumniDialogState extends State<_AdminComposeAlumniDialog> {
  final TextEditingController _search = TextEditingController();
  Timer? _debounce;
  List<RegisteredAlumniContact> _results = const [];
  bool _loading = true;
  String? _error;

  static const double _listMaxHeight = 320;

  @override
  void initState() {
    super.initState();
    unawaited(_load(''));
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load(String query) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await widget.messageService.searchRegisteredAlumniForCompose(
        query: query,
      );
      if (!mounted) return;
      setState(() {
        _results = rows;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load registered alumni.';
        _results = const [];
      });
    }
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 280), () {
      unawaited(_load(value));
    });
  }

  @override
  Widget build(BuildContext context) {
    final queryActive = _search.text.trim().isNotEmpty;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
          child: AdminModalHeader(
            title: 'New message',
            subtitle:
                'Choose a registered alumnus to open their support thread.',
            icon: Icons.mail_outline_rounded,
            onClose: () => Navigator.pop(context),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: SizedBox(
            height: AdminMessageTheme.toolbarControlHeight,
            child: TextField(
              controller: _search,
              autofocus: true,
              onChanged: _onSearchChanged,
              style: const TextStyle(
                fontSize: 13.5,
                color: AdminColors.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: 'Search name, email, or program…',
                hintStyle: const TextStyle(
                  color: AdminColors.textSecondary,
                  fontSize: 13.5,
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  size: 18,
                  color: AdminColors.textSecondary,
                ),
                prefixIconConstraints: const BoxConstraints(
                  minWidth: 40,
                  minHeight: AdminMessageTheme.toolbarControlHeight,
                ),
                suffixIcon: queryActive
                    ? IconButton(
                        tooltip: 'Clear',
                        visualDensity: VisualDensity.compact,
                        onPressed: () {
                          _search.clear();
                          _onSearchChanged('');
                        },
                        icon: const Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: AdminColors.textSecondary,
                        ),
                      )
                    : null,
                isDense: true,
                filled: true,
                fillColor: AdminColors.surface,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                border: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(AdminMessageTheme.radiusSm),
                  borderSide: const BorderSide(color: AdminColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(AdminMessageTheme.radiusSm),
                  borderSide: const BorderSide(color: AdminColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(AdminMessageTheme.radiusSm),
                  borderSide: const BorderSide(
                    color: AdminColors.primary,
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),
        ),
        const Divider(height: 1, color: AdminColors.border),
        ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: 120,
            maxHeight: _listMaxHeight,
          ),
          child: _buildResultsBody(),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
          decoration: const BoxDecoration(
            color: AdminColors.surface,
            border: Border(top: BorderSide(color: AdminColors.border)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _footerLabel(queryActive),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AdminColors.textSecondary,
                  ),
                ),
              ),
              OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: AdminButtonStyles.outlined(),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _footerLabel(bool queryActive) {
    if (_loading) return 'Searching…';
    if (_error != null) return 'Something went wrong';
    if (_results.isEmpty) {
      return queryActive ? 'No matches' : 'No registered alumni yet';
    }
    final n = _results.length;
    return n == 1 ? '1 alumnus' : '$n alumni';
  }

  Widget _buildResultsBody() {
    if (_loading) {
      return const AdminStateView.loading(
        compact: true,
        label: 'Loading alumni…',
      );
    }

    if (_error != null) {
      return AdminStateView.error(
        compact: true,
        title: "Couldn't load alumni",
        message: _error!,
        onRetry: () => _load(_search.text),
      );
    }

    if (_results.isEmpty) {
      final hasQuery = _search.text.trim().isNotEmpty;
      return AdminStateView.empty(
        compact: true,
        icon: Icons.person_search_outlined,
        title: hasQuery ? 'No matching alumni' : 'No registered alumni yet',
        message: hasQuery
            ? 'No alumni match “${_search.text.trim()}”.'
            : 'Registered alumni available for messaging will appear here.',
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(vertical: 6),
      itemCount: _results.length,
      separatorBuilder: (_, __) => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: Divider(height: 1, color: AdminColors.border),
      ),
      itemBuilder: (context, index) {
        final contact = _results[index];
        return _ComposeAlumniTile(
          contact: contact,
          onTap: () => Navigator.pop(context, contact),
        );
      },
    );
  }
}

class _ComposeAlumniTile extends StatefulWidget {
  const _ComposeAlumniTile({required this.contact, required this.onTap});

  final RegisteredAlumniContact contact;
  final VoidCallback onTap;

  @override
  State<_ComposeAlumniTile> createState() => _ComposeAlumniTileState();
}

class _ComposeAlumniTileState extends State<_ComposeAlumniTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final contact = widget.contact;
    final meta = [
      if (contact.program.isNotEmpty) contact.program,
      if (contact.batch.isNotEmpty) contact.batch,
    ].join(' · ');
    final provider = AppImage.provider(contact.avatarUrl);
    final letter =
        contact.name.isNotEmpty ? contact.name[0].toUpperCase() : 'A';

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Material(
        color: _hovered ? AdminColors.rowHover : Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AdminColors.primaryTint,
                  backgroundImage: provider,
                  child: provider == null
                      ? Text(
                          letter,
                          style: const TextStyle(
                            color: AdminColors.primary,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        contact.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13.5,
                          color: AdminColors.textPrimary,
                        ),
                      ),
                      if (contact.email.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          contact.email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AdminColors.textSecondary,
                          ),
                        ),
                      ],
                      if (meta.isNotEmpty) ...[
                        const SizedBox(height: 5),
                        AdminBadge.info(label: meta, dense: true),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: _hovered
                      ? AdminColors.primary
                      : AdminColors.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
