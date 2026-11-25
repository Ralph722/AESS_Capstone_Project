-- Drop unused forum tags from the alumni composer chip list.
-- forum_topic_tags rows cascade via tag_id FK.

begin;

delete from public.forum_tags
where slug in ('internship', 'scholarship');

commit;
