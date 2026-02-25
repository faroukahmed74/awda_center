# Awda Center — عودة للعلاج الطبيعي

A Flutter app for a physical therapy clinic: appointments, patient profiles, sessions, income/expenses, and multi-role users. Single codebase for **Web**, **Android**, **iOS**, and **Windows**. Backend: **Firebase** (Auth, Firestore, Storage, Messaging).

---

## Features

### User roles
- **admin** — Full access: users, appointments, patients, income/expenses, reports, requirements, admin todos, rooms, doctors admin, audit log.
- **secretary** — Users, appointments, reports (configurable via privileges).
- **doctor** — Appointments, patients, reports; doctor profile and availability.
- **patient** — My appointments, profile; book appointments with doctors.
- **trainee** — Limited; privileges configurable by admin.

Role-based dashboards and navigation. Admins can grant **per-feature privileges** to any user (e.g. give a secretary access to income/expenses).

### Main screens
| Screen | Description |
|--------|-------------|
| Login / Register / Forgot password | Email/password auth |
| Dashboard | Role-specific; today’s appointments, quick links |
| Admin dashboard | Admin-only overview and shortcuts |
| Users | List and manage users (admin/secretary) |
| Appointments | Create, edit, reschedule; filter by doctor/date |
| My Appointments | Patient/doctor view of own appointments |
| Profile | View/edit own info; change language and theme |
| User profile | View another user (by role) |
| Patients | Patient list and search |
| Patient detail | Profile, documents, sessions, appointments |
| Income & expenses | Records and summaries |
| Reports | Clinic reports |
| Requirements | Center requirements (e.g. compliance) |
| Admin todos | Admin task list |
| Rooms | Room management |
| Doctors | Doctor list (and admin: doctor management) |
| My doctor profile | Doctor’s own profile and availability |
| Audit log | Audit trail (admin) |

### Internationalization (i18n)
- **Arabic** and **English** with RTL support for Arabic.
- Language choice persisted; app restarts with selected locale.

### Theme
- **Light** and **dark** mode; preference persisted.

### Responsive layout
- Layout adapts to phone, tablet, and desktop (e.g. constrained width on large screens, responsive padding, ellipsis for long text).

### Notifications
- Firebase Cloud Messaging for push notifications.
- Local notifications for appointment reminders (patient and doctor); rescheduled when appointments are created or updated.

---

## Prerequisites

- **Flutter SDK** (stable, with Dart 3.9+) — [flutter.dev](https://flutter.dev)
- **Firebase project** — [console.firebase.google.com](https://console.firebase.google.com)
- For **iOS**: macOS and Xcode (for device/App Store builds)
- For **Android**: Android SDK (included with Flutter)

---

## Setup

### 1. Clone and install

```bash
git clone https://github.com/YOUR_USERNAME/awda_center.git
cd awda_center
flutter pub get
```

### 2. Configure Firebase (FlutterFire CLI)

Generate `lib/firebase_options.dart` and platform config files (do **not** commit this file; it contains project-specific keys):

```bash
dart run flutterfire configure
```

Select or create a Firebase project and choose the platforms you need (Android, iOS, Web, Windows).

### 3. Enable Firebase services

- **Authentication**: Enable **Email/Password** sign-in.
- **Firestore Database**: Create the database (test mode is fine for development).
- **Storage**: Enable if you use patient documents or file uploads.
- **Cloud Messaging**: Enable for push and appointment reminders.

### 4. Deploy Firestore rules

Copy the contents of `firestore.rules` into Firebase Console → **Firestore** → **Rules**, or deploy via Firebase CLI:

```bash
firebase deploy --only firestore:rules
```

(Ensure `firestore.rules` is in the project root when using CLI.)

### 5. First admin user

After the first user registers (e.g. yourself):

1. Open **Firestore** in Firebase Console.
2. Go to the `users` collection.
3. Find the document whose ID is the new user’s **Firebase Auth UID**.
4. Set:
   - `role` = `admin`
   - `isActive` = `true`

That user can then log in as admin and manage other users and app data.

---

## Run the app

```bash
# Web
flutter run -d chrome

# Android
flutter run -d android

# iOS
flutter run -d ios

# Windows
flutter run -d windows
```

---

## Build for release

Run each in a separate terminal if you want parallel builds.

### Android (APK)

```bash
flutter build apk --release
```

Output: `build/app/outputs/flutter-apk/app-release.apk`

### iOS

```bash
flutter build ios --release
```

For App Store archive:

```bash
flutter build ipa
```

Then open the generated `.ipa` in Xcode (Organizer) or Transporter and complete signing/distribution.

### Web

```bash
flutter build web --release
```

Output: `build/web/`. Deploy the contents to any static host (Firebase Hosting, Vercel, Netlify, etc.).

---

## Upload to Google Play and App Store

### iOS: Archive and upload to App Store

1. **Build the IPA (archive):**
   ```bash
   flutter build ipa
   ```
   Output: `build/ios/ipa/*.ipa` and the archive in `build/ios/archive/Runner.xcarchive`.

2. **Upload to App Store Connect:**
   - **Option A:** Open Xcode → **Window → Organizer** → select the archive → **Distribute App** → **App Store Connect** → follow the wizard (upload, then select the app in App Store Connect).
   - **Option B:** Install [Transporter](https://apps.apple.com/app/transporter/id1450874784) from the Mac App Store, then drag the `.ipa` from `build/ios/ipa/` into Transporter and deliver.

3. **In App Store Connect** ([appstoreconnect.apple.com](https://appstoreconnect.apple.com)):
   - Create the app if needed (bundle ID: `com.faroukahmed.awdacenter`).
   - In the app → **TestFlight** or **App Store** tab: the new build appears after processing.
   - Complete **App Information**, **Pricing**, **App Privacy**, **Version** (screenshots, description, keywords, etc.).
   - Submit the version for **Review**.

**Requirements:** Apple Developer account ($99/year), valid signing & provisioning in Xcode.

---

### Android: Upload to Google Play

1. **Build an Android App Bundle (preferred by Google):**
   ```bash
   flutter build appbundle --release
   ```
   Output: `build/app/outputs/bundle/release/app-release.aab`

2. **Create a Google Play Developer account** ([play.google.com/console](https://play.google.com/console)) — one-time $25 registration.

3. **Create the app** in Play Console:
   - **All apps → Create app** → fill name (e.g. Awda Center), default language, app or game, free/paid.

4. **Complete the dashboard:**
   - **Store listing:** short/full description, graphics (icon 512×512, feature graphic 1024×512), screenshots (phone 16:9 or 9:16, tablet if needed).
   - **Content rating:** run the questionnaire and submit.
   - **Target audience:** age groups.
   - **News app / COVID-19 apps:** declare if applicable.
   - **Data safety:** declare what data the app collects (e.g. email, Firebase).

5. **Upload the AAB:**
   - Go to **Release → Production** (or **Testing → Internal/Closed** first).
   - **Create new release** → upload `app-release.aab` from step 1.
   - Add **Release notes**, then **Review release** and **Start rollout**.

**Requirements:** Google Play Developer account, signing key (Flutter release build is already signed if configured in `android/app/build.gradle`).

---

## Updating the app (new features or bug fixes)

When you add features or fix bugs and want to ship a new version to Google Play and the App Store:

### 1. Bump the version

In **`pubspec.yaml`** update the `version` line:

```yaml
# Format: versionName+buildNumber
# Android: versionName = 1.0.0, versionCode = 2
# iOS:     CFBundleShortVersionString = 1.0.0, CFBundleVersion = 2
version: 1.0.0+2
```

- **First number (e.g. 1.0.0):** User-visible version. Increase when you have a notable release (e.g. 1.0.1 for a small fix, 1.1.0 for new features).
- **After the + (e.g. 2):** Build number. **Must increase for every upload** to each store (Google Play and App Store both require a higher build number than the previous release).

Example: after your first release was `1.0.0+1`, use `1.0.0+2` for the next upload, then `1.0.1+3`, etc.

### 2. Build the release artifacts

```bash
# Android (AAB for Google Play)
flutter build appbundle --release

# iOS (IPA for App Store)
flutter build ipa
```

Outputs:
- Android: `build/app/outputs/bundle/release/app-release.aab`
- iOS: `build/ios/ipa/*.ipa` (and archive in `build/ios/archive/`)

### 3. Upload to Google Play

1. Open [Google Play Console](https://play.google.com/console) → your app.
2. **Release → Production** (or **Testing → Internal/Closed** to test first).
3. **Create new release** → upload the new `app-release.aab`.
4. Add **Release notes** (what’s new or what you fixed).
5. **Review release** → **Start rollout**.

Users get the update via the Play Store when you roll out; no new listing needed if you only changed the build.

### 4. Upload to App Store

1. **Upload the build:**
   - **Option A:** Xcode → **Window → Organizer** → select the archive from `build/ios/archive/` (or from a new archive via **Product → Archive**) → **Distribute App** → **App Store Connect**.
   - **Option B:** Open [Transporter](https://apps.apple.com/app/transporter/id1450874784), drag the `.ipa` from `build/ios/ipa/` and deliver.
2. In [App Store Connect](https://appstoreconnect.apple.com) → your app:
   - The new build appears under **TestFlight** and **App Store** after processing.
   - If this is an update to an existing version: **App Store** tab → your version → select the new build.
   - Add **What’s New** (release notes) for the version.
   - Submit for **Review** when ready.

### 5. Backend / Firebase (if you changed them)

- **Firestore rules:** `firebase deploy --only firestore:rules`
- **Cloud Functions:** `firebase deploy --only functions`
- **Hosting (web):** `firebase deploy --only hosting` (if you deploy the Flutter web build to Firebase Hosting)

Deploy these when you change backend logic, rules, or the web app; they are independent of the mobile version number.

---

## Project structure

```
lib/
├── firebase_options.dart     # Generated by flutterfire configure (not committed)
├── main.dart
├── core/
│   ├── app_logo.dart
│   ├── app_permissions.dart  # Feature keys and role defaults
│   └── responsive.dart       # Breakpoints, responsive padding
├── l10n/
│   └── app_localizations.dart
├── models/
│   ├── user_model.dart
│   ├── appointment_model.dart
│   ├── session_model.dart
│   ├── patient_profile_model.dart
│   ├── doctor_model.dart
│   ├── room_model.dart
│   ├── income_expense_models.dart
│   ├── admin_todo_model.dart
│   ├── center_requirement_model.dart
│   └── audit_log_model.dart
├── providers/
│   ├── auth_provider.dart
│   ├── theme_provider.dart
│   └── locale_provider.dart
├── router/
│   └── app_router.dart       # go_router routes and redirects
├── screens/
│   ├── auth/
│   ├── dashboard/
│   ├── admin/
│   ├── users/
│   ├── appointments/
│   ├── patients/
│   ├── patient/
│   ├── profile/
│   ├── income_expenses/
│   ├── reports/
│   ├── requirements/
│   ├── admin_todos/
│   ├── rooms/
│   ├── doctors/
│   └── audit/
├── services/
│   ├── auth_service.dart
│   ├── firestore_service.dart
│   ├── storage_service.dart
│   ├── notification_service.dart
│   └── audit_service.dart
└── theme/
    └── app_theme.dart
```

Root files:
- `firestore.rules` — Firestore security rules (deploy to Firebase)
- `pubspec.yaml` — Dependencies and assets (e.g. app icon)

---

## Firestore collections (outline)

| Collection | Purpose |
|------------|---------|
| `users` | User profiles, role, `isActive`, optional `roles` and per-feature `permissions` |
| `doctors` | Doctor profile linked to `users`; availability in `doctor_availability` |
| `doctor_availability` | Slots per doctor |
| `rooms` | Room list for appointments |
| `appointments` | Appointments (patient, doctor, date, time, status, service, etc.) |
| `sessions` | Session records linked to patients/appointments |
| `patient_profiles` | Patient profile data |
| `patient_documents` | References to stored files (e.g. in Firebase Storage) |
| `income_records` | Income entries |
| `expense_records` | Expense entries |
| `admin_todos` | Admin task list |
| `center_requirements` | Requirements/compliance items |
| `audit_logs` | Audit trail entries |

See the code and `firestore.rules` for field names and security rules.

---

## Admin privileges (feature keys)

Admins can grant these features to any user via the Users screen (edit privileges):

- `admin_dashboard`
- `users`
- `appointments`
- `patients`
- `income_expenses`
- `reports`
- `requirements`
- `admin_todos`

Roles have default feature sets; privileges override or extend them.

---

## Firestore: clearing DB (keep admin-only)

To clear all Firestore data except admin users:

1. **Deploy rules** (if needed):
   ```bash
   firebase deploy --only firestore:rules --project awdacenter-eb0a8
   ```

2. **Run the clear script** (Node.js with Firebase Admin):
   - `cd scripts`, then `npm install`, then set `GOOGLE_APPLICATION_CREDENTIALS` to your Firebase service account JSON path.
   - Run: `node clear_firestore_keep_admins.js`.

   The script deletes all users who do **not** have role **admin**, and clears: `appointments`, `sessions`, `patient_profiles`, `patient_documents`, `doctors`, `doctor_availability`, `rooms`, `income_records`, `expense_records`, `center_requirements`, `admin_todos`, `audit_log`, `invites`. Only admin user(s) remain.

---

## License

Private / project-specific.
