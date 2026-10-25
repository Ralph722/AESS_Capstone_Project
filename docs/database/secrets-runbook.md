# Secrets Runbook

Where every server-side secret lives and how to recreate it on a new or restored Supabase project. Names only; never paste values into this file or into the repo.

## Edge Function secrets

Set with `supabase secrets set NAME=value --project-ref <ref>` or in Dashboard → Edge Functions → Secrets.

| Name | Used by | Where to get the value |
|---|---|---|
| `GMAIL_USER` | `send-email` | The Gmail address that sends AESS email |
| `GMAIL_APP_PASSWORD` | `send-email` | Google Account → Security → App passwords (requires 2-step verification) |
| `GMAIL_SENDER_NAME` | `send-email`, `contact-verify` | Display name on outgoing email — set to `AESS-USTP`, matching Authentication → SMTP sender name (code falls back to "AESS-USTP") |
| `SEMAPHORE_API_KEY` | `contact-verify` | Semaphore dashboard → API key. Never put this in the Flutter app |
| `SEMAPHORE_SENDER_NAME` | `contact-verify` | Approved Semaphore Sender Name (exact spelling) |
| `SMS_MODE` | `contact-verify` | `live` (or `semaphore`) on production; `mock` only for local/demo; omit or `disabled` to block mobile codes. Never leave `mock` on the live project |
| `CONTACT_OTP_SECRET` | `contact-verify` | Long random string for HMAC of OTPs; falls back to the service role key if unset |
| `GEMINI_API_KEY` | `tracer-help`, `ai-assist` | Google AI Studio. The only place the key lives; the Flutter app never holds it |
| `GEMINI_MODEL` | `tracer-help`, `ai-assist` | Optional; defaults to `gemini-2.5-flash` |
| `PUSH_DISPATCH_SECRET` | `send-push`, `send-scheduled-emails`, `send-scheduled-sms` | Any long random string; must equal the Vault secret `push_dispatch_secret`. Also guards automated survey email/SMS: pg_cron swaps `/send-push` for `/send-scheduled-emails` or `/send-scheduled-sms` in the Vault `push_dispatch_url` — no separate Vault pair |
| `VAPID_PUBLIC_KEY`, `VAPID_PRIVATE_KEY` | `send-push` (web push) | Generate a VAPID key pair; the public key must match `lib/core/config/push_config.dart` |
| `VAPID_SUBJECT` | `send-push` | A `mailto:` address or site URL; falls back to `SUPABASE_URL` |
| `FCM_SERVICE_ACCOUNT` | `send-push` (Android) | Firebase console → Project settings → Service accounts → Generate key (whole JSON) |

Supabase provides these automatically on every project, so they never need to be set by hand: `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY`, `SUPABASE_DB_URL`, `SUPABASE_JWKS`, `SUPABASE_PUBLISHABLE_KEYS`, `SUPABASE_SECRET_KEYS`.

## Vault secrets

Read by `notification_push_dispatch()` (migration `20261001060000_notifications_push.sql`). Without them, push notifications queue up but are never sent.

| Name | Value |
|---|---|
| `push_dispatch_url` | `https://<project-ref>.supabase.co/functions/v1/send-push` |
| `push_dispatch_secret` | The same value as the `PUSH_DISPATCH_SECRET` function secret |

Create them in the SQL editor:

```sql
select vault.create_secret('<url>', 'push_dispatch_url');
select vault.create_secret('<secret>', 'push_dispatch_secret');
```

## Local, gitignored files

| File | Holds |
|---|---|
| `supabase/.env` | `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY` for local scripts |

The app has no AI key file. All AI requests go through the `ai-assist` Edge Function, which checks the caller and a daily limit (`ai_usage` table: 30 requests a day for alumni, 200 for admins). Never put a Gemini key in Flutter code or `--dart-define`: anything compiled into the app can be read by its users.

## Dashboard-only settings

These aren't stored in the repo and must be re-entered on a new project:

- Authentication → SMTP Settings (Gmail, once Supabase email confirmation is enabled).
- Authentication → URL Configuration (site URL and redirect URLs).
- Authentication → Email templates.

## Hosted Auth settings

The app's password checks and email-code screens assume these values. Local development reads them from `supabase/config.toml`; the hosted project only has what's set in the Dashboard, so check them on every new or restored project.

| Dashboard location | Setting | Required value | Why |
|---|---|---|---|
| Authentication → Providers → Email | Minimum password length | 8 | Matches `PasswordPolicy` and `minimum_password_length` |
| Authentication → Providers → Email | Password requirements | Letters and digits | Matches `PasswordPolicy` and `password_requirements = "letters_digits"`. A stricter hosted rule makes Supabase reject passwords the app accepts, and users only see a generic message |
| Authentication → Providers → Email | Confirm email | On | Registration sends an email code. When off, registration stops with "We couldn't send a verification code" instead of skipping the code. Check with `GET /auth/v1/settings`: `mailer_autoconfirm` must be `false` |
| Authentication → Providers → Email | Email OTP Length | 6 (any of 6–10 works) | Matches `otp_length`. The code fields accept 6 to 10 digits (`EmailCodePolicy`), so a different hosted length still works |
| Authentication → Providers → Email | Secure password change | Either | Change Password signs in again first, which counts as a recent login |
| Authentication → Emails → Confirm signup | Body includes `{{ .Token }}` | Required | Registration asks for the code, not a link. Copy `supabase/templates/confirmation.html` |
| Authentication → Emails → Reset password | Body includes `{{ .Token }}` | Required | Forgot Password asks for the code, not a link. Copy `supabase/templates/recovery.html` |
| Authentication → Rate limits | Emails sent per hour | High enough for sign-ups plus resets | Each registration and each password reset sends one email |
| Authentication → Providers → Email | Leaked password protection | Optional (paid plans) | The app shows a specific message when a password is found in a breach |
| Authentication → Emails (security notifications, where available) | Password changed | Optional | Emails the user when their password changes; no app code needed |

## Rotating a secret

1. Set the new value with `supabase secrets set` (or update the Vault secret with `vault.update_secret`).
2. For `PUSH_DISPATCH_SECRET`, update the Vault secret `push_dispatch_secret` to the same value right away, or pushes stop.
3. Edge Functions pick up new values on their next cold start; redeploying forces it.
