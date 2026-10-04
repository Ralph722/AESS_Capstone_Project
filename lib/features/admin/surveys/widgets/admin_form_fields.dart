import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:alumni_system/features/admin/roster/widgets/alumni_directory_ui.dart';

/// Dense date field for admin editors (matches filter chrome).
Widget adminDatePicker(
  BuildContext context,
  String label,
  DateTime? selectedDate,
  ValueChanged<DateTime?> onDateSelected, {
  DateTime? firstDate,
  DateTime? lastDate,
}) {
  return DirectoryDateFilterChip(
    label: label,
    expand: true,
    width: null,
    displayText: selectedDate == null
        ? 'Select date'
        : DirectoryDateTimePickers.formatDate(selectedDate),
    active: selectedDate != null,
    onTap: () async {
      final picked = await DirectoryDateTimePickers.pickDate(
        context,
        initialDate: selectedDate ?? DateTime.now(),
        firstDate: firstDate ?? DateTime(2020),
        lastDate: lastDate ?? DateTime.now(),
        helpText: label,
      );
      if (picked != null) onDateSelected(picked);
    },
  );
}

/// Shared admin form field — text, date, or time — using Directory density.
Widget adminFormField(
  BuildContext context,
  String label,
  TextEditingController controller,
  String hint, {
  bool isDate = false,
  bool isTime = false,
  bool isMultiline = false,
  IconData? icon,
}) {
  if (isDate) {
    return _AdminControllerDateField(
      label: label,
      controller: controller,
      hint: hint,
    );
  }
  if (isTime) {
    return _AdminControllerTimeField(
      label: label,
      controller: controller,
      hint: hint,
    );
  }

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AdminDirectoryTheme.textSecondary,
        ),
      ),
      const SizedBox(height: 6),
      TextField(
        controller: controller,
        maxLines: isMultiline ? 4 : 1,
        style: const TextStyle(
          fontSize: 13,
          color: AdminDirectoryTheme.textPrimary,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(
            fontSize: 13,
            color: AdminDirectoryTheme.textMuted,
          ),
          prefixIcon: icon != null && !isMultiline
              ? Icon(icon, size: 18, color: AdminDirectoryTheme.textSecondary)
              : null,
          isDense: true,
          filled: true,
          fillColor: AdminDirectoryTheme.background,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AdminDirectoryTheme.radiusSm),
            borderSide: const BorderSide(color: AdminDirectoryTheme.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AdminDirectoryTheme.radiusSm),
            borderSide: const BorderSide(color: AdminDirectoryTheme.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AdminDirectoryTheme.radiusSm),
            borderSide: const BorderSide(color: AdminDirectoryTheme.primary),
          ),
        ),
      ),
    ],
  );
}

class _AdminControllerDateField extends StatefulWidget {
  const _AdminControllerDateField({
    required this.label,
    required this.controller,
    required this.hint,
  });

  final String label;
  final TextEditingController controller;
  final String hint;

  @override
  State<_AdminControllerDateField> createState() =>
      _AdminControllerDateFieldState();
}

class _AdminControllerDateFieldState extends State<_AdminControllerDateField> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
  }

  @override
  void didUpdateWidget(covariant _AdminControllerDateField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onChanged);
      widget.controller.addListener(_onChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  DateTime? get _parsed {
    final raw = widget.controller.text.trim();
    if (raw.isEmpty) return null;
    try {
      return DateFormat('MM/dd/yyyy').parseStrict(raw);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final parsed = _parsed;
    return DirectoryDateFilterChip(
      label: widget.label,
      expand: true,
      width: null,
      displayText: parsed == null
          ? (widget.hint.isNotEmpty ? widget.hint : 'Select date')
          : DirectoryDateTimePickers.formatDate(parsed),
      active: parsed != null,
      onTap: () async {
        final picked = await DirectoryDateTimePickers.pickDate(
          context,
          initialDate: parsed ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime(2100),
          helpText: widget.label,
        );
        if (picked == null) return;
        widget.controller.text = DateFormat('MM/dd/yyyy').format(picked);
      },
    );
  }
}

class _AdminControllerTimeField extends StatefulWidget {
  const _AdminControllerTimeField({
    required this.label,
    required this.controller,
    required this.hint,
  });

  final String label;
  final TextEditingController controller;
  final String hint;

  @override
  State<_AdminControllerTimeField> createState() =>
      _AdminControllerTimeFieldState();
}

class _AdminControllerTimeFieldState extends State<_AdminControllerTimeField> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
  }

  @override
  void didUpdateWidget(covariant _AdminControllerTimeField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onChanged);
      widget.controller.addListener(_onChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  TimeOfDay? get _parsed {
    final raw = widget.controller.text.trim();
    if (raw.isEmpty) return null;
    try {
      return TimeOfDay.fromDateTime(DateFormat.jm().parse(raw));
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.controller.text.trim();
    return DirectoryTimeFilterChip(
      label: widget.label,
      expand: true,
      width: null,
      displayText: text.isEmpty
          ? (widget.hint.isNotEmpty ? widget.hint : 'Select time')
          : text,
      active: text.isNotEmpty,
      onTap: () async {
        final picked = await DirectoryDateTimePickers.pickTime(
          context,
          initialTime: _parsed ?? TimeOfDay.now(),
          helpText: widget.label,
        );
        if (picked == null || !context.mounted) return;
        widget.controller.text =
            DirectoryDateTimePickers.formatTime(context, picked);
      },
    );
  }
}
