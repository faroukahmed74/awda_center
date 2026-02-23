# UI Screens & Behaviour by User Role

**Dynamic privileges:** Admins can set **roles** (multiple: admin, doctor, patient, secretary, trainee) and **permissions** (admin_dashboard, users, appointments, patients, income_expenses) per user. New users default to role **patient**. Access is permission-based when permissions are set; otherwise role-based. A user can be both **admin and doctor** (multiple roles).

## Before login (unauthenticated)

| Screen        | Route      | Who sees it | Behaviour |
|---------------|------------|-------------|-----------|
| **Login**     | `/login`   | Everyone    | Email + password, “Sign in with Google”. On success → redirect to `/dashboard`. Link to Register. |
| **Register**  | `/register`| Everyone    | Email, password, full name (AR/EN), phone. Creates user with role **patient** (or **invited role** if email had an invite). On success → `/dashboard`. Link to Login. |

**Router:** If not logged in and you open any other route → redirect to `/login`. If account is **inactive** (`isActive: false`) → redirect to `/login`.

---

## After login – Dashboard (all roles)

| Screen       | Route       | Who sees it | Behaviour |
|--------------|-------------|-------------|-----------|
| **Dashboard**| `/dashboard`| All roles   | Welcome message + role. **Drawer** shows only the menu items the role can access. App bar: logo, language (AR/EN), theme (light/dark), logout. |

---

## Drawer menu items by role

| Menu item           | By role / permission |
|---------------------|----------------------|
| Dashboard           | All                  |
| Admin Dashboard     | Permission `admin_dashboard` or role admin |
| Our doctors         | All (everyone can see doctors list) |
| My doctor profile   | Role doctor          |
| Users               | Permission `users` or role admin/secretary |
| Appointments        | Permission `appointments` or role admin/secretary/doctor |
| My Appointments     | Role patient         |
| Profile             | Role patient         |
| Patients            | Permission `patients` or role admin/doctor |
| Income & Expenses   | Permission `income_expenses` or role admin |

*(Drawer items are shown based on dynamic permissions first, then role defaults.)*

---

## Screen-by-screen behaviour by role

### 1. Admin Dashboard — `/admin-dashboard`

| Who can open | Behaviour |
|--------------|-----------|
| **Admin only** | Stats: total users, active users, today’s appointments. “Invite user” (email + role + optional names). “Manage users” → Users screen. Shortcuts: Appointments, Patients, Income & expenses. If not admin, body shows “Admin only”. |

---

### 2. Users — `/users`

| Who can open   | Behaviour |
|----------------|-----------|
| **Admin, Secretary** | List all users. Filter by role (dropdown). **Admin only:** app bar “Invite user” (➕), and per user: **role dropdown** (change to admin/doctor/patient/secretary/trainee), **enable/disable** (toggle). Secretary sees list and filter only, no edit. |

---

### 3. Appointments — `/appointments`

| Who can open   | Behaviour |
|----------------|-----------|
| **Admin, Secretary, Doctor** | List appointments (last 30 days). **Doctor:** only their own appointments. **Admin / Secretary / Doctor:** per appointment, menu (confirm, complete, cancel, no-show). List shows patient and doctor names. |

---

### 4. My Appointments — `/my-appointments`

| Who can open | Behaviour |
|--------------|-----------|
| **Patient only** | List **current user’s** appointments. Shows doctor name, date, time, status. Read-only. |

---

### 5. Profile — `/profile`

| Who can open | Behaviour |
|--------------|-----------|
| **Patient only** | User info. Lists **sessions** and **patient documents** for the current user. |

---

### 6. Patients — `/patients`

| Who can open   | Behaviour |
|----------------|-----------|
| **Admin, Doctor** | List users with role **patient**. Tap row → Patient detail. |

---

### 7. Patient detail — `/patients/:id`

| Who can open   | Behaviour |
|----------------|-----------|
| **Permission `patients` (admin, doctor)** | User info + **full patient profile** (personal + medical data, diagnosis, medical history, treatment progress, progress notes). **Edit profile** (doctor/admin): open dialog to edit all profile fields. Lists **sessions** and **patient documents**. |

---

### 8. Income & Expenses — `/income-expenses`

| Who can open | Behaviour |
|--------------|-----------|
| **Admin only** | Total income, total expenses, net. Lists income and expense records. Add income / Add expense dialogs (amount, source/category, date). *(Secretary has Firestore read/write for these collections but no drawer link in the app.)* |

---

### 9. Our doctors — `/doctors`

| Who can open | Behaviour |
|--------------|-----------|
| **All** | List of **doctors** with name, specialization, qualifications, bio. So patients can see who are the doctors and their qualifications. |

### 10. My doctor profile — `/my-doctor-profile`

| Who can open | Behaviour |
|--------------|-----------|
| **Role doctor** | Edit **own** doctor record: specialization (AR/EN), qualifications (AR/EN), bio. Saved to Firestore `doctors` (linked by userId). |

---

## Flow summary by role

- **Admin:** Login/Register (if needed) → Dashboard → Admin Dashboard, Users (invite + set roles + enable/disable), Appointments, Patients, Patient detail, Income & expenses.
- **Secretary:** Login → Dashboard → Users (view + filter), Appointments (view + update status).
- **Doctor:** Login → Dashboard → Appointments (own only, update status), Patients, Patient detail.
- **Patient:** Login or Register → Dashboard → My Appointments, Profile.
- **Trainee:** Login → Dashboard only (no other menu items).

---

## Invite flow (admin)

1. Admin opens **Admin Dashboard** or **Users** and taps **Invite user**.
2. Enters email, role (admin/doctor/patient/secretary/trainee), optional names → Save. Stored in Firestore `invites`.
3. When that **email is used to register**, the new user gets the **invited role** (and optional names) and the invite is marked used.
