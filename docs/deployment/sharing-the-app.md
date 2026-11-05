# Sharing AESS with alumni

**Saved:** 2026-11-06  
**Decision:** keep the live website on Firebase Hosting, and put the Android install file on a GitHub Release.

## What to share

| Channel | Use it for | Link |
|---|---|---|
| Firebase Hosting | Opening the app in a browser, and Add to Home Screen | https://ustp-aess.web.app and https://ustp-aess.firebaseapp.com |
| GitHub Release | The Android APK alumni install | A release on `Ralph722/AESS_Capstone_Project` |
| Google Drive | Do not use for the APK | Drive warns on APK files and the download page is harder to follow |

iPhone alumni use the website. A sideloaded iOS app is not a free option. Google Play is a one-time fee (about $25). The App Store is about $99 a year.

## Downloads do not grow the database

Alumni records live in Supabase. A download does not insert a row. Supabase grows when people register and use the app, whichever link they used.

Firebase Hosting stores the website once. Each visit counts against hosting transfer, not against a database. The free hosting allowance is about 10 GB of transfer per month. An APK is often 20–40 MB, so a few hundred installs from that site can use the month’s allowance. That is why the APK stays off Firebase Hosting.

A GitHub Release stores each APK once, keeps older versions, and those downloads do not use the Firebase transfer allowance or Supabase.

## Cutting an Android release

From the project root:

```powershell
flutter build apk --release
```

The file is `build/app/outputs/flutter-apk/app-release.apk`. Rename it to something alumni can recognize, such as `AESS-1.0.0.apk`, then attach it to a GitHub Release. Share that release URL when someone needs an installable Android file. Everyone else gets https://ustp-aess.web.app.
