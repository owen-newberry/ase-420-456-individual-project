const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

/**
 * Triggered when a file is uploaded to Firebase Storage.
 * Recommended: offload thumbnail/transcode work to Cloud Run or a third-party service.
 */
exports.onVideoUpload = functions.storage.object().onFinalize(async (object) => {
  console.log('Video uploaded:', object.name);
  // TODO: generate thumbnail via Cloud Run or a transcoder service
  // Then write video metadata to Firestore under /videos/{id}
  return null;
});

/**
 * Callable function that allows a trainer to create an athlete account and set custom claims.
 * Expects data: { email, password, displayName, trainerId }
 */
exports.createAthleteAccount = functions.https.onCall(async (data, context) => {
  // Only allow trainers (custom claim) to call this function
  if (!(context.auth && context.auth.token && context.auth.token.role === 'trainer')) {
    throw new functions.https.HttpsError('permission-denied', 'Only trainers can create athlete accounts.');
  }

  const { email, password, displayName, trainerId } = data;
  if (!email || !password) {
    throw new functions.https.HttpsError('invalid-argument', 'Email and password are required.');
  }

  const user = await admin.auth().createUser({ email, password, displayName });
  await admin.auth().setCustomUserClaims(user.uid, { role: 'athlete', trainerId });
  await admin.firestore().collection('users').doc(user.uid).set({
    displayName: displayName || null,
    email,
    role: 'athlete',
    trainerId: trainerId || null,
    createdAt: admin.firestore.FieldValue.serverTimestamp()
  });

  return { uid: user.uid };
});
