# Awda Physical Therapy — Project Audit

## 1. Responsive UI & Assets

### Implemented
- **`lib/core/responsive.dart`** — Central breakpoints and helpers:
  - **Breakpoints:** mobile &lt; 600px, tablet 600–1200px, desktop ≥ 1200px
  - **Helpers:** `contentMaxWidth`, `bodyPadding`, `logoSizeLarge`, `logoSizeAppBar`, `logoSizeDrawer`, `formMaxWidth`
  - **Extension:** `context.responsive` for easy access
- **Login screen** — Uses `LayoutBuilder` + `context.responsive`: responsive padding, form max width, and logo size (`logoSizeLarge`).
- **Dashboard** — AppBar logo uses `logoSizeAppBar`, Drawer header uses `logoSizeDrawer`, body uses `bodyPadding` and `contentMaxWidth`.
- **Assets** — Logo (`assets/CenterLogoWithoutWords.jpeg`) used via `AppLogo` widget with configurable size; scales with breakpoints on Login and Dashboard.
- **List screens** (Users, Appointments, My Appointments, Patients, Income/Expenses, Profile, Patient detail) — Use `ListView`/scroll views and fixed padding (16–24); content adapts to width. For tablet/desktop you can later wrap lists in `LayoutBuilder` and use `responsive.bodyPadding` or a grid for wide layouts.

### Recommendation
- Use `context.responsive.bodyPadding` for `ListView.builder` padding on all list screens for consistent horizontal padding on phone/tablet/desktop.
- On wide screens, consider grid or master-detail for lists (e.g. Patients list + detail side by side).

---

## 2. Features (by area)

### Authentication
- **Login** — Email + password; error display; redirect to dashboard on success; link to Register.
- **Register** — Email, password, full name (AR/EN), phone; creates Firestore `users/{uid}` with role `patient`, `isActive: true`; redirect to dashboard.
- **Logout** — AppBar action; signs out Firebase Auth and redirects to `/login`.
- **Auth state** — `AuthProvider` listens to `authStateChanges`, loads `users/{uid}` for profile/role; redirect if not logged in or if user is inactive.

### Role-based access
- **admin** — Users, Appointments, Patients, Income & expenses, Dashboard.
- **doctor** — Appointments (own), Patients, Patient detail, Dashboard.
- **secretary** — Users, Appointments, Dashboard.
- **patient** — My Appointments, Profile, Dashboard.
- **trainee** — Dashboard only (no extra nav items; can be extended in `canAccessRoute`).
- Route redirect and drawer items use `canAccessRoute(role, path)`.

### Screens
| Screen | Route | Who | Description |
|--------|--------|-----|-------------|
| Login | `/login` | All | Email/password form, logo, title. |
| Register | `/register` | All | Full name (AR/EN), phone, email, password. |
| Dashboard | `/dashboard` | All | Welcome + role; drawer with role-based links; AppBar: logo, language, theme, logout. |
| Users | `/users` | Admin, Secretary | List users; filter by role; admin: change role + isActive. |
| Appointments | `/appointments` | Admin, Secretary, Doctor | List appointments (doctor: own); update status (confirm/complete/cancel/no_show). |
| My Appointments | `/my-appointments` | Patient | List current user’s appointments. |
| Profile | `/profile` | Patient | User info + sessions + documents for current user. |
| Patients | `/patients` | Admin, Doctor | List patients (role=patient). |
| Patient detail | `/patients/:id` | Admin, Doctor | Patient info, sessions, documents. |
| Income & expenses | `/income-expenses` | Admin (and Secretary per rules) | Totals (income, expense, net); list income/expense; add income/expense dialogs. |

### Localization & theme
- **i18n** — Arabic (ar) and English (en); `AppLocalizations` with `_ar` / `_en` maps; RTL via `Directionality` in `main.dart` builder.
- **Theme** — Light/dark via `ThemeProvider`; persisted with `shared_preferences`; `AppTheme.light()` / `AppTheme.dark()`.

### Navigation
- **go_router** — All routes defined; redirect for unauthenticated and inactive user; path params for `/patients/:id`.

---

## 3. Database (Firestore) — Configuration & Usage

### Firebase configuration
- **`lib/firebase_options.dart`** — Configured for:
  - **Web:** projectId `awdacenter-eb0a8`, authDomain, storageBucket, apiKey, appId.
  - **Android / iOS / macOS:** same project; iOS/macOS share bundle id `com.faroukahmed.awdacenter`.
  - **Windows:** still placeholder (run `flutterfire configure --platforms=windows` if needed).
- **Initialization** — `main()` runs `Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)` before `runApp()`.

### Firestore collections used by the app
| Collection | Used in | Purpose |
|------------|---------|---------|
| **users** | Auth, Users screen, Patients, Appointments | Profile (email, name, phone, role, isActive); doc id = Auth UID. |
| **doctors** | Appointments (doctor filter) | Links userId to doctor record. |
| **doctor_availability** | (Rules only; no UI yet) | Slots per doctor. |
| **rooms** | (Rules only; no UI yet) | Room list. |
| **appointments** | Appointments, My Appointments | CRUD + status updates. |
| **sessions** | Profile, Patient detail | List by patientId. |
| **patient_profiles** | Profile, Patient detail | Extra patient info. |
| **patient_documents** | Profile, Patient detail | List by patientId. |
| **income_records** | Income & expenses | List + add. |
| **expense_records** | Income & expenses | List + add. |

### Firestore service (`lib/services/firestore_service.dart`)
- **Users:** `getUsers(roleFilter)`, `getPatients()`, `getUser(uid)`.
- **Doctors / Rooms:** `getDoctors()`, `getRooms()`.
- **Appointments:** `getAppointments(from, to, doctorId, patientId)`, `updateAppointmentStatus()`, `createAppointment()`.
- **Sessions:** `getSessionsForPatient(patientId)`.
- **Patient:** `getPatientProfile(userId)`, `getPatientDocuments(patientId)`.
- **Income/Expense:** `getIncomeRecords()`, `getExpenseRecords()`, `addIncomeRecord()`, `addExpenseRecord()`.
- Queries use valid Firestore constraints; date/role filters applied in memory where needed to avoid composite indexes.

### Auth service (`lib/services/auth_service.dart`)
- Sign in, register, sign out; `getCurrentUserProfile()` reads `users/{uid}`; `updateUserRole()`, `updateUserActive()` for admin.

---

## 4. Firestore security rules

- **Location:** `firestore.rules` in project root.
- **Deploy:** Firebase Console → Firestore → Rules (paste contents), or `firebase deploy --only firestore:rules`.
- **Behavior:**
  - **users:** Read all authenticated; create only own doc; update/delete self or admin.
  - **doctors, rooms:** Read authenticated; write admin.
  - **doctor_availability:** Read authenticated; create admin or doctor; update/delete admin or doctor (own `doctorId`).
  - **appointments:** Read authenticated; create/update/delete admin, secretary, doctor.
  - **sessions:** Read authenticated; create/update/delete admin, doctor.
  - **patient_profiles:** Read authenticated; create admin/doctor; update admin/doctor or own profile; delete admin.
  - **patient_documents:** Read authenticated; create/update/delete admin, doctor.
  - **income_records, expense_records:** Read/write admin or secretary.

**Note:** `userRole()` in rules uses `get(users/$(request.auth.uid))`. If that document is missing (e.g. right after sign-up before the app writes it), the rule can fail. Ensure the app always writes `users/{uid}` immediately after registration (already done in `AuthService.registerWithEmailAndPassword`).

---

## 5. App & platform configuration

- **Android** — Package `com.faroukahmed.awdacenter`; `google-services.json`; launcher icon from logo.
- **iOS** — Bundle id `com.faroukahmed.awdacenter`; `GoogleService-Info.plist`; launcher icon.
- **Web** — `firebase_options` web config; `index.html` favicon + title; `manifest.json` name/short_name and icons.
- **macOS** — Uses iOS Firebase config; launcher icon generation was skipped (can be redone with `flutter_launcher_icons` when macOS is supported).

---

## 6. Checklist: DB and configuration

| Item | Status |
|------|--------|
| Firebase initialized with `DefaultFirebaseOptions.currentPlatform` | Yes |
| Web/Android/iOS/macOS have real project ids and apiKeys in `firebase_options.dart` | Yes (Windows placeholder) |
| Auth: email/password sign-in and registration | Yes |
| Firestore: users doc created on register | Yes |
| Firestore: role stored in `users/{uid}.role` | Yes |
| Firestore rules deployed (user responsibility) | Rules file present |
| First admin: set `users/<uid>.role = 'admin'` and `isActive = true` in Console | Documented in README / SETUP_AND_RUN |
| Router redirect when not logged in / inactive | Yes |
| Role-based drawer and route access | Yes |

---

## 7. Summary

- **Responsive:** Central breakpoints and responsive helpers are in place; Login and Dashboard use them for padding, max width, and logo sizes; other screens can adopt `context.responsive.bodyPadding` (and optional grid) for consistency.
- **Features:** Auth, role-based navigation, all listed screens (Users, Appointments, My Appointments, Profile, Patients, Patient detail, Income & expenses), i18n (AR/EN), RTL, light/dark theme, and logout are implemented.
- **DB:** Firestore usage matches the described collections and security rules; configuration is correct for web, Android, iOS, and macOS. Ensuring rules are deployed and the first admin is set in Firestore will make the app work end-to-end.
