# PocketBase seeding instructions (create sample records)

These instructions help you create test accounts and sample records after you deploy PocketBase locally and create collections via the admin UI.

1) Start PocketBase locally (if not already running)

```bash
# requires Docker installed
docker compose up -d
# admin UI: http://localhost:8090
```

2) Create an admin user via the web UI at http://localhost:8090 — follow the prompt on first run.

3) Use the admin UI to create the collections from `docs/pocketbase_schema.md`.

4) Create a trainer and athlete user via the admin UI (Authentication > Users or Users collection). Note their emails and passwords.

5) Create a sample template and plan via the admin UI (Templates > New Record, Plans > New Record). Use sample JSON from `docs/pocketbase_schema.md`.

6) (Optional) Seed via API using curl: after creating an admin and signing in, use the following pattern to create records via the REST API.

# Example: sign in as admin to get session cookie
```bash
curl -c cookiejar.txt -X POST "http://localhost:8090/api/admins/auth-with-password" \
  -H "Content-Type: application/json" \
  -d '{"identity":"admin@example.com","password":"<ADMIN_PASSWORD>"}'
```

# Example: create a trainer user via API (adjust fields to match your collections)
```bash
curl -b cookiejar.txt -X POST "http://localhost:8090/api/collections/users/records" \
  -H "Content-Type: application/json" \
  -d '{"email":"trainer@dnasports.test","password":"TrainerPass123","displayName":"Coach","role":"trainer"}'
```

# Example: create an athlete user
```bash
curl -b cookiejar.txt -X POST "http://localhost:8090/api/collections/users/records" \
  -H "Content-Type: application/json" \
  -d '{"email":"athlete@dnasports.test","password":"AthletePass123","displayName":"Athlete One","role":"athlete","trainer":"<trainerUserId>"}'
```

Notes:
- The admin sign-in will set a session cookie inside `cookiejar.txt`; use `-b cookiejar.txt` to send it with subsequent requests.
- You may need to adapt field names to match exact field keys created in the collections.

If you'd like, I can add a scripted seeder (Node) that automates these curl calls — I left this as manual/curl steps because the initial admin user must be created via the UI on first run.
