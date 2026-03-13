# Notifications checklist – why notifications may not appear

Use this checklist to ensure push notifications (FCM) and local reminders work on **Android**, **iOS**, and **Web**.

---

## 1. App code (already configured)

- **Init**: `NotificationService().init()` is called in `main()` after Firebase init.
- **Token save**: After login, `AuthProvider.loadUserProfile()` calls `NotificationService().refreshTokenAndScheduleReminders(uid)`, which:
  - Requests notification permission (iOS/Web/Android 13+)
  - Gets FCM token and saves it to Firestore `users/{uid}.fcmToken`
- **Token refresh**: `onTokenRefresh` listener updates Firestore when the FCM token rotates.
- **Firestore rules**: Users can update their own document (`request.auth.uid == userId`), so writing `fcmToken` is allowed.

---

## 2. Android

- **`android/app/src/main/AndroidManifest.xml`**
  - `POST_NOTIFICATIONS` permission is declared (required for Android 13+).
- **`google-services.json`**
  - Present in `android/app/` and matches your Firebase project.
- **Runtime**
  - On Android 13+ the app requests notification permission when `refreshTokenAndScheduleReminders` runs. If the user taps **Don’t allow**, no token is saved and no push will be received until they enable notifications in system settings.
- **Build**
  - `compileSdkVersion` and `targetSdkVersion` 33+ recommended for FCM on Android 13+.

---

## 3. iOS

- **Info.plist**
  - `UIBackgroundModes` → `remote-notification` is set (so FCM can receive in background).
- **Xcode**
  - **Signing & Capabilities**: add **Push Notifications**.
  - **Signing & Capabilities**: add **Background Modes** and enable **Remote notifications**.
- **Firebase Console**
  - **Project Settings → Cloud Messaging → Apple app configuration**: upload APNs Authentication Key (or APNs certificate) so FCM can deliver to iOS.
- **Runtime**
  - First run will show the system permission prompt; if the user denies, no token is saved.

---

## 4. Web

- **Service worker**
  - `web/firebase-messaging-sw.js` exists and is deployed with the app (Flutter copies `web/` to `build/web/`, so it is at the same origin as your app).
- **Firebase Console**
  - **Project Settings → Cloud Messaging → Web Push certificates**: generate a key pair and add the **Key pair** (VAPID key).
  - In the app, `NotificationService.webVapidKey` must match this key (see `lib/services/notification_service.dart`). If you generate a new key in the console, update `webVapidKey` in code.
- **Browser**
  - User must **allow** notifications when the site requests permission; otherwise no token is saved.
  - HTTPS is required (and used in production).
  - Foreground: FCM messages are received and shown via the browser Notification API. Background: `firebase-messaging-sw.js` shows the notification.

---

## 5. Cloud Functions (backend)

- **Deployed**
  - Run `firebase deploy` (or `firebase deploy --only functions`) so `onAppointmentCreated` and `onAppointmentStatusChange` are deployed.
- **Recipients**
  - **New pending appointment**: users with role `secretary` or `admin`, or with `appointments` in `permissions` (or role `admin`/`secretary`).
  - **Status change (confirmed/completed/cancelled/no_show)**: the appointment’s patient, the appointment’s doctor (via `doctors` collection `userId`), and the same secretary/admin/appointments users as above.
- **Token field**
  - Functions read `users/{uid}.fcmToken`. If this field is missing or empty for a user, they will not receive FCM.

---

## 6. Quick checks when notifications don’t appear

1. **Firestore**
   - Open `users/{your-uid}` and check that `fcmToken` is set and non-empty after you log in. If it is empty, the app did not get or save a token (permission denied, init error, or platform config issue).
2. **Permission**
   - **Android**: Settings → Apps → Awda Center → Notifications → enabled.
   - **iOS**: Settings → Awda Center → Notifications → Allow Notifications.
   - **Web**: Browser site settings → Notifications → Allow.
3. **Cloud Functions**
   - In Firebase Console → Functions, confirm the latest deployment and check logs for errors when an appointment is created or status is updated.
4. **Who receives**
   - Patient: receives status updates for their appointments.
   - Doctor: receives status updates for appointments where they are the doctor (and their `users` doc has `fcmToken`).
   - Secretaries/admins (or users with `appointments`): receive new pending appointment and status updates.

---

## 7. Local reminders (Android / iOS only)

- **Patients**: Next 7 days appointments; reminder day before 6 PM or same day 7 AM.
- **Doctors**: Same, for their appointments.
- **Admins**: To-do items with `reminderAt` (for users with `admin_todos`).
- **Web**: Local scheduled notifications are not used; only FCM push is used on web.

If local reminders don’t fire, ensure the app has been opened at least once after login (so `refreshTokenAndScheduleReminders` has run and scheduled them) and that the device is not killing the app in a way that prevents scheduling (check battery/background restrictions).
