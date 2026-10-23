import 'package:alumni_system/features/admin/dss/models/dss_models.dart';

/// Diff of flag statuses before vs after a Re-run analysis.
class DssRerunDiff {
  const DssRerunDiff({
    this.raised = 0,
    this.movedToWatch = 0,
    this.superseded = 0,
    this.becameFinding = 0,
  });

  final int raised;
  final int movedToWatch;
  final int superseded;
  final int becameFinding;

  bool get isEmpty =>
      raised == 0 &&
      movedToWatch == 0 &&
      superseded == 0 &&
      becameFinding == 0;

  /// Short banner text, or null when nothing changed.
  String? get bannerText {
    if (isEmpty) return null;
    final parts = <String>[
      if (raised > 0)
        '$raised new finding${raised == 1 ? '' : 's'}',
      if (becameFinding > 0)
        '$becameFinding moved to Open',
      if (movedToWatch > 0)
        '$movedToWatch moved to Watch',
      if (superseded > 0)
        '$superseded superseded',
    ];
    return parts.join(' · ');
  }
}

/// Compares prior flag statuses to the list after a re-run.
DssRerunDiff dssRerunDiff({
  required Map<String, DssFlagStatus> before,
  required List<DssFlag> after,
}) {
  var raised = 0;
  var movedToWatch = 0;
  var superseded = 0;
  var becameFinding = 0;
  final afterById = {for (final f in after) f.id: f};

  for (final flag in after) {
    final prev = before[flag.id];
    if (prev == null) {
      if (flag.status == DssFlagStatus.open ||
          flag.status == DssFlagStatus.watch) {
        raised++;
      }
      continue;
    }
    if (prev != DssFlagStatus.watch && flag.status == DssFlagStatus.watch) {
      movedToWatch++;
    }
    if (prev == DssFlagStatus.watch && flag.status == DssFlagStatus.open) {
      becameFinding++;
    }
    if (prev != DssFlagStatus.superseded &&
        flag.status == DssFlagStatus.superseded) {
      superseded++;
    }
  }

  // Flags that disappeared from the active list but exist as superseded
  // with a new id are counted via the after list above. Flags removed
  // entirely without a supersede entry are ignored (history still has them).
  for (final id in before.keys) {
    if (afterById.containsKey(id)) continue;
  }

  return DssRerunDiff(
    raised: raised,
    movedToWatch: movedToWatch,
    superseded: superseded,
    becameFinding: becameFinding,
  );
}
