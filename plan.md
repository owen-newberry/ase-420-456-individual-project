# Sprint 1 — Athlete + Firebase foundation (weeks 1–5)

## Week 1 — Firebase project & core setup

### Action: Create the Firebase project (owner/developer step)

Follow the checklist below to create the Firebase project and capture the details needed by the Android app and CI.

- [ ] Pick a project name (e.g. dna-sports-center-dev) and create the Firebase project in the console or via the CLI.
- [ ] Record the Firebase Project ID here: 
- [ ] Enable Email/Password authentication in the Firebase Console -> Authentication -> Sign-in method.
- [ ] Enable Cloud Firestore (Native mode) and create a start collection to initialize the DB.
- [ ] Enable Firebase Storage (default bucket) for video uploads. Consider enabling CORS rules only if hosting videos from other domains.
- [ ] Enable Cloud Functions (or plan to use Cloud Run) — enable billing if you plan to use non-trivial compute for video processing or scheduled tasks.
- [ ] Register the Android app in the Firebase Console (provide the Android package name / applicationId).
	- Download `google-services.json` and place it at `android/app/google-services.json` (do not commit secrets to public repos).
	- Add the Android app SHA-1 if you plan to use Google sign-in or dynamic links (optional for email/password).
- [ ] Add one or two test users (trainer and athlete) in Authentication for quick verification.

Notes:
- If you prefer using the CLI to create projects, you can use `firebase projects:create` — however the Console is easiest for initial setup and enabling services.
- Add the Project ID and any notes (billing plan, default storage bucket, etc.) in `plan.md` after creating the project.
## Week 2 — Auth flows & user model
- Implement trainer provisioning flow (trainer creates athlete accounts) using Admin SDK or Cloud Function.
- Implement athlete sign-in, secure local token handling.
- Implement Firestore collections for plans, templates, logs, videos.
- Write security rules (trainers manage templates/plans; athletes read their plans and write logs only for their uid).
- Implement API patterns (Firestore structure, sample queries).
- Deliverable: Athlete can fetch a plan for selected date securely.

## Week 4 — Workout logging + offline support
- Implement log UI and write workoutLogs to Firestore.
- Configure Firestore offline persistence in Flutter.
- Implement optimistic UI & basic conflict handling.
- Deliverable: Logs persist offline and sync when online.

## Week 5 — Progress page + aggregation
- Create aggregated stats endpoints — either client-side aggregation with Firestore queries or Cloud Function for heavier aggregation.
- Add basic charts in Flutter (weights/reps over time).
- QA & staging deploy.
- Deliverable: Progress page with usable historical charts.

# Sprint 2 — Trainer features, video handling & polish (weeks 6–10)

## Week 6 — Trainer web/admin UI & role checks
- Build trainer dashboard (Flutter Web or simple React admin) to list athletes and templates.
- Implement RBAC enforcement in UI (check custom claims).
- Deliverable: Trainer dashboard functional.

## Week 7 — Workout templates & plan assignment
- CRUD for templates; UI to create plans from templates and assign to athlete(s) for dates.
- Use batched writes / transactions for bulk assignment.
- Deliverable: Create + assign templates.

## Week 8 — Video upload & processing
- Implement upload to Firebase Storage with resumable upload UI.
- Add Cloud Function to generate thumbnail + store video metadata in Firestore.
- Deliverable: Upload workflow + embedded video links in workouts.

## Week 9 — Notifications & scheduling
- Implement optional push notifications (FCM) for plan assignments and reminders.
- Add basic scheduling logic (Cloud Scheduler + Functions) for recurring plans.
- Deliverable: Notification flow + scheduled assignments.

## Week 10 — Polish, tests & deploy
- End‑to‑end tests, security rule audit, CI/CD deploy, billing/monitoring setup.
- Deliverable: Production-ready app and documentation.

As the trainer, I should be able to plan workouts for all of my athletes so that the workout plan will populate on the athletes application.
As a trainer, I should be able to create workout templates so that I can easily create a workout plan for a new athlete using a template.
As a trainer, I should be able to upload instructional videos so that I can embed the videos in a particular workout to demonstrate how to properly do a workout.

As an athlete, I should be able to sign in with credentials given to me by trainer.
As an athlete, I should be able to select a day so that I can see my workout plan for that day.
As an athlete, I should be able to log my workout (weight, reps, etc.) so that I can save my data to the database.
As an athlete, I should be able to go to a progress page so that I can see my progress on any given workout ( weights, reps, etc.).
As an athlete, I should be able to see a calendar view so that I can select a day to view a workout plan for that day or fill in information.