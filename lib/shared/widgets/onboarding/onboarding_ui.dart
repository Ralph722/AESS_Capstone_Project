import 'package:flutter/material.dart';
import 'package:alumni_system/shared/widgets/user/portal_menu.dart';
import 'package:alumni_system/shared/widgets/user/portal_theme.dart';

/// Onboarding visual system — aliases [PortalTheme] brand tokens for consistency.
abstract final class OnboardingTheme {
  static const navy = PortalTheme.navy;
  static const navyLight = PortalTheme.navyMid;
  static const gold = PortalTheme.gold;
  static const surface = PortalTheme.pageBg;
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

/// Compact modern step indicator with connected progress line.
class OnboardingStepStrip extends StatelessWidget {
  const OnboardingStepStrip({
    super.key,
    required this.currentIndex,
    required this.labels,
  });

  final int currentIndex;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: OnboardingTheme.card,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      child: Column(
        children: [
          Row(
            children: List.generate(labels.length * 2 - 1, (i) {
              if (i.isOdd) {
                final after = i ~/ 2;
                final filled = after < currentIndex;
                return Expanded(
                  child: Container(
                    height: 2,
                    margin: const EdgeInsets.only(bottom: 18),
                    color: filled
                        ? OnboardingTheme.success
                        : OnboardingTheme.border,
                  ),
                );
              }
              final step = i ~/ 2;
              final done = step < currentIndex;
              final active = step == currentIndex;
              return Column(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: done
                          ? OnboardingTheme.success
                          : active
                              ? OnboardingTheme.navy
                              : OnboardingTheme.surface,
                      border: Border.all(
                        color: active || done
                            ? Colors.transparent
                            : OnboardingTheme.border,
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: done
                          ? const Icon(Icons.check, size: 14, color: Colors.white)
                          : Text(
                              '${step + 1}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: active
                                    ? Colors.white
                                    : OnboardingTheme.muted,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    labels[step],
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                      color: active || done
                          ? OnboardingTheme.navy
                          : OnboardingTheme.muted,
                    ),
                  ),
                ],
              );
            }),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (currentIndex + 1) / labels.length,
              minHeight: 3,
              backgroundColor: OnboardingTheme.border,
              color: OnboardingTheme.gold,
            ),
          ),
        ],
      ),
    );
  }
}

class OnboardingFormCard extends StatelessWidget {
  const OnboardingFormCard({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    required this.child,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: OnboardingTheme.card,
        borderRadius: BorderRadius.circular(OnboardingSpacing.cardRadius),
        border: Border.all(color: OnboardingTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: OnboardingTheme.navy.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: OnboardingTheme.navy, size: 20),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: OnboardingTheme.navy,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          color: OnboardingTheme.muted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

class OnboardingIntroBullet extends StatelessWidget {
  const OnboardingIntroBullet({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.stepNumber,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final int? stepNumber;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: OnboardingTheme.navy.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(10),
            ),
            child: stepNumber != null
                ? Center(
                    child: Text(
                      '$stepNumber',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: OnboardingTheme.navy,
                      ),
                    ),
                  )
                : Icon(icon, color: OnboardingTheme.navy, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: OnboardingTheme.navy,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.35,
                    color: OnboardingTheme.muted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Binary Employed / Unemployed selector for the alumni employment tracer.
class OnboardingEmploymentToggle extends StatelessWidget {
  const OnboardingEmploymentToggle({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final String value;
  final ValueChanged<String> onChanged;
  final bool enabled;

  static const _options = ['Employed', 'Unemployed'];

  IconData _iconFor(String status) {
    return status == 'Employed'
        ? Icons.work_outline
        : Icons.person_search_outlined;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 360;
        final children = _options.map((status) {
          final selected = value == status;
          final card = Material(
            color: selected
                ? OnboardingTheme.navy.withValues(alpha: 0.08)
                : Colors.white,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              onTap: enabled ? () => onChanged(status) : null,
              borderRadius: BorderRadius.circular(14),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: narrow ? double.infinity : null,
                padding: const EdgeInsets.symmetric(
                  vertical: 14,
                  horizontal: 12,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: selected
                        ? OnboardingTheme.navy
                        : OnboardingTheme.border,
                    width: selected ? 2 : 1,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      selected ? Icons.check_circle : _iconFor(status),
                      size: 18,
                      color: selected
                          ? OnboardingTheme.navy
                          : OnboardingTheme.muted,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      status,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: selected
                            ? OnboardingTheme.navy
                            : OnboardingTheme.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );

          if (narrow) {
            return Padding(
              padding: EdgeInsets.only(bottom: status == 'Employed' ? 8 : 0),
              child: card,
            );
          }
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: status == 'Employed' ? 8 : 0),
              child: card,
            ),
          );
        }).toList();

        if (narrow) {
          return Column(children: children);
        }
        return Row(children: children);
      },
    );
  }
}

class OnboardingDateTile extends StatelessWidget {
  const OnboardingDateTile({
    super.key,
    required this.label,
    required this.valueText,
    required this.onTap,
    this.enabled = true,
    this.hasValue = false,
  });

  final String label;
  final String valueText;
  final VoidCallback onTap;
  final bool enabled;
  final bool hasValue;

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
          ),
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

class OnboardingBottomBar extends StatelessWidget {
  const OnboardingBottomBar({
    super.key,
    required this.primary,
    this.secondary,
  });

  final Widget primary;
  final Widget? secondary;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: OnboardingTheme.card,
      elevation: 8,
      shadowColor: OnboardingTheme.navy.withValues(alpha: 0.08),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              primary,
              if (secondary != null) ...[
                const SizedBox(height: 4),
                secondary!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class OnboardingStepLayout extends StatelessWidget {
  const OnboardingStepLayout({
    super.key,
    required this.content,
    required this.bottomBar,
    this.centerShortContent = false,
  });

  final Widget content;
  final Widget bottomBar;
  final bool centerShortContent;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  OnboardingSpacing.screenH,
                  16,
                  OnboardingSpacing.screenH,
                  16,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - 16,
                  ),
                  child: centerShortContent
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [content],
                        )
                      : content,
                ),
              );
            },
          ),
        ),
        bottomBar,
      ],
    );
  }
}

class OnboardingPrimaryButton extends StatelessWidget {
  const OnboardingPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.showTrailingArrow = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final bool showTrailingArrow;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: OnboardingSpacing.buttonHeight,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: OnboardingTheme.navy,
          foregroundColor: Colors.white,
          disabledBackgroundColor: OnboardingTheme.navy.withValues(alpha: 0.45),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
        ),
        child: loading
            ? const SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                  ),
                  if (showTrailingArrow) ...[
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward_rounded, size: 20),
                  ],
                ],
              ),
      ),
    );
  }
}

class OnboardingProfileProgress extends StatelessWidget {
  const OnboardingProfileProgress({
    super.key,
    required this.filled,
    required this.total,
  });

  final int filled;
  final int total;

  @override
  Widget build(BuildContext context) {
    final ratio = total == 0 ? 0.0 : filled / total;
    return Container(
      margin: const EdgeInsets.only(bottom: OnboardingSpacing.sectionGap),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: OnboardingTheme.navy.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.checklist_rtl, size: 16, color: OnboardingTheme.navy),
              const SizedBox(width: 8),
              Text(
                '$filled of $total required fields completed',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: OnboardingTheme.navy,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 4,
              backgroundColor: OnboardingTheme.border,
              color: ratio >= 1 ? OnboardingTheme.success : OnboardingTheme.gold,
            ),
          ),
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
      return _ProvincePickerSheet(
        provinces: provinces,
        selected: selected,
      );
    },
  );
}

class _ProvincePickerSheet extends StatefulWidget {
  const _ProvincePickerSheet({
    required this.provinces,
    this.selected,
  });

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
    helperStyle: const TextStyle(
      fontSize: 12,
      color: OnboardingTheme.muted,
      fontStyle: FontStyle.italic,
    ),
    prefixIcon: icon != null
        ? Icon(icon, color: OnboardingTheme.navy, size: 20)
        : null,
    filled: true,
    fillColor: readOnly ? const Color(0xFFF9FAFB) : Colors.white,
    labelStyle: const TextStyle(color: OnboardingTheme.muted, fontSize: 14),
    hintStyle: TextStyle(
      color: Colors.grey.shade500,
      fontWeight: FontWeight.w400,
    ),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(OnboardingSpacing.inputRadius),
      borderSide: const BorderSide(color: OnboardingTheme.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(OnboardingSpacing.inputRadius),
      borderSide: const BorderSide(color: OnboardingTheme.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(OnboardingSpacing.inputRadius),
      borderSide: const BorderSide(color: OnboardingTheme.navy, width: 1.8),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(OnboardingSpacing.inputRadius),
      borderSide: BorderSide(color: Colors.red.shade300),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
  );
}
