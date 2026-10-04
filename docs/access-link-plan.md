# Shareable access link and QR code (plan)

Status: planned, not implemented. Agreed on 2026-10-02.

Goal: let alumni open the portal from a link or QR code posted on Facebook and
other platforms, so people who rarely open the app can still reach it and
register.

Interactive walkthrough of the user journeys (admin shares the link, new
alumnus from Facebook, existing alumnus, non-alumni visitor, results):
`~/.cursor/projects/c-aess-systemproj/canvases/access-link-walkthrough.canvas.tsx`

## Decisions so far

- Web link only. No Android APK download button for now.
- Coding can start before hosting. The link and QR only work for other people
  once the app is live at a public `https://` address, so do not post a QR
  code until the final address is decided.
- Hosting: Firebase Hosting on the existing `aess-alumni` project is the
  recommendation (see "Hosting" below). Vercel or Cloudflare Pages are the
  alternatives if no billing card can be added.
- Open: whether to build the optional tracking phase (phase 3), and approval
  of the `qr_flutter` package (check version and license first).

## Link format

```
https://<public-address>/?go=register&src=facebook
```

| Part | Meaning |
|---|---|
| `https://<public-address>/` | Where the web app is hosted. Read from one config value. |
| `go=register` | Signed-out visitors land on registration instead of login. Signed-in users go straight to Home. |
| `src=facebook` | Label for which platform brought the visitor. Only known labels are accepted (e.g. `facebook`, `messenger`, `email`, `poster`). |

The link is the same for everyone and carries no secrets, tokens or personal
data. Registration is still gated by the official alumni roster check.

## Phase 1: make the link work well (no hosting needed)

1. Read the link options at startup with `Uri.base.queryParameters`, the same
   way `notification_route` is handled in
   `lib/features/notifications/push/web_push_bridge_web.dart`. No routing
   rewrite: the app keeps `home: AuthGate()` and hash URLs.
   - `go=register`: when `AuthGate` shows `LoginScreen`, push `RegisterScreen`
     on top once.
   - `src=...`: keep the label for the session (used by phase 3).
   - Remove the options from the address bar afterwards (`history.replaceState`).
2. Fix `web/index.html` and `web/manifest.json`. They currently say
   `alumni_system` and "A new Flutter project.":
   - Title "AESS Alumni Portal" and a real description.
   - Open Graph tags (`og:title`, `og:description`, `og:image` with an absolute
     URL, `og:url`) so Facebook shows a proper preview card. Facebook reads
     these from the HTML without running the app.
   - Navy theme colour instead of `#0175C2`.
   - Lightweight branded HTML loading screen so the Facebook in-app browser
     does not show a blank white page while the app downloads.
3. "Open in Chrome" tip: detect Facebook/Messenger/Instagram in-app browsers
   by user agent (`FBAN`, `FBAV`, `Instagram`, `Messenger`) and show a
   dismissible banner. Push notifications do not work inside those browsers
   and sessions may be cleared more often.

## Phase 2: admin "Access Link & QR" page

- New admin sidebar item. Adding a page takes three steps:
  1. Add an `AdminNavItem` with an unused index (3, 8, or 16+) to
     `kAdminNavSections` in
     `lib/features/admin/dashboard/widgets/admin_dashboard_shell.dart`.
  2. Add the index to `_pageOrder` in
     `lib/features/admin/dashboard/presentation/admin_dashboard_page.dart`.
  3. Add a `case` in `_buildPageForMenu` in the same file.
- Page contents:
  - Public link with a Copy button (`Clipboard.setData`, already used in the app).
  - Platform chips (Facebook, Messenger, Email, Poster) that set `src=`.
  - QR code preview and "Download QR (PNG)". Needs `qr_flutter`; approve
    after checking version and license.
  - Suggested post caption with a Copy button.
- The public address comes from one config value (e.g. a `--dart-define` with
  a default), so moving to the real address is a one-line change.

## Phase 3 (optional): registrations by source

- New table (e.g. `registration_sources(user_id, source, created_at)`) with
  its own RLS: the user can insert their own row, admins can read. Existing
  tables and RLS stay unchanged.
- Save the `src` label when registration completes.
- Show counts per source on the admin page.
- Count completed registrations only. Do not record anonymous visits, which
  would require letting anyone write to the database.

## Phase 4: go live

1. Host the web build. Firebase Hosting:
   - Add `firebase.json` (public `build/web`, rewrite all paths to
     `/index.html`, cache headers).
   - Update `deploy.sh`, which still targets the old project `alumni-3fb4d`.
2. Supabase dashboard: set Auth "Site URL" and redirect URLs to the live
   address (`supabase/config.toml` only has local `127.0.0.1:3000` values).
3. Set the real address in the link config.
4. Check the preview card with Facebook's Sharing Debugger.
5. Only then download and post the final QR code.
6. Later, optional:
   - Custom domain.
   - Android App Links so the link opens the installed app. This needs
     `assetlinks.json` on the host and changing the app ID from
     `com.example.alumni_system`, which also means re-registering the Android
     app in Firebase for push. Best done just before a Play Store release.

## Hosting

Each first-time visitor downloads roughly 2–4 MB from the host (main app file
6.7 MB before compression, plus images and fonts; CanvasKit is loaded from
Google's CDN). Returning visitors use their cache.

| | Firebase Hosting | Vercel |
|---|---|---|
| Setup | Same `aess-alumni` project as push | New account and CLI |
| Free data limit | 360 MB per day (about 100–150 new visitors a day) | 100 GB per month |
| If exceeded | Site stops serving until the next day, unless on the pay-as-you-go plan (about $0.15 per GB) | Usage paused or upgrade requested |
| Free plan terms | Any use | "Hobby" is personal and non-commercial only |
| Flutter build | Build locally, `firebase deploy` | Build locally, upload the prebuilt output |

Recommendation: Firebase Hosting. Before posting the link on Facebook, switch
`aess-alumni` to the pay-as-you-go plan with a small budget alert (e.g. $1),
so a busy announcement day costs cents instead of taking the site offline.
