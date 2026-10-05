// Prints SQL that seeds public.gts_question_catalog from the built-in CHED
// GTS schema. Run after changing ched_gts_schema.dart (and bump schemaVersion):
//   dart run tool/gen_gts_catalog.dart > catalog_seed.sql
import 'dart:convert';
import 'dart:io';

import 'package:alumni_system/features/surveys/ched_gts/ched_gts_schema.dart';

String _text(String? value) =>
    value == null ? 'null' : "'${value.replaceAll("'", "''")}'";

String _json(List<String> values) => "${_text(jsonEncode(values))}::jsonb";

void main() {
  final items = ChedGtsBuiltin.items;
  final out = StringBuffer()
    ..writeln('insert into public.gts_question_catalog (')
    ..writeln('  schema_version, item_id, ched_number, section, field_type, prompt,')
    ..writeln('  help_text, options, matrix_rows, matrix_columns, table_columns,')
    ..writeln('  required, others_specify_id, is_others_specify, sort_order')
    ..writeln(')')
    ..writeln('values');
  for (var i = 0; i < items.length; i++) {
    final item = items[i];
    final values = [
      _text(ChedGtsBuiltin.schemaVersion),
      _text(item.id),
      _text(item.chedNumber),
      _text(item.section.name),
      _text(item.type.name),
      _text(item.prompt),
      _text(item.helpText),
      _json(item.options),
      _json(item.matrixRows),
      _json(item.matrixColumns),
      _json(item.tableColumns),
      '${item.required}',
      _text(item.othersSpecifyId),
      '${item.isOthersSpecify}',
      '${i + 1}',
    ];
    out.writeln('  (${values.join(', ')})${i == items.length - 1 ? '' : ','}');
  }
  out
    ..writeln('on conflict (schema_version, item_id) do update set')
    ..writeln('  ched_number = excluded.ched_number,')
    ..writeln('  section = excluded.section,')
    ..writeln('  field_type = excluded.field_type,')
    ..writeln('  prompt = excluded.prompt,')
    ..writeln('  help_text = excluded.help_text,')
    ..writeln('  options = excluded.options,')
    ..writeln('  matrix_rows = excluded.matrix_rows,')
    ..writeln('  matrix_columns = excluded.matrix_columns,')
    ..writeln('  table_columns = excluded.table_columns,')
    ..writeln('  required = excluded.required,')
    ..writeln('  others_specify_id = excluded.others_specify_id,')
    ..writeln('  is_others_specify = excluded.is_others_specify,')
    ..writeln('  sort_order = excluded.sort_order;');
  stdout.write(out);
}
