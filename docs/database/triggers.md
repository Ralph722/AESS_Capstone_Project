# Triggers

> Snapshot of the live schema in the linked Supabase project, taken 2026-10-05 with read-only queries. It contains structure only, no row data. Regenerate it from `queries/` instead of editing by hand; the migrations in `supabase/migrations` remain the source of truth.

77 triggers on tables in the `public` and `auth` schemas.


## auth.users

| Trigger | Definition |
|---|---|
| on_auth_user_created | `AFTER INSERT OR UPDATE OF email_confirmed_at ON auth.users FOR EACH ROW EXECUTE FUNCTION handle_new_user()` |
| on_auth_user_email_changed | `AFTER UPDATE OF email ON auth.users FOR EACH ROW WHEN (((old.email)::text IS DISTINCT FROM (new.email)::text)) EXECUTE FUNCTION sync_user_email_from_auth()` |

## public.alumni_members

| Trigger | Definition |
|---|---|
| trg_alumni_members_guard_owner_update | `BEFORE UPDATE ON public.alumni_members FOR EACH ROW EXECUTE FUNCTION alumni_members_guard_owner_update()` |
| trg_alumni_members_normalize_year | `BEFORE INSERT OR UPDATE ON public.alumni_members FOR EACH ROW EXECUTE FUNCTION alumni_members_normalize_year()` |
| trg_alumni_members_sync_auth_ban | `AFTER UPDATE OF is_deactivated ON public.alumni_members FOR EACH ROW EXECUTE FUNCTION alumni_members_sync_auth_ban()` |
| trg_alumni_members_sync_user_identity | `AFTER INSERT OR UPDATE OF course, student_id, year_graduated, auth_uid ON public.alumni_members FOR EACH ROW EXECUTE FUNCTION alumni_members_sync_user_identity()` |
| trg_alumni_members_updated_at | `BEFORE UPDATE ON public.alumni_members FOR EACH ROW EXECUTE FUNCTION set_updated_at()` |

## public.announcements

| Trigger | Definition |
|---|---|
| trg_announcements_updated_at | `BEFORE UPDATE ON public.announcements FOR EACH ROW EXECUTE FUNCTION set_updated_at()` |
| trg_notify_announcement_published | `AFTER INSERT OR UPDATE OF status ON public.announcements FOR EACH ROW EXECUTE FUNCTION notify_announcement_published()` |

## public.audit_logs

| Trigger | Definition |
|---|---|
| trg_audit_logs_stamp_actor | `BEFORE INSERT ON public.audit_logs FOR EACH ROW EXECUTE FUNCTION audit_logs_stamp_actor()` |
| trg_audit_logs_updated_at | `BEFORE UPDATE ON public.audit_logs FOR EACH ROW EXECUTE FUNCTION set_updated_at()` |

## public.dss_flag_notes

| Trigger | Definition |
|---|---|
| trg_dss_flag_notes_stamp_author | `BEFORE INSERT ON public.dss_flag_notes FOR EACH ROW EXECUTE FUNCTION dss_flag_notes_stamp_author()` |

## public.dss_flags

| Trigger | Definition |
|---|---|
| trg_dss_flags_guard_status_transition | `BEFORE UPDATE OF status ON public.dss_flags FOR EACH ROW EXECUTE FUNCTION dss_flags_guard_status_transition()` |
| trg_dss_flags_updated_at | `BEFORE UPDATE ON public.dss_flags FOR EACH ROW EXECUTE FUNCTION set_updated_at()` |

## public.dss_rules

| Trigger | Definition |
|---|---|
| trg_dss_rules_updated_at | `BEFORE UPDATE ON public.dss_rules FOR EACH ROW EXECUTE FUNCTION set_updated_at()` |

## public.employment_records

| Trigger | Definition |
|---|---|
| trg_employment_owner_update | `BEFORE UPDATE ON public.employment_records FOR EACH ROW EXECUTE FUNCTION enforce_employment_owner_update()` |
| trg_employment_records_updated_at | `BEFORE UPDATE ON public.employment_records FOR EACH ROW EXECUTE FUNCTION set_updated_at()` |
| trg_notify_employment_verification | `AFTER UPDATE OF verification_status ON public.employment_records FOR EACH ROW EXECUTE FUNCTION notify_employment_verification()` |

## public.event_comments

| Trigger | Definition |
|---|---|
| trg_event_comments_updated_at | `BEFORE UPDATE ON public.event_comments FOR EACH ROW EXECUTE FUNCTION set_updated_at()` |
| trg_notify_admins_new_event_comment | `AFTER INSERT ON public.event_comments FOR EACH ROW EXECUTE FUNCTION notify_admins_new_event_comment()` |
| trg_sync_event_comments_count | `AFTER INSERT OR DELETE ON public.event_comments FOR EACH ROW EXECUTE FUNCTION sync_event_comments_count()` |

## public.event_replies

| Trigger | Definition |
|---|---|
| trg_event_replies_updated_at | `BEFORE UPDATE ON public.event_replies FOR EACH ROW EXECUTE FUNCTION set_updated_at()` |
| trg_notify_event_comment_reply | `AFTER INSERT ON public.event_replies FOR EACH ROW EXECUTE FUNCTION notify_event_comment_reply()` |

## public.events

| Trigger | Definition |
|---|---|
| trg_events_updated_at | `BEFORE UPDATE ON public.events FOR EACH ROW EXECUTE FUNCTION set_updated_at()` |
| trg_notify_event_changes | `AFTER INSERT OR UPDATE ON public.events FOR EACH ROW EXECUTE FUNCTION notify_event_changes()` |

## public.feedback

| Trigger | Definition |
|---|---|
| trg_feedback_updated_at | `BEFORE UPDATE ON public.feedback FOR EACH ROW EXECUTE FUNCTION set_updated_at()` |
| trg_notify_feedback_changes | `AFTER INSERT OR UPDATE ON public.feedback FOR EACH ROW EXECUTE FUNCTION notify_feedback_changes()` |

## public.forum_posts

| Trigger | Definition |
|---|---|
| trg_forum_posts_guard_author_update | `BEFORE UPDATE ON public.forum_posts FOR EACH ROW EXECUTE FUNCTION forum_posts_guard_author_update()` |
| trg_forum_posts_maintain_counts_del | `AFTER DELETE ON public.forum_posts FOR EACH ROW EXECUTE FUNCTION forum_posts_maintain_topic_counts()` |
| trg_forum_posts_maintain_counts_ins | `AFTER INSERT ON public.forum_posts FOR EACH ROW EXECUTE FUNCTION forum_posts_maintain_topic_counts()` |
| trg_notify_forum_topic_author_on_reply | `AFTER INSERT ON public.forum_posts FOR EACH ROW EXECUTE FUNCTION notify_forum_topic_author_on_reply()` |

## public.forum_reports

| Trigger | Definition |
|---|---|
| trg_forum_reports_updated_at | `BEFORE UPDATE ON public.forum_reports FOR EACH ROW EXECUTE FUNCTION set_updated_at()` |
| trg_notify_admins_forum_report | `AFTER INSERT ON public.forum_reports FOR EACH ROW EXECUTE FUNCTION notify_admins_forum_report()` |

## public.forum_topics

| Trigger | Definition |
|---|---|
| trg_forum_topics_guard_author_update | `BEFORE UPDATE ON public.forum_topics FOR EACH ROW EXECUTE FUNCTION forum_topics_guard_author_update()` |
| trg_forum_topics_guard_insert | `BEFORE INSERT ON public.forum_topics FOR EACH ROW EXECUTE FUNCTION forum_topics_guard_insert()` |
| trg_forum_topics_updated_at | `BEFORE UPDATE ON public.forum_topics FOR EACH ROW EXECUTE FUNCTION set_updated_at()` |
| trg_notify_forum_topic_moderation | `AFTER UPDATE OF is_locked, is_pinned ON public.forum_topics FOR EACH ROW EXECUTE FUNCTION notify_forum_topic_moderation()` |
| trg_notify_forum_topic_removed | `AFTER DELETE ON public.forum_topics FOR EACH ROW EXECUTE FUNCTION notify_forum_topic_removed()` |

## public.jobs

| Trigger | Definition |
|---|---|
| trg_jobs_sync_columns | `BEFORE INSERT OR UPDATE ON public.jobs FOR EACH ROW EXECUTE FUNCTION jobs_sync_columns()` |
| trg_jobs_updated_at | `BEFORE UPDATE ON public.jobs FOR EACH ROW EXECUTE FUNCTION set_updated_at()` |
| trg_notify_job_changes | `AFTER INSERT OR UPDATE ON public.jobs FOR EACH ROW EXECUTE FUNCTION notify_job_changes()` |

## public.messages

| Trigger | Definition |
|---|---|
| trg_messages_enforce_insert | `BEFORE INSERT ON public.messages FOR EACH ROW EXECUTE FUNCTION enforce_message_insert()` |
| trg_messages_enforce_update | `BEFORE UPDATE ON public.messages FOR EACH ROW EXECUTE FUNCTION enforce_message_update()` |
| trg_messages_set_edited_at | `BEFORE UPDATE ON public.messages FOR EACH ROW EXECUTE FUNCTION messages_set_edited_at()` |
| trg_messages_updated_at | `BEFORE UPDATE ON public.messages FOR EACH ROW EXECUTE FUNCTION set_updated_at()` |
| trg_notify_message_recipient | `AFTER INSERT ON public.messages FOR EACH ROW EXECUTE FUNCTION notify_message_recipient()` |

## public.notification_preferences

| Trigger | Definition |
|---|---|
| trg_notification_preferences_updated_at | `BEFORE UPDATE ON public.notification_preferences FOR EACH ROW EXECUTE FUNCTION set_updated_at()` |

## public.notifications

| Trigger | Definition |
|---|---|
| trg_notifications_updated_at | `BEFORE UPDATE ON public.notifications FOR EACH ROW EXECUTE FUNCTION set_updated_at()` |

## public.reminders

| Trigger | Definition |
|---|---|
| trg_reminders_updated_at | `BEFORE UPDATE ON public.reminders FOR EACH ROW EXECUTE FUNCTION set_updated_at()` |

## public.survey_assignments

| Trigger | Definition |
|---|---|
| trg_assignment_owner_update | `BEFORE UPDATE ON public.survey_assignments FOR EACH ROW EXECUTE FUNCTION enforce_assignment_owner_update()` |
| trg_notify_survey_assignment_created | `AFTER INSERT ON public.survey_assignments FOR EACH ROW EXECUTE FUNCTION notify_survey_assignment_created()` |
| trg_survey_assignments_recount_del | `AFTER DELETE ON public.survey_assignments REFERENCING OLD TABLE AS old_rows FOR EACH STATEMENT EXECUTE FUNCTION survey_children_recount()` |
| trg_survey_assignments_recount_ins | `AFTER INSERT ON public.survey_assignments REFERENCING NEW TABLE AS new_rows FOR EACH STATEMENT EXECUTE FUNCTION survey_children_recount()` |
| trg_survey_assignments_updated_at | `BEFORE UPDATE ON public.survey_assignments FOR EACH ROW EXECUTE FUNCTION set_updated_at()` |

## public.survey_questions

| Trigger | Definition |
|---|---|
| trg_survey_questions_updated_at | `BEFORE UPDATE ON public.survey_questions FOR EACH ROW EXECUTE FUNCTION set_updated_at()` |

## public.survey_responses

| Trigger | Definition |
|---|---|
| trg_notify_survey_submitted | `AFTER INSERT OR UPDATE OF status ON public.survey_responses FOR EACH ROW EXECUTE FUNCTION notify_survey_submitted()` |
| trg_survey_responses_guard_owner_update | `BEFORE UPDATE ON public.survey_responses FOR EACH ROW EXECUTE FUNCTION survey_responses_guard_owner_update()` |
| trg_survey_responses_recount_del | `AFTER DELETE ON public.survey_responses REFERENCING OLD TABLE AS old_rows FOR EACH STATEMENT EXECUTE FUNCTION survey_children_recount()` |
| trg_survey_responses_recount_ins | `AFTER INSERT ON public.survey_responses REFERENCING NEW TABLE AS new_rows FOR EACH STATEMENT EXECUTE FUNCTION survey_children_recount()` |
| trg_survey_responses_recount_upd | `AFTER UPDATE ON public.survey_responses REFERENCING OLD TABLE AS old_rows NEW TABLE AS new_rows FOR EACH STATEMENT EXECUTE FUNCTION survey_children_recount()` |
| trg_survey_responses_updated_at | `BEFORE UPDATE ON public.survey_responses FOR EACH ROW EXECUTE FUNCTION set_updated_at()` |

## public.survey_template_questions

| Trigger | Definition |
|---|---|
| trg_survey_template_questions_updated_at | `BEFORE UPDATE ON public.survey_template_questions FOR EACH ROW EXECUTE FUNCTION set_updated_at()` |

## public.survey_templates

| Trigger | Definition |
|---|---|
| trg_survey_templates_updated_at | `BEFORE UPDATE ON public.survey_templates FOR EACH ROW EXECUTE FUNCTION set_updated_at()` |

## public.surveys

| Trigger | Definition |
|---|---|
| trg_notify_survey_published | `AFTER UPDATE OF status ON public.surveys FOR EACH ROW EXECUTE FUNCTION notify_survey_published()` |
| trg_surveys_block_delete_with_submissions | `BEFORE DELETE ON public.surveys FOR EACH ROW EXECUTE FUNCTION surveys_block_delete_with_submissions()` |
| trg_surveys_guard_counters | `BEFORE INSERT OR UPDATE ON public.surveys FOR EACH ROW EXECUTE FUNCTION surveys_guard_counters()` |
| trg_surveys_updated_at | `BEFORE UPDATE ON public.surveys FOR EACH ROW EXECUTE FUNCTION set_updated_at()` |

## public.tracer_draft_reminders

| Trigger | Definition |
|---|---|
| trg_tracer_draft_reminders_updated_at | `BEFORE UPDATE ON public.tracer_draft_reminders FOR EACH ROW EXECUTE FUNCTION set_updated_at()` |

## public.user_notifications

| Trigger | Definition |
|---|---|
| trg_kick_notification_push | `AFTER INSERT ON public.user_notifications FOR EACH STATEMENT EXECUTE FUNCTION kick_notification_push()` |
| trg_queue_notification_push | `AFTER INSERT ON public.user_notifications FOR EACH ROW EXECUTE FUNCTION queue_notification_push()` |
| trg_user_notifications_track_read | `BEFORE UPDATE OF is_read ON public.user_notifications FOR EACH ROW EXECUTE FUNCTION user_notifications_track_read()` |
| trg_user_notifications_updated_at | `BEFORE UPDATE ON public.user_notifications FOR EACH ROW EXECUTE FUNCTION set_updated_at()` |

## public.users

| Trigger | Definition |
|---|---|
| trg_notify_admins_new_registration | `AFTER INSERT ON public.users FOR EACH ROW EXECUTE FUNCTION notify_admins_new_registration()` |
| trg_users_auto_assign_surveys | `AFTER INSERT OR UPDATE OF program, batch_year, year_graduated, role ON public.users FOR EACH ROW EXECUTE FUNCTION trg_users_auto_assign_surveys()` |
| trg_users_fill_roster_year | `AFTER INSERT OR UPDATE OF year_graduated ON public.users FOR EACH ROW EXECUTE FUNCTION users_fill_roster_year()` |
| trg_users_guard_protected_columns | `BEFORE INSERT OR UPDATE ON public.users FOR EACH ROW EXECUTE FUNCTION users_guard_protected_columns()` |
| trg_users_updated_at | `BEFORE UPDATE ON public.users FOR EACH ROW EXECUTE FUNCTION set_updated_at()` |
