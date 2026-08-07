import 'dart:async';

import 'package:flutter/material.dart';
import 'package:alumni_system/core/utils/app_image.dart';
import 'package:alumni_system/features/messages/data/message_service.dart';
import 'package:alumni_system/features/messages/widgets/admin_message_ui.dart';
import 'package:alumni_system/features/messages/widgets/message_theme.dart';

/// Picker for admin-started support threads with registered alumni.
Future<RegisteredAlumniContact?> showAdminComposeAlumniPicker({
  required BuildContext context,
  required MessageService messageService,
}) {
  return showDialog<RegisteredAlumniContact>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (ctx) => _AdminComposeAlumniDialog(messageService: messageService),
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

    return Dialog(
      backgroundColor: Colors.white,
      elevation: 8,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AdminMessageTheme.border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AdminMessageTheme.navy.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.mail_outline_rounded,
                      size: 20,
                      color: AdminMessageTheme.navy,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'New message',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: AdminMessageTheme.textPrimary,
                            height: 1.25,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Choose a registered alumnus to open their '
                          'support thread.',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: AdminMessageTheme.textSecondary,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.close_rounded,
                      size: 20,
                      color: AdminMessageTheme.textMuted,
                    ),
                  ),
                ],
              ),
            ),

            // Search
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: SizedBox(
                height: AdminMessageTheme.toolbarControlHeight,
                child: TextField(
                  controller: _search,
                  autofocus: true,
                  onChanged: _onSearchChanged,
                  style: const TextStyle(
                    fontSize: 13.5,
                    color: AdminMessageTheme.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search name, email, or program…',
                    hintStyle: const TextStyle(
                      color: AdminMessageTheme.textMuted,
                      fontSize: 13.5,
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      size: 18,
                      color: AdminMessageTheme.textMuted,
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
                              Icons.cancel_rounded,
                              size: 18,
                              color: AdminMessageTheme.textMuted,
                            ),
                          )
                        : null,
                    isDense: true,
                    filled: true,
                    fillColor: AdminMessageTheme.pageBg,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        AdminMessageTheme.radiusSm,
                      ),
                      borderSide:
                          const BorderSide(color: AdminMessageTheme.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        AdminMessageTheme.radiusSm,
                      ),
                      borderSide:
                          const BorderSide(color: AdminMessageTheme.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        AdminMessageTheme.radiusSm,
                      ),
                      borderSide: const BorderSide(
                        color: AdminMessageTheme.navy,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            const Divider(height: 1, color: AdminMessageTheme.border),

            // Results — height follows content, capped when long
            ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: 96,
                maxHeight: _listMaxHeight,
              ),
              child: _buildResultsBody(),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 12, 12),
              decoration: const BoxDecoration(
                color: AdminMessageTheme.pageBg,
                border: Border(
                  top: BorderSide(color: AdminMessageTheme.border),
                ),
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _footerLabel(queryActive),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AdminMessageTheme.textMuted,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      foregroundColor: AdminMessageTheme.textSecondary,
                      visualDensity: VisualDensity.compact,
                    ),
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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
      return const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2.2),
        ),
      );
    }

    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 28,
              color: AdminMessageTheme.textMuted.withValues(alpha: 0.9),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AdminMessageTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => _load(_search.text),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_results.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_search_outlined,
              size: 32,
              color: AdminMessageTheme.navy.withValues(alpha: 0.35),
            ),
            const SizedBox(height: 8),
            Text(
              _search.text.trim().isEmpty
                  ? 'No registered alumni available to message.'
                  : 'No alumni match “${_search.text.trim()}”.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AdminMessageTheme.textSecondary,
                height: 1.35,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(vertical: 6),
      itemCount: _results.length,
      separatorBuilder: (_, __) => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: Divider(height: 1, color: AdminMessageTheme.border),
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
        color: _hovered
            ? AdminMessageTheme.navy.withValues(alpha: 0.05)
            : Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor:
                      AdminMessageTheme.navy.withValues(alpha: 0.08),
                  backgroundImage: provider,
                  child: provider == null
                      ? Text(
                          letter,
                          style: const TextStyle(
                            color: AdminMessageTheme.navy,
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
                          color: MessageTheme.textPrimary,
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
                            color: MessageTheme.textSecondary,
                          ),
                        ),
                      ],
                      if (meta.isNotEmpty) ...[
                        const SizedBox(height: 5),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color:
                                AdminMessageTheme.navy.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            meta,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AdminMessageTheme.navy,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: _hovered
                      ? AdminMessageTheme.navy
                      : AdminMessageTheme.textMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
