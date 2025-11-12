# PocketBase setup — DNA Sports Center (Android)

This document explains how to run PocketBase locally for development, create the collections used by Sprint 1, and how to connect the Android Flutter app.

1) Run PocketBase with Docker (dev)

Create a folder `pb_data/` at project root to persist data. Use the provided `docker-compose.yml` (repo root) and start PocketBase:

```bash
docker compose up -d
# admin UI: http://localhost:8090
```

2) Access the admin UI
- Open http://localhost:8090 and create an admin user when prompted.

3) Collections to create (Sprint 1)
- users (use the built-in users collection or create a `profiles` collection): fields: `displayName` (text), `role` (text, trainer/athlete), `trainer` (relation to users)
- templates: `name` (text), `createdBy` (relation to users), `exercises` (json/object) — each exercise: id, name, sets, reps, notes, video (relation to videos collection)
- plans: `athlete` (relation to users), `date` (text yyyy-mm-dd), `exercises` (json/object), `createdBy` (relation)
- logs: `athlete` (relation), `plan` (relation), `exerciseId` (text), `sets` (json array of {weight, reps, notes, timestamp}), `createdAt` (date)
- videos: `title` (text), `description` (text), `file` (file), `thumbnailUrl` (text), `uploadedBy` (relation)

Create these collections through the admin UI, adding the fields above. For `exercises` and `sets`, use a JSON field (or text) that your client will parse.

4) Permissions / record rules (dev)
- In dev you can initially allow authenticated users to read/write while you model the flows. For Sprint 1, enforce these rules manually:
  - templates & plans: writable by trainers only (role === 'trainer')
  - logs: can be created by the athlete that owns them; trainers can read
  - videos: only trainers can upload/manage

5) File storage
- Uploaded files are stored in the `pb_data` directory by default in Docker. For production, consider S3-backed storage and configure PocketBase accordingly.

6) PocketBase API notes
- Use the PocketBase Dart client (`pocketbase` package) or raw REST API.
- Android emulator note: when running PocketBase locally, from the Android emulator use `http://10.0.2.2:8090` to reach the host machine.

7) Helpful commands

```bash
# start the server
docker compose up -d
# stop
docker compose down
# view logs
docker compose logs -f
```

8) Next steps
- Create the collections and add a trainer and athlete test user in the admin UI.
- I can generate an import JSON for the collections if you'd like an automated import of schema and sample records.
