import 'package:flutter/material.dart';

import 'package:alumni_system/core/utils/safe_external_link.dart';
import 'package:alumni_system/features/forum/widgets/forum_rich_text_controller.dart';
import 'package:alumni_system/shared/widgets/user/portal_theme.dart';

/// Bold / italic / list / quote / link buttons for a field driven by a
/// [ForumRichTextController]. Bold and italic light up when active.
class ForumFormatToolbar extends StatelessWidget {
  const ForumFormatToolbar({
    super.key,
    required this.controller,
    this.focusNode,
    this.enabled = true,
  });

  final ForumRichTextController controller;
  final FocusNode? focusNode;
  final bool enabled;

  static final _bullet = RegExp(r'^\s*[-*•]\s+');
  static final _numbered = RegExp(r'^\s*\d{1,3}[.)]\s+');
  static final _quote = RegExp(r'^\s*>\s?');

  @override
  Widget build(BuildContext context) {
    return TextFieldTapRegion(
      child: ExcludeFocus(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(
            color: PortalTheme.surfaceMuted,
            borderRadius: BorderRadius.circular(PortalTheme.radiusMd),
            border: Border.all(color: PortalTheme.border),
          ),
          child: ListenableBuilder(
            listenable: controller,
            builder: (context, _) => Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _button(
                  icon: Icons.format_bold_rounded,
                  tooltip: 'Bold',
                  active: controller.isActive(ForumInline.bold),
                  onTap: () => _toggle(ForumInline.bold),
                ),
                _button(
                  icon: Icons.format_italic_rounded,
                  tooltip: 'Italic',
                  active: controller.isActive(ForumInline.italic),
                  onTap: () => _toggle(ForumInline.italic),
                ),
                _divider(),
                _button(
                  icon: Icons.format_list_bulleted_rounded,
                  tooltip: 'Bulleted list',
                  onTap: () => _prefixLines((_) => '- ', _bullet),
                ),
                _button(
                  icon: Icons.format_list_numbered_rounded,
                  tooltip: 'Numbered list',
                  onTap: () => _prefixLines((i) => '${i + 1}. ', _numbered),
                ),
                _button(
                  icon: Icons.format_quote_rounded,
                  tooltip: 'Quote',
                  onTap: () => _prefixLines((_) => '> ', _quote),
                ),
                _divider(),
                _button(
                  icon: Icons.link_rounded,
                  tooltip: 'Link',
                  onTap: () => _insertLink(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _button({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    bool active = false,
  }) {
    return IconButton(
      tooltip: tooltip,
      onPressed: enabled ? onTap : null,
      isSelected: active,
      icon: Icon(icon, size: 20),
      style: IconButton.styleFrom(
        foregroundColor: PortalTheme.navy,
        backgroundColor: active
            ? PortalTheme.navy.withValues(alpha: 0.12)
            : null,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        visualDensity: VisualDensity.compact,
        minimumSize: const Size(36, 36),
        padding: EdgeInsets.zero,
      ),
    );
  }

  Widget _divider() => Container(
    width: 1,
    height: 20,
    margin: const EdgeInsets.symmetric(horizontal: 4),
    color: PortalTheme.border,
  );

  TextSelection get _selection {
    final s = controller.selection;
    if (s.isValid) return s;
    return TextSelection.collapsed(offset: controller.text.length);
  }

  void _toggle(int style) {
    controller.toggle(style);
    focusNode?.requestFocus();
  }

  /// Adds the line prefix from [prefixFor] to every line in the selection, or
  /// removes it when all of those lines already have one.
  void _prefixLines(String Function(int index) prefixFor, RegExp existing) {
    final text = controller.text;
    final sel = _selection;
    final blockStart = sel.start == 0
        ? 0
        : text.lastIndexOf('\n', sel.start - 1) + 1;
    var blockEnd = text.indexOf('\n', sel.end);
    if (blockEnd == -1) blockEnd = text.length;

    final lineStarts = [blockStart];
    for (var i = blockStart; i < blockEnd; i++) {
      if (text[i] == '\n') lineStarts.add(i + 1);
    }
    String lineAt(int k) {
      final end = k + 1 < lineStarts.length ? lineStarts[k + 1] - 1 : blockEnd;
      return text.substring(lineStarts[k], end);
    }

    final lines = [for (var k = 0; k < lineStarts.length; k++) lineAt(k)];
    final nonEmpty = lines.where((l) => l.trim().isNotEmpty);
    final removing =
        nonEmpty.isNotEmpty && nonEmpty.every((l) => existing.hasMatch(l));

    final edits = <(int, int, String)>[];
    var index = 0;
    for (var k = 0; k < lines.length; k++) {
      final line = lines[k];
      final start = lineStarts[k];
      if (removing) {
        final m = existing.firstMatch(line);
        if (m != null) edits.add((start, start + m.end, ''));
      } else if (line.trim().isNotEmpty || lines.length == 1) {
        final old = ForumRichTextController.anyLinePrefix.firstMatch(line);
        edits.add((start, start + (old?.end ?? 0), prefixFor(index++)));
      }
    }

    var delta = 0;
    // Bottom-up so earlier offsets stay valid; one edit per line keeps the
    // styles of the text in between.
    for (final (start, end, replacement) in edits.reversed) {
      controller.replaceRange(start, end, replacement);
      delta += replacement.length - (end - start);
    }

    final newEnd = blockEnd + delta;
    controller.selection = sel.isCollapsed
        ? TextSelection.collapsed(offset: newEnd)
        : TextSelection(baseOffset: blockStart, extentOffset: newEnd);
    focusNode?.requestFocus();
  }

  Future<void> _insertLink(BuildContext context) async {
    final sel = _selection;
    final selected = sel.isCollapsed
        ? ''
        : controller.text.substring(sel.start, sel.end);
    final selectedIsUrl = isSafeExternalHttpUrl(selected.trim());

    final result = await showDialog<(String, String)>(
      context: context,
      builder: (_) => _LinkDialog(
        initialLabel: selectedIsUrl ? '' : selected,
        initialUrl: selectedIsUrl ? selected.trim() : '',
      ),
    );
    if (result == null) return;

    final (label, url) = result;
    final length = controller.text.length;
    final start = sel.start.clamp(0, length);
    final end = sel.end.clamp(start, length);
    controller.insertLink(
      start: start,
      end: end,
      label: label.isEmpty ? url : label,
      url: url,
    );
    focusNode?.requestFocus();
  }
}

class _LinkDialog extends StatefulWidget {
  const _LinkDialog({required this.initialLabel, required this.initialUrl});

  final String initialLabel;
  final String initialUrl;

  @override
  State<_LinkDialog> createState() => _LinkDialogState();
}

class _LinkDialogState extends State<_LinkDialog> {
  late final _label = TextEditingController(text: widget.initialLabel);
  late final _url = TextEditingController(text: widget.initialUrl);
  String? _error;

  @override
  void dispose() {
    _label.dispose();
    _url.dispose();
    super.dispose();
  }

  void _submit() {
    var url = _url.text.trim();
    if (url.isNotEmpty &&
        !RegExp(r'^https?://', caseSensitive: false).hasMatch(url)) {
      url = 'https://$url';
    }
    if (!isSafeExternalHttpUrl(url) || !url.contains('.')) {
      setState(() => _error = 'Enter a valid web address, e.g. ustp.edu.ph');
      return;
    }
    Navigator.pop(context, (_label.text.trim(), url));
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Add a link',
                style: PortalTheme.pageTitle.copyWith(fontSize: 19),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _label,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Text to show (optional)',
                  hintText: 'e.g. Registration form',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _url,
                autofocus: widget.initialUrl.isEmpty,
                keyboardType: TextInputType.url,
                onSubmitted: (_) => _submit(),
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
                decoration: InputDecoration(
                  labelText: 'Web address',
                  hintText: 'https://',
                  errorText: _error,
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _submit,
                style: PortalTheme.primaryButton(dense: true),
                child: const Text('Add link'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(context),
                style: PortalTheme.ghostButton(dense: true),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
