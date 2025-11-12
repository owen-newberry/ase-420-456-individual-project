#!/usr/bin/env node
// Simple PocketBase seeder: creates trainer, athlete, a template and a plan
// Usage: POCKETBASE_URL=http://localhost:8090 ADMIN_EMAIL=admin@example.com ADMIN_PASSWORD=<pwd> node scripts/pocketbase_seeder.js

const fetch = global.fetch || require('node-fetch');

// Normalize POCKETBASE_URL so users can set it to the admin dashboard URL (e.g. http://localhost:8090/_/)
// This strips trailing slashes and any trailing '/_'
let PB_URL = process.env.POCKETBASE_URL || 'http://localhost:8090';
PB_URL = PB_URL.replace(/\/+$|\/+$/g, '');
PB_URL = PB_URL.replace(/\/_$/g, '');
const ADMIN_EMAIL = process.env.ADMIN_EMAIL;
const ADMIN_PASSWORD = process.env.ADMIN_PASSWORD;
const ADMIN_COOKIE = process.env.ADMIN_COOKIE; // optional: allow passing an already-authenticated admin cookie
const EXISTING_TRAINER_ID = process.env.TRAINER_ID;
const EXISTING_ATHLETE_ID = process.env.ATHLETE_ID;

if (!ADMIN_EMAIL || !ADMIN_PASSWORD) {
  console.error('Please set ADMIN_EMAIL and ADMIN_PASSWORD environment variables.');
  process.exit(1);
}

async function loginAdmin() {
  // If ADMIN_COOKIE is provided, use it directly (handy when you logged in via the browser and copied the cookie)
  if (ADMIN_COOKIE) {
    console.log('Using provided ADMIN_COOKIE from env.');
    return ADMIN_COOKIE;
  }

  const res = await fetch(`${PB_URL}/api/admins/auth-with-password`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ identity: ADMIN_EMAIL, password: ADMIN_PASSWORD }),
  });
  if (!res.ok) throw new Error('Admin login failed: ' + res.statusText);
  const setCookie = res.headers.get('set-cookie');
  if (!setCookie) throw new Error('No set-cookie returned from admin login');
  // Use cookie for subsequent admin-authenticated requests
  const cookie = setCookie.split(';')[0];
  return cookie;
}

async function createRecord(collection, body, cookie) {
  const res = await fetch(`${PB_URL}/api/collections/${collection}/records`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', cookie },
    body: JSON.stringify(body),
  });
  const json = await res.json();
  if (!res.ok) throw new Error(`Failed to create ${collection} record: ${JSON.stringify(json)}`);
  return json;
}

async function run() {
  try {
    console.log('Logging in as admin...');
    const cookie = await loginAdmin();
    console.log('Admin login OK. Cookie:', cookie);

    let trainer;
    let athlete;
    if (EXISTING_TRAINER_ID) {
      console.log('Using provided trainer id from TRAINER_ID env:', EXISTING_TRAINER_ID);
      trainer = { id: EXISTING_TRAINER_ID };
    } else {
      console.log('Creating trainer user...');
      trainer = await createRecord('users', {
        email: 'trainer@dnasports.test',
        password: 'TrainerPass123',
        passwordConfirm: 'TrainerPass123',
        displayName: 'Coach',
        role: 'trainer'
      }, cookie);
      console.log('Trainer created:', trainer.id);
    }

    if (EXISTING_ATHLETE_ID) {
      console.log('Using provided athlete id from ATHLETE_ID env:', EXISTING_ATHLETE_ID);
      athlete = { id: EXISTING_ATHLETE_ID };
    } else {
      console.log('Creating athlete user...');
      athlete = await createRecord('users', {
        email: 'athlete@dnasports.test',
        password: 'AthletePass123',
        passwordConfirm: 'AthletePass123',
        displayName: 'Athlete One',
        role: 'athlete',
        trainer: trainer.id
      }, cookie);
      console.log('Athlete created:', athlete.id);
    }

    console.log('Creating a sample template...');
    const template = await createRecord('templates', {
      name: 'Sample Full Body',
      createdBy: trainer.id,
      exercises: JSON.stringify([
        { id: 'e1', name: 'Back Squat', sets: 4, reps: '6-8', notes: 'Build to working sets' },
        { id: 'e2', name: 'Push Press', sets: 3, reps: '5-6', notes: 'Explosive' }
      ])
    }, cookie);
    console.log('Template created:', template.id);

    console.log('Creating a sample plan for today...');
    const today = new Date().toISOString().slice(0,10);
    const plan = await createRecord('plans', {
      athlete: athlete.id,
      date: today,
      exercises: JSON.stringify([
        { id: 'e1', name: 'Back Squat', sets: 4, reps: '6-8' },
        { id: 'e2', name: 'Push Press', sets: 3, reps: '5-6' }
      ]),
      createdBy: trainer.id
    }, cookie);
    console.log('Plan created:', plan.id);

    console.log('Seeding complete. Created trainer, athlete, template, and plan.');
    console.log('Trainer credentials: trainer@dnasports.test / TrainerPass123');
    console.log('Athlete credentials: athlete@dnasports.test / AthletePass123');
  } catch (err) {
    console.error('Seeding failed:', err);
    process.exit(1);
  }
}

run();
