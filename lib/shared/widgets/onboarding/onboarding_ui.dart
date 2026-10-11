import 'package:flutter/material.dart';
import 'package:alumni_system/shared/widgets/user/portal_menu.dart';
import 'package:alumni_system/shared/widgets/user/portal_theme.dart';

/// Onboarding visual system — aliases [PortalTheme] brand tokens for consistency.
abstract final class OnboardingTheme {
  static const navy = PortalTheme.navy;
  static const navyLight = PortalTheme.navyMid;
  static const gold = PortalTheme.gold;
  static const surface = Colors.white;
  static const card = PortalTheme.card;
  static const success = PortalTheme.success;
  static const muted = PortalTheme.textSecondary;
  static const border = PortalTheme.border;
}

abstract final class OnboardingSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double fieldGap = 14;
  static const double sectionGap = 16;
  static const double screenH = 20;
  static const double inputRadius = 12;
  static const double cardRadius = 16;
  static const double buttonHeight = 52;
}

class OnboardingDateTile extends StatelessWidget {
  const OnboardingDateTile({
    super.key,
    required this.label,
    required this.valueText,
    required this.onTap,
    this.enabled = true,
    this.hasValue = false,
    this.errorText,
  });

  final String label;
  final String valueText;
  final VoidCallback onTap;
  final bool enabled;
  final bool hasValue;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: OnboardingSpacing.fieldGap),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(OnboardingSpacing.inputRadius),
        child: InputDecorator(
          decoration: onboardingFieldDecoration(
            label: label,
            icon: Icons.calendar_today_outlined,
          ).copyWith(errorText: errorText),
          child: Text(
            valueText,
            style: TextStyle(
              fontSize: 15,
              fontWeight: hasValue ? FontWeight.w600 : FontWeight.w400,
              color: hasValue ? OnboardingTheme.navy : OnboardingTheme.muted,
            ),
          ),
        ),
      ),
    );
  }
}

class OnboardingSectionGroup extends StatelessWidget {
  const OnboardingSectionGroup({
    super.key,
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: OnboardingSpacing.sectionGap),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      decoration: BoxDecoration(
        color: OnboardingTheme.card,
        borderRadius: BorderRadius.circular(OnboardingSpacing.cardRadius),
        border: Border.all(color: OnboardingTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: OnboardingTheme.navy),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: OnboardingTheme.navy,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

/// Searchable province picker sheet.
Future<String?> showProvincePicker({
  required BuildContext context,
  required List<String> provinces,
  String? selected,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) {
      return _ProvincePickerSheet(provinces: provinces, selected: selected);
    },
  );
}

class _ProvincePickerSheet extends StatefulWidget {
  const _ProvincePickerSheet({required this.provinces, this.selected});

  final List<String> provinces;
  final String? selected;

  @override
  State<_ProvincePickerSheet> createState() => _ProvincePickerSheetState();
}

class _ProvincePickerSheetState extends State<_ProvincePickerSheet> {
  late final TextEditingController _query;
  late List<String> _filtered;

  @override
  void initState() {
    super.initState();
    _query = TextEditingController();
    _filtered = List.of(widget.provinces);
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  void _filter(String q) {
    final needle = q.trim().toLowerCase();
    setState(() {
      _filtered = needle.isEmpty
          ? List.of(widget.provinces)
          : widget.provinces
                .where((p) => p.toLowerCase().contains(needle))
                .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.72,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: PortalTheme.borderStrong,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 12, 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Select province',
                      style: PortalTheme.pageTitle,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, size: 20),
                    color: PortalTheme.textSecondary,
                    style: IconButton.styleFrom(
                      backgroundColor: PortalTheme.surfaceMuted,
                      fixedSize: const Size(36, 36),
                      minimumSize: const Size(36, 36),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: _query,
                autofocus: true,
                onChanged: _filter,
                decoration: onboardingFieldDecoration(
                  label: 'Search province',
                  icon: Icons.search,
                  hint: 'Type to filter…',
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _filtered.isEmpty
                  ? const Center(
                      child: Text(
                        'No provinces found',
                        style: PortalTheme.bodySecondary,
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 8),
                      itemCount: _filtered.length,
                      itemBuilder: (context, index) {
                        final province = _filtered[index];
                        return PortalSheetOption(
                          label: province,
                          selected: province == widget.selected,
                          onTap: () => Navigator.pop(context, province),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

InputDecoration onboardingFieldDecoration({
  required String label,
  String? hint,
  IconData? icon,
  bool readOnly = false,
  String? helperText,
}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    helperText: helperText,
    helperStyle: PortalTheme.meta,
    prefixIcon: icon != null
        ? Icon(icon, color: PortalTheme.navy, size: 20)
        : null,
    filled: true,
    fillColor: readOnly ? PortalTheme.surfaceMuted : PortalTheme.card,
    labelStyle: const TextStyle(color: PortalTheme.textSecondary, fontSize: 14),
    hintStyle: const TextStyle(
      color: PortalTheme.textMuted,
      fontWeight: FontWeight.w400,
    ),
    errorStyle: PortalTheme.meta.copyWith(color: PortalTheme.danger),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(PortalTheme.radiusMd),
      borderSide: const BorderSide(color: PortalTheme.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(PortalTheme.radiusMd),
      borderSide: const BorderSide(color: PortalTheme.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(PortalTheme.radiusMd),
      borderSide: const BorderSide(color: PortalTheme.navy, width: 1.8),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(PortalTheme.radiusMd),
      borderSide: BorderSide(color: PortalTheme.danger.withValues(alpha: 0.6)),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(PortalTheme.radiusMd),
      borderSide: const BorderSide(color: PortalTheme.danger, width: 1.8),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
  );
}
