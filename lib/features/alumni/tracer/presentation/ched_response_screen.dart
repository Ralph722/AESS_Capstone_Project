import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:alumni_system/features/surveys/ched_gts/ched_gts_schema.dart';
import 'package:alumni_system/features/surveys/ched_gts/ched_gts_visibility.dart';
import 'package:alumni_system/features/surveys/ched_gts/ched_gts_wizard.dart';
import 'package:alumni_system/features/surveys/data/survey_answer_display.dart';
import 'package:alumni_system/shared/widgets/user/portal_breakpoints.dart';
import 'package:alumni_system/shared/widgets/user/portal_headers.dart';
import 'package:alumni_system/shared/widgets/user/portal_theme.dart';

/// Read-only view of a submitted CHED GTS response, one tab per section.
class ChedResponseScreen extends StatelessWidget {
  const ChedResponseScreen({
    super.key,
    required this.surveyTitle,
    required this.answers,
    this.submittedAt,
  });

  final String surveyTitle;
  final Map<String, dynamic> answers;
  final DateTime? submittedAt;

  static Future<void> open(
    BuildContext context, {
    required String surveyTitle,
    required Map<String, dynamic> answers,
    DateTime? submittedAt,
  }) {
    return Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (_) => ChedResponseScreen(
          surveyTitle: surveyTitle,
          answers: answers,
          submittedAt: submittedAt,
        ),
      ),
    );
  }

  static String _tabLabel(ChedGtsSection s) => switch (s) {
    ChedGtsSection.a => 'General',
    ChedGtsSection.b => 'Education',
    ChedGtsSection.c => 'Training',
    ChedGtsSection.d => 'Employment',
  };

  @override
  Widget build(BuildContext context) {
    final submittedLabel = submittedAt != null
        ? DateFormat.yMMMd().add_jm().format(submittedAt!.toLocal())
        : null;
    final visible = ChedGtsVisibility.visibleItemIds(answers);

    return DefaultTabController(
      length: ChedGtsSection.values.length,
      child: Scaffold(
        backgroundColor: PortalTheme.pageBg,
        appBar: PortalAppBar(
          title: 'Your response',
          subtitle: surveyTitle,
          centerTitle: true,
          automaticallyImplyLeading: true,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(47),
            child: Column(
              children: [
                TabBar(
                  indicatorColor: PortalTheme.gold,
                  indicatorWeight: 3,
                  labelColor: PortalTheme.navy,
                  unselectedLabelColor: PortalTheme.textSecondary,
                  labelStyle: PortalTheme.meta.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  tabs: [
                    for (final s in ChedGtsSection.values)
                      Tab(text: _tabLabel(s)),
                  ],
                ),
                Container(height: 1, color: PortalTheme.border),
              ],
            ),
          ),
        ),
        body: TabBarView(
          children: [
            for (final s in ChedGtsSection.values)
              PortalContentFrame(
                child: _SectionAnswers(
                  section: s,
                  answers: answers,
                  visible: visible,
                  submittedLabel: submittedLabel,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SectionAnswers extends StatelessWidget {
  const _SectionAnswers({
    required this.section,
    required this.answers,
    required this.visible,
    required this.submittedLabel,
  });

  final ChedGtsSection section;
  final Map<String, dynamic> answers;
  final Set<String> visible;
  final String? submittedLabel;

  String? _specifyText(ChedGtsItem item) {
    final id = item.othersSpecifyId;
    if (id == null) return null;
    final text = formatSurveyAnswerValue(answers[id]);
    return text.isEmpty ? null : text;
  }

  @override
  Widget build(BuildContext context) {
    final items = ChedGtsBuiltin.items
        .where(
          (i) =>
              i.section == section &&
              !i.isOthersSpecify &&
              visible.contains(i.id),
        )
        .toList();
    final answered = items
        .where((i) => !isSurveyAnswerEmpty(answers[i.id]))
        .length;
    final width = PortalBreakpoints.widthOf(context);
    final padding = PortalBreakpoints.pagePadding(
      width,
    ).copyWith(left: 16, right: 16);

    return ListView(
      padding: padding.copyWith(
        top: PortalTheme.space3,
        bottom: PortalTheme.space6 + MediaQuery.paddingOf(context).bottom,
      ),
      children: [
        _SectionHeaderCard(
          title: chedSectionLabel(section),
          answered: answered,
          total: items.length,
          submittedLabel: submittedLabel,
        ),
        const SizedBox(height: PortalTheme.space2),
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: PortalTheme.space5),
            child: Text(
              'No questions applied to you in this section.',
              textAlign: TextAlign.center,
              style: PortalTheme.bodySecondary,
            ),
          )
        else
          for (final item in items) ...[
            _AnswerCard(
              prompt: item.prompt,
              value: formatSurveyAnswerValue(answers[item.id]),
              specify: _specifyText(item),
              requiredField: item.required,
            ),
            const SizedBox(height: PortalTheme.space1),
          ],
      ],
    );
  }
}

class _SectionHeaderCard extends StatelessWidget {
  const _SectionHeaderCard({
    required this.title,
    required this.answered,
    required this.total,
    required this.submittedLabel,
  });

  final String title;
  final int answered;
  final int total;
  final String? submittedLabel;

  @override
  Widget build(BuildContext context) {
    final complete = answered == total;
    return Container(
      padding: const EdgeInsets.all(PortalTheme.space3),
      decoration: BoxDecoration(
        color: PortalTheme.card,
        borderRadius: BorderRadius.circular(PortalTheme.radiusLg),
        border: Border.all(color: PortalTheme.border),
        boxShadow: PortalTheme.softShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: PortalTheme.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(PortalTheme.radiusSm),
            ),
            child: const Icon(
              Icons.verified_outlined,
              color: PortalTheme.success,
              size: 20,
            ),
          ),
          const SizedBox(width: PortalTheme.space2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: PortalTheme.cardTitle),
                const SizedBox(height: 2),
                Text(
                  submittedLabel != null
                      ? 'Submitted $submittedLabel'
                      : 'Submitted',
                  style: PortalTheme.meta,
                ),
              ],
            ),
          ),
          const SizedBox(width: PortalTheme.space1),
          PortalChip(
            label: '$answered of $total answered',
            tone: complete ? PortalChipTone.success : PortalChipTone.neutral,
          ),
        ],
      ),
    );
  }
}

class _AnswerCard extends StatelessWidget {
  const _AnswerCard({
    required this.prompt,
    required this.value,
    required this.requiredField,
    this.specify,
  });

  final String prompt;
  final String value;
  final String? specify;
  final bool requiredField;

  @override
  Widget build(BuildContext context) {
    final empty = value.isEmpty;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(PortalTheme.space3),
      decoration: BoxDecoration(
        color: PortalTheme.card,
        borderRadius: BorderRadius.circular(PortalTheme.radiusMd),
        border: Border.all(color: PortalTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  prompt,
                  style: PortalTheme.body.copyWith(
                    fontWeight: FontWeight.w600,
                    color: PortalTheme.textPrimary,
                  ),
                ),
              ),
              if (requiredField) ...[
                const SizedBox(width: PortalTheme.space1),
                Text(
                  'Required',
                  style: PortalTheme.caption.copyWith(
                    color: PortalTheme.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Text(
            empty ? 'No answer' : value,
            style: PortalTheme.bodySecondary.copyWith(
              fontStyle: empty ? FontStyle.italic : FontStyle.normal,
              color: empty ? PortalTheme.textMuted : PortalTheme.navy,
            ),
          ),
          if (specify != null) ...[
            const SizedBox(height: 4),
            Text(
              'Others: $specify',
              style: PortalTheme.bodySecondary.copyWith(
                color: PortalTheme.navy,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
