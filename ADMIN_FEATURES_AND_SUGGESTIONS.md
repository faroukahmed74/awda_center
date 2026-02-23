# Admin Dashboard & Feature Suggestions

## Admin Dashboard (Implemented)

- **Route**: `/admin-dashboard` (admin only). Access from drawer: "Admin Dashboard".
- **Stats**: Total users, active users, today’s appointments (from Firestore).
- **User management**
  - **Invite user**: Create an invite (email + role + optional names). When someone registers with that email, they get the assigned role (doctor, secretary, trainee, patient, admin). Invites stored in Firestore `invites` collection.
  - **Manage users**: Link to Users screen — list all users, filter by role, change role (admin only), enable/disable account.
- **Shortcuts**: Appointments, Patients, Income & expenses.

## Current Admin Capabilities

| Area | What admin can do |
|------|-------------------|
| **Users** | View all users, filter by role, change any user’s role (admin/doctor/patient/secretary/trainee), enable/disable account, invite new users by email (invite applies on first register). |
| **Appointments** | View all appointments (secretary too), confirm/complete/cancel/no-show. |
| **Patients** | View patients list and patient detail (doctor too). |
| **Income & expenses** | View and add income/expense records (secretary too). |
| **Firestore** | Rules restrict writes by role; admin has broad access where defined. |

## Suggested Features to Add

1. **Doctors & rooms**
   - Admin CRUD for **doctors** (link user to doctor profile, specialty).
   - Admin CRUD for **rooms** (name, active/inactive).
   - Use doctors/rooms when creating appointments.

2. **Appointments**
   - **Create appointment** from app: choose patient, doctor, room, date, time, service, cost.
   - **Edit appointment** (reschedule, change doctor/room).
   - **Recurring appointments** (e.g. weekly).

3. **Sessions**
   - **Create session** from patient detail: link to appointment or standalone, session type, fees.
   - **Edit session**.

4. **Patient profile & documents**
   - **Edit patient profile** (DOB, gender, address, diagnosis, etc.) from patient detail.
   - **Upload patient documents** (type, file or URL) from patient detail or profile.

5. **Reports**
   - Appointments report (by date range, doctor, status).
   - Income/expense report (by period, category/source).
   - Export (e.g. CSV/PDF) or simple in-app summary.

6. **Notifications**
   - In-app or push: new appointment, reminder before appointment, account disabled.
   - Firebase Cloud Messaging for push.

7. **Audit log**
   - Firestore collection for sensitive actions (role change, account disabled, appointment cancelled) with who/when.

8. **Invites**
   - List pending invites in Admin dashboard; delete/cancel invite.
   - Optional: send email with sign-up link (e.g. via Cloud Function).

9. **Settings**
   - App-wide settings (e.g. default currency, date format, business hours) stored in Firestore, editable by admin.

10. **Backup / export**
    - Admin-only export of key data (users, appointments, income/expense) for backup (e.g. JSON/CSV via Cloud Function or client-side export).

## Firestore Indexes

If you use **invites** with `where('used', isEqualTo: false).orderBy('createdAt', descending: true)`, create a composite index in Firebase Console:

- Collection: `invites`
- Fields: `used` (Ascending), `createdAt` (Descending)

For `getInviteByEmail`, a composite index on `invites`: `email` (Ascending), `used` (Ascending) may be required if Firestore prompts for it.

## Deploy Rules

After adding `invites` rules, deploy:

```bash
firebase deploy --only firestore:rules
```
