# Run PocketBase locally and seed sample data

Steps to run PocketBase and seed sample data created by the repository.

1) Start PocketBase (we've provided a docker-compose that uses `elestio/pocketbase:latest`):

```bash
docker compose up -d
```

Admin UI will be available at: http://localhost:8090 — create the first admin user when prompted.

2) Create collections via the admin UI following `docs/pocketbase_schema.md`.

3) Seed sample data using the script in `scripts/pocketbase_seeder.js`.

Example (macOS/Linux) — run from repo root:

```bash
# set env vars for the admin account you created in the admin UI
export POCKETBASE_URL=http://localhost:8090
export ADMIN_EMAIL=admin@example.com
export ADMIN_PASSWORD=YourAdminPassword

node scripts/pocketbase_seeder.js
```

The seeder will create:
- trainer user (trainer@dnasports.test / TrainerPass123)
- athlete user (athlete@dnasports.test / AthletePass123)
- a sample template and a plan for today

If the seeder fails with HTTP errors, double-check that the admin credentials are correct and that collections `templates` and `plans` exist.
