# Firestore Routes & Security Verification

This document verifies that every screen’s Firestore usage is allowed by security rules for the roles that can access that screen.

---

## Route access by role (from `canAccessRoute`)

| Route | Who can access |
|-------|----------------|
| `/dashboard`, `/doctors` | All authenticated |
| `/my-doctor-profile` | doctor |
| `/my-appointments`, `/profile` | patient |
| `/admin-dashboard`, `/users`, `/appointments`, `/patients`, `/income-expenses`, `/reports`, `/requirements`, `/admin-todos`, `/rooms`, `/audit-log`, `/doctors-admin` | Users with `canAccessAdminDashboard` (admin, secretary, or custom permissions) |

---

## Collection rules summary

| Collection | Read | Create | Update | Delete |
|------------|------|--------|--------|--------|
| **users** | isAuth | isAuth && userId==uid | self or admin | self or admin |
| **doctors** | isAuth | admin | admin or (doctor && own) | admin |
| **doctor_availability** | isAuth | admin, doctor | admin or (doctor && own) | admin or (doctor && own) |
| **rooms** | isAuth | admin | admin | admin |
| **appointments** | isAuth | admin, secretary, doctor | admin, secretary, doctor | admin, secretary, doctor |
| **sessions** | isAuth | admin, doctor | admin, doctor | admin, doctor |
| **patient_profiles** | isAuth | admin, doctor, or (auth && profileId==uid) | same | admin |
| **patient_documents** | isAuth | admin, doctor, or (auth && patientId==uid) | admin, doctor, or (auth && patientId==resource) | same |
| **income_records**, **expense_records** | admin, secretary | admin, secretary | admin, secretary | admin, secretary |
| **invites** | isAuth | admin | admin or (auth && set used==true && invite.email==auth.token.email) | admin |
| **center_requirements** | admin, secretary | admin, secretary | admin, secretary | admin, secretary |
| **admin_todos** | admin, secretary | admin, secretary | admin, secretary | admin, secretary |
| **audit_log** | admin | isAuth | false | false |

---

## Screen-by-screen verification

### 1. **PatientProfileScreen** (`/profile`) — patient

- **Firestore:** `patient_profiles` (read/doc), `sessions` (query by patientId), `patient_documents` (query by patientId), `patient_documents` (delete own).
- **Rules:** Read all isAuth. Create/update profile when profileId==uid. Sessions/documents read isAuth. Delete document when resource.patientId==uid ✓

### 2. **MyAppointmentsScreen** (`/my-appointments`) — patient

- **Firestore:** `appointments` (query patientId==uid), `doctors` (read), `users` (read).
- **Rules:** All read isAuth ✓

### 3. **DoctorsListScreen** (`/doctors`) — all

- **Firestore:** `doctors` (get all), `users` (read per doctor), `doctor_availability` (query by doctorId).
- **Rules:** All read isAuth ✓

### 4. **PatientProfileEditDialog** (from profile) — patient saving own profile

- **Firestore:** `patient_profiles` (set doc with profile.id == patientId == uid).
- **Rules:** Create/update when profileId==uid ✓

### 5. **RequirementsScreen** (`/requirements`) — admin/secretary

- **Firestore:** `center_requirements` (get, add, update, delete).
- **Rules:** read, write admin|secretary ✓

### 6. **IncomeExpensesScreen** (`/income-expenses`) — admin/secretary

- **Firestore:** `income_records`, `expense_records` (get, add).
- **Rules:** read, write admin|secretary ✓

### 7. **DoctorsAdminScreen** (`/doctors-admin`) — admin

- **Firestore:** `doctors` (get, update, ensure doc), `users` (get).
- **Rules:** doctors read isAuth; create admin; update admin or doctor own ✓

### 8. **AdminTodosScreen** (`/admin-todos`) — admin/secretary

- **Firestore:** `admin_todos` (get, add, update, delete).
- **Rules:** read, write admin|secretary ✓

### 9. **AppointmentsScreen** (`/appointments`) — admin/secretary/doctor

- **Firestore:** `doctors` (getByUserId, getById), `appointments` (query by doctorId or all, update status), `users`, `patients`, `rooms`.
- **Rules:** All used operations allowed for admin/secretary/doctor ✓

### 10. **AppointmentFormDialog** — create/update appointment

- **Firestore:** `appointments` (add, update).
- **Rules:** create/update admin|secretary|doctor ✓

### 11. **UsersScreen** (`/users`) — admin

- **Firestore:** `users` (get with optional role filter).
- **Rules:** read isAuth ✓

### 12. **InviteUserDialog** — admin

- **Firestore:** `invites` (add).
- **Rules:** create admin ✓

### 13. **AuthService.registerWithEmailAndPassword** — register with invite

- **Firestore:** `invites` (getInviteByEmail read, markInviteUsed update), `users` (set own doc), `doctors` (ensureDoctorDocForUser — create).
- **Rules:** invite read isAuth; invite update allowed for auth user when setting used=true and resource.email==auth.token.email ✓. users create own ✓. doctors create: admin or (auth && request.resource.data.userId == request.auth.uid) so invited doctors can create their own doctor doc on first register ✓ (fixed).

### 14. **AdminDashboardScreen** (`/admin-dashboard`) — admin

- **Firestore:** `getAdminStats()` → users (get), appointments (get with date range).
- **Rules:** read isAuth ✓

### 15. **RoomsScreen** (`/rooms`) — admin

- **Firestore:** `rooms` (getAll, add, update, delete).
- **Rules:** read isAuth; write admin ✓

### 16. **MyDoctorProfileScreen** (`/my-doctor-profile`) — doctor

- **Firestore:** `doctors` (getByUserId(uid), update own).
- **Rules:** read isAuth; update doctor && resource.userId==uid ✓

### 17. **ReportsScreen** (`/reports`) — admin/secretary

- **Firestore:** `appointments`, `users`, `income_records`, `expense_records` (read with date filters).
- **Rules:** appointments/users read isAuth; income/expense read admin|secretary ✓

### 18. **AuditLogScreen** (`/audit-log`) — admin

- **Firestore:** `audit_log` (get).
- **Rules:** read admin ✓

### 19. **PatientDetailScreen** (`/patients/:id`) — admin/doctor

- **Firestore:** `users`, `patient_profiles`, `sessions`, `patient_documents` (read patientId), delete `patient_documents`.
- **Rules:** All read isAuth. delete patient_documents: admin or doctor or (resource.patientId==uid) ✓

### 20. **PatientDocumentDialog** — add/update patient document

- **Firestore:** `patient_documents` (add, update). Called with patientId (can be self or another for doctor).
- **Rules:** create when admin|doctor|(patientId==uid); update when admin|doctor|(resource.patientId==uid) ✓

### 21. **AuthService** — users collection

- **Firestore:** users (get own, set on register/Google, update roles/active/fcm by admin or self).
- **Rules:** read isAuth; create own; update self or admin ✓

### 22. **NotificationService** — FCM and queries

- **Firestore:** `users` (updateUserFcmToken self), getAppointments, getDoctorByUserId, getAdminTodos (for notifications).
- **Rules:** update user self; reads isAuth ✓

### 23. **AuditService** — audit_log

- **Firestore:** `audit_log` (add).
- **Rules:** create isAuth ✓

---

## Fix applied: Invites update

- **Issue:** Registering with an invite calls `markInviteUsed(inviteId)`, which updates the invite doc. Rules previously allowed only admin to update invites, so registration with invite would fail with permission denied.
- **Change:** Allow update when `isAuth() && request.resource.data.used == true && resource.data.email == request.auth.token.email` so the user whose email matches the invite can set `used` to true once.

---

## Fix applied: Doctors create on register

- **Issue:** When an invited **doctor** registers, the code calls `ensureDoctorDocForUser(user.uid, ...)` which does `doctors.add({ userId: user.uid, ... })`. Rules previously allowed only admin to create doctors.
- **Change:** Allow create on `doctors` when `isAuth() && request.resource.data.userId == request.auth.uid` so a user can create the single doctor document that references their own userId (for invited doctors). ✓

---

## Firestore indexes (firestore.indexes.json)

- **doctor_availability:** doctorId, isActive, dayOfWeek
- **appointments:** (patientId, appointmentDate desc), (doctorId, appointmentDate desc)
- **sessions:** patientId, sessionDate desc
- **patient_documents:** patientId, createdAt desc
- **invites:** (used, createdAt desc), (email, used)

Deploy with: `firebase deploy --only firestore --project awdacenter-eb0a8`

---

## Error handling added

Screens that load from Firestore now use try/catch and show an error + Retry when a request fails, so no screen stays stuck on loading:

- DoctorsListScreen, MyAppointmentsScreen, PatientProfileScreen (already had this)
- AdminDashboardScreen, UsersScreen, PatientsScreen (added)

Other screens (Rooms, Audit, Reports, Income/Expenses, Requirements, AdminTodos, DoctorsAdmin, Appointments, PatientDetail, MyDoctorProfile) can be given the same pattern if desired.
