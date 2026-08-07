#!/usr/bin/env python3
"""Migrate lib/ to feature-first architecture and update imports."""

from __future__ import annotations

import os
import re
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LIB = ROOT / "lib"

# old path (relative to lib/) -> new path (relative to lib/)
MOVES: dict[str, str] = {
    # --- core ---
    "config/ai_config.dart": "core/config/ai_config.dart",
    "config/ai_defaults.dart": "core/config/ai_defaults.dart",
    "config/email_delivery_config.dart": "core/config/email_delivery_config.dart",
    "config/migration_config.dart": "core/config/migration_config.dart",
    "config/supabase_config.dart": "core/config/supabase_config.dart",
    "config/supabase_defaults.dart": "core/config/supabase_defaults.dart",
    "core/audience_targeting.dart": "core/constants/audience_targeting.dart",
    "core/course_constants.dart": "core/constants/course_constants.dart",
    "core/program_constants.dart": "core/constants/program_constants.dart",
    "core/local_id.dart": "core/utils/local_id.dart",
    "utils/app_image.dart": "core/utils/app_image.dart",
    "utils/export_platform.dart": "core/utils/export_platform.dart",
    "utils/web_file_download.dart": "core/utils/web_file_download.dart",
    "utils/web_file_upload.dart": "core/utils/web_file_upload.dart",
    "services/app_session.dart": "core/services/app_session.dart",
    "services/supabase_user_bridge.dart": "core/services/supabase_user_bridge.dart",
    "services/email_service.dart": "core/services/email_service.dart",
    "services/audit_service.dart": "core/services/audit_service.dart",
    "services/ched_gts_export_service.dart": "core/services/ched_gts_export_service.dart",
    # --- shared widgets ---
    "widgets/admin/admin_skeletons.dart": "shared/widgets/admin/admin_skeletons.dart",
    "widgets/user/portal_skeletons.dart": "shared/widgets/user/portal_skeletons.dart",
    "widgets/user/skeleton.dart": "shared/widgets/user/skeleton.dart",
    "widgets/onboarding/onboarding_ui.dart": "shared/widgets/onboarding/onboarding_ui.dart",
    "widgets/tracer/demographic_tracer_tab.dart": "shared/widgets/tracer/demographic_tracer_tab.dart",
    "widgets/tracer/tracer_profile_checklist.dart": "shared/widgets/tracer/tracer_profile_checklist.dart",
    # --- auth ---
    "screens/login_screen.dart": "features/auth/presentation/login_page.dart",
    "screens/register_screen.dart": "features/auth/presentation/register_page.dart",
    "services/auth_service.dart": "features/auth/data/auth_service.dart",
    "services/login_preferences_service.dart": "features/auth/data/login_preferences_service.dart",
    "services/alumni_eligibility_service.dart": "features/auth/data/alumni_eligibility_service.dart",
    # --- onboarding ---
    "screens/alumni_home_gate.dart": "features/onboarding/presentation/alumni_home_gate.dart",
    "screens/alumni_onboarding_screen.dart": "features/onboarding/presentation/alumni_onboarding_page.dart",
    "services/onboarding_service.dart": "features/onboarding/data/onboarding_service.dart",
    # --- shell ---
    "screens/main_navigation.dart": "features/shell/presentation/main_navigation.dart",
    # --- home ---
    "screens/home_screen.dart": "features/home/presentation/home_page.dart",
    # --- alumni profile ---
    "screens/profile_screen.dart": "features/alumni/profile/presentation/profile_page.dart",
    "services/user_profile_service.dart": "features/alumni/profile/data/user_profile_service.dart",
    "services/user_profile_events.dart": "features/alumni/profile/data/user_profile_events.dart",
    # --- alumni tracer ---
    "screens/id_tracer_screen.dart": "features/alumni/tracer/presentation/id_tracer_page.dart",
    "services/id_tracer_service.dart": "features/alumni/tracer/data/id_tracer_service.dart",
    "services/survey_prefill_helper.dart": "features/alumni/tracer/data/survey_prefill_helper.dart",
    "models/id_tracer_model.dart": "features/alumni/tracer/models/id_tracer_model.dart",
    "models/tracer_profile_model.dart": "features/alumni/tracer/models/tracer_profile_model.dart",
    # --- events ---
    "screens/events_screen.dart": "features/events/presentation/events_page.dart",
    "services/event_service.dart": "features/events/data/event_service.dart",
    "services/event_comment_service.dart": "features/events/data/event_comment_service.dart",
    "services/reminder_service.dart": "features/events/data/reminder_service.dart",
    "models/event_model.dart": "features/events/models/event_model.dart",
    "models/event_comment_model.dart": "features/events/models/event_comment_model.dart",
    # --- jobs ---
    "screens/job_posting_screen.dart": "features/jobs/presentation/job_posting_page.dart",
    "screens/add_job_dialog.dart": "features/jobs/presentation/add_job_dialog.dart",
    "services/job_service.dart": "features/jobs/data/job_service.dart",
    "services/favorite_job_service.dart": "features/jobs/data/favorite_job_service.dart",
    "models/job_posting_model.dart": "features/jobs/models/job_posting_model.dart",
    # --- messages ---
    "screens/user_messages_screen.dart": "features/messages/presentation/user_messages_page.dart",
    "screens/admin_messages_screen.dart": "features/messages/presentation/admin_messages_page.dart",
    "services/message_service.dart": "features/messages/data/message_service.dart",
    "services/image_storage_service.dart": "features/messages/data/image_storage_service.dart",
    # --- forum ---
    "screens/forum_screen.dart": "features/forum/presentation/forum_page.dart",
    "screens/forum_topic_screen.dart": "features/forum/presentation/forum_topic_page.dart",
    "services/forum_service.dart": "features/forum/data/forum_service.dart",
    "models/forum_model.dart": "features/forum/models/forum_model.dart",
    # --- announcements ---
    "screens/user_announcements_screen.dart": "features/announcements/presentation/user_announcements_page.dart",
    "services/announcement_service.dart": "features/announcements/data/announcement_service.dart",
    "models/announcement_model.dart": "features/announcements/models/announcement_model.dart",
    # --- surveys ---
    "screens/user_surveys_screen.dart": "features/surveys/presentation/user_surveys_page.dart",
    "screens/user_survey_take_screen.dart": "features/surveys/presentation/user_survey_take_page.dart",
    "services/survey_service.dart": "features/surveys/data/survey_service.dart",
    "services/survey_template_service.dart": "features/surveys/data/survey_template_service.dart",
    "services/survey_report_analytics.dart": "features/surveys/data/survey_report_analytics.dart",
    "models/survey_model.dart": "features/surveys/models/survey_model.dart",
    "models/survey_template_model.dart": "features/surveys/models/survey_template_model.dart",
    "models/survey_reports_aggregate.dart": "features/surveys/models/survey_reports_aggregate.dart",
    "data/ched_survey_template_seed.dart": "features/surveys/data/ched_survey_template_seed.dart",
    # --- feedback ---
    "screens/user_feedback_list_screen.dart": "features/feedback/presentation/user_feedback_list_page.dart",
    "screens/user_feedback_detail_screen.dart": "features/feedback/presentation/user_feedback_detail_page.dart",
    "screens/user_feedback_submit_screen.dart": "features/feedback/presentation/user_feedback_submit_page.dart",
    "services/feedback_service.dart": "features/feedback/data/feedback_service.dart",
    "models/feedback_model.dart": "features/feedback/models/feedback_model.dart",
    # --- notifications ---
    "services/notification_service.dart": "features/notifications/data/notification_service.dart",
    "models/notification_model.dart": "features/notifications/models/notification_model.dart",
  # --- ai ---
    "screens/ai_assistant_screen.dart": "features/ai/presentation/ai_assistant_page.dart",
    "services/ai_assistant_service.dart": "features/ai/data/ai_assistant_service.dart",
    "models/ai_chat_message.dart": "features/ai/models/ai_chat_message.dart",
    # --- admin dashboard ---
    "screens/admin_dashboard_web.dart": "features/admin/dashboard/presentation/admin_dashboard_page.dart",
    "screens/admin/admin_dashboard_home.dart": "features/admin/dashboard/presentation/admin_dashboard_home.dart",
    "screens/admin/admin_dashboard_metrics.dart": "features/admin/dashboard/application/admin_dashboard_metrics.dart",
    "screens/admin/dashboard_activity_trend.dart": "features/admin/dashboard/application/dashboard_activity_trend.dart",
    "screens/admin/widgets/admin_dashboard_shell.dart": "features/admin/dashboard/widgets/admin_dashboard_shell.dart",
    "screens/admin/widgets/admin_dashboard_widgets.dart": "features/admin/dashboard/widgets/admin_dashboard_widgets.dart",
    "screens/admin/widgets/dashboard_engagement_chart.dart": "features/admin/dashboard/widgets/dashboard_engagement_chart.dart",
    "screens/admin/widgets/admin_instant_content.dart": "features/admin/dashboard/widgets/admin_instant_content.dart",
    # --- admin roster ---
    "screens/admin_alumni_members_screen.dart": "features/admin/roster/presentation/admin_alumni_members_page.dart",
    "screens/admin/admin_alumni_directory_screen.dart": "features/admin/roster/presentation/admin_alumni_directory_page.dart",
    "screens/admin/admin_alumni_member_detail_screen.dart": "features/admin/roster/presentation/admin_alumni_member_detail_page.dart",
    "screens/admin/widgets/alumni_directory_ui.dart": "features/admin/roster/widgets/alumni_directory_ui.dart",
    "services/alumni_member_service.dart": "features/admin/roster/data/alumni_member_service.dart",
    "services/alumni_roster_import_service.dart": "features/admin/roster/data/alumni_roster_import_service.dart",
    "services/alumni_directory_detail_service.dart": "features/admin/roster/data/alumni_directory_detail_service.dart",
    "models/alumni_member_model.dart": "features/admin/roster/models/alumni_member_model.dart",
    # --- admin events ---
    "screens/admin/admin_events_screen.dart": "features/admin/events/presentation/admin_events_page.dart",
    "screens/admin/admin_event_comments_dialog.dart": "features/admin/events/presentation/admin_event_comments_dialog.dart",
    # --- admin jobs ---
    "screens/admin_job_management.dart": "features/admin/jobs/presentation/admin_job_management_page.dart",
    # --- admin reports ---
    "screens/admin_reports_screen.dart": "features/admin/reports/presentation/admin_reports_page.dart",
    "screens/admin/admin_reports_analytics.dart": "features/admin/reports/application/admin_reports_analytics.dart",
    "screens/admin/admin_registered_alumni_tab.dart": "features/admin/reports/widgets/admin_registered_alumni_tab.dart",
    # --- admin surveys ---
    "screens/admin/admin_surveys_screen.dart": "features/admin/surveys/presentation/admin_surveys_page.dart",
    "screens/admin/admin_survey_editor_screen.dart": "features/admin/surveys/presentation/admin_survey_editor_page.dart",
    "screens/admin/admin_survey_responses_screen.dart": "features/admin/surveys/presentation/admin_survey_responses_page.dart",
    "screens/admin/widgets/admin_survey_template_picker.dart": "features/admin/surveys/widgets/admin_survey_template_picker.dart",
    "screens/admin/widgets/admin_form_fields.dart": "features/admin/surveys/widgets/admin_form_fields.dart",
    # --- admin announcements ---
    "screens/admin/admin_announcements_screen.dart": "features/admin/announcements/presentation/admin_announcements_page.dart",
    "screens/admin/admin_announcement_editor_screen.dart": "features/admin/announcements/presentation/admin_announcement_editor_page.dart",
    # --- admin forum ---
    "screens/admin/admin_forum_screen.dart": "features/admin/forum/presentation/admin_forum_page.dart",
    # --- admin feedback ---
    "screens/admin/admin_feedback_screen.dart": "features/admin/feedback/presentation/admin_feedback_page.dart",
    "screens/admin/admin_feedback_detail_screen.dart": "features/admin/feedback/presentation/admin_feedback_detail_page.dart",
    # --- admin archives ---
    "screens/admin/admin_archives_screen.dart": "features/admin/archives/presentation/admin_archives_page.dart",
    # --- admin activity ---
    "screens/admin/admin_activity_logs_screen.dart": "features/admin/activity/presentation/admin_activity_logs_page.dart",
    "models/audit_log_model.dart": "features/admin/activity/models/audit_log_model.dart",
}

DELETE_FILES = [
    "core/app_constants.dart",
    "screens/tracer_profile_screen.dart",
    "services/migration_read.dart",
    "services/migration_write.dart",
]

PACKAGE_PREFIX = "package:alumni_system/"


def move_files() -> None:
    for old_rel, new_rel in MOVES.items():
        src = LIB / old_rel.replace("/", os.sep)
        dst = LIB / new_rel.replace("/", os.sep)
        if not src.exists():
            print(f"SKIP missing: {old_rel}")
            continue
        dst.parent.mkdir(parents=True, exist_ok=True)
        if dst.exists():
            print(f"SKIP exists: {new_rel}")
            continue
        shutil.move(str(src), str(dst))
        print(f"MOVED {old_rel} -> {new_rel}")


def delete_dead_files() -> None:
    for rel in DELETE_FILES:
        path = LIB / rel.replace("/", os.sep)
        if path.exists():
            path.unlink()
            print(f"DELETED {rel}")


def cleanup_empty_dirs() -> None:
    for dirpath, dirnames, filenames in os.walk(LIB, topdown=False):
        if not dirnames and not filenames and Path(dirpath) != LIB:
            Path(dirpath).rmdir()
            print(f"RMDIR {dirpath}")


def build_import_map() -> dict[str, str]:
    mapping: dict[str, str] = {}
    for old_rel, new_rel in MOVES.items():
        old_import = f"{PACKAGE_PREFIX}{old_rel}"
        new_import = f"{PACKAGE_PREFIX}{new_rel}"
        mapping[old_import] = new_import
    return mapping


def update_imports() -> None:
    import_map = build_import_map()
    # Sort longest first to avoid partial replacements
    patterns = sorted(import_map.items(), key=lambda x: len(x[0]), reverse=True)

    roots = [LIB, ROOT / "test"]
    for root in roots:
        if not root.exists():
            continue
        for dart_file in root.rglob("*.dart"):
            text = dart_file.read_text(encoding="utf-8")
            original = text

            for old_import, new_import in patterns:
                text = text.replace(old_import, new_import)

            # Fix relative imports in admin dashboard (was using bare relative)
            relative_fixes = {
                "import 'admin_job_management.dart'": "import 'package:alumni_system/features/admin/jobs/presentation/admin_job_management_page.dart'",
                "import 'admin_alumni_members_screen.dart'": "import 'package:alumni_system/features/admin/roster/presentation/admin_alumni_members_page.dart'",
                "import 'admin_reports_screen.dart'": "import 'package:alumni_system/features/admin/reports/presentation/admin_reports_page.dart'",
                "import 'add_job_dialog.dart'": "import 'package:alumni_system/features/jobs/presentation/add_job_dialog.dart'",
            }
            for old, new in relative_fixes.items():
                text = text.replace(old, new)

            if text != original:
                dart_file.write_text(text, encoding="utf-8")
                print(f"UPDATED {dart_file.relative_to(ROOT)}")


def update_main() -> None:
    main = LIB / "main.dart"
    text = main.read_text(encoding="utf-8")
    text = text.replace(
        "package:alumni_system/config/supabase_config.dart",
        "package:alumni_system/core/config/supabase_config.dart",
    )
    text = text.replace(
        "package:alumni_system/screens/login_screen.dart",
        "package:alumni_system/features/auth/presentation/login_page.dart",
    )
    main.write_text(text, encoding="utf-8")
    print("UPDATED main.dart")


def main() -> None:
    print("=== Moving files ===")
    move_files()
    print("\n=== Deleting dead files ===")
    delete_dead_files()
    print("\n=== Updating imports ===")
    update_imports()
    update_main()
    print("\n=== Cleaning empty dirs ===")
    cleanup_empty_dirs()
    print("\nDone.")


if __name__ == "__main__":
    main()
