# USTP Alumni System

Flutter + Supabase alumni portal with official roster, gated registration, graduate tracer, surveys, announcements, forum, events, and jobs.

## Documentation

- [docs/system-audit/AESS-COMPLETE-SYSTEM-OVERVIEW.md](docs/system-audit/AESS-COMPLETE-SYSTEM-OVERVIEW.md) - **2026-11-05** complete system overview (architecture, screens, DB, security, deployment, backlog)
- [docs/dss-complete-overview.md](docs/dss-complete-overview.md) - Complete DSS / Program Insights overview (what exists, how it works, how to operate)
- [docs/full-system-overview.md](docs/full-system-overview.md) - Full system overview (features, screens, flows, admin + alumni)
- [docs/admin-survey-screens.md](docs/admin-survey-screens.md) - Admin survey UI deep dive
- [docs/notifications.md](docs/notifications.md) - In-app notifications, push alerts and the delivery log
- [docs/deployment/sharing-the-app.md](docs/deployment/sharing-the-app.md) - How to share the app: website on Firebase, Android APK on a GitHub Release
- [docs/database/](docs/database/) - Generated database reference (tables, constraints, policies, functions)
- [docs/archive/](docs/archive/) - Older notes from the Firebase era, kept for history only

## Quick start

```powershell
flutter pub get
flutter run -d chrome
```

Configure Supabase in `lib/core/config/supabase_defaults.dart` (or dart-define / env).
Email delivery uses Gmail SMTP through the Supabase Edge Function `send-email`.
Set `GMAIL_USER`, `GMAIL_APP_PASSWORD`, and `GMAIL_SENDER_NAME` as
Supabase Function secrets before using OTP or email reminders.

## Ensure admin account

```powershell
cd scripts/restore_admin
npm install
npm run ensure-admin
```

Default admin after seed: `admin@gmail.com` / `123123` (change in production).

## Official roster courses

BSIT, BFPT, BTLED-IA, BTLED-ICT, BTLED-HE
