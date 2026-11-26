import 'package:flutter/material.dart';
import 'package:alumni_system/features/forum/models/forum_model.dart';
import 'package:alumni_system/features/forum/widgets/forum_ui.dart';
import 'package:alumni_system/shared/widgets/user/portal_theme.dart';

/// Poll options: tap to vote / change vote; public tallies once anyone has voted.
class ForumPollCard extends StatelessWidget {
  const ForumPollCard({
    super.key,
    required this.summary,
    required this.onVote,
    this.compact = false,
    this.enabled = true,
    this.voting = false,
  });

  final ForumPollSummary summary;
  final ValueChanged<String> onVote;
  final bool compact;
  final bool enabled;
  final bool voting;

  @override
  Widget build(BuildContext context) {
    final showResults = summary.showResults;
    final footer = !showResults
        ? 'Tap an option to vote. You can change your vote later.'
        : summary.hasVoted
        ? (summary.total == 1
              ? '1 vote · Tap another option to change'
              : '${summary.total} votes · Tap another option to change')
        : (summary.total == 1
              ? '1 vote · Tap an option to vote'
              : '${summary.total} votes · Tap an option to vote');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < summary.options.length; i++) ...[
          if (i > 0) SizedBox(height: compact ? 6 : 8),
          _PollOptionTile(
            option: summary.options[i],
            selected: summary.myOptionId == summary.options[i].id,
            showResults: showResults,
            percent: summary.percentFor(summary.options[i].id),
            total: summary.total,
            enabled: enabled && !voting,
            compact: compact,
            onTap: () => onVote(summary.options[i].id),
          ),
        ],
        SizedBox(height: compact ? 8 : 10),
        Text(
          footer,
          style: PortalTheme.caption.copyWith(
            color: ForumTheme.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _PollOptionTile extends StatelessWidget {
  const _PollOptionTile({
    required this.option,
    required this.selected,
    required this.showResults,
    required this.percent,
    required this.total,
    required this.enabled,
    required this.compact,
    required this.onTap,
  });

  final ForumPollOption option;
  final bool selected;
  final bool showResults;
  final double percent;
  final int total;
  final bool enabled;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pctLabel = total <= 0 ? '0%' : '${(percent * 100).round()}%';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? ForumTheme.navy
                  : ForumTheme.border.withValues(alpha: 0.9),
              width: selected ? 1.5 : 1,
            ),
            color: selected
                ? ForumTheme.navy.withValues(alpha: 0.06)
                : Colors.white,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(11),
            child: Stack(
              children: [
                if (showResults)
                  Positioned.fill(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: percent.clamp(0.0, 1.0),
                        child: ColoredBox(
                          color: ForumTheme.navy.withValues(
                            alpha: selected ? 0.16 : 0.08,
                          ),
                        ),
                      ),
                    ),
                  ),
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: compact ? 12 : 14,
                    vertical: compact ? 10 : 12,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          option.label,
                          style: PortalTheme.body.copyWith(
                            fontSize: compact ? 13 : 14,
                            fontWeight:
                                selected ? FontWeight.w700 : FontWeight.w600,
                            color: ForumTheme.navy,
                          ),
                        ),
                      ),
                      if (showResults)
                        Text(
                          pctLabel,
                          style: PortalTheme.caption.copyWith(
                            fontWeight: FontWeight.w800,
                            color: ForumTheme.navy,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
