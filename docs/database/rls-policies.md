# Row Level Security Policies and Grants

> Snapshot of the live schema in the linked Supabase project, taken 2026-10-05 with read-only queries. It contains structure only, no row data. Regenerate it from `queries/` instead of editing by hand; the migrations in `supabase/migrations` remain the source of truth.

129 policies across the `public` and `storage` schemas. `USING` decides which existing rows a role can see or change; `WITH CHECK` decides which new or updated rows it may write.


## public.alumni_members

| Policy | Command | Roles | USING | WITH CHECK |
|---|---|---|---|---|
| alumni_members_delete_admin_only | DELETE | authenticated | `( SELECT is_admin() AS is_admin)` |  |
| alumni_members_insert_admin_only | INSERT | authenticated |  | `( SELECT is_admin() AS is_admin)` |
| alumni_members_select_admin_or_owner | SELECT | authenticated | `(( SELECT is_admin() AS is_admin) OR (auth_uid = ( SELECT auth.uid() AS uid)))` |  |
| alumni_members_update_admin_or_owner | UPDATE | authenticated | `(( SELECT is_admin() AS is_admin) OR (auth_uid = ( SELECT auth.uid() AS uid)))` | `(( SELECT is_admin() AS is_admin) OR (auth_uid = ( SELECT auth.uid() AS uid)))` |

## public.announcements

| Policy | Command | Roles | USING | WITH CHECK |
|---|---|---|---|---|
| announcements_admin_delete | DELETE | authenticated | `( SELECT is_admin() AS is_admin)` |  |
| announcements_admin_insert | INSERT | authenticated |  | `( SELECT is_admin() AS is_admin)` |
| announcements_select_signed_in | SELECT | authenticated | `( SELECT is_signed_in() AS is_signed_in)` |  |
| announcements_admin_update | UPDATE | authenticated | `( SELECT is_admin() AS is_admin)` | `( SELECT is_admin() AS is_admin)` |

## public.audit_logs

| Policy | Command | Roles | USING | WITH CHECK |
|---|---|---|---|---|
| audit_logs_insert_own | INSERT | authenticated |  | `(user_id = ( SELECT auth.uid() AS uid))` |
| audit_logs_select_admin | SELECT | authenticated | `( SELECT is_admin() AS is_admin)` |  |

## public.dss_flag_checks

| Policy | Command | Roles | USING | WITH CHECK |
|---|---|---|---|---|
| dss_flag_checks_select_admin | SELECT | authenticated | `( SELECT is_admin() AS is_admin)` |  |

## public.dss_flag_notes

| Policy | Command | Roles | USING | WITH CHECK |
|---|---|---|---|---|
| dss_flag_notes_admin_all | ALL | authenticated | `( SELECT is_admin() AS is_admin)` | `( SELECT is_admin() AS is_admin)` |

## public.dss_flags

| Policy | Command | Roles | USING | WITH CHECK |
|---|---|---|---|---|
| dss_flags_admin_all | ALL | authenticated | `( SELECT is_admin() AS is_admin)` | `( SELECT is_admin() AS is_admin)` |

## public.dss_rules

| Policy | Command | Roles | USING | WITH CHECK |
|---|---|---|---|---|
| dss_rules_admin_all | ALL | authenticated | `( SELECT is_admin() AS is_admin)` | `( SELECT is_admin() AS is_admin)` |

## public.event_comments

| Policy | Command | Roles | USING | WITH CHECK |
|---|---|---|---|---|
| event_comments_delete_admin_or_author | DELETE | authenticated | `(( SELECT is_admin() AS is_admin) OR (user_id = ( SELECT auth.uid() AS uid)))` |  |
| event_comments_insert_own | INSERT | authenticated |  | `(user_id = ( SELECT auth.uid() AS uid))` |
| event_comments_select_signed_in | SELECT | authenticated | `( SELECT is_signed_in() AS is_signed_in)` |  |
| event_comments_update_admin_or_author | UPDATE | authenticated | `(( SELECT is_admin() AS is_admin) OR (user_id = ( SELECT auth.uid() AS uid)))` | `(( SELECT is_admin() AS is_admin) OR (user_id = ( SELECT auth.uid() AS uid)))` |

## public.event_replies

| Policy | Command | Roles | USING | WITH CHECK |
|---|---|---|---|---|
| event_replies_admin_delete | DELETE | authenticated | `( SELECT is_admin() AS is_admin)` |  |
| event_replies_admin_insert | INSERT | authenticated |  | `( SELECT is_admin() AS is_admin)` |
| event_replies_select_signed_in | SELECT | authenticated | `( SELECT is_signed_in() AS is_signed_in)` |  |
| event_replies_admin_update | UPDATE | authenticated | `( SELECT is_admin() AS is_admin)` | `( SELECT is_admin() AS is_admin)` |

## public.event_rsvps

| Policy | Command | Roles | USING | WITH CHECK |
|---|---|---|---|---|
| event_rsvps_delete_own | DELETE | authenticated | `((user_id = ( SELECT auth.uid() AS uid)) OR ( SELECT is_admin() AS is_admin))` |  |
| event_rsvps_insert_own | INSERT | authenticated |  | `((user_id = ( SELECT auth.uid() AS uid)) OR ( SELECT is_admin() AS is_admin))` |
| event_rsvps_select_signed_in | SELECT | authenticated | `( SELECT is_signed_in() AS is_signed_in)` |  |
| event_rsvps_update_own | UPDATE | authenticated | `((user_id = ( SELECT auth.uid() AS uid)) OR ( SELECT is_admin() AS is_admin))` | `((user_id = ( SELECT auth.uid() AS uid)) OR ( SELECT is_admin() AS is_admin))` |

## public.events

| Policy | Command | Roles | USING | WITH CHECK |
|---|---|---|---|---|
| events_admin_delete | DELETE | authenticated | `( SELECT is_admin() AS is_admin)` |  |
| events_admin_write | INSERT | authenticated |  | `( SELECT is_admin() AS is_admin)` |
| events_select_signed_in | SELECT | authenticated | `( SELECT is_signed_in() AS is_signed_in)` |  |
| events_admin_update | UPDATE | authenticated | `( SELECT is_admin() AS is_admin)` | `( SELECT is_admin() AS is_admin)` |

## public.favorite_jobs

| Policy | Command | Roles | USING | WITH CHECK |
|---|---|---|---|---|
| favorite_jobs_owner_rw | ALL | authenticated | `(user_id = ( SELECT auth.uid() AS uid))` | `(user_id = ( SELECT auth.uid() AS uid))` |

## public.feedback

| Policy | Command | Roles | USING | WITH CHECK |
|---|---|---|---|---|
| feedback_delete_admin_only | DELETE | authenticated | `( SELECT is_admin() AS is_admin)` |  |
| feedback_insert_owner_constraints | INSERT | authenticated |  | `((user_id = ( SELECT auth.uid() AS uid)) AND (status = 'submitted'::text) AND (length(message) >= 10))` |
| feedback_select_owner_or_admin | SELECT | authenticated | `(( SELECT is_admin() AS is_admin) OR (user_id = ( SELECT auth.uid() AS uid)))` |  |
| feedback_update_delete_admin_only | UPDATE | authenticated | `( SELECT is_admin() AS is_admin)` | `( SELECT is_admin() AS is_admin)` |

## public.forum_bookmarks

| Policy | Command | Roles | USING | WITH CHECK |
|---|---|---|---|---|
| forum_bookmarks_delete_own | DELETE | authenticated | `(user_id = ( SELECT auth.uid() AS uid))` |  |
| forum_bookmarks_insert_own | INSERT | authenticated |  | `(user_id = ( SELECT auth.uid() AS uid))` |
| forum_bookmarks_select_own | SELECT | authenticated | `(user_id = ( SELECT auth.uid() AS uid))` |  |

## public.forum_helpful_reactions

| Policy | Command | Roles | USING | WITH CHECK |
|---|---|---|---|---|
| forum_helpful_delete_own | DELETE | authenticated | `(user_id = ( SELECT auth.uid() AS uid))` |  |
| forum_helpful_insert_own | INSERT | authenticated |  | `(user_id = ( SELECT auth.uid() AS uid))` |
| forum_helpful_select_signed_in | SELECT | authenticated | `( SELECT is_signed_in() AS is_signed_in)` |  |

## public.forum_moderation_events

| Policy | Command | Roles | USING | WITH CHECK |
|---|---|---|---|---|
| forum_moderation_insert_admin | INSERT | authenticated |  | `(( SELECT is_admin() AS is_admin) AND (actor_uid = ( SELECT auth.uid() AS uid)))` |
| forum_moderation_select_admin | SELECT | authenticated | `( SELECT is_admin() AS is_admin)` |  |

## public.forum_posts

| Policy | Command | Roles | USING | WITH CHECK |
|---|---|---|---|---|
| forum_posts_delete_admin_or_author | DELETE | authenticated | `(( SELECT is_admin() AS is_admin) OR (author_uid = ( SELECT auth.uid() AS uid)))` |  |
| forum_posts_insert_author_when_unlocked | INSERT | authenticated |  | `((author_uid = ( SELECT auth.uid() AS uid)) AND (EXISTS ( SELECT 1 FROM forum_topics t WHERE ((t.id = forum_posts.topic_id) AND (t.is_locked = false)))))` |
| forum_posts_select_signed_in | SELECT | authenticated | `( SELECT is_signed_in() AS is_signed_in)` |  |
| forum_posts_update_admin_or_author | UPDATE | authenticated | `(( SELECT is_admin() AS is_admin) OR (author_uid = ( SELECT auth.uid() AS uid)))` | `(( SELECT is_admin() AS is_admin) OR (author_uid = ( SELECT auth.uid() AS uid)))` |

## public.forum_reports

| Policy | Command | Roles | USING | WITH CHECK |
|---|---|---|---|---|
| forum_reports_insert_own | INSERT | authenticated |  | `(reporter_uid = ( SELECT auth.uid() AS uid))` |
| forum_reports_select_admin_or_reporter | SELECT | authenticated | `(( SELECT is_admin() AS is_admin) OR (reporter_uid = ( SELECT auth.uid() AS uid)))` |  |
| forum_reports_admin_update | UPDATE | authenticated | `( SELECT is_admin() AS is_admin)` | `( SELECT is_admin() AS is_admin)` |

## public.forum_tags

| Policy | Command | Roles | USING | WITH CHECK |
|---|---|---|---|---|
| forum_tags_admin_delete | DELETE | authenticated | `( SELECT is_admin() AS is_admin)` |  |
| forum_tags_admin_insert | INSERT | authenticated |  | `( SELECT is_admin() AS is_admin)` |
| forum_tags_select_signed_in | SELECT | authenticated | `( SELECT is_signed_in() AS is_signed_in)` |  |
| forum_tags_admin_update | UPDATE | authenticated | `( SELECT is_admin() AS is_admin)` | `( SELECT is_admin() AS is_admin)` |

## public.forum_topic_tags

| Policy | Command | Roles | USING | WITH CHECK |
|---|---|---|---|---|
| forum_topic_tags_delete_author_or_admin | DELETE | authenticated | `(( SELECT is_admin() AS is_admin) OR (EXISTS ( SELECT 1 FROM forum_topics t WHERE ((t.id = forum_topic_tags.topic_id) AND (t.author_uid = ( SELECT auth.uid() AS uid))))))` |  |
| forum_topic_tags_insert_author_or_admin | INSERT | authenticated |  | `(( SELECT is_admin() AS is_admin) OR (EXISTS ( SELECT 1 FROM forum_topics t WHERE ((t.id = forum_topic_tags.topic_id) AND (t.author_uid = ( SELECT auth.uid() AS uid))))))` |
| forum_topic_tags_select_signed_in | SELECT | authenticated | `( SELECT is_signed_in() AS is_signed_in)` |  |

## public.forum_topics

| Policy | Command | Roles | USING | WITH CHECK |
|---|---|---|---|---|
| forum_topics_delete_admin_or_author | DELETE | authenticated | `(( SELECT is_admin() AS is_admin) OR (author_uid = ( SELECT auth.uid() AS uid)))` |  |
| forum_topics_insert_author | INSERT | authenticated |  | `(author_uid = ( SELECT auth.uid() AS uid))` |
| forum_topics_select_signed_in | SELECT | authenticated | `( SELECT is_signed_in() AS is_signed_in)` |  |
| forum_topics_update_admin_or_author | UPDATE | authenticated | `(( SELECT is_admin() AS is_admin) OR (author_uid = ( SELECT auth.uid() AS uid)))` | `(( SELECT is_admin() AS is_admin) OR (author_uid = ( SELECT auth.uid() AS uid)))` |

## public.gts_question_catalog

| Policy | Command | Roles | USING | WITH CHECK |
|---|---|---|---|---|
| gts_question_catalog_select_signed_in | SELECT | authenticated | `( SELECT is_signed_in() AS is_signed_in)` |  |

## public.job_interests

| Policy | Command | Roles | USING | WITH CHECK |
|---|---|---|---|---|
| job_interests_delete_own | DELETE | authenticated | `((user_id = ( SELECT auth.uid() AS uid)) OR ( SELECT is_admin() AS is_admin))` |  |
| job_interests_insert_own | INSERT | authenticated |  | `(user_id = ( SELECT auth.uid() AS uid))` |
| job_interests_select_own_or_admin | SELECT | authenticated | `(( SELECT is_admin() AS is_admin) OR (user_id = ( SELECT auth.uid() AS uid)))` |  |

## public.jobs

| Policy | Command | Roles | USING | WITH CHECK |
|---|---|---|---|---|
| jobs_admin_delete | DELETE | authenticated | `( SELECT is_admin() AS is_admin)` |  |
| jobs_admin_insert | INSERT | authenticated |  | `( SELECT is_admin() AS is_admin)` |
| jobs_select_signed_in | SELECT | authenticated | `( SELECT is_signed_in() AS is_signed_in)` |  |
| jobs_admin_update | UPDATE | authenticated | `( SELECT is_admin() AS is_admin)` | `( SELECT is_admin() AS is_admin)` |

## public.messages

| Policy | Command | Roles | USING | WITH CHECK |
|---|---|---|---|---|
| messages_delete_sender_or_admin | DELETE | authenticated | `(( SELECT is_admin() AS is_admin) OR (sender_id = ( SELECT auth.uid() AS uid)))` |  |
| messages_insert_participant | INSERT | authenticated |  | `((sender_id = ( SELECT auth.uid() AS uid)) AND (( SELECT is_admin() AS is_admin) OR (EXISTS ( SELECT 1 FROM users u WHERE ((u.id = messages.recipient_id) AND (u.role = 'admin'::text))))))` |
| messages_select_participant_or_admin | SELECT | authenticated | `(( SELECT is_admin() AS is_admin) OR (sender_id = ( SELECT auth.uid() AS uid)) OR (recipient_id = ( SELECT auth.uid() AS uid)))` |  |
| messages_update_participant_or_admin | UPDATE | authenticated | `(( SELECT is_admin() AS is_admin) OR (sender_id = ( SELECT auth.uid() AS uid)) OR (recipient_id = ( SELECT auth.uid() AS uid)))` | `(( SELECT is_admin() AS is_admin) OR (sender_id = ( SELECT auth.uid() AS uid)) OR (recipient_id = ( SELECT auth.uid() AS uid)))` |

## public.notification_deliveries

| Policy | Command | Roles | USING | WITH CHECK |
|---|---|---|---|---|
| notification_deliveries_admin_select | SELECT | authenticated | `( SELECT is_admin() AS is_admin)` |  |

## public.notification_preferences

| Policy | Command | Roles | USING | WITH CHECK |
|---|---|---|---|---|
| notification_preferences_insert_own | INSERT | public |  | `(user_id = ( SELECT auth.uid() AS uid))` |
| notification_preferences_select_own | SELECT | public | `(user_id = ( SELECT auth.uid() AS uid))` |  |
| notification_preferences_update_own | UPDATE | public | `(user_id = ( SELECT auth.uid() AS uid))` | `(user_id = ( SELECT auth.uid() AS uid))` |

## public.programs

| Policy | Command | Roles | USING | WITH CHECK |
|---|---|---|---|---|
| programs_admin_delete | DELETE | authenticated | `( SELECT is_admin() AS is_admin)` |  |
| programs_admin_insert | INSERT | authenticated |  | `( SELECT is_admin() AS is_admin)` |
| programs_select_all | SELECT | anon,authenticated | `true` |  |
| programs_admin_update | UPDATE | authenticated | `( SELECT is_admin() AS is_admin)` | `( SELECT is_admin() AS is_admin)` |

## public.push_tokens

| Policy | Command | Roles | USING | WITH CHECK |
|---|---|---|---|---|
| push_tokens_delete_own | DELETE | public | `(user_id = ( SELECT auth.uid() AS uid))` |  |
| push_tokens_select_own | SELECT | public | `(user_id = ( SELECT auth.uid() AS uid))` |  |

## public.survey_assignments

| Policy | Command | Roles | USING | WITH CHECK |
|---|---|---|---|---|
| survey_assignments_delete_admin | DELETE | authenticated | `( SELECT is_admin() AS is_admin)` |  |
| survey_assignments_insert_delete_admin | INSERT | authenticated |  | `( SELECT is_admin() AS is_admin)` |
| survey_assignments_select_owner_or_admin | SELECT | authenticated | `(( SELECT is_admin() AS is_admin) OR (user_id = ( SELECT auth.uid() AS uid)))` |  |
| survey_assignments_update_admin_or_owner | UPDATE | authenticated | `(( SELECT is_admin() AS is_admin) OR (user_id = ( SELECT auth.uid() AS uid)))` | `(( SELECT is_admin() AS is_admin) OR (user_id = ( SELECT auth.uid() AS uid)))` |

## public.survey_questions

| Policy | Command | Roles | USING | WITH CHECK |
|---|---|---|---|---|
| survey_questions_admin_delete | DELETE | authenticated | `( SELECT is_admin() AS is_admin)` |  |
| survey_questions_admin_insert | INSERT | authenticated |  | `( SELECT is_admin() AS is_admin)` |
| survey_questions_select_signed_in | SELECT | authenticated | `( SELECT is_signed_in() AS is_signed_in)` |  |
| survey_questions_admin_update | UPDATE | authenticated | `( SELECT is_admin() AS is_admin)` | `( SELECT is_admin() AS is_admin)` |

## public.survey_response_events

| Policy | Command | Roles | USING | WITH CHECK |
|---|---|---|---|---|
| survey_response_events_delete_admin | DELETE | authenticated | `( SELECT is_admin() AS is_admin)` |  |
| survey_response_events_insert_owner | INSERT | authenticated |  | `(user_id = ( SELECT auth.uid() AS uid))` |
| survey_response_events_select_admin_or_owner | SELECT | authenticated | `(( SELECT is_admin() AS is_admin) OR (user_id = ( SELECT auth.uid() AS uid)))` |  |

## public.survey_responses

| Policy | Command | Roles | USING | WITH CHECK |
|---|---|---|---|---|
| survey_responses_delete_admin | DELETE | authenticated | `( SELECT is_admin() AS is_admin)` |  |
| survey_responses_insert_owner | INSERT | authenticated |  | `(user_id = ( SELECT auth.uid() AS uid))` |
| survey_responses_select_admin_or_owner | SELECT | authenticated | `(( SELECT is_admin() AS is_admin) OR (user_id = ( SELECT auth.uid() AS uid)))` |  |
| survey_responses_update_owner | UPDATE | authenticated | `(user_id = ( SELECT auth.uid() AS uid))` | `(user_id = ( SELECT auth.uid() AS uid))` |

## public.survey_template_questions

| Policy | Command | Roles | USING | WITH CHECK |
|---|---|---|---|---|
| survey_template_questions_admin_delete | DELETE | authenticated | `( SELECT is_admin() AS is_admin)` |  |
| survey_template_questions_admin_insert | INSERT | authenticated |  | `( SELECT is_admin() AS is_admin)` |
| survey_template_questions_select_signed_in | SELECT | authenticated | `( SELECT is_signed_in() AS is_signed_in)` |  |
| survey_template_questions_admin_update | UPDATE | authenticated | `( SELECT is_admin() AS is_admin)` | `( SELECT is_admin() AS is_admin)` |

## public.survey_templates

| Policy | Command | Roles | USING | WITH CHECK |
|---|---|---|---|---|
| survey_templates_admin_delete | DELETE | authenticated | `( SELECT is_admin() AS is_admin)` |  |
| survey_templates_admin_insert | INSERT | authenticated |  | `( SELECT is_admin() AS is_admin)` |
| survey_templates_select_signed_in | SELECT | authenticated | `( SELECT is_signed_in() AS is_signed_in)` |  |
| survey_templates_admin_update | UPDATE | authenticated | `( SELECT is_admin() AS is_admin)` | `( SELECT is_admin() AS is_admin)` |

## public.surveys

| Policy | Command | Roles | USING | WITH CHECK |
|---|---|---|---|---|
| surveys_delete_admin | DELETE | authenticated | `( SELECT is_admin() AS is_admin)` |  |
| surveys_insert_admin | INSERT | authenticated |  | `( SELECT is_admin() AS is_admin)` |
| surveys_select_signed_in | SELECT | authenticated | `( SELECT is_signed_in() AS is_signed_in)` |  |
| surveys_update_admin | UPDATE | authenticated | `( SELECT is_admin() AS is_admin)` | `( SELECT is_admin() AS is_admin)` |

## public.tracer_draft_reminders

| Policy | Command | Roles | USING | WITH CHECK |
|---|---|---|---|---|
| tracer_draft_reminders_delete_own | DELETE | public | `(user_id = ( SELECT auth.uid() AS uid))` |  |
| tracer_draft_reminders_insert_own | INSERT | public |  | `(user_id = ( SELECT auth.uid() AS uid))` |
| tracer_draft_reminders_select_own | SELECT | public | `(user_id = ( SELECT auth.uid() AS uid))` |  |
| tracer_draft_reminders_update_own | UPDATE | public | `(user_id = ( SELECT auth.uid() AS uid))` | `(user_id = ( SELECT auth.uid() AS uid))` |

## public.user_notifications

| Policy | Command | Roles | USING | WITH CHECK |
|---|---|---|---|---|
| user_notifications_delete_owner | DELETE | authenticated | `(user_id = ( SELECT auth.uid() AS uid))` |  |
| user_notifications_select_owner | SELECT | authenticated | `(user_id = ( SELECT auth.uid() AS uid))` |  |
| user_notifications_update_delete_owner | UPDATE | authenticated | `(user_id = ( SELECT auth.uid() AS uid))` | `(user_id = ( SELECT auth.uid() AS uid))` |

## public.users

| Policy | Command | Roles | USING | WITH CHECK |
|---|---|---|---|---|
| users_delete_admin_only | DELETE | authenticated | `( SELECT is_admin() AS is_admin)` |  |
| users_insert_self_user_role | INSERT | authenticated |  | `(((id = ( SELECT auth.uid() AS uid)) AND (role = 'user'::text)) OR ( SELECT is_admin() AS is_admin))` |
| users_select_owner_admin_or_admin_target | SELECT | authenticated | `(( SELECT is_signed_in() AS is_signed_in) AND ((id = ( SELECT auth.uid() AS uid)) OR ( SELECT is_admin() AS is_admin) OR (role = 'admin'::text)))` |  |
| users_update_self_user_role | UPDATE | authenticated | `((id = ( SELECT auth.uid() AS uid)) OR ( SELECT is_admin() AS is_admin))` | `(((id = ( SELECT auth.uid() AS uid)) AND (role = 'user'::text)) OR ( SELECT is_admin() AS is_admin))` |

## storage.objects

| Policy | Command | Roles | USING | WITH CHECK |
|---|---|---|---|---|
| images_owner_delete | DELETE | authenticated | `((bucket_id = 'images'::text) AND (is_admin() OR (((storage.foldername(name))[1] = 'messages'::text) AND ((storage.foldername(name))[2] = (auth.uid())::text)) OR (((storage.foldername(name))[1] = 'avatars'::text) AND (name ~~ (('avatars/'::text \|\| (auth.uid())::text) \|\| '%'::text)))))` |  |
| message_attachments_delete_own_or_admin | DELETE | authenticated | `((bucket_id = 'message-attachments'::text) AND (((storage.foldername(name))[1] = (( SELECT auth.uid() AS uid))::text) OR ( SELECT is_admin() AS is_admin)))` |  |
| images_owner_insert | INSERT | authenticated |  | `((bucket_id = 'images'::text) AND (( SELECT is_admin() AS is_admin) OR (((storage.foldername(name))[1] = 'avatars'::text) AND (name ~~ (('avatars/'::text \|\| (( SELECT auth.uid() AS uid))::text) \|\| '%'::text)))))` |
| message_attachments_insert_own | INSERT | authenticated |  | `((bucket_id = 'message-attachments'::text) AND ((storage.foldername(name))[1] = (( SELECT auth.uid() AS uid))::text))` |
| images_public_read | SELECT | authenticated | `(bucket_id = 'images'::text)` |  |
| message_attachments_select_participants | SELECT | authenticated | `((bucket_id = 'message-attachments'::text) AND (((storage.foldername(name))[1] = (( SELECT auth.uid() AS uid))::text) OR ( SELECT is_admin() AS is_admin) OR (EXISTS ( SELECT 1 FROM messages m WHERE ((m.image_base64 = ('message-attachments/'::text \|\| objects.name)) AND (m.recipient_id = ( SELECT auth.uid() AS uid)))))))` |  |
| images_owner_update | UPDATE | authenticated | `((bucket_id = 'images'::text) AND (( SELECT is_admin() AS is_admin) OR (((storage.foldername(name))[1] = 'avatars'::text) AND (name ~~ (('avatars/'::text \|\| (( SELECT auth.uid() AS uid))::text) \|\| '%'::text)))))` | `((bucket_id = 'images'::text) AND (( SELECT is_admin() AS is_admin) OR (((storage.foldername(name))[1] = 'avatars'::text) AND (name ~~ (('avatars/'::text \|\| (( SELECT auth.uid() AS uid))::text) \|\| '%'::text)))))` |
| message_attachments_update_own | UPDATE | authenticated | `((bucket_id = 'message-attachments'::text) AND ((storage.foldername(name))[1] = (( SELECT auth.uid() AS uid))::text))` | `((bucket_id = 'message-attachments'::text) AND ((storage.foldername(name))[1] = (( SELECT auth.uid() AS uid))::text))` |

## Table grants

Table privileges held by the `anon` and `authenticated` roles. Row level security still filters every row these grants allow.

| Table | Role | Privileges |
|---|---|---|
| alumni_members | anon | DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE |
| alumni_members | authenticated | DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE |
| announcements | anon | DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE |
| announcements | authenticated | DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE |
| audit_logs | anon | INSERT, REFERENCES, SELECT, TRIGGER |
| audit_logs | authenticated | INSERT, REFERENCES, SELECT, TRIGGER |
| dss_flag_checks | authenticated | SELECT |
| dss_flag_notes | anon | DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE |
| dss_flag_notes | authenticated | DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE |
| dss_flags | anon | DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE |
| dss_flags | authenticated | DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE |
| dss_rules | anon | DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE |
| dss_rules | authenticated | DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE |
| event_comments | anon | DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE |
| event_comments | authenticated | DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE |
| event_replies | anon | DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE |
| event_replies | authenticated | DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE |
| event_rsvps | anon | DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE |
| event_rsvps | authenticated | DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE |
| events | anon | DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE |
| events | authenticated | DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE |
| favorite_jobs | anon | DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE |
| favorite_jobs | authenticated | DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE |
| feedback | anon | DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE |
| feedback | authenticated | DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE |
| forum_bookmarks | anon | DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE |
| forum_bookmarks | authenticated | DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE |
| forum_helpful_reactions | anon | DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE |
| forum_helpful_reactions | authenticated | DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE |
| forum_moderation_events | anon | DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE |
| forum_moderation_events | authenticated | DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE |
| forum_posts | anon | DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE |
| forum_posts | authenticated | DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE |
| forum_reports | anon | DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE |
| forum_reports | authenticated | DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE |
| forum_tags | anon | DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE |
| forum_tags | authenticated | DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE |
| forum_topic_tags | anon | DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE |
| forum_topic_tags | authenticated | DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE |
| forum_topics | anon | DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE |
| forum_topics | authenticated | DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE |
| gts_employment_records | authenticated | SELECT |
| gts_question_catalog | authenticated | SELECT |
| gts_respondent_facts | authenticated | SELECT |
| job_interests | anon | DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE |
| job_interests | authenticated | DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE |
| jobs | anon | DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE |
| jobs | authenticated | DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE |
| messages | anon | DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE |
| messages | authenticated | DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE |
| notification_deliveries | authenticated | SELECT |
| notification_preferences | anon | DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE |
| notification_preferences | authenticated | DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE |
| programs | anon | SELECT |
| programs | authenticated | DELETE, INSERT, SELECT, UPDATE |
| push_tokens | anon | DELETE, REFERENCES, SELECT, TRIGGER, TRUNCATE |
| push_tokens | authenticated | DELETE, REFERENCES, SELECT, TRIGGER, TRUNCATE |
| survey_assignments | anon | DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE |
| survey_assignments | authenticated | DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE |
| survey_questions | anon | DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE |
| survey_questions | authenticated | DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE |
| survey_response_events | anon | DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE |
| survey_response_events | authenticated | DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE |
| survey_responses | anon | DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE |
| survey_responses | authenticated | DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE |
| survey_template_questions | anon | DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE |
| survey_template_questions | authenticated | DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE |
| survey_templates | anon | DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE |
| survey_templates | authenticated | DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE |
| surveys | anon | DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE |
| surveys | authenticated | DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE |
| tracer_draft_reminders | anon | DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE |
| tracer_draft_reminders | authenticated | DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE |
| user_notifications | authenticated | DELETE, REFERENCES, SELECT, TRIGGER, TRUNCATE |
| users | anon | DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE |
| users | authenticated | DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE |
