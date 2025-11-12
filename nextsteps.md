# Next Steps — PocketBase + Flutter (Sprint 1)

Date: 2025-11-10

## Purpose
This file records the current state of the project, what changed in the last edit, analyzer results, how to seed and run the local PocketBase dev server, and a prioritized list of next actions to finish Sprint 1 (athlete flows + local backend).

## What I changed just now
- Replaced PocketBase SDK usage with a REST-based `PocketBaseService`:
  - File: `app/lib/services/pocketbase_service.dart`
  - Endpoints implemented: auth (`/api/collections/users/auth-with-password`), fetch plans (`/api/collections/plans/records`), create logs (`/api/collections/logs/records`), and upload files to videos.
- Fixed an analyzer error in `app/test/widget_test.dart` (removed `const` usage to match `MyApp` constructor).

These changes avoid a PocketBase SDK API mismatch and let the app call the backend explicitly via HTTP.

## Current workspace status (short)
- Local PocketBase container: expected to be running on port `8090` (admin UI: http://localhost:8090). The compose setup uses host networking via `elestio/pocketbase:latest` in `docker-compose.yml`.
- Seeder script: `scripts/pocketbase_seeder.js` — uses admin cookie authentication to create trainer, athlete, template, and a sample plan for today.
- Flutter project: `app/` — dependencies updated; `flutter pub get` was run previously. `app/lib/services/pocketbase_service.dart` now contains the REST client.

## Analyzer results (after recent fixes)
I ran `flutter analyze` in `app/`. Current findings (informational/warning items remain):

- Remaining analyzer items (info / warnings):
  - Missing `Key? key` parameter in public widget constructors (e.g., `lib/main.dart`, `lib/screens/*.dart`).
  - File names not in snake_case (e.g., `dayView.dart`, `logEntry.dart`, `adminDashboard.dart`, `athleteService.dart`). Consider renaming files to meet Dart conventions.
  - `use_build_context_synchronously` warnings in `lib/screens/logEntry.dart` — add `if (!mounted) return;` checks after await calls in State objects.
  - `@immutable` constructors should be `const` where possible.
- Hard errors: resolved (previous undefined `collection` / `files` members). The REST conversion fixed those.

## How to seed and run the local PocketBase (manual steps)
1. Start PocketBase via Docker Compose (from project root):

```bash
# from repo root
docker compose up -d
```

2. Open the admin UI and create the initial admin account (first-run step):

- Visit: http://localhost:8090
- Create admin email and password (this is required for the seeder to work).

3. Run the seeder script (example):

```bash
# set these to the admin account you created
export POCKETBASE_URL=http://localhost:8090
export ADMIN_EMAIL=admin@example.com
export ADMIN_PASSWORD=YourAdminPassword

# run the seeder
node scripts/pocketbase_seeder.js
```

The seeder will create a trainer and an athlete and print their credentials. It assumes collections named `users`, `templates`, `plans`, and `logs` exist and have appropriate field definitions. If collections are not created, either create them in the admin UI or use the collection import (see next section).

## Option: programmatic collection import
- I can generate a PocketBase collection import JSON (collections + fields per `docs/pocketbase_schema.md`) so you can import them via the admin UI or apply programmatically. Tell me if you want me to generate and commit that JSON; I can also run the import for you (with your permission).

## Prioritized next steps (recommended)
1. Finalize the REST `PocketBaseService` (verify token extraction, error handling, and file upload flow). Re-run `flutter analyze` and fix any remaining critical issues. (Currently in-progress.)
2. Generate and import PocketBase collections (users, templates, plans, logs, videos) or create them manually in the admin UI from `docs/pocketbase_schema.md`.
3. Run `scripts/pocketbase_seeder.js` to create trainer + athlete + sample plan.
4. Fix the Flutter analyzer infos:
   - Rename files to snake_case.
   - Add `Key? key` to public widget constructors and forward to super.
   - Add `if (!mounted) return;` after async awaits in State classes (e.g., `logEntry.dart`).
   - Add `const` to immutable constructors where appropriate.
5. Wire sign-in flow and ensure the athlete id from auth is passed to Day View. Update `app/lib/screens/dayView.dart` and `logEntry.dart` to call the REST client.
6. Run widget tests and a quick integration flow (login -> fetch plan -> create log). Fix regressions.
7. Optional: Add offline caching (Hive/SQLite) and conflict resolution for offline-first behavior.

## Quick commands (dev)

From repo root:

```bash
# start pocketbase
docker compose up -d

# in app/ folder: fetch packages
cd app
flutter pub get

# analyze flutter project
flutter analyze

# run seeder (after admin created)
export POCKETBASE_URL=http://localhost:8090
export ADMIN_EMAIL=admin@example.com
export ADMIN_PASSWORD=YourAdminPassword
node scripts/pocketbase_seeder.js
```

## Notes and assumptions
- Android emulator networking: the REST client defaults to `http://10.0.2.2:8090` so the Android emulator can reach the host PocketBase running on localhost. Running on a physical device or iOS simulator will need to adjust that URL accordingly.
- The seeder expects collections and fields exist. If they do not, create them in the admin UI or ask me to generate an import file and I will apply it.
- I avoided using the PocketBase Dart SDK to prevent issues with SDK API version mismatches; the REST approach is explicit and stable for now.

## Next action I will take if you ask me to proceed
- Optionally generate/import collection JSON and then run the seeder automatically, then wire the auth to the Day View and Log Entry screens and run `flutter analyze` and simple integration checks.

---

If you'd like, I can now (pick one):
- Rename files to snake_case and apply the analyzer fixes automatically (I estimate ~15–30 minutes).
- Generate collection import JSON and apply it, then run the seeder (I estimate ~10–20 minutes).
- Wire the auth flow to the UI and demo a complete login -> fetch plan -> create log cycle (I estimate ~30–60 minutes).

Tell me which of those you'd like me to do next, or paste admin credentials if you want me to run the seeder now.

## Backend checkpoint (pin)
Date: 2025-11-10

I've pinned the current backend/dev-server status here so we can pick up later without re-discovery. Quick facts:

- PocketBase is running locally on port 8090. Admin dashboard: http://localhost:8090/_/
- Data directory (mounted): `pb_data/` at repo root. Backup made: `pb_data.bak.<timestamp>` (if you ran the full-wipe flow earlier). The live DB is `pb_data/data.db`.
- Superuser created: `owen@owennewberry.com` (password used locally: `Cooldude1`). You can recreate or update via:

```bash
docker compose exec pocketbase /usr/local/bin/pocketbase --dir /pb_data superuser upsert 'owen@owennewberry.com' 'Cooldude1'
```

- Collections: the collection schemas exist (`users`, `templates`, `plans`, `logs`, `videos`) but there are currently zero records in them (counts reported as 0). The admin UI shows empty collections.
- Seeder: `scripts/pocketbase_seeder.js` was updated to
  - normalize `POCKETBASE_URL` (strip trailing `/_/`),
  - accept an optional `ADMIN_COOKIE` to bypass admin login, and
  - accept `TRAINER_ID` and `ATHLETE_ID` env vars so it can create templates/plans without creating users.

- Temporary DB change: to allow programmatic record creation during seeding we temporarily set `createRule='true'` for the target collections in the SQLite `_collections` table. This was a temporary developer action — revert it after seeding (instructions below).

How to resume from here (quick):

1. If you want to seed now (recommended flow):
   - Create a trainer and athlete record in the admin UI (or copy their ids if already created).
   - Run the seeder with those ids:

```bash
export POCKETBASE_URL=http://localhost:8090
export TRAINER_ID=<trainerId>
export ATHLETE_ID=<athleteId>
node scripts/pocketbase_seeder.js
```

2. After seeding, revert the temporary `createRule` changes (important):

```bash
# backup DB (if you haven't already)
cp pb_data/data.db pb_data/data.db.postseed.bak

sqlite3 pb_data/data.db "BEGIN TRANSACTION; UPDATE _collections SET createRule=NULL WHERE name IN ('users','templates','plans','logs','videos'); COMMIT;"
```

3. Verify records in admin UI and then continue wiring the Flutter app (auth -> day view -> log flow).

Where we left off (summary):
- PocketBase running and reachable at port 8090.
- Superuser exists and was created via CLI.
- Collections exist but are empty.
- Seeder script is updated but requires TRAINER_ID/ATHLETE_ID (or ADMIN_COOKIE) to create templates/plans.

If you'd like, I can (pick one):
- create trainer/athlete via the admin CLI and run the seeder for you now, then revert the createRule changes; or
- generate a collection import JSON so you can import the schema and re-run seeding later; or
- leave this pinned and we pivot back to the Flutter client work.
