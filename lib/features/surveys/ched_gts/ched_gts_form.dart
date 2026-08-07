import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:alumni_system/features/surveys/ched_gts/ched_gts_schema.dart';
import 'package:alumni_system/features/surveys/ched_gts/ched_gts_visibility.dart';
import 'package:alumni_system/shared/widgets/onboarding/onboarding_ui.dart';

typedef ChedGtsAnswersChanged = void Function(Map<String, dynamic> answers);

/// Digitized official CHED GTS form with paper-accurate skip logic.
class ChedGtsForm extends StatefulWidget {
  const ChedGtsForm({
    super.key,
    required this.answers,
    required this.onChanged,
    this.readOnly = false,
    this.showIntro = true,
    this.sectionFilter,
    this.showSectionHeaders = true,
  });

  final Map<String, dynamic> answers;
  final ChedGtsAnswersChanged onChanged;
  final bool readOnly;
  final bool showIntro;
  /// When set, only items in this section are rendered.
  final ChedGtsSection? sectionFilter;
  final bool showSectionHeaders;

  @override
  State<ChedGtsForm> createState() => _ChedGtsFormState();
}

class _ChedGtsFormState extends State<ChedGtsForm> {
  late Map<String, dynamic> _answers;
  final Map<String, TextEditingController> _textControllers = {};

  @override
  void initState() {
    super.initState();
    _answers = Map<String, dynamic>.from(widget.answers);
    _syncTextControllers();
  }

  @override
  void didUpdateWidget(covariant ChedGtsForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.answers, widget.answers)) {
      _answers = Map<String, dynamic>.from(widget.answers);
      _syncTextControllers();
    }
  }

  @override
  void dispose() {
    for (final c in _textControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _syncTextControllers() {
    for (final item in ChedGtsBuiltin.items) {
      if (item.type != ChedGtsFieldType.text &&
          item.type != ChedGtsFieldType.longText) {
        continue;
      }
      final text = _answers[item.id]?.toString() ?? '';
      final existing = _textControllers[item.id];
      if (existing == null) {
        _textControllers[item.id] = TextEditingController(text: text);
      } else if (existing.text != text) {
        existing.text = text;
      }
    }
  }

  Set<String> get _visible => ChedGtsVisibility.visibleItemIds(_answers);

  void _set(String id, dynamic value) {
    if (widget.readOnly) return;
    setState(() {
      _answers[id] = value;
      _answers = ChedGtsVisibility.pruneHiddenAnswers(_answers);
      _syncTextControllers();
    });
    widget.onChanged(Map<String, dynamic>.from(_answers));
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visible;
    ChedGtsSection? lastSection;

    final children = <Widget>[];
    if (widget.showIntro) {
      children.add(_IntroBanner());
      children.add(const SizedBox(height: 16));
    }

    for (final item in ChedGtsBuiltin.items) {
      if (!visible.contains(item.id)) continue;
      if (widget.sectionFilter != null &&
          item.section != widget.sectionFilter) {
        continue;
      }
      if (widget.showSectionHeaders && item.section != lastSection) {
        lastSection = item.section;
        children.add(_SectionHeader(title: item.sectionTitle));
        children.add(const SizedBox(height: 12));
      }
      children.add(_ItemCard(
        item: item,
        value: _answers[item.id],
        textController: _textControllers[item.id],
        readOnly: widget.readOnly,
        onChanged: (v) => _set(item.id, v),
      ));
      children.add(const SizedBox(height: 12));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }
}

class _IntroBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: OnboardingTheme.navy.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: OnboardingTheme.border),
      ),
      child: const Text(
        'Please complete this GTS questionnaire as accurately & frankly as '
        'possible. Your answers will be used for research purposes to assess '
        'graduate employability and improve course offerings. Answers are '
        'treated with strictest confidentiality.\n\n'
        'Items marked Optional may be skipped. For example, if you have not '
        'passed any professional examinations, leave item 13 blank or write None / N/A.',
        style: TextStyle(fontSize: 13, height: 1.4, color: OnboardingTheme.muted),
      ),
    );
  }
}

class _RequiredBadge extends StatelessWidget {
  const _RequiredBadge({required this.required});

  final bool required;

  @override
  Widget build(BuildContext context) {
    final bg = required
        ? const Color(0xFFFEF3C7)
        : const Color(0xFFECFDF5);
    final fg = required
        ? const Color(0xFF92400E)
        : const Color(0xFF047857);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        required ? 'Required' : 'Optional',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [OnboardingTheme.navy, OnboardingTheme.navyLight],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 13,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({
    required this.item,
    required this.value,
    required this.onChanged,
    required this.readOnly,
    this.textController,
  });

  final ChedGtsItem item;
  final dynamic value;
  final ValueChanged<dynamic> onChanged;
  final bool readOnly;
  final TextEditingController? textController;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 0,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: OnboardingTheme.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    '${item.chedNumber}. ${item.prompt}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: OnboardingTheme.navy,
                      height: 1.35,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _RequiredBadge(required: item.required),
              ],
            ),
            if (!item.required && !item.isOthersSpecify) ...[
              const SizedBox(height: 6),
              Text(
                'Optional — you may skip this item or write None / N/A if it does not apply.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.35,
                  color: Colors.grey.shade700,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            const SizedBox(height: 12),
            _buildField(),
          ],
        ),
      ),
    );
  }

  Widget _buildField() {
    switch (item.type) {
      case ChedGtsFieldType.text:
      case ChedGtsFieldType.longText:
        return TextField(
          controller: textController,
          readOnly: readOnly,
          maxLines: item.type == ChedGtsFieldType.longText ? 4 : 1,
          onChanged: onChanged,
          decoration: onboardingFieldDecoration(
            label: item.required ? 'Your answer *' : 'Optional — skip if N/A',
            hint: item.required ? null : 'None / N/A or leave blank',
          ),
        );
      case ChedGtsFieldType.date:
        return _DateField(
          value: value?.toString(),
          readOnly: readOnly,
          onChanged: onChanged,
        );
      case ChedGtsFieldType.single:
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: item.options.map((opt) {
            final selected = value?.toString() == opt;
            return ChoiceChip(
              label: Text(opt),
              selected: selected,
              onSelected: readOnly
                  ? null
                  : (_) => onChanged(opt),
              selectedColor: OnboardingTheme.navy.withValues(alpha: 0.12),
              labelStyle: TextStyle(
                fontWeight: FontWeight.w600,
                color: selected ? OnboardingTheme.navy : OnboardingTheme.muted,
                fontSize: 12,
              ),
            );
          }).toList(),
        );
      case ChedGtsFieldType.multi:
        final selected = value is List
            ? value!.map((e) => e.toString()).toSet()
            : <String>{};
        return Column(
          children: item.options.map((opt) {
            final checked = selected.contains(opt);
            return CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(opt, style: const TextStyle(fontSize: 13)),
              value: checked,
              onChanged: readOnly
                  ? null
                  : (v) {
                      final next = Set<String>.from(selected);
                      if (v == true) {
                        next.add(opt);
                      } else {
                        next.remove(opt);
                      }
                      onChanged(next.toList());
                    },
            );
          }).toList(),
        );
      case ChedGtsFieldType.matrix:
        return _MatrixField(
          item: item,
          value: value is Map
              ? Map<String, dynamic>.from(value as Map)
              : <String, dynamic>{},
          readOnly: readOnly,
          onChanged: onChanged,
        );
      case ChedGtsFieldType.tableRows:
        return _TableRowsField(
          item: item,
          value: value is List
              ? List<Map<String, dynamic>>.from(
                  (value as List).map(
                    (e) => e is Map
                        ? Map<String, dynamic>.from(e)
                        : <String, dynamic>{},
                  ),
                )
              : <Map<String, dynamic>>[{}],
          readOnly: readOnly,
          onChanged: onChanged,
        );
    }
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.value,
    required this.onChanged,
    required this.readOnly,
  });

  final String? value;
  final ValueChanged<String> onChanged;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    DateTime? parsed;
    if (value != null && value!.isNotEmpty) {
      parsed = DateTime.tryParse(value!);
    }
    final label = parsed != null
        ? DateFormat.yMMMd().format(parsed)
        : 'Tap to select date';

    return InkWell(
      onTap: readOnly
          ? null
          : () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: parsed ?? DateTime(2000, 1, 1),
                firstDate: DateTime(1950),
                lastDate: DateTime.now(),
              );
              if (picked != null) {
                onChanged(DateFormat('yyyy-MM-dd').format(picked));
              }
            },
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: onboardingFieldDecoration(
          label: 'Birthday',
          icon: Icons.calendar_today_outlined,
        ),
        child: Text(label),
      ),
    );
  }
}

class _MatrixField extends StatelessWidget {
  const _MatrixField({
    required this.item,
    required this.value,
    required this.onChanged,
    required this.readOnly,
  });

  final ChedGtsItem item;
  final Map<String, dynamic> value;
  final ValueChanged<Map<String, dynamic>> onChanged;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowHeight: 40,
        dataRowMinHeight: 40,
        dataRowMaxHeight: 56,
        columns: [
          const DataColumn(label: Text('')),
          ...item.matrixColumns.map(
            (c) => DataColumn(
              label: Text(c, style: const TextStyle(fontSize: 11)),
            ),
          ),
        ],
        rows: item.matrixRows.map((row) {
          final rowMap = value[row] is Map
              ? Map<String, dynamic>.from(value[row] as Map)
              : <String, dynamic>{};
          return DataRow(
            cells: [
              DataCell(
                SizedBox(
                  width: 160,
                  child: Text(row, style: const TextStyle(fontSize: 12)),
                ),
              ),
              ...item.matrixColumns.map((col) {
                final checked = rowMap[col] == true;
                return DataCell(
                  Checkbox(
                    value: checked,
                    onChanged: readOnly
                        ? null
                        : (v) {
                            final next = Map<String, dynamic>.from(value);
                            final nextRow = Map<String, dynamic>.from(rowMap);
                            // Single select per column for job level (item 30).
                            if (item.id == 'ched_30' && v == true) {
                              for (final r in item.matrixRows) {
                                final other = next[r] is Map
                                    ? Map<String, dynamic>.from(next[r] as Map)
                                    : <String, dynamic>{};
                                other[col] = false;
                                next[r] = other;
                              }
                            }
                            nextRow[col] = v == true;
                            next[row] = nextRow;
                            onChanged(next);
                          },
                  ),
                );
              }),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _TableRowsField extends StatelessWidget {
  const _TableRowsField({
    required this.item,
    required this.value,
    required this.onChanged,
    required this.readOnly,
  });

  final ChedGtsItem item;
  final List<Map<String, dynamic>> value;
  final ValueChanged<List<Map<String, dynamic>>> onChanged;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final rows = value.isEmpty ? [<String, dynamic>{}] : value;

    return Column(
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const Divider(height: 20),
          ...item.tableColumns.map((col) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: TextFormField(
                initialValue: rows[i][col]?.toString() ?? '',
                readOnly: readOnly,
                onChanged: (text) {
                  final next = rows
                      .map((r) => Map<String, dynamic>.from(r))
                      .toList();
                  next[i][col] = text;
                  onChanged(next);
                },
                decoration: onboardingFieldDecoration(
                  label: item.required ? col : '$col (optional)',
                  hint: item.required ? null : 'Leave blank or None / N/A',
                ),
              ),
            );
          }),
        ],
        if (!readOnly)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () {
                onChanged([
                  ...rows.map((r) => Map<String, dynamic>.from(r)),
                  <String, dynamic>{},
                ]);
              },
              icon: const Icon(Icons.add, size: 18),
              label: Text(item.required ? 'Add row' : 'Add row (optional)'),
            ),
          ),
      ],
    );
  }
}

/// Formats a builtin answer for history / admin display.
String formatChedGtsAnswer(ChedGtsItem item, dynamic value) {
  if (value == null) return '—';
  switch (item.type) {
    case ChedGtsFieldType.multi:
      if (value is List) return value.join(', ');
      return value.toString();
    case ChedGtsFieldType.matrix:
      if (value is! Map) return value.toString();
      final parts = <String>[];
      value.forEach((row, cols) {
        if (cols is Map) {
          final checked = cols.entries
              .where((e) => e.value == true)
              .map((e) => e.key.toString())
              .toList();
          if (checked.isNotEmpty) {
            parts.add('$row: ${checked.join(", ")}');
          }
        }
      });
      return parts.isEmpty ? '—' : parts.join(' · ');
    case ChedGtsFieldType.tableRows:
      if (value is! List) return value.toString();
      return value
          .whereType<Map>()
          .map((row) => row.values.where((v) => '$v'.trim().isNotEmpty).join(' | '))
          .where((s) => s.isNotEmpty)
          .join('\n');
    default:
      return value.toString();
  }
}
