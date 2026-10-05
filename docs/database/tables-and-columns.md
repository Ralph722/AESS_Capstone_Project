# Tables and Columns

> Snapshot of the live schema in the linked Supabase project, taken 2026-10-05 with read-only queries. It contains structure only, no row data. Regenerate it from `queries/` instead of editing by hand; the migrations in `supabase/migrations` remain the source of truth.

Public schema: 43 tables, 475 columns.

| Table | Columns | Row level security |
|---|---|---|
| [alumni_members](#alumni_members) | 26 | enabled=true, forced=false |
| [announcements](#announcements) | 8 | enabled=true, forced=false |
| [archived_employment_records](#archived_employment_records) | 13 | enabled=true, forced=false |
| [audit_logs](#audit_logs) | 8 | enabled=true, forced=false |
| [dss_flag_checks](#dss_flag_checks) | 11 | enabled=true, forced=false |
| [dss_flag_notes](#dss_flag_notes) | 10 | enabled=true, forced=false |
| [dss_flags](#dss_flags) | 32 | enabled=true, forced=false |
| [dss_rules](#dss_rules) | 15 | enabled=true, forced=false |
| [event_comments](#event_comments) | 6 | enabled=true, forced=false |
| [event_replies](#event_replies) | 7 | enabled=true, forced=false |
| [event_rsvps](#event_rsvps) | 6 | enabled=true, forced=false |
| [events](#events) | 21 | enabled=true, forced=false |
| [favorite_jobs](#favorite_jobs) | 3 | enabled=true, forced=false |
| [feedback](#feedback) | 8 | enabled=true, forced=false |
| [forum_bookmarks](#forum_bookmarks) | 3 | enabled=true, forced=false |
| [forum_helpful_reactions](#forum_helpful_reactions) | 3 | enabled=true, forced=false |
| [forum_moderation_events](#forum_moderation_events) | 7 | enabled=true, forced=false |
| [forum_posts](#forum_posts) | 11 | enabled=true, forced=false |
| [forum_reports](#forum_reports) | 8 | enabled=true, forced=false |
| [forum_tags](#forum_tags) | 5 | enabled=true, forced=false |
| [forum_topic_tags](#forum_topic_tags) | 2 | enabled=true, forced=false |
| [forum_topics](#forum_topics) | 19 | enabled=true, forced=false |
| [gts_question_catalog](#gts_question_catalog) | 16 | enabled=true, forced=false |
| [job_interests](#job_interests) | 3 | enabled=true, forced=false |
| [jobs](#jobs) | 10 | enabled=true, forced=false |
| [messages](#messages) | 15 | enabled=true, forced=false |
| [notification_preferences](#notification_preferences) | 9 | enabled=true, forced=false |
| [notification_push_deliveries](#notification_push_deliveries) | 11 | enabled=true, forced=false |
| [notifications](#notifications) | 9 | enabled=true, forced=false |
| [programs](#programs) | 5 | enabled=true, forced=false |
| [push_tokens](#push_tokens) | 12 | enabled=true, forced=false |
| [reminders](#reminders) | 9 | enabled=true, forced=false |
| [survey_assignments](#survey_assignments) | 10 | enabled=true, forced=false |
| [survey_questions](#survey_questions) | 15 | enabled=true, forced=false |
| [survey_response_events](#survey_response_events) | 10 | enabled=true, forced=false |
| [survey_responses](#survey_responses) | 13 | enabled=true, forced=false |
| [survey_template_questions](#survey_template_questions) | 15 | enabled=true, forced=false |
| [survey_templates](#survey_templates) | 7 | enabled=true, forced=false |
| [surveys](#surveys) | 16 | enabled=true, forced=false |
| [tracer_draft_reminders](#tracer_draft_reminders) | 10 | enabled=true, forced=false |
| [tracer_help_usage](#tracer_help_usage) | 4 | enabled=true, forced=false |
| [user_notifications](#user_notifications) | 15 | enabled=true, forced=false |
| [users](#users) | 29 | enabled=true, forced=false |

## alumni_members

| Column | Type | Not null | Default | Generated |
|---|---|---|---|---|
| id | uuid | yes | `gen_random_uuid()` |  |
| full_name | text | yes | `''::text` |  |
| course | text | yes | `''::text` |  |
| student_id | text | yes | `''::text` |  |
| auth_uid | uuid |  |  |  |
| registered_email | text |  |  |  |
| is_registered_user | boolean | yes | `false` |  |
| is_deactivated | boolean | yes | `false` |  |
| profile_image_url | text |  |  |  |
| last_active_at | timestamp with time zone |  |  |  |
| has_profile_updates | boolean | yes | `false` |  |
| admin_viewed_at | timestamp with time zone |  |  |  |
| batch_year | text | yes | `''::text` |  |
| contact_number | text | yes | `''::text` |  |
| email_address | text | yes | `''::text` |  |
| current_position | text |  |  |  |
| current_company | text |  |  |  |
| address | text |  |  |  |
| gender | text |  |  |  |
| civil_status | text |  |  |  |
| birth_date | date |  |  |  |
| year_graduated | text |  |  |  |
| tracer_profile_complete | boolean | yes | `false` |  |
| employment_status | text |  |  |  |
| created_at | timestamp with time zone | yes | `now()` |  |
| updated_at | timestamp with time zone | yes | `now()` |  |

## announcements

| Column | Type | Not null | Default | Generated |
|---|---|---|---|---|
| id | uuid | yes | `gen_random_uuid()` |  |
| title | text | yes | `''::text` |  |
| body | text | yes | `''::text` |  |
| status | text | yes | `'draft'::text` |  |
| published_at | timestamp with time zone |  |  |  |
| data | jsonb | yes | `'{}'::jsonb` |  |
| created_at | timestamp with time zone | yes | `now()` |  |
| updated_at | timestamp with time zone | yes | `now()` |  |

## archived_employment_records

| Column | Type | Not null | Default | Generated |
|---|---|---|---|---|
| id | uuid | yes | `gen_random_uuid()` |  |
| user_id | uuid | yes |  |  |
| status | text | yes | `''::text` |  |
| company | text | yes | `''::text` |  |
| position | text | yes | `''::text` |  |
| start_date | date |  |  |  |
| end_date | date |  |  |  |
| data | jsonb | yes | `'{}'::jsonb` |  |
| verification_status | text | yes | `'Pending'::text` |  |
| verified_by | uuid |  |  |  |
| verified_at | timestamp with time zone |  |  |  |
| created_at | timestamp with time zone | yes | `now()` |  |
| updated_at | timestamp with time zone | yes | `now()` |  |

## audit_logs

| Column | Type | Not null | Default | Generated |
|---|---|---|---|---|
| id | uuid | yes | `gen_random_uuid()` |  |
| user_id | uuid |  |  |  |
| action | text | yes | `''::text` |  |
| entity_type | text | yes | `''::text` |  |
| entity_id | text | yes | `''::text` |  |
| details | jsonb | yes | `'{}'::jsonb` |  |
| created_at | timestamp with time zone | yes | `now()` |  |
| updated_at | timestamp with time zone | yes | `now()` |  |

## dss_flag_checks

| Column | Type | Not null | Default | Generated |
|---|---|---|---|---|
| flag_id | uuid | yes |  |  |
| metric_key | text | yes |  |  |
| metric_version | integer | yes |  |  |
| checked_at | timestamp with time zone | yes | `now()` |  |
| metric_value | numeric |  |  |  |
| hits | integer |  |  |  |
| total | integer |  |  |  |
| sample_n | integer | yes | `0` |  |
| eligible_n | integer |  |  |  |
| state | text | yes |  |  |
| recovered_since | timestamp with time zone |  |  |  |

## dss_flag_notes

| Column | Type | Not null | Default | Generated |
|---|---|---|---|---|
| id | uuid | yes | `gen_random_uuid()` |  |
| flag_id | uuid | yes |  |  |
| author_id | uuid |  |  |  |
| author_name | text | yes | `''::text` |  |
| note | text | yes | `''::text` |  |
| status_from | text |  |  |  |
| status_to | text |  |  |  |
| created_at | timestamp with time zone | yes | `now()` |  |
| event_type | text | yes | `'note'::text` |  |
| metadata | jsonb | yes | `'{}'::jsonb` |  |

## dss_flags

| Column | Type | Not null | Default | Generated |
|---|---|---|---|---|
| id | uuid | yes | `gen_random_uuid()` |  |
| rule_id | text | yes |  |  |
| course | text | yes | `''::text` |  |
| batch_year | text | yes | `''::text` |  |
| survey_id | text | yes | `''::text` |  |
| survey_title | text | yes | `''::text` |  |
| metric_value | numeric | yes |  |  |
| threshold_snapshot | numeric | yes |  |  |
| sample_n | integer | yes | `0` |  |
| eligible_n | integer |  |  |  |
| confidence | text | yes | `'ok'::text` |  |
| status | text | yes | `'open'::text` |  |
| title | text | yes |  |  |
| body | text | yes | `''::text` |  |
| recommended_action | text | yes | `''::text` |  |
| evidence | jsonb | yes | `'{}'::jsonb` |  |
| baseline_value | numeric |  |  |  |
| followup_value | numeric |  |  |  |
| followup_at | timestamp with time zone |  |  |  |
| intervention_type | text |  |  |  |
| assigned_to | uuid |  |  |  |
| created_by | uuid |  |  |  |
| updated_by | uuid |  |  |  |
| created_at | timestamp with time zone | yes | `now()` |  |
| updated_at | timestamp with time zone | yes | `now()` |  |
| resolved_at | timestamp with time zone |  |  |  |
| verify_due_at | timestamp with time zone |  |  |  |
| impact_verdict | text |  |  |  |
| intervention_detail | text |  |  |  |
| linked_announcement_id | text |  |  |  |
| followup_sample_n | integer |  |  |  |
| cohort_level | text | yes | `'batch'::text` |  |

## dss_rules

| Column | Type | Not null | Default | Generated |
|---|---|---|---|---|
| rule_id | text | yes |  |  |
| name | text | yes |  |  |
| description | text | yes | `''::text` |  |
| metric_key | text | yes |  |  |
| operator | text | yes | `'gte'::text` |  |
| threshold | numeric | yes |  |  |
| min_n | integer | yes | `20` |  |
| enabled | boolean | yes | `true` |  |
| severity | text | yes | `'warning'::text` |  |
| recommended_action | text | yes | `''::text` |  |
| playbook | jsonb | yes | `'[]'::jsonb` |  |
| category | text | yes | `'outcome'::text` |  |
| sort_order | integer | yes | `100` |  |
| created_at | timestamp with time zone | yes | `now()` |  |
| updated_at | timestamp with time zone | yes | `now()` |  |

## event_comments

| Column | Type | Not null | Default | Generated |
|---|---|---|---|---|
| id | uuid | yes | `gen_random_uuid()` |  |
| event_id | uuid | yes |  |  |
| user_id | uuid | yes |  |  |
| body | text | yes | `''::text` |  |
| created_at | timestamp with time zone | yes | `now()` |  |
| updated_at | timestamp with time zone | yes | `now()` |  |

## event_replies

| Column | Type | Not null | Default | Generated |
|---|---|---|---|---|
| id | uuid | yes | `gen_random_uuid()` |  |
| event_id | uuid | yes |  |  |
| comment_id | uuid | yes |  |  |
| user_id | uuid | yes |  |  |
| body | text | yes | `''::text` |  |
| created_at | timestamp with time zone | yes | `now()` |  |
| updated_at | timestamp with time zone | yes | `now()` |  |

## event_rsvps

| Column | Type | Not null | Default | Generated |
|---|---|---|---|---|
| id | uuid | yes | `gen_random_uuid()` |  |
| event_id | uuid | yes |  |  |
| user_id | uuid | yes |  |  |
| status | text | yes |  |  |
| created_at | timestamp with time zone | yes | `now()` |  |
| updated_at | timestamp with time zone | yes | `now()` |  |

## events

| Column | Type | Not null | Default | Generated |
|---|---|---|---|---|
| id | uuid | yes | `gen_random_uuid()` |  |
| theme | text | yes | `''::text` |  |
| batch_year | text | yes | `''::text` |  |
| date | timestamp with time zone | yes |  |  |
| venue | text | yes | `''::text` |  |
| status | text | yes | `'Active'::text` |  |
| comments_count | integer | yes | `0` |  |
| start_time | text | yes | `'09:00'::text` |  |
| end_time | text | yes | `'17:00'::text` |  |
| description | text | yes | `''::text` |  |
| created_at | timestamp with time zone | yes | `now()` |  |
| updated_at | timestamp with time zone | yes | `now()` |  |
| cover_image_url | text | yes | `''::text` |  |
| category | text | yes | `'Other'::text` |  |
| capacity | integer |  |  |  |
| registration_deadline | timestamp with time zone |  |  |  |
| agenda | jsonb | yes | `'[]'::jsonb` |  |
| views_count | integer | yes | `0` |  |
| cancelled | boolean | yes | `false` |  |
| venue_latitude | double precision |  |  |  |
| venue_longitude | double precision |  |  |  |

## favorite_jobs

| Column | Type | Not null | Default | Generated |
|---|---|---|---|---|
| user_id | uuid | yes |  |  |
| job_id | uuid | yes |  |  |
| created_at | timestamp with time zone | yes | `now()` |  |

## feedback

| Column | Type | Not null | Default | Generated |
|---|---|---|---|---|
| id | uuid | yes | `gen_random_uuid()` |  |
| user_id | uuid | yes |  |  |
| status | text | yes | `'submitted'::text` |  |
| message | text | yes | `''::text` |  |
| admin_reply | text |  |  |  |
| created_at | timestamp with time zone | yes | `now()` |  |
| updated_at | timestamp with time zone | yes | `now()` |  |
| data | jsonb | yes | `'{}'::jsonb` |  |

## forum_bookmarks

| Column | Type | Not null | Default | Generated |
|---|---|---|---|---|
| user_id | uuid | yes |  |  |
| topic_id | uuid | yes |  |  |
| created_at | timestamp with time zone | yes | `now()` |  |

## forum_helpful_reactions

| Column | Type | Not null | Default | Generated |
|---|---|---|---|---|
| user_id | uuid | yes |  |  |
| post_id | uuid | yes |  |  |
| created_at | timestamp with time zone | yes | `now()` |  |

## forum_moderation_events

| Column | Type | Not null | Default | Generated |
|---|---|---|---|---|
| id | uuid | yes | `gen_random_uuid()` |  |
| topic_id | uuid |  |  |  |
| actor_uid | uuid | yes |  |  |
| action | text | yes |  |  |
| reason | text |  |  |  |
| metadata | jsonb | yes | `'{}'::jsonb` |  |
| created_at | timestamp with time zone | yes | `now()` |  |

## forum_posts

| Column | Type | Not null | Default | Generated |
|---|---|---|---|---|
| id | uuid | yes | `gen_random_uuid()` |  |
| topic_id | uuid | yes |  |  |
| body | text | yes | `''::text` |  |
| author_uid | uuid |  |  |  |
| author_name | text | yes | `''::text` |  |
| created_at | timestamp with time zone | yes | `now()` |  |
| updated_at | timestamp with time zone | yes | `now()` |  |
| edited_at | timestamp with time zone |  |  |  |
| parent_post_id | uuid |  |  |  |
| quoted_post_id | uuid |  |  |  |
| quoted_excerpt | text |  |  |  |

## forum_reports

| Column | Type | Not null | Default | Generated |
|---|---|---|---|---|
| id | uuid | yes | `gen_random_uuid()` |  |
| reporter_uid | uuid | yes |  |  |
| topic_id | uuid |  |  |  |
| post_id | uuid |  |  |  |
| reason | text | yes | `''::text` |  |
| status | text | yes | `'open'::text` |  |
| created_at | timestamp with time zone | yes | `now()` |  |
| updated_at | timestamp with time zone | yes | `now()` |  |

## forum_tags

| Column | Type | Not null | Default | Generated |
|---|---|---|---|---|
| id | uuid | yes | `gen_random_uuid()` |  |
| slug | text | yes |  |  |
| label | text | yes |  |  |
| sort_order | integer | yes | `0` |  |
| created_at | timestamp with time zone | yes | `now()` |  |

## forum_topic_tags

| Column | Type | Not null | Default | Generated |
|---|---|---|---|---|
| topic_id | uuid | yes |  |  |
| tag_id | uuid | yes |  |  |

## forum_topics

| Column | Type | Not null | Default | Generated |
|---|---|---|---|---|
| id | uuid | yes | `gen_random_uuid()` |  |
| title | text | yes | `''::text` |  |
| body | text | yes | `''::text` |  |
| author_uid | uuid |  |  |  |
| author_name | text | yes | `''::text` |  |
| author_program | text | yes | `''::text` |  |
| reply_count | integer | yes | `0` |  |
| last_reply_at | timestamp with time zone |  |  |  |
| is_locked | boolean | yes | `false` |  |
| is_pinned | boolean | yes | `false` |  |
| created_at | timestamp with time zone | yes | `now()` |  |
| updated_at | timestamp with time zone | yes | `now()` |  |
| author_batch | text | yes | `''::text` |  |
| is_solved | boolean | yes | `false` |  |
| is_announcement | boolean | yes | `false` |  |
| is_featured | boolean | yes | `false` |  |
| edited_at | timestamp with time zone |  |  |  |
| moderation_reason | text |  |  |  |
| view_count | integer | yes | `0` |  |

## gts_question_catalog

| Column | Type | Not null | Default | Generated |
|---|---|---|---|---|
| schema_version | text | yes |  |  |
| item_id | text | yes |  |  |
| ched_number | text | yes |  |  |
| section | text | yes |  |  |
| field_type | text | yes |  |  |
| prompt | text | yes |  |  |
| help_text | text |  |  |  |
| options | jsonb | yes | `'[]'::jsonb` |  |
| matrix_rows | jsonb | yes | `'[]'::jsonb` |  |
| matrix_columns | jsonb | yes | `'[]'::jsonb` |  |
| table_columns | jsonb | yes | `'[]'::jsonb` |  |
| required | boolean | yes | `false` |  |
| others_specify_id | text |  |  |  |
| is_others_specify | boolean | yes | `false` |  |
| sort_order | integer | yes |  |  |
| created_at | timestamp with time zone | yes | `now()` |  |

## job_interests

| Column | Type | Not null | Default | Generated |
|---|---|---|---|---|
| user_id | uuid | yes |  |  |
| job_id | uuid | yes |  |  |
| created_at | timestamp with time zone | yes | `now()` |  |

## jobs

| Column | Type | Not null | Default | Generated |
|---|---|---|---|---|
| id | uuid | yes | `gen_random_uuid()` |  |
| title | text | yes | `''::text` |  |
| company | text | yes | `''::text` |  |
| location | text | yes | `''::text` |  |
| description | text | yes | `''::text` |  |
| status | text | yes | `'active'::text` |  |
| data | jsonb | yes | `'{}'::jsonb` |  |
| created_at | timestamp with time zone | yes | `now()` |  |
| updated_at | timestamp with time zone | yes | `now()` |  |
| views | integer | yes | `0` |  |

## messages

| Column | Type | Not null | Default | Generated |
|---|---|---|---|---|
| id | uuid | yes | `gen_random_uuid()` |  |
| sender_id | uuid | yes |  |  |
| recipient_id | uuid | yes |  |  |
| body | text | yes | `''::text` |  |
| image_base64 | text |  |  |  |
| is_read | boolean | yes | `false` |  |
| reactions | jsonb | yes | `'{}'::jsonb` |  |
| created_at | timestamp with time zone | yes | `now()` |  |
| updated_at | timestamp with time zone | yes | `now()` |  |
| sender_doc_id | text |  |  |  |
| recipient_doc_id | text |  |  |  |
| sender_role | text | yes | `''::text` |  |
| sender_name | text | yes | `''::text` |  |
| sender_email | text | yes | `''::text` |  |
| edited_at | timestamp with time zone |  |  |  |

## notification_preferences

| Column | Type | Not null | Default | Generated |
|---|---|---|---|---|
| user_id | uuid | yes |  |  |
| in_app | jsonb | yes | `'{}'::jsonb` |  |
| push | jsonb | yes | `'{}'::jsonb` |  |
| quiet_hours_enabled | boolean | yes | `false` |  |
| quiet_start | time without time zone | yes | `'22:00:00'::time without time zone` |  |
| quiet_end | time without time zone | yes | `'07:00:00'::time without time zone` |  |
| timezone | text | yes | `'Asia/Manila'::text` |  |
| created_at | timestamp with time zone | yes | `now()` |  |
| updated_at | timestamp with time zone | yes | `now()` |  |

## notification_push_deliveries

| Column | Type | Not null | Default | Generated |
|---|---|---|---|---|
| id | uuid | yes | `gen_random_uuid()` |  |
| notification_id | uuid | yes |  |  |
| user_id | uuid | yes |  |  |
| token_id | uuid | yes |  |  |
| status | text | yes | `'queued'::text` |  |
| scheduled_at | timestamp with time zone | yes | `now()` |  |
| attempts | integer | yes | `0` |  |
| last_error | text |  |  |  |
| created_at | timestamp with time zone | yes | `now()` |  |
| claimed_at | timestamp with time zone |  |  |  |
| sent_at | timestamp with time zone |  |  |  |

## notifications

| Column | Type | Not null | Default | Generated |
|---|---|---|---|---|
| id | uuid | yes | `gen_random_uuid()` |  |
| user_id | uuid | yes |  |  |
| title | text | yes | `''::text` |  |
| body | text | yes | `''::text` |  |
| type | text | yes | `''::text` |  |
| is_read | boolean | yes | `false` |  |
| data | jsonb | yes | `'{}'::jsonb` |  |
| created_at | timestamp with time zone | yes | `now()` |  |
| updated_at | timestamp with time zone | yes | `now()` |  |

## programs

| Column | Type | Not null | Default | Generated |
|---|---|---|---|---|
| code | text | yes |  |  |
| name | text | yes |  |  |
| active | boolean | yes | `true` |  |
| sort_order | integer | yes | `0` |  |
| created_at | timestamp with time zone | yes | `now()` |  |

## push_tokens

| Column | Type | Not null | Default | Generated |
|---|---|---|---|---|
| id | uuid | yes | `gen_random_uuid()` |  |
| user_id | uuid | yes |  |  |
| provider | text | yes |  |  |
| platform | text | yes |  |  |
| token | text | yes |  |  |
| subscription | jsonb |  |  |  |
| device_label | text |  |  |  |
| failure_count | integer | yes | `0` |  |
| disabled_at | timestamp with time zone |  |  |  |
| last_seen_at | timestamp with time zone | yes | `now()` |  |
| created_at | timestamp with time zone | yes | `now()` |  |
| updated_at | timestamp with time zone | yes | `now()` |  |

## reminders

| Column | Type | Not null | Default | Generated |
|---|---|---|---|---|
| id | uuid | yes | `gen_random_uuid()` |  |
| user_id | uuid | yes |  |  |
| title | text | yes | `''::text` |  |
| body | text | yes | `''::text` |  |
| scheduled_at | timestamp with time zone |  |  |  |
| sent_at | timestamp with time zone |  |  |  |
| data | jsonb | yes | `'{}'::jsonb` |  |
| created_at | timestamp with time zone | yes | `now()` |  |
| updated_at | timestamp with time zone | yes | `now()` |  |

## survey_assignments

| Column | Type | Not null | Default | Generated |
|---|---|---|---|---|
| id | uuid | yes | `gen_random_uuid()` |  |
| survey_id | uuid | yes |  |  |
| user_id | uuid | yes |  |  |
| survey_title | text | yes | `''::text` |  |
| status | text | yes | `'notStarted'::text` |  |
| assigned_at | timestamp with time zone | yes | `now()` |  |
| last_reminder_at | timestamp with time zone |  |  |  |
| reminder_count | integer | yes | `0` |  |
| created_at | timestamp with time zone | yes | `now()` |  |
| updated_at | timestamp with time zone | yes | `now()` |  |

## survey_questions

| Column | Type | Not null | Default | Generated |
|---|---|---|---|---|
| id | uuid | yes | `gen_random_uuid()` |  |
| survey_id | uuid | yes |  |  |
| order | integer | yes | `0` |  |
| type | text | yes | `'text'::text` |  |
| prompt | text | yes | `''::text` |  |
| required | boolean | yes | `true` |  |
| options | ARRAY (_text) | yes | `'{}'::text[]` |  |
| scale_min | integer |  |  |  |
| scale_max | integer |  |  |  |
| section | text |  |  |  |
| ched_item_number | text |  |  |  |
| prefill_key | text |  |  |  |
| is_standard_item | boolean | yes | `false` |  |
| created_at | timestamp with time zone | yes | `now()` |  |
| updated_at | timestamp with time zone | yes | `now()` |  |

## survey_response_events

| Column | Type | Not null | Default | Generated |
|---|---|---|---|---|
| id | uuid | yes | `gen_random_uuid()` |  |
| survey_id | uuid | yes |  |  |
| user_id | uuid | yes |  |  |
| response_id | uuid |  |  |  |
| event_type | text | yes |  |  |
| device_category | text |  |  |  |
| platform_family | text |  |  |  |
| browser_family | text |  |  |  |
| meta | jsonb | yes | `'{}'::jsonb` |  |
| created_at | timestamp with time zone | yes | `now()` |  |

## survey_responses

| Column | Type | Not null | Default | Generated |
|---|---|---|---|---|
| id | uuid | yes | `gen_random_uuid()` |  |
| survey_id | uuid | yes |  |  |
| user_id | uuid | yes |  |  |
| status | text | yes | `'draft'::text` |  |
| answers | jsonb | yes | `'{}'::jsonb` |  |
| submitted_at | timestamp with time zone |  |  |  |
| created_at | timestamp with time zone | yes | `now()` |  |
| updated_at | timestamp with time zone | yes | `now()` |  |
| opened_at | timestamp with time zone |  |  |  |
| first_draft_at | timestamp with time zone |  |  |  |
| device_category | text |  |  |  |
| platform_family | text |  |  |  |
| browser_family | text |  |  |  |

## survey_template_questions

| Column | Type | Not null | Default | Generated |
|---|---|---|---|---|
| id | uuid | yes | `gen_random_uuid()` |  |
| template_id | uuid | yes |  |  |
| order | integer | yes | `0` |  |
| type | text | yes | `'text'::text` |  |
| prompt | text | yes | `''::text` |  |
| required | boolean | yes | `true` |  |
| options | ARRAY (_text) | yes | `'{}'::text[]` |  |
| scale_min | integer |  |  |  |
| scale_max | integer |  |  |  |
| section | text |  |  |  |
| ched_item_number | text |  |  |  |
| prefill_key | text |  |  |  |
| is_standard_item | boolean | yes | `false` |  |
| created_at | timestamp with time zone | yes | `now()` |  |
| updated_at | timestamp with time zone | yes | `now()` |  |

## survey_templates

| Column | Type | Not null | Default | Generated |
|---|---|---|---|---|
| id | uuid | yes | `gen_random_uuid()` |  |
| title | text | yes | `''::text` |  |
| description | text | yes | `''::text` |  |
| version | text | yes | `''::text` |  |
| data | jsonb | yes | `'{}'::jsonb` |  |
| created_at | timestamp with time zone | yes | `now()` |  |
| updated_at | timestamp with time zone | yes | `now()` |  |

## surveys

| Column | Type | Not null | Default | Generated |
|---|---|---|---|---|
| id | uuid | yes | `gen_random_uuid()` |  |
| title | text | yes | `''::text` |  |
| description | text | yes | `''::text` |  |
| status | text | yes | `'draft'::text` |  |
| target_programs | ARRAY (_text) | yes | `'{}'::text[]` |  |
| target_batch_years | ARRAY (_text) | yes | `'{}'::text[]` |  |
| open_at | timestamp with time zone |  |  |  |
| close_at | timestamp with time zone |  |  |  |
| created_by | uuid |  |  |  |
| assignment_count | integer | yes | `0` |  |
| response_count | integer | yes | `0` |  |
| template_id | uuid |  |  |  |
| template_version | text |  |  |  |
| created_at | timestamp with time zone | yes | `now()` |  |
| updated_at | timestamp with time zone | yes | `now()` |  |
| data | jsonb | yes | `'{}'::jsonb` |  |

## tracer_draft_reminders

| Column | Type | Not null | Default | Generated |
|---|---|---|---|---|
| id | uuid | yes | `gen_random_uuid()` |  |
| user_id | uuid | yes |  |  |
| survey_id | uuid | yes |  |  |
| remind_at | timestamp with time zone | yes |  |  |
| repeat_hourly | boolean | yes | `false` |  |
| followups_sent | integer | yes | `0` |  |
| last_sent_at | timestamp with time zone |  |  |  |
| cancelled_at | timestamp with time zone |  |  |  |
| created_at | timestamp with time zone | yes | `now()` |  |
| updated_at | timestamp with time zone | yes | `now()` |  |

## tracer_help_usage

| Column | Type | Not null | Default | Generated |
|---|---|---|---|---|
| user_id | uuid | yes |  |  |
| used_on | date | yes |  |  |
| count | integer | yes | `0` |  |
| updated_at | timestamp with time zone | yes | `now()` |  |

## user_notifications

| Column | Type | Not null | Default | Generated |
|---|---|---|---|---|
| id | uuid | yes | `gen_random_uuid()` |  |
| user_id | uuid | yes |  |  |
| title | text | yes | `''::text` |  |
| body | text | yes | `''::text` |  |
| type | text | yes | `''::text` |  |
| is_read | boolean | yes | `false` |  |
| data | jsonb | yes | `'{}'::jsonb` |  |
| created_at | timestamp with time zone | yes | `now()` |  |
| updated_at | timestamp with time zone | yes | `now()` |  |
| priority | text | yes | `'normal'::text` |  |
| dedupe_key | text |  |  |  |
| route | text |  |  |  |
| read_at | timestamp with time zone |  |  |  |
| expires_at | timestamp with time zone |  |  |  |
| source | text | yes | `'app'::text` |  |

## users

| Column | Type | Not null | Default | Generated |
|---|---|---|---|---|
| id | uuid | yes |  |  |
| role | text | yes | `'user'::text` |  |
| display_name | text | yes | `''::text` |  |
| email | text | yes | `''::text` |  |
| student_id | text | yes | `''::text` |  |
| program | text | yes | `''::text` |  |
| batch_year | text | yes | `''::text` |  |
| year_graduated | text | yes | `''::text` |  |
| address | text | yes | `''::text` |  |
| gender | text | yes | `''::text` |  |
| civil_status | text | yes | `''::text` |  |
| onboarding_complete | boolean | yes | `false` |  |
| tracer_profile_completion | integer | yes | `0` |  |
| tracer_profile_complete | boolean | yes | `false` |  |
| profile_image_base64 | text |  |  |  |
| last_active_at | timestamp with time zone |  |  |  |
| created_at | timestamp with time zone | yes | `now()` |  |
| updated_at | timestamp with time zone | yes | `now()` |  |
| birth_date | date |  |  |  |
| telephone_number | text | yes | `''::text` |  |
| mobile_number | text | yes | `''::text` |  |
| region_of_origin | text | yes | `''::text` |  |
| province | text | yes | `''::text` |  |
| location_of_residence | text | yes | `''::text` |  |
| college_university | text | yes | `''::text` |  |
| honors_awards | text | yes | `''::text` |  |
| employment_status | text | yes | `''::text` |  |
| deactivated_at | timestamp with time zone |  |  |  |
| anonymized_at | timestamp with time zone |  |  |  |
