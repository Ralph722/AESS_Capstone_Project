import 'package:intl/intl.dart';
import 'package:alumni_system/features/admin/reports/application/gts_alumni_list.dart';
import 'package:alumni_system/features/admin/reports/application/gts_list_tables.dart';
import 'package:alumni_system/features/admin/reports/models/gts_list_config.dart';

/// Formal note at the top of an alumni list. The wording is built from the
/// same tally the preview and the export print, so a figure in the note is
/// a figure in the tally. Names are never included.
///
/// The note is composed locally. It is not sent to the AI assistant, so
/// changing columns or filters only rebuilds the text from the tally.
abstract final class GtsListNarrative {
  static final _asOf = DateFormat('d MMMM yyyy');

  static String compose(GtsAlumniListResult result) {
    final tally = result.tally;
    final rate = GtsListTables.percent(tally.responseRate);
    final asOf = _asOf.format(result.generatedAt.toLocal());
    final buffer = StringBuffer()
      ..writeln(
        'This report covers ${tally.total} alumni on the alumni list. '
        'Answers are taken from ${GtsListTables.scope(result)}. '
        '${tally.answered} of these alumni submitted the tracer, a response '
        'rate of $rate. The response rate is calculated by dividing the '
        'number who submitted the tracer (${tally.answered}) by the number '
        'of alumni on the alumni list (${tally.total}).',
      );

    for (final section in GtsListTables.sections(result)) {
      if (section.title == 'Summary') continue;
      final categories = [
        for (final line in section.lines)
          if (!line.isRate && !line.isTotal)
            '${line.count} (${line.share.isEmpty ? 'outside the alumni list total' : line.share}) ${line.label}',
      ];
      if (section.title == 'Tracer status') {
        buffer.writeln(
          'By tracer status, the alumni list is distributed as follows: '
          '${categories.join('; ')}.',
        );
        continue;
      }
      final answered = section.line(GtsListTables.answeredQuestionLabel);
      final employment = section.line(GtsListTables.employmentRateLabel);
      buffer.write(
        'For ${section.title}, ${answered?.count ?? '0 of 0'} alumni who '
        'were asked this question gave an answer'
        '${answered == null ? '' : ' (${answered.share})'}. ',
      );
      if (categories.isEmpty) {
        buffer.write('No answer was recorded. ');
      } else {
        buffer.write('Of those who answered: ${categories.join('; ')}. ');
      }
      if (employment != null) {
        buffer.write(
          'The employment rate is ${employment.share}, calculated by '
          'dividing the number who answered Yes by the number who answered '
          'this question (${employment.count}). ',
        );
      }
      if (section.note != null &&
          section.note!.contains('more than one answer')) {
        buffer.write(
          'Alumni may select more than one answer, so these shares can '
          'add up to more than 100%. ',
        );
      }
      buffer.writeln();
    }

    final offRoster = tally.count(GtsTracerStatus.offRoster);
    if (offRoster > 0) {
      buffer.writeln(
        '$offRoster ${offRoster == 1 ? 'graduate' : 'graduates'} submitted '
        'the tracer without an active alumni list record. '
        '${offRoster == 1 ? 'This graduate is' : 'These graduates are'} '
        'listed separately and ${offRoster == 1 ? 'is' : 'are'} not included '
        'in the total or in the rates above.',
      );
    }
    final charts = GtsListTables.charts(result);
    if (charts.length >= GtsListTables.maxCharts &&
        GtsListTables.sections(result).length > charts.length) {
      buffer.writeln(
        'The charts show the first ${GtsListTables.maxCharts} distributions. '
        'The tally lists every selected question.',
      );
    }
    buffer.write('Figures are as of $asOf.');
    return buffer.toString().trim();
  }
}
