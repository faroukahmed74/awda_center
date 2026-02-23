# Awda Center — Run the app & check Firebase

Follow these steps in order to run the app and verify Firebase and all features.

---

## Step 1: Generate Flutter Firebase config

You added **google-services.json** (Android) and **GoogleService-Info.plist** (iOS) manually. The app also needs **`lib/firebase_options.dart`** (used by Flutter at runtime). Generate it with FlutterFire:

```bash
cd /Users/ahmedfarouk/StudioProjects/awda_center
dart run flutterfire configure
```

- Select your existing Firebase project (the one where you created the Android/iOS apps).
- Choose platforms: **Android**, **iOS**, **Web**, **macOS** (and Windows if you need it).
- This will **overwrite** `lib/firebase_options.dart` with real API keys and project ID. Your existing `google-services.json` and `GoogleService-Info.plist` stay as they are; FlutterFire links everything.

If the command fails (e.g. “no Firebase project”), install the CLI and log in:

```bash
dart pub global activate flutterfire_cli
firebase login
dart run flutterfire configure
```

---

## Step 2: Firebase Console setup

In [Firebase Console](https://console.firebase.google.com) → your project:

1. **Authentication**
   - Go to **Build → Authentication → Sign-in method**.
   - Enable **Email/Password** (first provider in the list).

2. **Firestore**
   - Go to **Build → Firestore Database**.
   - If you don’t have a database, click **Create database** (you can start in **test mode** for development).
   - Go to **Rules** and paste the contents of your project’s **`firestore.rules`** file, then **Publish**.

---

## Step 3: Run the app

```bash
flutter clean
flutter pub get
```

Then run on the platform you want:

```bash
# Android (device or emulator)
flutter run -d android

# iOS (simulator or device)
flutter run -d ios

# Web (Chrome)
flutter run -d chrome

# macOS (desktop)
flutter run -d macos
```

If you see “No devices found”, start an Android emulator or iOS simulator from Android Studio / Xcode, or connect a physical device.

---

## Step 4: Check Firebase connectivity and features

### 4.1 Auth and first user

1. Open the app → you should see the **Login** screen.
2. Tap **Register** (or “إنشاء حساب” in Arabic).
3. Enter email, password, and name → **Register**.
4. If registration succeeds, you should be taken to the **Dashboard** and see a welcome message.  
   → **Firebase Auth and Firestore are working** (the app creates a user document on first register).

### 4.2 First admin (required for full features)

1. In Firebase Console → **Firestore** → **users** collection.
2. Find the document whose **document ID** is the new user’s UID (same as in Authentication → Users → UID).
3. Edit that document:
   - Set **`role`** = `admin`
   - Set **`isActive`** = `true`
4. In the app, **log out** (app bar) and **log in again** with the same email/password.  
   → You should now see the full **admin** drawer: Users, Appointments, Patients, Income & expenses.

### 4.3 Quick feature checklist

| What to do | What to check |
|------------|----------------|
| **Language** | App bar → language icon → switch to Arabic; UI and layout should go RTL. |
| **Theme** | App bar → sun/moon icon → switch light/dark; preference should persist after restart. |
| **Users (admin)** | Drawer → Users → list loads; change a user’s role or Active and save. |
| **Appointments** | Drawer → Appointments → list (may be empty); open menu on an appointment to change status. |
| **Patients** | Drawer → Patients → list; tap a patient → Patient detail (sessions, documents). |
| **Income & expenses** | Drawer → Income & expenses → totals and lists; use “+” to add income/expense. |
| **Register another user as patient** | Register with a different email → log in → drawer shows “My Appointments” and “Profile”. |

If any step fails (e.g. “permission denied” in Firestore), re-check **Step 2** (Auth enabled, Firestore rules deployed) and that you ran **Step 1** so `firebase_options.dart` matches your project.

---

## Step 5: If something fails

- **“Firebase not configured” / Auth or Firestore errors**  
  Run **Step 1** again (`dart run flutterfire configure`) and ensure you select the same Firebase project and the correct platforms.

- **“Permission denied” in Firestore**  
  Deploy the project’s **`firestore.rules`** in Firebase Console → Firestore → Rules (see Step 2).

- **Android build errors about package name**  
  Confirm `applicationId` in `android/app/build.gradle.kts` is `com.faroukahmed.awdacenter` and that `google-services.json` has `"package_name": "com.faroukahmed.awdacenter"`.

- **iOS build / signing**  
  Open `ios/Runner.xcworkspace` in Xcode, select the Runner target, and set the correct **Team** and **Bundle Identifier** (`com.faroukahmed.awdacenter`).

- **Web: Auth or Firestore not working**  
  In Firebase Console → Project settings → **Your apps**, add a **Web** app if you don’t have one. Then run `flutterfire configure --platforms=web` to refresh `lib/firebase_options.dart` with the web app’s config.

- **macOS**  
  The app uses the same Firebase project as iOS. If macOS build fails, open `macos/Runner.xcworkspace` in Xcode and set the correct **Team** and **Bundle Identifier** (`com.faroukahmed.awdacenter`).

---

## Summary

1. Run **`dart run flutterfire configure`** to generate `firebase_options.dart`.
2. In Firebase Console: enable **Email/Password** Auth and create Firestore + deploy **`firestore.rules`**.
3. **`flutter clean && flutter pub get`** then **`flutter run -d android`** (or `ios`, `chrome`, `macos`).
4. **Register** a user, then in Firestore set that user’s **`role`** to **`admin`** and **`isActive`** to **`true`**, log out and log in again.
5. Use the checklist above to verify connectivity and all features.
