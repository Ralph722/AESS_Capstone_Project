# Secrets Runbook

Where every server-side secret lives and how to recreate it on a new or restored Supabase project. Names only; never paste values into this file or into the repo.

## Edge Function secrets

Set with `supabase secrets set NAME=value --project-ref <ref>` or in Dashboard → Edge Functions → Secrets.

| Name | Used by | Where to get the value |
|---|---|---|
| `GMAIL_USER` | `send-email` | The Gmail address that sends AESS email |
| `GMAIL_APP_PASSWORD` | `send-email` | Google Account → Security → App passwords (requires 2-step verification) |
| `GMAIL_SENDER_NAME` | `send-email` | Display name on outgoing email (falls back to "Alumni System") |
| `GEMINI_API_KEY` | `tracer-help` | Google AI Studio |
| `GEMINI_MODEL` | `tracer-help` | Optional; defaults to `gemini-2.5-flash` |
| `PUSH_DISPATCH_SECRET` | `send-push` | Any long random string; must equal the Vault secret `push_dispatch_secret` |
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
| `lib/core/config/ai_secrets.dart` | Local Gemini key for development (`ai_secrets.example.dart` shows the shape) |

## Dashboard-only settings

These aren't stored in the repo and must be re-entered on a new project:

- Authentication → SMTP Settings (Gmail, once Supabase email confirmation is enabled).
- Authentication → URL Configuration (site URL and redirect URLs).
- Authentication → Email templates.

## Rotating a secret

1. Set the new value with `supabase secrets set` (or update the Vault secret with `vault.update_secret`).
2. For `PUSH_DISPATCH_SECRET`, update the Vault secret `push_dispatch_secret` to the same value right away, or pushes stop.
3. Edge Functions pick up new values on their next cold start; redeploying forces it.
