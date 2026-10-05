begin transaction read only;
select 'flag' as kind,
  fl.status || ' ' || fl.rule_id || ' [' || fl.cohort_level || ' ' || coalesce(fl.course, '') || ' ' || coalesce(fl.batch_year, '') || ']' as item,
  round(fl.metric_value, 4) || ' n=' || coalesce(fl.sample_n::text, '-') || ' of ' || coalesce(fl.eligible_n::text, '-')
    || coalesce(' hits=' || (fl.evidence ->> 'hits'), '') as stored,
  round(m.value, 4) || ' n=' || coalesce(m.sample_n::text, '-') || ' of ' || coalesce(m.eligible_n::text, '-')
    || ' hits=' || coalesce(m.hits::text, '-') as replayed,
  case when round(fl.metric_value, 6) is not distinct from round(m.value, 6)
        and fl.sample_n is not distinct from m.sample_n
        and fl.eligible_n is not distinct from m.eligible_n then 'match' else 'DIFF' end as result
from public.dss_flags fl
join public.dss_rules r on r.rule_id = fl.rule_id
cross join lateral public.gts_metric(r.metric_key, fl.survey_id::uuid,
  case when fl.cohort_level = 'institution' then null else fl.course end,
  case when fl.cohort_level in ('institution', 'course') then null else fl.batch_year end) m
union all
select 'counter', 'surveys.assignment_count / response_count',
  sum(s.assignment_count) || ' / ' || sum(s.response_count),
  sum((select count(*) from public.survey_assignments a where a.survey_id = s.id)) || ' / '
    || sum((select count(*) from public.survey_responses r where r.survey_id = s.id and r.status = 'submitted')),
  case when count(*) filter (where s.assignment_count <> (select count(*) from public.survey_assignments a where a.survey_id = s.id)
                                or s.response_count <> (select count(*) from public.survey_responses r where r.survey_id = s.id and r.status = 'submitted')) = 0
       then 'match' else 'DIFF' end
from public.surveys s
union all
select 'counter', 'events.comments_count',
  sum(e.comments_count)::text,
  sum((select count(*) from public.event_comments c where c.event_id = e.id))::text || ' comments, '
    || sum((select count(*) from public.event_replies rp join public.event_comments c on c.id = rp.comment_id where c.event_id = e.id))::text || ' replies',
  case when count(*) filter (where e.comments_count not in (
           (select count(*) from public.event_comments c where c.event_id = e.id),
           (select count(*) from public.event_comments c where c.event_id = e.id)
             + (select count(*) from public.event_replies rp join public.event_comments c on c.id = rp.comment_id where c.event_id = e.id))) = 0
       then 'match' else 'DIFF' end
from public.events e
union all
select 'counter', 'forum_topics.reply_count',
  sum(t.reply_count)::text,
  sum((select count(*) from public.forum_posts p where p.topic_id = t.id))::text,
  case when count(*) filter (where t.reply_count <> (select count(*) from public.forum_posts p where p.topic_id = t.id)) = 0
       then 'match' else 'DIFF' end
from public.forum_topics t
union all
select 'employment', 'gts_employment_records vs latest raw ched_16',
  (select string_agg(status || '=' || n, ' ' order by status) from (select status, count(*) n from public.gts_employment_records group by 1) a),
  (select string_agg(st || '=' || n, ' ' order by st) from (
     select case public.gts_single(r.answers -> 'ched_16') when 'Yes' then 'Employed' when 'No' then 'Unemployed' when 'Never Employed' then 'Never Employed' else 'other' end st, count(*) n
     from (select distinct on (r.user_id) r.user_id, r.answers
           from public.survey_responses r join public.surveys s on s.id = r.survey_id
           where r.status = 'submitted' and s.data ->> 'template_key' = 'ched_gts_builtin'
           order by r.user_id, r.submitted_at desc nulls last) r
     group by 1) b),
  ''
union all
select 'employment', 'unemployment_rate (institution, latest CHED wave) vs raw',
  (select round(value, 4) || ' n=' || sample_n from public.gts_metric('unemployment_rate',
     (select s.id from public.surveys s where s.data ->> 'template_key' = 'ched_gts_builtin' and s.status = 'published' order by s.created_at desc limit 1))),
  (select round(avg(case when public.gts_single(r.answers -> 'ched_16') in ('No', 'Never Employed') then 1.0 else 0 end), 4) || ' n=' || count(*)
   from public.survey_responses r
   where r.status = 'submitted' and public.gts_single(r.answers -> 'ched_16') is not null
     and r.survey_id = (select s.id from public.surveys s where s.data ->> 'template_key' = 'ched_gts_builtin' and s.status = 'published' order by s.created_at desc limit 1)),
  ''
union all
select 'cron', j.jobname || ' (' || j.schedule || ')',
  coalesce((select d.status || ' ' || to_char(d.start_time at time zone 'Asia/Manila', 'MM-DD HH24:MI')
            from cron.job_run_details d where d.jobid = j.jobid order by d.start_time desc limit 1), 'never ran'),
  (select count(*) filter (where d.status <> 'succeeded') || ' failed of ' || count(*) || ' in 7d'
   from cron.job_run_details d where d.jobid = j.jobid and d.start_time > now() - interval '7 days'),
  ''
from cron.job j
order by 1, 2;
rollback;
