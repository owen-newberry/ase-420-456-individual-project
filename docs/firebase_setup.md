# Firebase project setup — DNA Sports Center (Android)

This document lists the step-by-step actions to create and configure the Firebase project for Sprint 1 (Android-only development).

1) Choose a project name and create the project
- Prefer a name like `dna-sports-center-dev` (use separate projects for `stage` and `prod` later).
- You can create the project in the Firebase Console: https://console.firebase.google.com/
- Alternatively, use the Firebase CLI (may require enabling Cloud APIs):

```bash
# install firebase CLI if not present
npm install -g firebase-tools
# login
firebase login
# create project (example)
# firebase projects:create dna-sports-center-dev --display-name "DNA Sports Center (dev)"
```

2) Enable core services
- Authentication -> Sign-in method -> enable Email/Password.
- Firestore -> Create database -> Native mode -> choose location.
- Storage -> Use default bucket.
- Functions -> enable (you will need billing for outbound networking or longer running jobs).

3) Register the Android app
- In the Firebase Console, go to Project Settings -> Add App -> Android.
- Provide the Android package name (applicationId). Example: `com.dnasports.center` (replace with your app's package name from `android/app/build.gradle`).
- Optionally add a nickname and SHA-1 (for Google sign-in or App signing features).
- Download the generated `google-services.json` and place it at `android/app/google-services.json` in your Flutter project.

Security note: do NOT commit `google-services.json` to public repos. For private repos you may commit to a protected branch or add CI secrets that inject the file at build time.

4) Initial security and billing considerations
- If you enable Storage and plan to accept video uploads, enable billing to avoid cold-start and processing limitations.
- Set up Billing Alerts in the Google Cloud Console to avoid surprises while testing video uploads.

5) Initial test users
- Add a trainer account and an athlete account in Authentication -> Users for manual testing.
- Keep a secure record of test credentials in your project notes (do not commit passwords).

6) Next steps after project creation
- Record the Project ID in `plan.md` under Week 1.
- Run `firebase init` in the repository root to scaffold `firebase.json`, `firestore.rules`, and the `functions/` directory (see todo #2).
- Add `google-services.json` to `android/app/` and update `android/build.gradle` / `android/app/build.gradle` per FlutterFire instructions.

Recommended CLI commands (macOS zsh):
```bash
# install CLI
npm install -g firebase-tools
# login
firebase login
# initialize project files (run after creating project in console and linking via firebase use)
firebase init
```

Useful links
- FlutterFire docs: https://firebase.flutter.dev/docs/overview
- Firebase Console: https://console.firebase.google.com/
- Firestore security rules guide: https://firebase.google.com/docs/firestore/security/get-started

If you want, I can now:
- open a checklist for you to fill `Project ID` and `Android package name` into `plan.md`, or
- scaffold `firebase.json` and a `firestore.rules` starter file in the repo for when you run `firebase init`.
