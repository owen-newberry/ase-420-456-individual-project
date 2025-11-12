# PocketBase collection schema (Sprint 1)

This file documents the PocketBase collections and fields to create for Sprint 1 (athlete flows).

Collections

1) users (use PocketBase built-in `users` collection)
  - displayName: text
  - role: text (trainer | athlete)
  - trainer: relation -> users (nullable) — for athlete records store their trainer's user id

2) templates
  - name: text
  - createdBy: relation -> users
  - exercises: json (text) — stores a JSON array of exercise objects. Each exercise object should follow this shape:
      {
        "id": "e1",             // stable local id for the exercise in the template
        "name": "Back Squat",
        "sets": 4,               // number of sets the trainer prescribes (integer)
        "reps": "6-8",         // reps per set (string or number)
        "notes": "Warm up first",
        "videoId": "v1"        // optional reference to videos collection record id
      }
    Note: PocketBase does not have a native JSON field type — use a `text` field and store serialized JSON. Clients must deserialize/serialize this field.
  - createdAt: dateTime

3) plans
  - athlete: relation -> users
  - date: text (YYYY-MM-DD)
  - exercises: json (text) — copy of exercises from template or a custom JSON array. Each exercise in the plan should include the `sets` and `reps` fields so the LogEntry screen can render the correct number of input rows and reps value.
    Example plan exercise item:
      { "id": "e1", "name": "Back Squat", "sets": 5, "reps": "5" }
  - createdBy: relation -> users
  - createdAt: dateTime

4) logs
  - athlete: relation -> users
  - plan: relation -> plans
  - exerciseId: text
  - sets: json (text) — serialized JSON array of set entries. Each set entry should include at least:
      {
        "weight": 120.5,              // number (kg/lb depending on app settings)
        "reps": 5,                    // integer
        "notes": "Felt strong",     // optional text
        "timestamp": "2025-11-11T15:03:00Z" // optional ISO8601 timestamp
      }
    The LogEntry UI saves per-set records with the `reps` value taken from the plan's exercise `reps` and allows the athlete to enter `weight` and optional notes.
  - createdAt: dateTime

5) videos
  - title: text
  - description: text
  - file: file
  - thumbnailUrl: text
  - uploadedBy: relation -> users
  - createdAt: dateTime

Notes
- For `exercises` and `sets` we use JSON fields for flexibility. PocketBase supports JSON via the "text" field where clients store serialized JSON, or you can use multiple fields depending on your UI needs.
- Use relations for `athlete`, `createdBy`, and `uploadedBy` to make queries easier and enforce referential integrity in the client.
- For production, consider moving large video files to S3 and storing the URL in `videos.file` or `videos.s3Path` and configure PocketBase file storage accordingly.

Sample record examples (JSON-ish)

- Template example:

```
{
  "name": "Hypertrophy Lower",
  "createdBy": "<trainerUserId>",
  "exercises": [
    {"id": "e1", "name": "Back Squat", "sets": 4, "reps": "6-8", "notes": "Warm up sets first", "videoId": "v1"},
    {"id": "e2", "name": "Romanian Deadlift", "sets": 3, "reps": "8-10", "notes": "Focus on hip hinge", "videoId": "v2"}
  ]
}
```

- Plan example:

```
{
  "athlete": "<athleteUserId>",
  "date": "2025-11-20",
  "exercises": [ ... copy from template ... ],
  "createdBy": "<trainerUserId>"
}
```
