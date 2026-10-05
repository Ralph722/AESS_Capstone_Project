# Constraints

> Snapshot of the live schema in the linked Supabase project, taken 2026-10-05 with read-only queries. It contains structure only, no row data. Regenerate it from `queries/` instead of editing by hand; the migrations in `supabase/migrations` remain the source of truth.

Primary keys, foreign keys (with their ON DELETE behaviour), unique and check constraints. 142 constraints in total.


## alumni_members

| Constraint | Kind | Definition |
|---|---|---|
| alumni_members_auth_uid_fkey | Foreign key | `FOREIGN KEY (auth_uid) REFERENCES auth.users(id) ON DELETE SET NULL` |
| alumni_members_pkey | Primary key | `PRIMARY KEY (id)` |

## announcements

| Constraint | Kind | Definition |
|---|---|---|
| announcements_status_check | Check | `CHECK ((status = ANY (ARRAY['draft'::text, 'published'::text, 'archived'::text])))` |
| announcements_pkey | Primary key | `PRIMARY KEY (id)` |

## audit_logs

| Constraint | Kind | Definition |
|---|---|---|
| audit_logs_user_id_fkey | Foreign key | `FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE SET NULL` |
| audit_logs_pkey | Primary key | `PRIMARY KEY (id)` |

## dss_flag_notes

| Constraint | Kind | Definition |
|---|---|---|
| dss_flag_notes_event_type_check | Check | `CHECK ((event_type = ANY (ARRAY['note'::text, 'status'::text, 'assign'::text, 'impact'::text, 'announcement'::text, 'reopen'::text, 'action'::text])))` |
| dss_flag_notes_author_id_fkey | Foreign key | `FOREIGN KEY (author_id) REFERENCES auth.users(id) ON DELETE SET NULL` |
| dss_flag_notes_flag_id_fkey | Foreign key | `FOREIGN KEY (flag_id) REFERENCES dss_flags(id) ON DELETE CASCADE` |
| dss_flag_notes_pkey | Primary key | `PRIMARY KEY (id)` |

## dss_flags

| Constraint | Kind | Definition |
|---|---|---|
| dss_flags_cohort_level_check | Check | `CHECK ((cohort_level = ANY (ARRAY['batch'::text, 'course'::text, 'institution'::text])))` |
| dss_flags_confidence_check | Check | `CHECK ((confidence = ANY (ARRAY['ok'::text, 'low'::text])))` |
| dss_flags_impact_verdict_check | Check | `CHECK (((impact_verdict IS NULL) OR (impact_verdict = ANY (ARRAY['improved'::text, 'unchanged'::text, 'still_flagged'::text, 'insufficient_data'::text]))))` |
| dss_flags_status_check | Check | `CHECK ((status = ANY (ARRAY['open'::text, 'in_progress'::text, 'resolved'::text, 'dismissed'::text])))` |
| dss_flags_assigned_to_fkey | Foreign key | `FOREIGN KEY (assigned_to) REFERENCES auth.users(id) ON DELETE SET NULL` |
| dss_flags_created_by_fkey | Foreign key | `FOREIGN KEY (created_by) REFERENCES auth.users(id) ON DELETE SET NULL` |
| dss_flags_rule_id_fkey | Foreign key | `FOREIGN KEY (rule_id) REFERENCES dss_rules(rule_id) ON DELETE RESTRICT` |
| dss_flags_updated_by_fkey | Foreign key | `FOREIGN KEY (updated_by) REFERENCES auth.users(id) ON DELETE SET NULL` |
| dss_flags_pkey | Primary key | `PRIMARY KEY (id)` |

## dss_rules

| Constraint | Kind | Definition |
|---|---|---|
| dss_rules_category_check | Check | `CHECK ((category = ANY (ARRAY['outcome'::text, 'data_quality'::text, 'opportunity'::text, 'trend'::text])))` |
| dss_rules_operator_check | Check | `CHECK ((operator = ANY (ARRAY['gte'::text, 'lte'::text, 'gt'::text, 'lt'::text])))` |
| dss_rules_severity_check | Check | `CHECK ((severity = ANY (ARRAY['info'::text, 'warning'::text, 'critical'::text])))` |
| dss_rules_pkey | Primary key | `PRIMARY KEY (rule_id)` |

## employment_records

| Constraint | Kind | Definition |
|---|---|---|
| employment_records_user_id_fkey | Foreign key | `FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE` |
| employment_records_verified_by_fkey | Foreign key | `FOREIGN KEY (verified_by) REFERENCES auth.users(id) ON DELETE SET NULL` |
| employment_records_pkey | Primary key | `PRIMARY KEY (id)` |

## event_comments

| Constraint | Kind | Definition |
|---|---|---|
| event_comments_event_id_fkey | Foreign key | `FOREIGN KEY (event_id) REFERENCES events(id) ON DELETE CASCADE` |
| event_comments_user_id_fkey | Foreign key | `FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE` |
| event_comments_pkey | Primary key | `PRIMARY KEY (id)` |

## event_replies

| Constraint | Kind | Definition |
|---|---|---|
| event_replies_comment_id_fkey | Foreign key | `FOREIGN KEY (comment_id) REFERENCES event_comments(id) ON DELETE CASCADE` |
| event_replies_event_id_fkey | Foreign key | `FOREIGN KEY (event_id) REFERENCES events(id) ON DELETE CASCADE` |
| event_replies_user_id_fkey | Foreign key | `FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE` |
| event_replies_pkey | Primary key | `PRIMARY KEY (id)` |

## event_rsvps

| Constraint | Kind | Definition |
|---|---|---|
| event_rsvps_status_check | Check | `CHECK ((status = ANY (ARRAY['going'::text, 'cant_attend'::text])))` |
| event_rsvps_event_id_fkey | Foreign key | `FOREIGN KEY (event_id) REFERENCES events(id) ON DELETE CASCADE` |
| event_rsvps_user_id_fkey | Foreign key | `FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE` |
| event_rsvps_pkey | Primary key | `PRIMARY KEY (id)` |
| event_rsvps_event_id_user_id_key | Unique | `UNIQUE (event_id, user_id)` |

## events

| Constraint | Kind | Definition |
|---|---|---|
| events_status_check | Check | `CHECK ((status = ANY (ARRAY['Active'::text, 'Archived'::text])))` |
| events_pkey | Primary key | `PRIMARY KEY (id)` |

## favorite_jobs

| Constraint | Kind | Definition |
|---|---|---|
| favorite_jobs_job_id_fkey | Foreign key | `FOREIGN KEY (job_id) REFERENCES jobs(id) ON DELETE CASCADE` |
| favorite_jobs_user_id_fkey | Foreign key | `FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE` |
| favorite_jobs_pkey | Primary key | `PRIMARY KEY (user_id, job_id)` |

## feedback

| Constraint | Kind | Definition |
|---|---|---|
| feedback_status_check | Check | `CHECK ((status = ANY (ARRAY['submitted'::text, 'inReview'::text, 'resolved'::text, 'closed'::text])))` |
| feedback_user_id_fkey | Foreign key | `FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE` |
| feedback_pkey | Primary key | `PRIMARY KEY (id)` |

## forum_bookmarks

| Constraint | Kind | Definition |
|---|---|---|
| forum_bookmarks_topic_id_fkey | Foreign key | `FOREIGN KEY (topic_id) REFERENCES forum_topics(id) ON DELETE CASCADE` |
| forum_bookmarks_user_id_fkey | Foreign key | `FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE` |
| forum_bookmarks_pkey | Primary key | `PRIMARY KEY (user_id, topic_id)` |

## forum_helpful_reactions

| Constraint | Kind | Definition |
|---|---|---|
| forum_helpful_reactions_post_id_fkey | Foreign key | `FOREIGN KEY (post_id) REFERENCES forum_posts(id) ON DELETE CASCADE` |
| forum_helpful_reactions_user_id_fkey | Foreign key | `FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE` |
| forum_helpful_reactions_pkey | Primary key | `PRIMARY KEY (user_id, post_id)` |

## forum_moderation_events

| Constraint | Kind | Definition |
|---|---|---|
| forum_moderation_events_actor_uid_fkey | Foreign key | `FOREIGN KEY (actor_uid) REFERENCES auth.users(id) ON DELETE CASCADE` |
| forum_moderation_events_topic_id_fkey | Foreign key | `FOREIGN KEY (topic_id) REFERENCES forum_topics(id) ON DELETE SET NULL` |
| forum_moderation_events_pkey | Primary key | `PRIMARY KEY (id)` |

## forum_posts

| Constraint | Kind | Definition |
|---|---|---|
| forum_posts_author_uid_fkey | Foreign key | `FOREIGN KEY (author_uid) REFERENCES auth.users(id) ON DELETE SET NULL` |
| forum_posts_parent_post_id_fkey | Foreign key | `FOREIGN KEY (parent_post_id) REFERENCES forum_posts(id) ON DELETE SET NULL` |
| forum_posts_quoted_post_id_fkey | Foreign key | `FOREIGN KEY (quoted_post_id) REFERENCES forum_posts(id) ON DELETE SET NULL` |
| forum_posts_topic_id_fkey | Foreign key | `FOREIGN KEY (topic_id) REFERENCES forum_topics(id) ON DELETE CASCADE` |
| forum_posts_pkey | Primary key | `PRIMARY KEY (id)` |

## forum_reports

| Constraint | Kind | Definition |
|---|---|---|
| forum_reports_status_check | Check | `CHECK ((status = ANY (ARRAY['open'::text, 'resolved'::text, 'dismissed'::text])))` |
| forum_reports_post_id_fkey | Foreign key | `FOREIGN KEY (post_id) REFERENCES forum_posts(id) ON DELETE SET NULL` |
| forum_reports_reporter_uid_fkey | Foreign key | `FOREIGN KEY (reporter_uid) REFERENCES auth.users(id) ON DELETE CASCADE` |
| forum_reports_topic_id_fkey | Foreign key | `FOREIGN KEY (topic_id) REFERENCES forum_topics(id) ON DELETE SET NULL` |
| forum_reports_pkey | Primary key | `PRIMARY KEY (id)` |

## forum_tags

| Constraint | Kind | Definition |
|---|---|---|
| forum_tags_pkey | Primary key | `PRIMARY KEY (id)` |
| forum_tags_slug_key | Unique | `UNIQUE (slug)` |

## forum_topic_tags

| Constraint | Kind | Definition |
|---|---|---|
| forum_topic_tags_tag_id_fkey | Foreign key | `FOREIGN KEY (tag_id) REFERENCES forum_tags(id) ON DELETE CASCADE` |
| forum_topic_tags_topic_id_fkey | Foreign key | `FOREIGN KEY (topic_id) REFERENCES forum_topics(id) ON DELETE CASCADE` |
| forum_topic_tags_pkey | Primary key | `PRIMARY KEY (topic_id, tag_id)` |

## forum_topics

| Constraint | Kind | Definition |
|---|---|---|
| forum_topics_author_uid_fkey | Foreign key | `FOREIGN KEY (author_uid) REFERENCES auth.users(id) ON DELETE SET NULL` |
| forum_topics_pkey | Primary key | `PRIMARY KEY (id)` |

## job_interests

| Constraint | Kind | Definition |
|---|---|---|
| job_interests_job_id_fkey | Foreign key | `FOREIGN KEY (job_id) REFERENCES jobs(id) ON DELETE CASCADE` |
| job_interests_user_id_fkey | Foreign key | `FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE` |
| job_interests_pkey | Primary key | `PRIMARY KEY (user_id, job_id)` |

## jobs

| Constraint | Kind | Definition |
|---|---|---|
| jobs_status_check | Check | `CHECK ((status = ANY (ARRAY['active'::text, 'expired'::text, 'closed'::text, 'archived'::text])))` |
| jobs_pkey | Primary key | `PRIMARY KEY (id)` |

## messages

| Constraint | Kind | Definition |
|---|---|---|
| messages_recipient_id_fkey | Foreign key | `FOREIGN KEY (recipient_id) REFERENCES auth.users(id) ON DELETE CASCADE` |
| messages_sender_id_fkey | Foreign key | `FOREIGN KEY (sender_id) REFERENCES auth.users(id) ON DELETE CASCADE` |
| messages_pkey | Primary key | `PRIMARY KEY (id)` |

## notification_preferences

| Constraint | Kind | Definition |
|---|---|---|
| notification_preferences_user_id_fkey | Foreign key | `FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE` |
| notification_preferences_pkey | Primary key | `PRIMARY KEY (user_id)` |

## notification_push_deliveries

| Constraint | Kind | Definition |
|---|---|---|
| notification_push_deliveries_status_check | Check | `CHECK ((status = ANY (ARRAY['queued'::text, 'sending'::text, 'sent'::text, 'failed'::text, 'skipped'::text])))` |
| notification_push_deliveries_notification_id_fkey | Foreign key | `FOREIGN KEY (notification_id) REFERENCES user_notifications(id) ON DELETE CASCADE` |
| notification_push_deliveries_token_id_fkey | Foreign key | `FOREIGN KEY (token_id) REFERENCES push_tokens(id) ON DELETE CASCADE` |
| notification_push_deliveries_user_id_fkey | Foreign key | `FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE` |
| notification_push_deliveries_pkey | Primary key | `PRIMARY KEY (id)` |
| notification_push_deliveries_notification_id_token_id_key | Unique | `UNIQUE (notification_id, token_id)` |

## notifications

| Constraint | Kind | Definition |
|---|---|---|
| notifications_user_id_fkey | Foreign key | `FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE` |
| notifications_pkey | Primary key | `PRIMARY KEY (id)` |

## push_tokens

| Constraint | Kind | Definition |
|---|---|---|
| push_tokens_device_label_check | Check | `CHECK (((device_label IS NULL) OR (length(device_label) <= 120)))` |
| push_tokens_platform_check | Check | `CHECK ((platform = ANY (ARRAY['web'::text, 'android'::text, 'ios'::text])))` |
| push_tokens_provider_check | Check | `CHECK ((provider = ANY (ARRAY['webpush'::text, 'fcm'::text])))` |
| push_tokens_token_check | Check | `CHECK (((length(token) >= 10) AND (length(token) <= 4096)))` |
| push_tokens_user_id_fkey | Foreign key | `FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE` |
| push_tokens_pkey | Primary key | `PRIMARY KEY (id)` |
| push_tokens_token_key | Unique | `UNIQUE (token)` |

## reminders

| Constraint | Kind | Definition |
|---|---|---|
| reminders_user_id_fkey | Foreign key | `FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE` |
| reminders_pkey | Primary key | `PRIMARY KEY (id)` |

## survey_assignments

| Constraint | Kind | Definition |
|---|---|---|
| survey_assignments_status_check | Check | `CHECK ((status = ANY (ARRAY['notStarted'::text, 'inProgress'::text, 'completed'::text])))` |
| survey_assignments_survey_id_fkey | Foreign key | `FOREIGN KEY (survey_id) REFERENCES surveys(id) ON DELETE CASCADE` |
| survey_assignments_user_id_fkey | Foreign key | `FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE RESTRICT` |
| survey_assignments_pkey | Primary key | `PRIMARY KEY (id)` |

## survey_questions

| Constraint | Kind | Definition |
|---|---|---|
| survey_questions_survey_id_fkey | Foreign key | `FOREIGN KEY (survey_id) REFERENCES surveys(id) ON DELETE CASCADE` |
| survey_questions_pkey | Primary key | `PRIMARY KEY (id)` |

## survey_response_events

| Constraint | Kind | Definition |
|---|---|---|
| survey_response_events_browser_family_check | Check | `CHECK (((browser_family IS NULL) OR (browser_family = ANY (ARRAY['chrome'::text, 'safari'::text, 'firefox'::text, 'edge'::text, 'opera'::text, 'other'::text, 'native'::text]))))` |
| survey_response_events_device_category_check | Check | `CHECK (((device_category IS NULL) OR (device_category = ANY (ARRAY['mobile'::text, 'tablet'::text, 'desktop'::text, 'other'::text]))))` |
| survey_response_events_event_type_check | Check | `CHECK ((event_type = ANY (ARRAY['opened'::text, 'draft_saved'::text, 'submitted'::text])))` |
| survey_response_events_platform_family_check | Check | `CHECK (((platform_family IS NULL) OR (platform_family = ANY (ARRAY['android'::text, 'ios'::text, 'web'::text, 'windows'::text, 'macos'::text, 'linux'::text, 'other'::text]))))` |
| survey_response_events_response_id_fkey | Foreign key | `FOREIGN KEY (response_id) REFERENCES survey_responses(id) ON DELETE SET NULL` |
| survey_response_events_survey_id_fkey | Foreign key | `FOREIGN KEY (survey_id) REFERENCES surveys(id) ON DELETE CASCADE` |
| survey_response_events_user_id_fkey | Foreign key | `FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE RESTRICT` |
| survey_response_events_pkey | Primary key | `PRIMARY KEY (id)` |

## survey_responses

| Constraint | Kind | Definition |
|---|---|---|
| survey_responses_browser_family_check | Check | `CHECK (((browser_family IS NULL) OR (browser_family = ANY (ARRAY['chrome'::text, 'safari'::text, 'firefox'::text, 'edge'::text, 'opera'::text, 'other'::text, 'native'::text]))))` |
| survey_responses_device_category_check | Check | `CHECK (((device_category IS NULL) OR (device_category = ANY (ARRAY['mobile'::text, 'tablet'::text, 'desktop'::text, 'other'::text]))))` |
| survey_responses_platform_family_check | Check | `CHECK (((platform_family IS NULL) OR (platform_family = ANY (ARRAY['android'::text, 'ios'::text, 'web'::text, 'windows'::text, 'macos'::text, 'linux'::text, 'other'::text]))))` |
| survey_responses_status_check | Check | `CHECK ((status = ANY (ARRAY['draft'::text, 'submitted'::text])))` |
| survey_responses_survey_id_fkey | Foreign key | `FOREIGN KEY (survey_id) REFERENCES surveys(id) ON DELETE CASCADE` |
| survey_responses_user_id_fkey | Foreign key | `FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE RESTRICT` |
| survey_responses_pkey | Primary key | `PRIMARY KEY (id)` |
| survey_responses_survey_id_user_id_key | Unique | `UNIQUE (survey_id, user_id)` |

## survey_template_questions

| Constraint | Kind | Definition |
|---|---|---|
| survey_template_questions_template_id_fkey | Foreign key | `FOREIGN KEY (template_id) REFERENCES survey_templates(id) ON DELETE CASCADE` |
| survey_template_questions_pkey | Primary key | `PRIMARY KEY (id)` |

## survey_templates

| Constraint | Kind | Definition |
|---|---|---|
| survey_templates_pkey | Primary key | `PRIMARY KEY (id)` |

## surveys

| Constraint | Kind | Definition |
|---|---|---|
| surveys_status_check | Check | `CHECK ((status = ANY (ARRAY['draft'::text, 'published'::text, 'closed'::text])))` |
| surveys_created_by_fkey | Foreign key | `FOREIGN KEY (created_by) REFERENCES auth.users(id) ON DELETE SET NULL` |
| surveys_template_id_fkey | Foreign key | `FOREIGN KEY (template_id) REFERENCES survey_templates(id)` |
| surveys_pkey | Primary key | `PRIMARY KEY (id)` |

## tracer_draft_reminders

| Constraint | Kind | Definition |
|---|---|---|
| tracer_draft_reminders_followups_check | Check | `CHECK (((followups_sent >= 0) AND (followups_sent <= 3)))` |
| tracer_draft_reminders_survey_id_fkey | Foreign key | `FOREIGN KEY (survey_id) REFERENCES surveys(id) ON DELETE CASCADE` |
| tracer_draft_reminders_user_id_fkey | Foreign key | `FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE` |
| tracer_draft_reminders_pkey | Primary key | `PRIMARY KEY (id)` |
| tracer_draft_reminders_user_survey_key | Unique | `UNIQUE (user_id, survey_id)` |

## tracer_help_usage

| Constraint | Kind | Definition |
|---|---|---|
| tracer_help_usage_count_check | Check | `CHECK ((count >= 0))` |
| tracer_help_usage_user_id_fkey | Foreign key | `FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE` |
| tracer_help_usage_pkey | Primary key | `PRIMARY KEY (user_id, used_on)` |

## user_notifications

| Constraint | Kind | Definition |
|---|---|---|
| user_notifications_priority_check | Check | `CHECK ((priority = ANY (ARRAY['low'::text, 'normal'::text, 'high'::text, 'urgent'::text])))` |
| user_notifications_user_id_fkey | Foreign key | `FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE` |
| user_notifications_pkey | Primary key | `PRIMARY KEY (id)` |

## users

| Constraint | Kind | Definition |
|---|---|---|
| users_role_check | Check | `CHECK ((role = ANY (ARRAY['user'::text, 'admin'::text])))` |
| users_id_fkey | Foreign key | `FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE` |
| users_pkey | Primary key | `PRIMARY KEY (id)` |
