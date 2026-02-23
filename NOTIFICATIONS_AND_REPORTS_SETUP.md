# Notifications and Reports Setup

## Notifications (FCM + local reminders)

- **firebase_messaging**: Push notifications. Token is saved to the user document (`fcmToken`, `fcmTokenUpdatedAt`) via `FirestoreService.updateUserFcmToken`. Deploy Firestore rules so users can update their own `fcmToken` (existing user update rule already allows it).
- **flutter_local_notifications**: Local scheduled reminders for:
  - **Patients**: Upcoming appointments (next 7 days) — reminder day before or morning of.
  - **Doctors**: Upcoming appointments (next 7 days) — same logic.
  - **Admins**: To-do items with a `reminderAt` date/time.
- **Initialization**: In `main()`, timezone is set to `Africa/Cairo` and `NotificationService().init()` runs. After login, `AuthProvider` calls `NotificationService().refreshTokenAndScheduleReminders(uid)`.
- **Platforms**:
  - **Android**: FCM and local notifications work. Ensure `google-services.json` is present and Firebase Cloud Messaging is enabled.
  - **iOS/macOS**: Enable Push Notifications and Background Modes (Remote notifications) in Xcode; upload APNs key to Firebase.
  - **Web**: FCM works (request permission, get token). Local scheduled notifications are not used on web (`!kIsWeb` guard).

## Reports

- **Reports screen** (`/reports`): Two tabs — **Patients report** and **Income report**.
  - **Period**: Day / Month / Year and a date picker. Data is filtered by the selected range.
  - **Patients report**: Appointments in range → unique patient IDs → names from `users` → count and list.
  - **Income report**: `income_records` in range → total and list.
- **Access**: Users with the `reports` feature (admin by default; secretary/doctor if granted).

## Requirements (to-buy list)

- **Requirements screen** (`/requirements`): List of center requirements. Create (title, description, quantity), toggle completed, delete.
- **Firestore**: Collection `center_requirements`. Rules: read/write for `isAdmin() || isSecretary()`.
- **Access**: Users with the `requirements` feature (admin by default).

## Admin to-do list

- **To-do screen** (`/admin-todos`): List of tasks with optional due date and reminder. Create, toggle completed, delete. Reminders are scheduled locally for users with `admin_todos` access.
- **Firestore**: Collection `admin_todos`. Rules: read/write for `isAdmin() || isSecretary()`.
- **Access**: Users with the `admin_todos` feature (admin by default).

## Firestore rules

- `center_requirements` and `admin_todos`: added with `allow read, write: if isAdmin() || isSecretary();`.
- Deploy: `firebase deploy --only firestore`.

## CRUD and Firestore — verification

| Screen / flow           | Create              | Read                    | Update                    | Delete            |
|-------------------------|---------------------|-------------------------|---------------------------|-------------------|
| **Users**               | Invite (creates invite doc) | getUsers, getUser       | updateUserRoles, updateUserPermissions, updateUserActive (users doc) | —                 |
| **Appointments**        | createAppointment (service; no UI yet) | getAppointments, stream | updateAppointmentStatus   | —                 |
| **Patient profile**     | savePatientProfile (merge) | getPatientProfile       | savePatientProfile       | —                 |
| **Patient documents**   | addPatientDocument  | getPatientDocuments     | updatePatientDocument     | deletePatientDocument |
| **Income / expense**    | addIncomeRecord, addExpenseRecord | getIncomeRecords, getExpenseRecords | —                 | —                 |
| **Doctors**             | ensureDoctorDocForUser (when role added) | getDoctors, getDoctorById, getDoctorByUserId | updateDoctor     | —                 |
| **Invites**             | createInvite        | getInvites, getInviteByEmail | markInviteUsed        | —                 |
| **Requirements**        | addCenterRequirement| getCenterRequirements   | updateCenterRequirement   | deleteCenterRequirement |
| **Admin todos**         | addAdminTodo        | getAdminTodos           | updateAdminTodo           | deleteAdminTodo   |
| **FCM token**           | —                   | —                       | updateUserFcmToken (users doc, merge) | —                 |

All of the above use `FirestoreService` methods that map to Firestore `collection().add()`, `doc().get()`, `doc().update()`, `doc().set(..., merge: true)`, or `doc().delete()`. Ensure Firestore rules allow the intended roles (admin, secretary, doctor, patient) as in `firestore.rules`.
