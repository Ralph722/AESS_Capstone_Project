/// Debounced desktop search field for the Admin Portal.
///
/// Matches the Alumni Directory pattern: 300ms debounce, clear button with
/// tooltip, and an immediate empty callback when cleared.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:alumni_system/shared/widgets/admin/admin_density.dart';

typedef AdminSearchCallback = void Function(String query);

/// Standard admin search field with debounce and clear affordance.
class AdminSearchField extends StatefulWidget {
  const AdminSearchField({
    super.key,
    required this.onDebouncedChanged,
    this.controller,
    this.focusNode,
    this.hintText = 'Search…',
    this.debounce = const Duration(milliseconds: 300),
    this.decoration,
    this.enabled = true,
    this.onSubmitted,
  });

  /// Called after [debounce] when the query changes, and immediately on clear.
  final AdminSearchCallback onDebouncedChanged;

  /// Optional external controller. When null, an internal one is created.
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String hintText;
  final Duration debounce;
  final InputDecoration? decoration;
  final bool enabled;
  final ValueChanged<String>? onSubmitted;

  @override
  State<AdminSearchField> createState() => _AdminSearchFieldState();
}

class _AdminSearchFieldState extends State<AdminSearchField> {
  TextEditingController? _internalController;
  Timer? _timer;
  String _lastEmitted = '';

  TextEditingController get _controller =>
      widget.controller ?? _internalController!;

  @override
  void initState() {
    super.initState();
    if (widget.controller == null) {
      _internalController = TextEditingController();
    }
    _lastEmitted = _controller.text;
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.removeListener(_onTextChanged);
    _internalController?.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final text = _controller.text;
    _timer?.cancel();
    if (text.isEmpty) {
      _emit('');
      if (mounted) setState(() {});
      return;
    }
    _timer = Timer(widget.debounce, () => _emit(text));
    if (mounted) setState(() {});
  }

  void _emit(String value) {
    if (value == _lastEmitted) return;
    _lastEmitted = value;
    widget.onDebouncedChanged(value);
  }

  void _clear() {
    _timer?.cancel();
    _controller.clear();
    _emit('');
    widget.focusNode?.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final hasText = _controller.text.isNotEmpty;
    final base = widget.decoration ??
        InputDecoration(
          hintText: widget.hintText,
          prefixIcon: const Icon(Icons.search, size: 20),
          isDense: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          filled: true,
          fillColor: Colors.white,
        );

    return TextField(
      controller: _controller,
      focusNode: widget.focusNode,
      enabled: widget.enabled,
      onSubmitted: widget.onSubmitted,
      decoration: base.copyWith(
        hintText: base.hintText ?? widget.hintText,
        prefixIcon: base.prefixIcon ?? const Icon(Icons.search, size: 20),
        suffixIcon: hasText
            ? IconButton(
                tooltip: 'Clear search',
                onPressed: _clear,
                icon: const Icon(Icons.clear, size: 18),
                style: AdminDensity.iconButtonStyle(),
              )
            : base.suffixIcon,
      ),
    );
  }
}

/// Lightweight hover shell for desktop cards that are not [AdminDataRow].
class AdminHoverShell extends StatefulWidget {
  const AdminHoverShell({
    super.key,
    required this.builder,
    this.cursor = SystemMouseCursors.basic,
  });

  final Widget Function(BuildContext context, bool hovered) builder;
  final MouseCursor cursor;

  @override
  State<AdminHoverShell> createState() => _AdminHoverShellState();
}

class _AdminHoverShellState extends State<AdminHoverShell> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: widget.cursor,
      child: widget.builder(context, _hovered),
    );
  }
}
