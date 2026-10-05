select c.table_name tbl, c.column_name col,
  c.data_type || case when c.data_type in ('USER-DEFINED','ARRAY') then ' (' || c.udt_name || ')' else '' end typ,
  case when c.is_nullable='NO' then 'yes' else '' end not_null,
  coalesce(c.column_default,'') def,
  case when c.is_generated='ALWAYS' then coalesce(c.generation_expression,'generated') else '' end generated
from information_schema.columns c
join information_schema.tables tb on tb.table_schema=c.table_schema and tb.table_name=c.table_name and tb.table_type='BASE TABLE'
where c.table_schema='public'
order by c.table_name, c.ordinal_position;
