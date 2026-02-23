# Awda Center — App Audit, Logic Verification & Suggestions

## 1. File upload (images/PDFs) — implemented

- **firebase_storage** and **file_picker** added.
- **StorageService** (`lib/services/storage_service.dart`): `pickAndUploadForPatient(patientId)` — picks image/PDF, uploads to `patient_docs/{patientId}/{timestamp}_{filename}`, returns download URL and filename.
- **Patient document dialog**: "Upload file (image or PDF)" button uploads to Storage and fills URL + title; "Or paste URL" still available. Works in the same add/edit flow.
- **Storage rules** (`storage.rules`): Authenticated users can read/write under `patient_docs/`. Deploy with: `firebase deploy --only storage`.
- **Note**: Enable Firebase Storage in the Firebase Console and deploy `storage.rules`. On web, ensure your storage bucket is authorized for the app domain.

---

## 2. Logic verification

### 2.1 Auth & redirect
- **Redirect**: Not logged in → `/login`. Logged in on `/login` or `/register` → `/dashboard`. User inactive → `/login`. Applied in `createAppRouter` redirect. **OK.**
- **Roles vs permissions**: Access uses `canAccessRoute(user, path)`: permission-based when `user.permissions` is set, else role-based. **OK.**

### 2.2 Doctor id vs user id (fixed)
- **Appointments** store `doctorId` = **doctors collection document id** (not auth uid).
- **My appointments**: Was resolving doctor name with `getUser(doctorId)` (wrong). **Fixed**: now uses `getDoctorById(doctorId)` then `getUser(doctor.userId)` (or doctor displayName).
- **Appointments screen**: Same fix for building `_userNames` for list: resolve doctor id via `getDoctorById` and then user/display name. **Fixed.**

### 2.3 Invite flow
- Admin creates invite (email, role). On **register** with that email, `AuthService` applies invite (sets role, marks invite used). **OK.**

### 2.4 Patient documents (profile items)
- Patient can add/edit/delete own (`patientId == auth.uid`). Doctor/admin can add/edit/delete any. Firestore rules and UI match. **OK.**

### 2.5 Income / expense & salary
- Income and expense records; net = total income − total expense. Add expense includes **Salary** and other categories. **OK.**

---

## 3. Possible logical / UX issues

1. **Appointments list doctor/patient names**: Now correctly resolve doctor by doctors doc id; patient by user id. **Resolved.**
2. **Creating appointments**: There is no "Create appointment" UI yet; only status updates. So staff cannot create new appointments from the app (only via backend or future feature). **Suggestion**: Add "Create appointment" (patient, doctor, date, time, etc.).
3. **Doctor availability**: Shown on "Our doctors" from `doctor_availability`; if no rows exist, availability is empty. **OK.** Composite index may be needed: `doctor_availability` (doctorId, isActive, dayOfWeek).
4. **Trainee**: Has only dashboard in the drawer; no other nav. If trainees should see limited data, consider adding specific permissions. **OK as designed.**

---

## 4. Responsive, localization, theme — verification

### 4.1 Responsive
- **Breakpoints** in `lib/core/responsive.dart`: mobile &lt; 600, tablet &lt; 900, desktop ≥ 1200.
- **Usage**: `ResponsivePadding.all(context)` and/or `responsiveListPadding(context)` on: login, register, dashboard, admin dashboard, users, appointments, my appointments, patient profile, patient detail, patients list, doctors list, my doctor profile, income/expenses. **OK.**
- **SafeArea**: Login, register, dashboard body. Other screens use AppBar so content is below system UI. **OK.**
- **Constrained width**: Login/register use `responsiveMaxFormWidth`; dashboard uses `responsiveMaxContentWidth`. **OK.**

### 4.2 Localization (AR / EN)
- **main.dart**: `locale: locale.locale`, `supportedLocales: [en, ar]`, `LocalizationsDelegate` for `AppLocalizations` + Material/Cupertino/Widgets delegates. **OK.**
- **RTL**: `builder` wraps child in `Directionality(textDirection: isRtl ? RTL : LTR)`. **OK.**
- **Screens**: All main screens use `AppLocalizations.of(context)` and pass `isRtl` into `Directionality` in their build. **OK.**
- **Dialogs**: Shown in same context, so they inherit locale and direction. **OK.**

### 4.3 Dark / light mode
- **main.dart**: `theme: AppTheme.light()`, `darkTheme: AppTheme.dark()`, `themeMode: theme.themeMode` from `ThemeProvider`. **OK.**
- **AppTheme**: Light and dark `ThemeData` with Material 3, `ColorScheme.fromSeed`, same structure. **OK.**
- **ThemeProvider**: Persists theme mode (e.g. via SharedPreferences). **OK.**
- **Screens**: Use `Theme.of(context)` (colorScheme, textTheme, etc.) so they follow current theme. **OK.**

### 4.4 Platforms (Android, iOS, Mac, Web)
- **Firebase**: `DefaultFirebaseOptions.currentPlatform`; config present for Android, iOS, Web, macOS. **OK.**
- **Layout**: Responsive breakpoints and padding work on all; no platform-specific UI branches required for basic layout. **OK.**
- **File picker**: `file_picker` supports mobile and web; `withData: true` used for upload. **OK.** (Very large files on mobile might need fallback or size limit.)
- **Storage**: Firebase Storage works on all platforms once bucket and rules are set. **OK.**

---

## 5. Suggested features / edits (many implemented)

1. **Create appointment** ✅ — Appointments screen: FAB opens `AppointmentFormDialog` (patient, doctor, room, date, time, service, cost, notes). Firestore: `createAppointment`, `updateAppointment`.
2. **Edit appointment** ✅ — Same screen: per-appointment menu → Edit opens form; status actions (Confirm/Complete/Cancel/No show) also in menu.
3. **Rooms CRUD** ✅ — `/rooms` (admin): list all rooms, add, edit, delete. Firestore: `getAllRooms`, `getRooms`, `addRoom`, `updateRoom`, `deleteRoom`. Drawer: "Rooms" under admin.
4. **Doctors CRUD** ✅ — `/doctors-admin`: list doctors, add (link user with doctor role), edit (specialization, qualifications, bio). Drawer: "Manage doctors" under admin.
5. **Patient profile creation** ✅ — Profile screen: when `_profile == null`, show "Create profile" card; opening edit with `existing: null` creates `patient_profiles/{userId}` via `savePatientProfile` (merge).
6. **Push notifications** ✅ — FCM + local reminders (see NOTIFICATIONS_AND_REPORTS_SETUP.md).
7. **Audit log** ✅ — `audit_log` collection; `AuditService.log()` on role/permission update, user activate/deactivate, patient document delete. `/audit-log` screen (admin) to view. Firestore rules: create if isAuth(), read if isAdmin().
8. **Export** ✅ — Reports screen: Export menu → "Export income & expense" or "Export appointments" (CSV via share_plus).
9. **Localized strings in dialogs** ✅ — Document dialog, delete confirm, appointment form, rooms, requirements, admin todos use l10n (AR/EN). Edit user privileges uses `_featureLabel` for all feature keys including reports, requirements, toDoList.
10. **Image/PDF viewer** ✅ — `document_viewer.dart`: tap image document → in-app dialog with `Image.network`; tap PDF → `url_launcher` to open in browser. Used in patient detail and patient profile document lists.

---

## 6. Summary

- **Logic**: Auth, redirect, roles/permissions, invite, and patient documents are consistent. **Doctor name resolution** in appointments and my appointments was wrong (doctorId used as user id); **fixed** with `getDoctorById` and resolving user/display name.
- **File upload**: Implemented with Firebase Storage and file_picker in the same add/edit document flow; optional URL paste kept.
- **Responsive**: Main screens use responsive padding and width constraints; layout works across phone, tablet, desktop.
- **Localization**: AR/EN and RTL are applied in main and in screens; dialogs inherit context.
- **Theme**: Light/dark from AppTheme and ThemeProvider; screens use theme-based styling.
- **Platforms**: Single codebase works on Android, iOS, macOS, and Web with current setup; enable Storage and deploy rules.
