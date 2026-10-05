-- Phase 4: performance.
--   * RLS: auth.uid(), auth.role(), auth.jwt(), is_admin() and is_signed_in()
--     wrapped in sub-selects so they run once per query instead of per row
--   * overlapping permissive policies merged (one policy per table + command)
--   * indexes for every foreign key; redundant event_rsvps index dropped
--   * realtime trimmed to tables the app listens to

update public.programs set name = 'BFPT' where code = 'BFPT';

-- ---------------------------------------------------------------------------
-- RLS initplan rewrite (generated from the live policies; logic unchanged)
-- ---------------------------------------------------------------------------
alter policy alumni_members_delete_admin_only on public.alumni_members
  using ((select public.is_admin()));

alter policy alumni_members_insert_admin_only on public.alumni_members
  with check ((select public.is_admin()));

alter policy announcements_admin_write on public.announcements
  using ((select public.is_admin()))
  with check ((select public.is_admin()));

alter policy announcements_select_signed_in on public.announcements
  using ((select public.is_signed_in()));

alter policy audit_logs_insert_own on public.audit_logs
  with check ((user_id = (select auth.uid())));

alter policy audit_logs_select_admin on public.audit_logs
  using ((select public.is_admin()));

alter policy dss_flag_notes_admin_all on public.dss_flag_notes
  using ((select public.is_admin()))
  with check ((select public.is_admin()));

alter policy dss_flags_admin_all on public.dss_flags
  using ((select public.is_admin()))
  with check ((select public.is_admin()));

alter policy dss_rules_admin_all on public.dss_rules
  using ((select public.is_admin()))
  with check ((select public.is_admin()));

alter policy employment_records_delete_admin on public.employment_records
  using ((select public.is_admin()));

alter policy employment_records_insert_own on public.employment_records
  with check ((user_id = (select auth.uid())));

alter policy employment_records_select_owner_or_admin on public.employment_records
  using (((select public.is_admin()) OR (user_id = (select auth.uid()))));

alter policy employment_records_update_admin_or_owner on public.employment_records
  using (((select public.is_admin()) OR (user_id = (select auth.uid()))))
  with check (((select public.is_admin()) OR (user_id = (select auth.uid()))));

alter policy event_comments_delete_admin_or_author on public.event_comments
  using (((select public.is_admin()) OR (user_id = (select auth.uid()))));

alter policy event_comments_insert_own on public.event_comments
  with check ((user_id = (select auth.uid())));

alter policy event_comments_select_signed_in on public.event_comments
  using ((select public.is_signed_in()));

alter policy event_comments_update_admin_or_author on public.event_comments
  using (((select public.is_admin()) OR (user_id = (select auth.uid()))))
  with check (((select public.is_admin()) OR (user_id = (select auth.uid()))));

alter policy event_replies_admin_delete on public.event_replies
  using ((select public.is_admin()));

alter policy event_replies_admin_insert on public.event_replies
  with check ((select public.is_admin()));

alter policy event_replies_admin_update on public.event_replies
  using ((select public.is_admin()))
  with check ((select public.is_admin()));

alter policy event_replies_select_signed_in on public.event_replies
  using ((select public.is_signed_in()));

alter policy event_rsvps_admin_all on public.event_rsvps
  using ((select public.is_admin()))
  with check ((select public.is_admin()));

alter policy event_rsvps_delete_own on public.event_rsvps
  using ((user_id = (select auth.uid())));

alter policy event_rsvps_insert_own on public.event_rsvps
  with check ((user_id = (select auth.uid())));

alter policy event_rsvps_select_signed_in on public.event_rsvps
  using ((select public.is_signed_in()));

alter policy event_rsvps_update_own on public.event_rsvps
  using ((user_id = (select auth.uid())))
  with check ((user_id = (select auth.uid())));

alter policy events_admin_delete on public.events
  using ((select public.is_admin()));

alter policy events_admin_update on public.events
  using ((select public.is_admin()))
  with check ((select public.is_admin()));

alter policy events_admin_write on public.events
  with check ((select public.is_admin()));

alter policy events_select_signed_in on public.events
  using ((select public.is_signed_in()));

alter policy favorite_jobs_owner_rw on public.favorite_jobs
  using ((user_id = (select auth.uid())))
  with check ((user_id = (select auth.uid())));

alter policy feedback_delete_admin_only on public.feedback
  using ((select public.is_admin()));

alter policy feedback_insert_owner_constraints on public.feedback
  with check (((user_id = (select auth.uid())) AND (status = 'submitted'::text) AND (length(message) >= 10)));

alter policy feedback_select_owner_or_admin on public.feedback
  using (((select public.is_admin()) OR (user_id = (select auth.uid()))));

alter policy feedback_update_delete_admin_only on public.feedback
  using ((select public.is_admin()))
  with check ((select public.is_admin()));

alter policy forum_bookmarks_delete_own on public.forum_bookmarks
  using ((user_id = (select auth.uid())));

alter policy forum_bookmarks_insert_own on public.forum_bookmarks
  with check ((user_id = (select auth.uid())));

alter policy forum_bookmarks_select_own on public.forum_bookmarks
  using ((user_id = (select auth.uid())));

alter policy forum_helpful_delete_own on public.forum_helpful_reactions
  using ((user_id = (select auth.uid())));

alter policy forum_helpful_insert_own on public.forum_helpful_reactions
  with check ((user_id = (select auth.uid())));

alter policy forum_helpful_select_signed_in on public.forum_helpful_reactions
  using ((select public.is_signed_in()));

alter policy forum_moderation_insert_admin on public.forum_moderation_events
  with check (((select public.is_admin()) AND (actor_uid = (select auth.uid()))));

alter policy forum_moderation_select_admin on public.forum_moderation_events
  using ((select public.is_admin()));

alter policy forum_posts_delete_admin_or_author on public.forum_posts
  using (((select public.is_admin()) OR (author_uid = (select auth.uid()))));

alter policy forum_posts_insert_author_when_unlocked on public.forum_posts
  with check (((author_uid = (select auth.uid())) AND (EXISTS ( SELECT 1
   FROM forum_topics t
  WHERE ((t.id = forum_posts.topic_id) AND (t.is_locked = false))))));

alter policy forum_posts_select_signed_in on public.forum_posts
  using ((select public.is_signed_in()));

alter policy forum_posts_update_admin_or_author on public.forum_posts
  using (((select public.is_admin()) OR (author_uid = (select auth.uid()))))
  with check (((select public.is_admin()) OR (author_uid = (select auth.uid()))));

alter policy forum_reports_admin_update on public.forum_reports
  using ((select public.is_admin()))
  with check ((select public.is_admin()));

alter policy forum_reports_insert_own on public.forum_reports
  with check ((reporter_uid = (select auth.uid())));

alter policy forum_reports_select_admin_or_reporter on public.forum_reports
  using (((select public.is_admin()) OR (reporter_uid = (select auth.uid()))));

alter policy forum_tags_admin_write on public.forum_tags
  using ((select public.is_admin()))
  with check ((select public.is_admin()));

alter policy forum_tags_select_signed_in on public.forum_tags
  using ((select public.is_signed_in()));

alter policy forum_topic_tags_delete_author_or_admin on public.forum_topic_tags
  using (((select public.is_admin()) OR (EXISTS ( SELECT 1
   FROM forum_topics t
  WHERE ((t.id = forum_topic_tags.topic_id) AND (t.author_uid = (select auth.uid())))))));

alter policy forum_topic_tags_insert_author_or_admin on public.forum_topic_tags
  with check (((select public.is_admin()) OR (EXISTS ( SELECT 1
   FROM forum_topics t
  WHERE ((t.id = forum_topic_tags.topic_id) AND (t.author_uid = (select auth.uid())))))));

alter policy forum_topic_tags_select_signed_in on public.forum_topic_tags
  using ((select public.is_signed_in()));

alter policy forum_topics_delete_admin_or_author on public.forum_topics
  using (((select public.is_admin()) OR (author_uid = (select auth.uid()))));

alter policy forum_topics_insert_author on public.forum_topics
  with check ((author_uid = (select auth.uid())));

alter policy forum_topics_select_signed_in on public.forum_topics
  using ((select public.is_signed_in()));

alter policy forum_topics_update_admin_or_author on public.forum_topics
  using (((select public.is_admin()) OR (author_uid = (select auth.uid()))))
  with check (((select public.is_admin()) OR (author_uid = (select auth.uid()))));

alter policy job_interests_admin_delete on public.job_interests
  using ((select public.is_admin()));

alter policy job_interests_delete_own on public.job_interests
  using ((user_id = (select auth.uid())));

alter policy job_interests_insert_own on public.job_interests
  with check ((user_id = (select auth.uid())));

alter policy job_interests_select_own_or_admin on public.job_interests
  using (((select public.is_admin()) OR (user_id = (select auth.uid()))));

alter policy jobs_admin_delete on public.jobs
  using ((select public.is_admin()));

alter policy jobs_admin_insert on public.jobs
  with check ((select public.is_admin()));

alter policy jobs_admin_update on public.jobs
  using ((select public.is_admin()))
  with check ((select public.is_admin()));

alter policy jobs_select_signed_in on public.jobs
  using ((select public.is_signed_in()));

alter policy messages_delete_sender_or_admin on public.messages
  using (((select public.is_admin()) OR (sender_id = (select auth.uid()))));

alter policy messages_insert_participant on public.messages
  with check (((sender_id = (select auth.uid())) AND ((select public.is_admin()) OR (EXISTS ( SELECT 1
   FROM users u
  WHERE ((u.id = messages.recipient_id) AND (u.role = 'admin'::text)))))));

alter policy messages_select_participant_or_admin on public.messages
  using (((select public.is_admin()) OR (sender_id = (select auth.uid())) OR (recipient_id = (select auth.uid()))));

alter policy messages_update_participant_or_admin on public.messages
  using (((select public.is_admin()) OR (sender_id = (select auth.uid())) OR (recipient_id = (select auth.uid()))))
  with check (((select public.is_admin()) OR (sender_id = (select auth.uid())) OR (recipient_id = (select auth.uid()))));

alter policy notification_preferences_insert_own on public.notification_preferences
  with check ((user_id = (select auth.uid())));

alter policy notification_preferences_select_own on public.notification_preferences
  using ((user_id = (select auth.uid())));

alter policy notification_preferences_update_own on public.notification_preferences
  using ((user_id = (select auth.uid())))
  with check ((user_id = (select auth.uid())));

alter policy notification_push_deliveries_admin_select on public.notification_push_deliveries
  using ((select public.is_admin()));

alter policy notifications_select_owner_or_admin on public.notifications
  using (((select public.is_admin()) OR (user_id = (select auth.uid()))));

alter policy notifications_write_admin_only on public.notifications
  using ((select public.is_admin()))
  with check ((select public.is_admin()));

alter policy push_tokens_delete_own on public.push_tokens
  using ((user_id = (select auth.uid())));

alter policy push_tokens_select_own on public.push_tokens
  using ((user_id = (select auth.uid())));

alter policy reminders_owner_rw on public.reminders
  using ((user_id = (select auth.uid())))
  with check ((user_id = (select auth.uid())));

alter policy survey_assignments_delete_admin on public.survey_assignments
  using ((select public.is_admin()));

alter policy survey_assignments_insert_delete_admin on public.survey_assignments
  with check ((select public.is_admin()));

alter policy survey_assignments_select_owner_or_admin on public.survey_assignments
  using (((select public.is_admin()) OR (user_id = (select auth.uid()))));

alter policy survey_assignments_update_admin_or_owner on public.survey_assignments
  using (((select public.is_admin()) OR (user_id = (select auth.uid()))))
  with check (((select public.is_admin()) OR (user_id = (select auth.uid()))));

alter policy survey_questions_admin_write on public.survey_questions
  using ((select public.is_admin()))
  with check ((select public.is_admin()));

alter policy survey_questions_select_signed_in on public.survey_questions
  using ((select public.is_signed_in()));

alter policy survey_response_events_delete_admin on public.survey_response_events
  using ((select public.is_admin()));

alter policy survey_response_events_insert_owner on public.survey_response_events
  with check ((user_id = (select auth.uid())));

alter policy survey_response_events_select_admin_or_owner on public.survey_response_events
  using (((select public.is_admin()) OR (user_id = (select auth.uid()))));

alter policy survey_responses_delete_admin on public.survey_responses
  using ((select public.is_admin()));

alter policy survey_responses_insert_owner on public.survey_responses
  with check ((user_id = (select auth.uid())));

alter policy survey_responses_select_admin_or_owner on public.survey_responses
  using (((select public.is_admin()) OR (user_id = (select auth.uid()))));

alter policy survey_responses_update_owner on public.survey_responses
  using ((user_id = (select auth.uid())))
  with check ((user_id = (select auth.uid())));

alter policy survey_template_questions_admin_write on public.survey_template_questions
  using ((select public.is_admin()))
  with check ((select public.is_admin()));

alter policy survey_template_questions_select_signed_in on public.survey_template_questions
  using ((select public.is_signed_in()));

alter policy survey_templates_admin_write on public.survey_templates
  using ((select public.is_admin()))
  with check ((select public.is_admin()));

alter policy survey_templates_select_signed_in on public.survey_templates
  using ((select public.is_signed_in()));

alter policy surveys_delete_admin on public.surveys
  using ((select public.is_admin()));

alter policy surveys_insert_admin on public.surveys
  with check ((select public.is_admin()));

alter policy surveys_select_signed_in on public.surveys
  using ((select public.is_signed_in()));

alter policy surveys_update_admin on public.surveys
  using ((select public.is_admin()))
  with check ((select public.is_admin()));

alter policy tracer_draft_reminders_delete_own on public.tracer_draft_reminders
  using ((user_id = (select auth.uid())));

alter policy tracer_draft_reminders_insert_own on public.tracer_draft_reminders
  with check ((user_id = (select auth.uid())));

alter policy tracer_draft_reminders_select_own on public.tracer_draft_reminders
  using ((user_id = (select auth.uid())));

alter policy tracer_draft_reminders_update_own on public.tracer_draft_reminders
  using ((user_id = (select auth.uid())))
  with check ((user_id = (select auth.uid())));

alter policy user_notifications_delete_owner on public.user_notifications
  using ((user_id = (select auth.uid())));

alter policy user_notifications_insert_admin_or_owner on public.user_notifications
  with check (((select public.is_admin()) OR (user_id = (select auth.uid()))));

alter policy user_notifications_select_owner on public.user_notifications
  using ((user_id = (select auth.uid())));

alter policy user_notifications_update_delete_owner on public.user_notifications
  using ((user_id = (select auth.uid())))
  with check ((user_id = (select auth.uid())));

alter policy users_admin_write on public.users
  using ((select public.is_admin()))
  with check ((select public.is_admin()));

alter policy users_delete_admin_only on public.users
  using ((select public.is_admin()));

alter policy users_insert_self_user_role on public.users
  with check (((id = (select auth.uid())) AND (role = 'user'::text)));

alter policy users_select_owner_admin_or_admin_target on public.users
  using (((select public.is_signed_in()) and ((id = (select auth.uid())) OR (select public.is_admin()) OR (role = 'admin'::text))));

alter policy users_update_self_user_role on public.users
  using (((id = (select auth.uid())) OR (select public.is_admin())))
  with check ((((id = (select auth.uid())) AND (role = 'user'::text)) OR (select public.is_admin())));

-- ---------------------------------------------------------------------------
-- One permissive policy per table and command
-- ---------------------------------------------------------------------------
do $$
declare
  t text;
begin
  foreach t in array array[
    'announcements', 'forum_tags', 'notifications', 'programs',
    'survey_questions', 'survey_template_questions', 'survey_templates'
  ] loop
    execute format('drop policy if exists %I on public.%I',
      case t when 'notifications' then 'notifications_write_admin_only' else t || '_admin_write' end, t);
    execute format('drop policy if exists %I on public.%I', t || '_admin_insert', t);
    execute format('drop policy if exists %I on public.%I', t || '_admin_update', t);
    execute format('drop policy if exists %I on public.%I', t || '_admin_delete', t);
    execute format(
      'create policy %I on public.%I for insert to authenticated with check ((select public.is_admin()))',
      t || '_admin_insert', t);
    execute format(
      'create policy %I on public.%I for update to authenticated using ((select public.is_admin())) with check ((select public.is_admin()))',
      t || '_admin_update', t);
    execute format(
      'create policy %I on public.%I for delete to authenticated using ((select public.is_admin()))',
      t || '_admin_delete', t);
  end loop;
end;
$$;

-- users: select/update/delete policies already allow admins.
drop policy if exists users_admin_write on public.users;
alter policy users_insert_self_user_role on public.users
  with check ((((id = (select auth.uid())) and (role = 'user'::text)) or (select public.is_admin())));

-- event_rsvps: the select policy already covers admins.
drop policy if exists event_rsvps_admin_all on public.event_rsvps;
alter policy event_rsvps_insert_own on public.event_rsvps
  with check (((user_id = (select auth.uid())) or (select public.is_admin())));
alter policy event_rsvps_update_own on public.event_rsvps
  using (((user_id = (select auth.uid())) or (select public.is_admin())))
  with check (((user_id = (select auth.uid())) or (select public.is_admin())));
alter policy event_rsvps_delete_own on public.event_rsvps
  using (((user_id = (select auth.uid())) or (select public.is_admin())));

drop policy if exists job_interests_admin_delete on public.job_interests;
alter policy job_interests_delete_own on public.job_interests
  using (((user_id = (select auth.uid())) or (select public.is_admin())));

-- ---------------------------------------------------------------------------
-- Foreign key indexes
-- ---------------------------------------------------------------------------
create index if not exists idx_alumni_members_course on public.alumni_members (course);
create index if not exists idx_audit_logs_user_id on public.audit_logs (user_id);
create index if not exists idx_dss_flag_notes_author_id on public.dss_flag_notes (author_id);
create index if not exists idx_dss_flags_created_by on public.dss_flags (created_by);
create index if not exists idx_dss_flags_updated_by on public.dss_flags (updated_by);
create index if not exists idx_employment_records_verified_by on public.employment_records (verified_by);
create index if not exists idx_event_comments_user_id on public.event_comments (user_id);
create index if not exists idx_event_replies_event_id on public.event_replies (event_id);
create index if not exists idx_event_replies_user_id on public.event_replies (user_id);
create index if not exists idx_favorite_jobs_job_id on public.favorite_jobs (job_id);
create index if not exists idx_feedback_user_id on public.feedback (user_id);
create index if not exists idx_forum_helpful_reactions_post_id on public.forum_helpful_reactions (post_id);
create index if not exists idx_forum_moderation_events_actor_uid on public.forum_moderation_events (actor_uid);
create index if not exists idx_forum_posts_author_uid on public.forum_posts (author_uid);
create index if not exists idx_forum_posts_parent_post_id on public.forum_posts (parent_post_id);
create index if not exists idx_forum_posts_quoted_post_id on public.forum_posts (quoted_post_id);
create index if not exists idx_forum_reports_post_id on public.forum_reports (post_id);
create index if not exists idx_forum_reports_reporter_uid on public.forum_reports (reporter_uid);
create index if not exists idx_forum_reports_topic_id on public.forum_reports (topic_id);
create index if not exists idx_forum_topics_author_uid on public.forum_topics (author_uid);
create index if not exists idx_messages_recipient_id on public.messages (recipient_id);
create index if not exists idx_notification_push_deliveries_token_id on public.notification_push_deliveries (token_id);
create index if not exists idx_notification_push_deliveries_user_id on public.notification_push_deliveries (user_id);
create index if not exists idx_reminders_user_id on public.reminders (user_id);
create index if not exists idx_survey_response_events_response_id on public.survey_response_events (response_id);
create index if not exists idx_survey_response_events_user_id on public.survey_response_events (user_id);
create index if not exists idx_survey_responses_user_id on public.survey_responses (user_id);
create index if not exists idx_surveys_created_by on public.surveys (created_by);
create index if not exists idx_surveys_template_id on public.surveys (template_id);
create index if not exists idx_tracer_draft_reminders_survey_id on public.tracer_draft_reminders (survey_id);

-- Covered by event_rsvps_event_id_user_id_key and event_rsvps_status_idx.
drop index if exists public.event_rsvps_event_id_idx;

-- ---------------------------------------------------------------------------
-- Realtime: no screen listens to these
-- ---------------------------------------------------------------------------
do $$
declare
  t text;
begin
  foreach t in array array['forum_reports', 'forum_helpful_reactions'] loop
    if exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = t
    ) then
      execute format('alter publication supabase_realtime drop table public.%I', t);
    end if;
  end loop;
end;
$$;

notify pgrst, 'reload schema';
