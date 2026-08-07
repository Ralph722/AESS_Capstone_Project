# Restore admin account (Auth + Firestore)

If you deleted all users in **Firebase Authentication** and the **`users`** collection, the app cannot route anyone to the admin dashboard. Admin access requires **both**:

1. A row in **Authentication** (email + password)
2. A document **`users/{uid}`** with **`role`: `"admin"`** (document ID must equal the Auth UID)

---

## Option A — Firebase Console (about 5 minutes, no code)

### Step 1 — Create Authentication user

1. Open [Firebase Console](https://console.firebase.google.com/) → project **alumni-3fb4d**
2. **Build** → **Authentication** → **Users** → **Add user**
3. Enter the admin **email** and **password** you want (min. 8 characters)
4. Click **Add user**
5. Copy the **User UID** (long string like `xYz123...`)

### Step 2 — Create Firestore `users` document

1. **Build** → **Firestore Database** → collection **`users`**
2. **Add document**
3. **Document ID:** paste the **UID** from Step 1 (must match exactly)
4. Add fields:

| Field | Type | Value |
|-------|------|--------|
| `uid` | string | same UID |
| `role` | string | `admin` |
| `email` | string | admin email |
| `displayName` | string | e.g. `Alumni Admin` |
| `tracerProfileComplete` | boolean | `true` |
| `tracerProfileCompletion` | number | `100` |
| `onboardingComplete` | boolean | `true` |
| `createdAt` | timestamp | now |

5. **Save**

### Step 3 — Log in

1. Run the app: `flutter run -d chrome`
2. Log in with the email and password from Step 1
3. You should land on the **Admin Dashboard**

> **Important:** Log in only **after** Step 2 is done. If you log in before the Firestore doc exists, the app used to create a `user` profile automatically (fixed in code now).

---

## Option B — Automated script (Node.js)

From the project root:

```powershell
cd "c:\Users\Acer Laptop\alumni_system\scripts\restore_admin"
npm install
```

Download **service account key**:

1. Firebase Console → ⚙️ **Project settings** → **Service accounts**
2. **Generate new private key** → save as  
   `scripts/restore_admin/serviceAccountKey.json`  
   (do not commit this file)

Run:

```powershell
$env:GOOGLE_APPLICATION_CREDENTIALS=".\serviceAccountKey.json"
$env:ADMIN_EMAIL="your.admin@school.edu"
$env:ADMIN_PASSWORD="YourSecurePassword123!"
$env:ADMIN_DISPLAY_NAME="Alumni Admin"
npm run restore
```

Then log in with `ADMIN_EMAIL` / `ADMIN_PASSWORD`.

---

## Your old admin email

Deleted Auth accounts **cannot be recovered** unless you remember the email/password. Use a **new** admin email in the steps above (school Gmail is fine).

---

## Other collections

Deleting **`users`** does **not** delete `alumni_members`, `events`, `jobs`, etc. Only recreate **`users`** for admin (and later alumni as they register).

If **`audit_logs`** or other collections were removed, they are optional; the app will create new logs as you use it.

---

## Still stuck?

- **Wrong password / user-not-found:** recreate the user in Authentication.
- **Logs in but opens user portal:** Firestore `users/{uid}.role` is not `admin` or document ID ≠ Auth UID.
- **Permission denied:** deploy rules: `firebase deploy --only firestore:rules`
