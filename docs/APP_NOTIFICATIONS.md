# Appointments: Notifications (confirmed / completed) and where they appear

## Who gets notified when an appointment is confirmed (or completed / cancelled)

| Recipient   | How they are notified |
|------------|------------------------|
| **Patient** | FCM push (when Cloud Function is deployed) + local scheduled reminder (day before / morning of) |
| **Doctor**  | FCM push (when Cloud Function is deployed) + local scheduled reminder (day before / morning of) |
| **Secretary** | FCM push (when Cloud Function is deployed). All users with role `secretary` or `admin`, or with permission `appointments`, receive the same push. |

### Current implementation

1. **App (Appointments screen)**  
   When a user changes an appointment’s status (e.g. to Confirmed, Completed, Cancelled, No-show):
   - Firestore is updated via `updateAppointmentStatus`.
   - **Local reminders** for that appointment are rescheduled for the **patient** and **doctor** (so their “Appointment reminder” at day-before / morning-of stays correct). Secretaries do not get local reminders for individual appointments; they get the push when status changes.

2. **Cloud Function (push to patient, doctor, secretary)**  
   Deploy the function so that **FCM push** is sent when status changes:
   ```bash
   cd functions && npm install && cd .. && firebase deploy --only functions
   ```
   - **Trigger:** `appointments/{appointmentId}` document update.
   - **When:** Status changes to `confirmed`, `completed`, `cancelled`, or `no_show`.
   - **Recipients:**  
     - Patient (user id = `patientId`),  
     - Doctor (user id from `doctors` doc),  
     - All users who are secretary/admin or have `appointments` permission.  
   - **Payload:** Notification title (e.g. “Appointment confirmed”) and body (date/time); data: `type`, `appointmentId`, `status` for optional in-app navigation.

3. **Local reminders (existing)**  
   - **Patient:** Upcoming appointments in the next 7 days → reminder day before or morning of.  
   - **Doctor:** Same for their appointments.  
   - **Secretary:** No per-appointment local reminders; they rely on the FCM push when status is updated.

---

## Where notifications should appear in the app

### Already in place

- **Dashboard (home)**  
  Today’s and upcoming appointments are shown for the current user (patient or doctor). After a status change, reopening the app or refreshing the dashboard shows the new status.

- **Appointments screen** (`/appointments`)  
  Staff see the list; status updates are reflected in real time via the appointments stream.

- **My appointments** (`/my-appointments`)  
  Patients see their list; status updates are reflected in real time.

- **Patient detail → Sessions**  
  Confirmed and completed appointments appear in the Sessions section and update when status changes (e.g. confirmed → completed).

- **System / FCM**  
  When the Cloud Function is deployed, patient, doctor, and secretary receive a **push notification** (title + body) on their device when an appointment is confirmed, completed, cancelled, or marked no-show. Tapping the notification can open the app (and optionally deep-link to the appointment; payload includes `appointmentId` and `status`).

### Suggested additions (optional)

- **App bar “bell” (in-app notification center)**  
  A bell icon that opens a list of recent notifications (e.g. “Appointment X confirmed”, “Appointment Y completed”). This would require storing notification events (e.g. in Firestore `user_notifications` or similar) when sending FCM, or when the Cloud Function runs, and having the app read and display them.

- **Badge on “Appointments” / “My appointments”**  
  Show a count of e.g. new confirmations or today’s appointments next to the menu item or tab.

- **On open from FCM tap**  
  Use the FCM data payload (`appointmentId`, `status`) in `onMessageOpenedApp` / `onNotificationTap` to navigate to the appointment or to “My appointments” / “Appointments” and scroll to that appointment.

---

## Deploying the notification Cloud Function

From the project root:

```bash
cd functions && npm install && cd ..
firebase deploy --only functions
```

Ensure your Firebase project has the Blaze plan if you use out-of-free-tier resources. The function uses Firestore (read users, doctors) and FCM (send messages).

---

## Web notifications

On **web**, notifications work as follows:

1. **Foreground** (tab open and focused): When an FCM message arrives, the app shows a **browser notification** (using the Web Notifications API). The user must allow notifications when prompted after login.

2. **Background** (tab in background or closed): The **service worker** `web/firebase-messaging-sw.js` receives the message and shows the notification. It is included in the app and deployed with `flutter build web`.

3. **FCM token on web**: For the server to send pushes to the web client, the app must get a token with a **VAPID key**. In `lib/services/notification_service.dart`, set `NotificationService.webVapidKey` to your **Web Push certificate** (public key) from Firebase Console → Project Settings → Cloud Messaging → **Web Push certificates** → “Key pair” (generate one if needed). If `webVapidKey` is empty, web may not receive any push notifications.
