# Privacy Policy Link for App Store Connect

Apple requires a **public URL** to your app’s privacy policy when you submit to App Store Connect.

## 1. Edit the privacy policy (optional)

- Open **`web/privacy.html`** and replace the placeholder contact email with your real one:
  - Change `privacy@awdacenter.com` to your support or privacy contact email.

## 2. Get a public URL

You need to host `privacy.html` on a public website. Two simple options:

### Option A – Deploy with your Flutter web app

1. Run: `flutter build web`
2. Copy the privacy page into the build output:
   - **macOS/Linux:** `cp web/privacy.html build/web/`
   - **Windows:** `copy web\privacy.html build\web\`
3. Deploy the **`build/web`** folder to your hosting (Firebase Hosting, Vercel, Netlify, your own server, etc.).

Your link will be:

**`https://YOUR-WEB-DOMAIN/privacy.html`**

Example: if your app’s site is `https://awdacenter.web.app`, use **`https://awdacenter.web.app/privacy.html`**.

### Option B – Host only the privacy page

Upload **`web/privacy.html`** to any static host (e.g. Firebase Hosting, GitHub Pages, or your existing website) and use the URL where that file is available.

## 3. Add the link in App Store Connect

1. Open [App Store Connect](https://appstoreconnect.apple.com) → your app.
2. Go to **App Information** (or **App Privacy** / the section where “Privacy Policy URL” is asked).
3. In **Privacy Policy URL**, paste your full link, e.g.:
   - `https://awdacenter.web.app/privacy.html`
   - or whatever URL you used in step 2.

The link must be **https** and **publicly reachable** (no login required).

## Quick Firebase Hosting (if you use it)

If you use Firebase Hosting for your web app:

```bash
flutter build web
cp web/privacy.html build/web/
firebase deploy --only hosting
```

Then use: **`https://YOUR-PROJECT-ID.web.app/privacy.html`** (or your custom domain) in App Store Connect.
