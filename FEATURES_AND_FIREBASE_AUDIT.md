# Awda Center — Features & Firebase/Firestore Audit

## 1. Responsive UI (All Platforms)

- **Breakpoints** (`lib/core/responsive.dart`): `mobile` 600px, `tablet` 900px, `desktop` 1200px. Used across Android, iOS, Web, and macOS.
- **Padding**: `ResponsivePadding.all(context)` — 12 (phone) / 16 / 20 / 24 (desktop). Applied to: Login, Register, Dashboard, Users, Appointments, My Appointments, Profile, Patients, Patient detail, Income & expenses.
- **Safe area**: Login and Register wrap body in `SafeArea`; Dashboard body uses `SafeArea` so content respects notches and system UI.
- **Form width**: `responsiveMaxFormWidth(context)` — forms capped at 480px on wider screens (Login, Register).
- **Content width**: `responsiveMaxContentWidth(context)` — dashboard content capped at 800px on desktop.
- **Logo**: `AppLogo(useResponsiveSize: true)` on login; dashboard uses `responsiveLogoSizeSmall(context)` and drawer logo scales by breakpoint.
- **Lists**: All list screens use `responsiveListPadding(context)` for list padding.
- **Theme**: Uses Material 2021 typography; system font size (accessibility) is respected via `MediaQuery` on all platforms.

---

## 2. All App Features (Codebase Summary)

### 2.1 Authentication
- **Login** (`/login`): Email + password; **Sign in with Google** (all platforms); error display; redirect to dashboard on success; link to Register.
- **Google Sign-In**: **Web**: Firebase `signInWithPopup(GoogleAuthProvider())`. **Android / iOS / macOS**: `google_sign_in` plugin then `signInWithCredential`. New Google users get a Firestore `users/{uid}` doc with role `patient` automatically.
- **Register** (`/register`): Email, password, fullNameAr, fullNameEn, phone; creates Firestore `users/{uid}` with role `patient`, `isActive: true`; redirect to dashboard.
- **Logout**: App bar action on dashboard; signs out Firebase Auth (and Google on non-web); redirect to `/login`.
- **Auth state**: `AuthProvider` listens to `authStateChanges`, loads `users/{uid}` for role; redirect if not logged in or if `isActive == false`.

### 2.2 Role-Based Access
- **admin**: **Admin Dashboard** (`/admin-dashboard`), Users, Appointments, Patients, Income & expenses, Dashboard. Can invite users (email + role), set any user role, enable/disable accounts.
- **doctor**: Appointments (filtered by own doctorId), Patients, Patient detail, Dashboard.
- **secretary**: Users, Appointments, Dashboard.
- **patient**: My Appointments, Profile, Dashboard.
- **trainee**: Dashboard only (no extra nav items; can be extended in drawer).
- Route guard: `canAccessRoute(role, path)` used in drawer; router redirect sends unauthenticated to `/login`.

### 2.3 Screens & Flows
| Screen | Route | Who | Description |
|--------|--------|-----|-------------|
| Login | `/login` | All | Email/password form, logo, RTL/locale from context. |
| Register | `/register` | All | Full name (AR/EN), phone, email, password. |
| Dashboard | `/dashboard` | All | Welcome + role; drawer with role-based links; app bar: logo, title, language, theme, logout. |
| Users | `/users` | Admin, Secretary | List users; filter by role (in memory); admin: change role (Dropdown), toggle isActive. |
| Appointments | `/appointments` | Admin, Secretary, Doctor | List appointments (last 30 days; doctor sees own); PopupMenu: confirm, complete, cancel, no_show. |
| My Appointments | `/my-appointments` | Patient | List current user’s appointments; doctor name, date, time, status. |
| Profile | `/profile` | Patient | User info; list sessions; list patient_documents. |
| Patients | `/patients` | Admin, Doctor | List patients (role patient); tap → Patient detail. |
| Patient detail | `/patients/:id` | Admin, Doctor | User + patient_profile; sessions list; patient_documents list. |
| Income & expenses | `/income-expenses` | Admin, Secretary | Total income, total expenses, net; lists; add income / add expense dialogs (amount, source/category, date). |

### 2.4 Localization & Theme
- **i18n**: `AppLocalizations` (AR/EN); all UI strings from `l10n`; RTL when locale is Arabic (`Directionality` in main builder).
- **Theme**: Light/dark via `ThemeProvider`; persisted with `shared_preferences`; applied in `MaterialApp.router` theme/darkTheme/themeMode.
- **Locale**: Persisted; toggle in app bar; `supportedLocales: [en, ar]`, `LocalizationsDelegate` for `AppLocalizations`.

### 2.5 Assets & Branding
- **Logo**: `assets/CenterLogoWithoutWords.jpeg`; used in Login, Dashboard (title + drawer), and as app/launcher icon (Android, iOS, Web) via `flutter_launcher_icons`.
- **Responsive logo**: Sizes by breakpoint (e.g. login uses `responsiveLogoSize`).

### 2.6 Data (Firestore)
- **users**: Document ID = Auth UID; email, fullNameAr, fullNameEn, phone, role, isActive, createdAt, updatedAt.
- **doctors**, **doctor_availability**, **rooms**: Used by services; UI lists appointments/patients (doctors/rooms can be shown where needed).
- **appointments**: patientId, doctorId, roomId?, appointmentDate, startTime, endTime, status, service?, costAmount?, notes?, createdByUserId?, createdAt, updatedAt.
- **sessions**: appointmentId?, patientId, doctorId, sessionDate, startTime, endTime, sessionType, service?, feesAmount?, etc.; listed in Profile and Patient detail.
- **patient_profiles**: Document ID = userId; userId, dateOfBirth, gender, address, diagnosis, etc.
- **patient_documents**: patientId, documentType, filePathOrUrl, fileName, etc.; listed in Profile and Patient detail.
- **income_records**, **expense_records**: amount, source/category, dates, recordedByUserId; listed and added from Income & expenses screen.

---

## 3. Firebase Configuration

### 3.1 Initialization
- **main.dart**: `WidgetsFlutterBinding.ensureInitialized()` then `Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)` then `runApp(AwdaApp())`. Correct for all platforms.

### 3.2 firebase_options.dart
- **Android**: `projectId: awdacenter-eb0a8`, real apiKey, appId, storageBucket. OK.
- **iOS**: Same project, ios-specific apiKey/appId, `iosBundleId: com.faroukahmed.awdacenter`. OK.
- **Web**: Same project, authDomain, real apiKey/appId. OK.
- **macOS**: Uses same options as iOS (shared bundle id). OK.
- **Windows**: Still placeholder (projectId `awda-clinic-placeholder`). For Windows release, run `flutterfire configure` and add Windows app in Firebase Console.

### 3.3 Firebase Auth
- **AuthService**: `signInWithEmailAndPassword`, `createUserWithEmailAndPassword`, `signOut`; `getCurrentUserProfile()` reads `users/{uid}` after auth. Registration creates `users/{uid}` with `toFirestore()`. No custom token; email/password only. Matches Firestore rules (create only own user doc).

### 3.4 Firestore Usage
- **Auth**: Read/write `users` as per rules (own doc on register; admin/self update).
- **Users screen**: `getUsers(roleFilter)` — `users` orderBy createdAt; role filter in memory. Works with rules (read if isAuth).
- **Appointments**: `getAppointments(from, to, doctorId, patientId)`; `updateAppointmentStatus`; `createAppointment`. Rules: read all auth; create/update/delete admin/secretary/doctor. OK.
- **Sessions**: `getSessionsForPatient`; rules: read auth; write admin/doctor. OK.
- **Patient profile/documents**: `getPatientProfile`, `getPatientDocuments`; rules allow read for auth, write admin/doctor (and profile update by patient on own doc). OK.
- **Income/expense**: `getIncomeRecords`, `getExpenseRecords`, `addIncomeRecord`, `addExpenseRecord`. Rules: read/write admin or secretary. OK.
- **Indexes**: If you use `orderBy('createdAt')` or `orderBy('appointmentDate')` with `where`, Firestore may require composite indexes. The app uses in-memory filters where needed to reduce index requirements; add any indexes suggested in the Firebase Console errors when testing.

---

## 4. Firestore Security Rules — Verification

| Collection | Read | Create | Update/Delete | Notes |
|------------|------|--------|----------------|------|
| users | isAuth | isAuth && request.auth.uid == userId | self or admin | OK. |
| doctors | isAuth | admin | admin | OK. |
| doctor_availability | isAuth | admin or doctor | admin or (doctor && resource.data.doctorId == request.auth.uid) | If doctorId is stored as UID, doctor can update own. If doctorId is doctor doc ID, you may need to allow by matching doctor’s userId in app or adjust rule. |
| rooms | isAuth | admin | admin | OK. |
| appointments | isAuth | admin/secretary/doctor | admin/secretary/doctor | OK. |
| sessions | isAuth | admin/doctor | admin/doctor | OK. |
| patient_profiles | isAuth | admin/doctor | admin/doctor or profileId == request.auth.uid | OK. |
| patient_documents | isAuth | admin/doctor | admin/doctor | OK. |
| income_records | admin or secretary | same | same | OK. |
| expense_records | admin or secretary | same | same | OK. |

- **userRole()** in rules does `get(users/$(request.auth.uid)).data.role`. If the user doc is missing (e.g. first login before doc exists), the rule can throw. Ensure registration creates the user doc before redirecting; then only logged-in users with a doc hit protected routes. OK as implemented.
- **Deploy**: Copy `firestore.rules` into Firebase Console → Firestore → Rules and publish, or use `firebase deploy --only firestore:rules`.

---

## 5. Checklist for “All Configurations Work Successfully”

1. **Firebase project**: Same project (`awdacenter-eb0a8`) for Android, iOS, Web, macOS in `firebase_options.dart`. Windows still placeholder.
2. **Auth**: In Firebase Console → Authentication → Sign-in method, enable **Email/Password**.
3. **Firestore**: Database created; rules deployed from `firestore.rules`; add composite indexes if requested in console when running the app.
4. **First admin**: After first user registers, in Firestore set `users/<that-uid>.role = 'admin'` and `isActive = true`.
5. **Android**: `google-services.json` in `android/app/`, package `com.faroukahmed.awdacenter`; Google Services plugin applied in `app/build.gradle.kts`.
6. **iOS**: `GoogleService-Info.plist` in Xcode Runner target; bundle id `com.faroukahmed.awdacenter`.
7. **Web**: No extra script in `index.html`; Dart SDK uses `firebase_options.dart`. If Web auth fails, add a Web app in Firebase and run `flutterfire configure --platforms=web`.
8. **macOS**: Uses iOS config; no separate plist required for basic Auth/Firestore.

---

## 6. Summary

- **Responsive**: All main screens use breakpoints, responsive padding, SafeArea, and constrained widths so layout works on small phones, tablets, and desktop (Android, iOS, Web, macOS).
- **Features**: Auth (login/register/logout), role-based dashboard and drawer, Users, Appointments, My Appointments, Profile, Patients, Patient detail, Income & expenses, full i18n (AR/EN), RTL, light/dark theme persistence, app logo and launcher icons.
- **Firebase**: Initialization and `firebase_options.dart` are correct for Android, iOS, Web, and macOS (Windows is placeholder). Auth and Firestore usage match the provided security rules; deploy rules and enable Email/Password, then set the first admin in `users` for full functionality.
