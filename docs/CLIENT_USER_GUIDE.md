# Awda Center — User Guide (Client Documentation)

**عودة للعلاج الطبيعي**

This document describes all features of the Awda Center app for the clinic and its clients. The app runs on **phones**, **tablets**, **desktops**, and **web browsers**.

---

## 1. Overview

Awda Center is a single app for managing a physical therapy clinic. It includes:

- **User accounts** with different roles (admin, secretary, doctor, patient, trainee).
- **Appointments** — booking, confirming, rescheduling, and viewing.
- **Patient records** — profiles, sessions, documents.
- **Income and expenses** — clinic finances.
- **Reports** — summaries and exports.
- **Notifications** — appointment reminders and status updates.
- **Arabic and English** — full language support with right-to-left layout for Arabic.
- **Light and dark theme** — user preference.

Staff and patients use the same app; the menu and screens depend on their role.

---

## 2. Where You Can Use the App

- **Android** — Install from Google Play or an APK.
- **iPhone / iPad** — Install from the App Store.
- **Web** — Open in a browser (e.g. Chrome, Safari) at the clinic’s web address.
- **Windows** — Desktop version if provided.

Your data (appointments, patients, users) is shared across all these. Log in with the same email and password on any device.

---

## 3. Getting Started

### 3.1 Log in

- Open the app (or web link).
- Enter your **email** and **password**.
- Tap **Login**.

If you don’t have an account, use **Register** (if the clinic allows it) or ask an admin to create one for you.

### 3.2 Register (if enabled)

- Tap **Register**.
- Enter **email**, **password**, and any required fields (e.g. name, phone).
- After registration, an admin must set your **role** and **active** status in the system before you can use the app fully.

### 3.3 Forgot password

- On the login screen, tap **Forgot password**.
- Enter your email.
- Follow the link sent to your email to set a new password.

---

## 4. User Roles and Access

What you see in the app depends on your **role**. Admins can also give extra permissions to any user.

| Role        | Typical access |
|------------|----------------|
| **Admin**  | Full access: users, appointments, patients, income/expenses, reports, requirements, admin to‑do list, rooms, doctor management, audit log. |
| **Secretary** | Usually: users, appointments, reports. Can be given more (e.g. income/expenses) by admin. |
| **Doctor** | Appointments (own and list), patients, reports, own doctor profile and availability. |
| **Patient** | My appointments, profile (and patient profile if they have one), book appointments with doctors. |
| **Trainee** | Limited; exact access is set by admin. |

- **Dashboard** and **Profile** are available to everyone (with role-specific content).
- The **menu** (drawer) shows only the sections you are allowed to use.
- **Version number** is shown at the bottom of the menu for all users.

---

## 5. Main Features in Detail

### 5.1 Dashboard (Home)

- **Welcome** message and your name and role.
- **Today’s and upcoming appointments** (for the next 14 days), depending on your role:
  - **Patient:** your own appointments.
  - **Doctor:** your own appointments.
  - **Staff (e.g. secretary/admin):** all appointments (if they have access).
- A short list of appointments with date, time, status, and service.
- Buttons to open **Appointments** or **My Appointments** for more details.

### 5.2 Admin Dashboard (admin only)

- Shortcuts to:
  - Admin dashboard overview
  - Rooms
  - Manage doctors
  - Audit log
- Quick access to main admin tasks.

### 5.3 Users (admin / secretary, if permitted)

- **List of all users** in the system.
- **Invite new user** (admin): send an invite so they can register.
- **Filter by role** (admin, secretary, doctor, patient, trainee).
- **Open a user profile** to view or edit:
  - Name, email, phone, role(s), active/inactive.
  - **Privileges (permissions):** which parts of the app they can use (e.g. appointments, patients, reports, income/expenses, requirements, admin to‑do list). Admins can change these per user.
- **Deactivate** a user so they can no longer log in.

### 5.4 Appointments

- **List of appointments** with filters (e.g. by doctor, date).
- **Create new appointment:** choose patient, doctor, date, time, room, service, and optional notes.
- **Edit or reschedule** an existing appointment.
- **Change status:** Pending → Confirmed → Completed, or Cancelled / No-show.
- When status is updated, **patient and doctor** can get a push notification and local reminder; **secretaries** can get a push (when configured).
- Appointments are shown in real time; the list updates when something changes.

### 5.5 My Appointments (patients and doctors)

- **Patients:** list of your own appointments (past and upcoming).
- **Doctors:** list of your own appointments.
- Same statuses: Pending, Confirmed, Completed, Cancelled, No-show.
- Dates and times; you can see when an appointment was confirmed or completed.

### 5.6 Profile (everyone)

- **Personal data:** name, email, phone, role(s), active status.
- **Edit my info:** change name, phone, etc. (if allowed).
- **Change password** (if the account supports it).
- **Language:** switch between **Arabic** and **English**. The app restarts with the chosen language and uses right-to-left layout for Arabic.
- **Theme:** switch between **light** and **dark** mode. The choice is saved.
- **Patients:** if your role includes “patient”, you also see:
  - **Medical / patient profile:** date of birth, diagnosis, medical history, treatment progress, progress notes.
  - **Create or edit** your patient profile if the clinic allows it.
  - **Sessions:** list of your sessions and **confirmed/completed appointments** (same as what doctors see for you).
  - **Documents / notes:** your attached documents and notes; add, edit, or delete (if permitted).
- **Doctors:** link to **My doctor profile** (availability and profile details).

### 5.7 User profile (viewing another user)

- When you open a user from the **Users** list, you see their **user profile**.
- Depending on your permissions, you can see their role, contact info, and **privileges**.
- Admins can **edit** their role, permissions, and active status.

### 5.8 Patients (staff with access)

- **List of all patients** (linked to user accounts).
- **Search** to find a patient quickly.
- **Open a patient** to see **Patient detail**.

### 5.9 Patient detail (staff with access)

- **User info:** name, email, phone.
- **Patient profile:** date of birth, diagnosis, medical history, treatment progress, notes.
- **Sessions:** combined list of:
  - Sessions recorded in the system
  - **Confirmed and completed appointments** (so all sessions appear in one place)
- Sorted by date (newest first).
- **Documents:** patient documents and notes; view, add, or delete (depending on permissions).

### 5.10 Income & expenses (admin / users with permission)

- **Income records:** list of income entries with date, amount, description/category.
- **Expense records:** list of expense entries with date, amount, description/category.
- **Totals** for the selected period.
- Add, edit, or delete records (if you have permission).
- Used for clinic accounting and reporting.

### 5.11 Reports

- **Tabs:** Income & expenses, Appointments, Patients, Users (depending on your access).
- **Period:** choose **day**, **month**, or **year** and select the date.
- **Income & expenses:** totals and list of income and expenses in the period.
- **Appointments:** count by status (e.g. pending, confirmed, completed, cancelled) and list of appointments.
- **Patients:** count and list of patients (e.g. who had appointments in the period).
- **Users:** count by role (admin, secretary, doctor, patient, trainee).
- **Export:** from the menu you can export:
  - Income & expense report (CSV)
  - Appointments (CSV)
  - Patients (CSV)
  - Users (CSV)
  - Audit log (CSV)
- Exports are shared via the device’s share option (e.g. save to files, email). A message confirms when the export is ready.

### 5.12 Requirements (admin / users with permission)

- **Center requirements** — e.g. compliance items, to‑do items for the clinic.
- List and manage requirement entries (add, edit, complete, delete as allowed).

### 5.13 Admin to‑do list (admin / users with permission)

- **Task list** for admins (or permitted users).
- Add, edit, mark as done, or delete tasks.
- Keeps daily admin work in one place.

### 5.14 Rooms (admin)

- **List of rooms** used for appointments.
- Add, edit, or delete rooms (e.g. “Room 1”, “Physiotherapy A”).
- Used when creating or editing appointments.

### 5.15 Doctors (staff and patients)

- **List of doctors** — names and info (and profile if available).
- **Patients** can use this to choose a doctor when booking an appointment.
- **Admin:** link to **Manage doctors** to link users to doctor profiles and manage availability.

### 5.16 My doctor profile (doctors only)

- **Doctor’s own profile:** professional info, photo, specializations, etc.
- **Availability:** set when the doctor is available for appointments (e.g. days and time slots).
- Used by the clinic when creating appointments and by patients when booking.

### 5.17 Manage doctors (admin only)

- **List of doctors** linked to user accounts.
- **Add a doctor:** link an existing user (with doctor role) to a doctor profile.
- **Edit** doctor profile and availability.
- **Remove** the link between a user and a doctor profile if needed.

### 5.18 Audit log (admin only)

- **History of important actions** in the system (e.g. who did what and when).
- Used for accountability and reviewing changes.
- Can be **exported** from Reports (Audit log export).

---

## 6. Notifications

### 6.1 Push notifications (Firebase Cloud Messaging)

- When an appointment’s status is changed (e.g. to **Confirmed**, **Completed**, **Cancelled**, **No-show**):
  - **Patient** and **Doctor** receive a push notification on their device.
  - **Secretaries** (and admins) with appointment access can receive the same push.
- Notification shows a short title and message (e.g. “Appointment confirmed” with date/time).
- Tapping the notification opens the app.

### 6.2 Local reminders (patient and doctor)

- **Appointment reminders** are scheduled on the device for upcoming appointments (e.g. day before or morning of).
- They are updated automatically when an appointment is created, rescheduled, or cancelled.
- Only the **patient** and **doctor** of that appointment get these reminders; secretaries do not.

---

## 7. Language and Appearance

- **Language:** Arabic and English. Switch from the **Profile** or the **language icon** in the app bar. The app uses **right-to-left (RTL)** layout in Arabic.
- **Theme:** Light or dark. Switch from **Profile** or the **theme icon** in the app bar. The choice is saved for the next time you open the app.
- **Responsive layout:** The app adapts to phone, tablet, and desktop so it is usable on all screen sizes.

---

## 8. Logout and Version

- **Logout:** Use the **logout** icon in the app bar to sign out. You will return to the login screen.
- **Version:** The current app **version** is shown at the **bottom of the menu** (e.g. v1.0.1+2). All roles can see it.

---

## 9. Summary Table of Features by Role

| Feature              | Admin | Secretary | Doctor | Patient | Trainee |
|----------------------|-------|-----------|--------|---------|---------|
| Dashboard            | ✓     | ✓         | ✓      | ✓       | ✓       |
| Admin dashboard      | ✓     | —         | —      | —       | —       |
| Users                | ✓     | ✓*        | —      | —       | —       |
| Appointments         | ✓     | ✓*        | ✓      | —       | —       |
| My appointments      | —     | —         | ✓      | ✓       | —       |
| Profile / My info    | ✓     | ✓         | ✓      | ✓       | ✓       |
| Patient profile (own)| —     | —         | —      | ✓       | —       |
| Patients             | ✓     | ✓*        | ✓      | —       | —       |
| Income & expenses    | ✓     | ✓*        | ✓*     | —       | —       |
| Reports              | ✓     | ✓*        | ✓      | —       | —       |
| Requirements         | ✓     | ✓*        | —      | —       | —       |
| Admin to‑do list     | ✓     | ✓*        | —      | —       | —       |
| Rooms                | ✓     | —         | —      | —       | —       |
| Doctors list         | ✓     | ✓         | ✓      | ✓       | ✓*      |
| My doctor profile    | —     | —         | ✓      | —       | —       |
| Manage doctors       | ✓     | —         | —      | —       | —       |
| Audit log            | ✓     | —         | —      | —       | —       |

\* When the admin has granted the corresponding permission to that role.

---

## 10. Support and Data

- **Data:** Stored securely in the cloud (Firebase). The same data is used on mobile apps and web.
- **First-time setup:** The first admin user is usually set in the backend (e.g. by the developer). After that, admins can invite and manage all other users and permissions from the app.
- For **technical or access issues**, contact your clinic administrator or the person who provided the app.

---

*Document version: 1.0 — Awda Center app.*
