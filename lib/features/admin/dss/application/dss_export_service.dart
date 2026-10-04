import 'dart:convert';
import 'dart:typed_data';

import 'package:alumni_system/core/utils/web_file_download.dart';
import 'package:alumni_system/features/admin/dss/models/dss_models.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class DssExportService {
  Future<void> exportFlagsCsv(List<DssFlag> flags) async {
    if (!kIsWeb) {
      throw StateError(
        'Export is only available in the web admin portal.',
      );
    }
    final buf = StringBuffer();
    buf.writeln(
      [
        'id',
        'rule_id',
        'title',
        'cohort_level',
        'course',
        'batch_year',
        'survey_id',
        'survey_title',
        'metric_value',
        'likely_low_95',
        'likely_high_95',
        'certainty',
        'threshold',
        'sample_n',
        'eligible_n',
        'registered_n',
        'confidence',
        'status',
        'recommended_action',
        'intervention_type',
        'baseline_value',
        'followup_value',
        'created_at',
        'resolved_at',
      ].map(_csv).join(','),
    );
    for (final f in flags) {
      buf.writeln(
        [
          f.id,
          f.ruleId,
          f.title,
          f.cohortLevel.dbValue,
          f.course,
          f.batchYear,
          f.surveyId,
          f.surveyTitle,
          f.metricValue.toString(),
          f.ciLow?.toString() ?? '',
          f.ciHigh?.toString() ?? '',
          f.certainty?.dbValue ?? '',
          f.thresholdSnapshot.toString(),
          f.sampleN.toString(),
          f.eligibleN?.toString() ?? '',
          f.evidence['registered_roster']?.toString() ?? '',
          f.confidence.dbValue,
          f.status.dbValue,
          f.recommendedAction,
          f.interventionType ?? '',
          f.baselineValue?.toString() ?? '',
          f.followupValue?.toString() ?? '',
          f.createdAt.toIso8601String(),
          f.resolvedAt?.toIso8601String() ?? '',
        ].map(_csv).join(','),
      );
    }
    final bytes = Uint8List.fromList(utf8.encode(buf.toString()));
    downloadBytesOnWeb(
      bytes: bytes,
      fileName:
          'dss_flags_${DateTime.now().toIso8601String().split('T').first}.csv',
      mimeType: 'text/csv',
    );
  }

  String _csv(String value) {
    final v = value.replaceAll('"', '""');
    if (v.contains(',') || v.contains('"') || v.contains('\n')) {
      return '"$v"';
    }
    return v;
  }
}
