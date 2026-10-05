# Indexes

> Snapshot of the live schema in the linked Supabase project, taken 2026-10-05 with read-only queries. It contains structure only, no row data. Regenerate it from `queries/` instead of editing by hand; the migrations in `supabase/migrations` remain the source of truth.

120 indexes, including the ones that back primary keys and unique constraints.


## alumni_members

| Index | Kind | Definition |
|---|---|---|
| alumni_members_auth_uid_key | UNIQUE | `btree (auth_uid) WHERE (auth_uid IS NOT NULL)` |
| alumni_members_pkey | PK | `btree (id)` |
| alumni_members_student_course_key | UNIQUE | `btree (normalize_student_id(student_id), COALESCE(normalize_course(course), upper(TRIM(BOTH FROM course)))) WHERE (normalize_student_id(student_id) <> ''::text)` |
| idx_alumni_members_course |  | `btree (course)` |

## announcements

| Index | Kind | Definition |
|---|---|---|
| announcements_pkey | PK | `btree (id)` |

## archived_employment_records

| Index | Kind | Definition |
|---|---|---|
| employment_records_pkey | PK | `btree (id)` |
| idx_employment_records_user |  | `btree (user_id)` |
| idx_employment_records_verified_by |  | `btree (verified_by)` |

## audit_logs

| Index | Kind | Definition |
|---|---|---|
| audit_logs_pkey | PK | `btree (id)` |
| idx_audit_logs_user_id |  | `btree (user_id)` |

## dss_flag_checks

| Index | Kind | Definition |
|---|---|---|
| dss_flag_checks_pkey | PK | `btree (flag_id)` |

## dss_flag_notes

| Index | Kind | Definition |
|---|---|---|
| dss_flag_notes_pkey | PK | `btree (id)` |
| idx_dss_flag_notes_author_id |  | `btree (author_id)` |
| idx_dss_flag_notes_flag |  | `btree (flag_id, created_at DESC)` |

## dss_flags

| Index | Kind | Definition |
|---|---|---|
| dss_flags_pkey | PK | `btree (id)` |
| idx_dss_flags_assigned |  | `btree (assigned_to) WHERE (assigned_to IS NOT NULL)` |
| idx_dss_flags_created_by |  | `btree (created_by)` |
| idx_dss_flags_rule |  | `btree (rule_id, created_at DESC)` |
| idx_dss_flags_status_created |  | `btree (status, created_at DESC)` |
| idx_dss_flags_updated_by |  | `btree (updated_by)` |
| idx_dss_flags_verify_due |  | `btree (verify_due_at) WHERE ((verify_due_at IS NOT NULL) AND (status = 'resolved'::text))` |
| uq_dss_flags_active_cohort | UNIQUE | `btree (rule_id, cohort_level, course, batch_year, survey_id) WHERE (status = ANY (ARRAY['open'::text, 'in_progress'::text]))` |

## dss_rules

| Index | Kind | Definition |
|---|---|---|
| dss_rules_pkey | PK | `btree (rule_id)` |

## event_comments

| Index | Kind | Definition |
|---|---|---|
| event_comments_pkey | PK | `btree (id)` |
| idx_event_comments_event |  | `btree (event_id)` |
| idx_event_comments_user_id |  | `btree (user_id)` |

## event_replies

| Index | Kind | Definition |
|---|---|---|
| event_replies_pkey | PK | `btree (id)` |
| idx_event_replies_comment |  | `btree (comment_id)` |
| idx_event_replies_event_id |  | `btree (event_id)` |
| idx_event_replies_user_id |  | `btree (user_id)` |

## event_rsvps

| Index | Kind | Definition |
|---|---|---|
| event_rsvps_event_id_user_id_key | UNIQUE | `btree (event_id, user_id)` |
| event_rsvps_pkey | PK | `btree (id)` |
| event_rsvps_status_idx |  | `btree (event_id, status)` |
| event_rsvps_user_id_idx |  | `btree (user_id)` |

## events

| Index | Kind | Definition |
|---|---|---|
| events_category_idx |  | `btree (category)` |
| events_date_status_idx |  | `btree (date, status)` |
| events_pkey | PK | `btree (id)` |

## favorite_jobs

| Index | Kind | Definition |
|---|---|---|
| favorite_jobs_pkey | PK | `btree (user_id, job_id)` |
| idx_favorite_jobs_job_id |  | `btree (job_id)` |

## feedback

| Index | Kind | Definition |
|---|---|---|
| feedback_pkey | PK | `btree (id)` |
| idx_feedback_user_id |  | `btree (user_id)` |

## forum_bookmarks

| Index | Kind | Definition |
|---|---|---|
| forum_bookmarks_pkey | PK | `btree (user_id, topic_id)` |
| idx_forum_bookmarks_topic |  | `btree (topic_id)` |

## forum_helpful_reactions

| Index | Kind | Definition |
|---|---|---|
| forum_helpful_reactions_pkey | PK | `btree (user_id, post_id)` |
| idx_forum_helpful_reactions_post_id |  | `btree (post_id)` |

## forum_moderation_events

| Index | Kind | Definition |
|---|---|---|
| forum_moderation_events_pkey | PK | `btree (id)` |
| idx_forum_moderation_events_actor_uid |  | `btree (actor_uid)` |
| idx_forum_moderation_topic |  | `btree (topic_id, created_at DESC)` |

## forum_posts

| Index | Kind | Definition |
|---|---|---|
| forum_posts_pkey | PK | `btree (id)` |
| idx_forum_posts_author_uid |  | `btree (author_uid)` |
| idx_forum_posts_parent_post_id |  | `btree (parent_post_id)` |
| idx_forum_posts_quoted_post_id |  | `btree (quoted_post_id)` |
| idx_forum_posts_topic |  | `btree (topic_id, created_at)` |

## forum_reports

| Index | Kind | Definition |
|---|---|---|
| forum_reports_pkey | PK | `btree (id)` |
| idx_forum_reports_post_id |  | `btree (post_id)` |
| idx_forum_reports_reporter_uid |  | `btree (reporter_uid)` |
| idx_forum_reports_topic_id |  | `btree (topic_id)` |

## forum_tags

| Index | Kind | Definition |
|---|---|---|
| forum_tags_pkey | PK | `btree (id)` |
| forum_tags_slug_key | UNIQUE | `btree (slug)` |

## forum_topic_tags

| Index | Kind | Definition |
|---|---|---|
| forum_topic_tags_pkey | PK | `btree (topic_id, tag_id)` |
| idx_forum_topic_tags_tag |  | `btree (tag_id)` |

## forum_topics

| Index | Kind | Definition |
|---|---|---|
| forum_topics_pkey | PK | `btree (id)` |
| idx_forum_topics_announcement |  | `btree (is_announcement) WHERE (is_announcement = true)` |
| idx_forum_topics_author_name |  | `gin (to_tsvector('english'::regconfig, ((((((COALESCE(title, ''::text) \|\| ' '::text) \|\| COALESCE(body, ''::text)) \|\| ' '::text) \|\| COALESCE(author_name, ''::text)) \|\| ' '::text) \|\| COALESCE(author_program, ''::text))))` |
| idx_forum_topics_author_uid |  | `btree (author_uid)` |
| idx_forum_topics_list |  | `btree (is_pinned DESC, last_reply_at DESC NULLS LAST, created_at DESC)` |
| idx_forum_topics_reply_count |  | `btree (reply_count DESC)` |
| idx_forum_topics_solved |  | `btree (is_solved) WHERE (is_solved = true)` |

## gts_question_catalog

| Index | Kind | Definition |
|---|---|---|
| gts_question_catalog_pkey | PK | `btree (schema_version, item_id)` |

## job_interests

| Index | Kind | Definition |
|---|---|---|
| idx_job_interests_job_id |  | `btree (job_id, created_at DESC)` |
| job_interests_pkey | PK | `btree (user_id, job_id)` |

## jobs

| Index | Kind | Definition |
|---|---|---|
| jobs_pkey | PK | `btree (id)` |

## messages

| Index | Kind | Definition |
|---|---|---|
| idx_messages_participants |  | `btree (sender_id, recipient_id, created_at DESC)` |
| idx_messages_recipient_id |  | `btree (recipient_id)` |
| messages_pkey | PK | `btree (id)` |

## notification_preferences

| Index | Kind | Definition |
|---|---|---|
| notification_preferences_pkey | PK | `btree (user_id)` |

## notification_push_deliveries

| Index | Kind | Definition |
|---|---|---|
| idx_notification_push_deliveries_token_id |  | `btree (token_id)` |
| idx_notification_push_deliveries_user_id |  | `btree (user_id)` |
| notification_push_deliveries_created_idx |  | `btree (created_at DESC)` |
| notification_push_deliveries_due_idx |  | `btree (scheduled_at) WHERE (status = ANY (ARRAY['queued'::text, 'sending'::text]))` |
| notification_push_deliveries_notification_id_token_id_key | UNIQUE | `btree (notification_id, token_id)` |
| notification_push_deliveries_pkey | PK | `btree (id)` |

## notifications

| Index | Kind | Definition |
|---|---|---|
| idx_notifications_user |  | `btree (user_id, created_at DESC)` |
| notifications_pkey | PK | `btree (id)` |

## programs

| Index | Kind | Definition |
|---|---|---|
| programs_pkey | PK | `btree (code)` |

## push_tokens

| Index | Kind | Definition |
|---|---|---|
| push_tokens_pkey | PK | `btree (id)` |
| push_tokens_token_key | UNIQUE | `btree (token)` |
| push_tokens_user_active_idx |  | `btree (user_id) WHERE (disabled_at IS NULL)` |

## reminders

| Index | Kind | Definition |
|---|---|---|
| idx_reminders_user_id |  | `btree (user_id)` |
| reminders_pkey | PK | `btree (id)` |

## survey_assignments

| Index | Kind | Definition |
|---|---|---|
| idx_survey_assignments_survey_user | UNIQUE | `btree (survey_id, user_id)` |
| idx_survey_assignments_user |  | `btree (user_id)` |
| survey_assignments_pkey | PK | `btree (id)` |

## survey_questions

| Index | Kind | Definition |
|---|---|---|
| idx_survey_questions_survey |  | `btree (survey_id, "order")` |
| survey_questions_pkey | PK | `btree (id)` |

## survey_response_events

| Index | Kind | Definition |
|---|---|---|
| idx_survey_response_events_response_id |  | `btree (response_id)` |
| idx_survey_response_events_survey_user_time |  | `btree (survey_id, user_id, created_at)` |
| idx_survey_response_events_user_id |  | `btree (user_id)` |
| survey_response_events_pkey | PK | `btree (id)` |

## survey_responses

| Index | Kind | Definition |
|---|---|---|
| idx_survey_responses_survey_status |  | `btree (survey_id, status)` |
| idx_survey_responses_user_id |  | `btree (user_id)` |
| survey_responses_pkey | PK | `btree (id)` |
| survey_responses_survey_id_user_id_key | UNIQUE | `btree (survey_id, user_id)` |

## survey_template_questions

| Index | Kind | Definition |
|---|---|---|
| idx_survey_template_questions_template |  | `btree (template_id, "order")` |
| survey_template_questions_pkey | PK | `btree (id)` |

## survey_templates

| Index | Kind | Definition |
|---|---|---|
| survey_templates_pkey | PK | `btree (id)` |

## surveys

| Index | Kind | Definition |
|---|---|---|
| idx_surveys_created_by |  | `btree (created_by)` |
| idx_surveys_template_id |  | `btree (template_id)` |
| surveys_pkey | PK | `btree (id)` |

## tracer_draft_reminders

| Index | Kind | Definition |
|---|---|---|
| idx_tracer_draft_reminders_survey_id |  | `btree (survey_id)` |
| tracer_draft_reminders_due_idx |  | `btree (remind_at) WHERE (cancelled_at IS NULL)` |
| tracer_draft_reminders_pkey | PK | `btree (id)` |
| tracer_draft_reminders_user_survey_key | UNIQUE | `btree (user_id, survey_id)` |

## tracer_help_usage

| Index | Kind | Definition |
|---|---|---|
| tracer_help_usage_pkey | PK | `btree (user_id, used_on)` |

## user_notifications

| Index | Kind | Definition |
|---|---|---|
| user_notifications_pkey | PK | `btree (id)` |
| user_notifications_user_created_idx |  | `btree (user_id, created_at DESC)` |
| user_notifications_user_dedupe_key | UNIQUE | `btree (user_id, dedupe_key)` |
| user_notifications_user_unread_idx |  | `btree (user_id) WHERE (is_read = false)` |

## users

| Index | Kind | Definition |
|---|---|---|
| users_email_lower_key | UNIQUE | `btree (lower(email)) WHERE (email <> ''::text)` |
| users_pkey | PK | `btree (id)` |
