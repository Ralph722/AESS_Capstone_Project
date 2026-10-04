# Notifications

How notifications are created, stored, shown and delivered as phone/browser
alerts, and what is needed to turn on Android alerts.

## Overview

| Piece | Where |
| --- | --- |
| Storage | `public.user_notifications` (Supabase), one row per recipient |
| Creation | Database triggers and `SECURITY DEFINER` functions only; the app never inserts notifications |
| Scheduled notices | `pg_cron` jobs `aess-notify-*` (deadlines, survey closing/opening, event reminders, admin digest, cleanup) |
| In-app list | Bell panel (Home / admin header), full history in Profile → Notifications |
| Preferences | `public.notification_preferences` (Profile → Notifications → settings) |
| Alerts | `push_tokens` + `notification_push_deliveries`, sent by the `send-push` edge function |

## Alert delivery

1. A notification row is inserted (trigger, RPC or scheduled job).
2. `trg_queue_notification_push` queues one delivery per registered device,
   unless the user turned alerts off for that category, quiet hours apply
   (the delivery is delayed; urgent notices skip quiet hours), the notice is
   expired, or it was created with `data.push = false`.
3. The database calls `send-push` through `pg_net` (and every minute via
   `aess-push-dispatch` as a safety net). The call is authenticated with a
   shared secret stored in Vault (`push_dispatch_secret`) and in the function
   secret `PUSH_DISPATCH_SECRET`.
4. `send-push` sends Web Push (browsers) or Firebase Cloud Messaging
   (Android), then reports results. Failures retry up to 4 times with
   backoff; devices the provider reports as gone are disabled.

Alert text never contains private content: message and feedback alerts only
say that something new arrived, and account alerts only say to open the app.

## Devices

- Browsers: Profile → Notifications → settings → **This device**. The browser
  asks for permission; the subscription is stored through
  `register_push_token`.
- Android: alerts turn on after sign-in when the phone allows notifications;
  the same **This device** switch turns them off for that phone.
- Signing out detaches the device from the account.
- iOS is not supported (needs an Apple Developer account and APNs setup).

## Secrets (never in the app)

Set as Supabase Edge Function secrets:

| Secret | Purpose |
| --- | --- |
| `PUSH_DISPATCH_SECRET` | Shared with Vault `push_dispatch_secret` |
| `VAPID_PUBLIC_KEY`, `VAPID_PRIVATE_KEY`, `VAPID_SUBJECT` | Web Push signing |
| `FCM_SERVICE_ACCOUNT` | Firebase service account (Android), raw JSON or base64 |

The VAPID public key is also compiled into the app
(`lib/core/config/push_config.dart`); it is public by design.

## Turning on Android alerts

Firebase is used only to deliver alerts to Android phones. No data is stored
in Firebase.

1. Go to <https://console.firebase.google.com>, create a project, and add an
   **Android app** with package name `com.example.alumni_system`.
   Skip the `google-services.json` and Gradle plugin steps; the app reads its
   Firebase values from build flags instead.
2. In **Project settings → General**, note for the Android app:
   - Web API key → `FIREBASE_API_KEY`
   - App ID (`1:…:android:…`) → `FIREBASE_APP_ID`
   - Project number (Cloud Messaging tab: Sender ID) →
     `FIREBASE_MESSAGING_SENDER_ID`
   - Project ID → `FIREBASE_PROJECT_ID`
3. In **Project settings → Service accounts**, click **Generate new private
   key** and save the JSON file somewhere outside the project folder.
4. Give the key to Supabase (PowerShell):

   ```powershell
   $json = Get-Content -Raw 'C:\path\to\service-account.json'
   $b64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($json))
   supabase secrets set "FCM_SERVICE_ACCOUNT=$b64"
   ```

   Then delete the downloaded file or keep it in a safe place. Do not commit
   it.
5. Put the four values in `lib/core/config/push_config.dart` as the
   defaults (already done for the `aess-alumni` project). Every build then
   includes them, so a normal build is all that is needed:

   ```powershell
   flutter build apk --release
   ```

   These values identify the Firebase app and are safe to ship in the APK.
   To use a different Firebase project for one build, override them with
   `--dart-define=FIREBASE_...=...`.

Status: set up for project `aess-alumni`; server-side delivery verified on
2026-10-01; confirmed working on a real Android phone on 2026-10-03.

## Checking delivery

```sql
-- Recent alert attempts (admins can also read this table through the API)
select status, attempts, last_error, scheduled_at, sent_at
from public.notification_push_deliveries
order by scheduled_at desc
limit 50;

-- Scheduled job runs
select jobname, status, return_message, start_time
from cron.job_run_details d join cron.job j using (jobid)
order by start_time desc
limit 20;
```

## Rollout note

Older app builds that still create notifications from the client keep
working; those notifications also produce alerts. Once every user is on the
new build, the database is the only source of notifications.
