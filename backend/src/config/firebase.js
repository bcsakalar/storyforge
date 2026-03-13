const admin = require('firebase-admin');
const path = require('path');

let firebaseApp = null;

function initFirebase() {
  if (firebaseApp) return firebaseApp;

  const serviceAccountPath = process.env.FIREBASE_SERVICE_ACCOUNT_PATH;
  const projectId = process.env.FIREBASE_PROJECT_ID;

  if (!serviceAccountPath && !projectId) {
    console.warn('Firebase: No credentials configured. Push notifications disabled.');
    return null;
  }

  try {
    if (serviceAccountPath) {
      const absolutePath = path.resolve(serviceAccountPath);
      const serviceAccount = require(absolutePath);
      firebaseApp = admin.initializeApp({
        credential: admin.credential.cert(serviceAccount),
      });
    } else {
      // Use application default credentials
      firebaseApp = admin.initializeApp({
        credential: admin.credential.applicationDefault(),
        projectId,
      });
    }
    console.log('Firebase initialized successfully');
  } catch (err) {
    console.error('Firebase init error:', err.message);
    return null;
  }
  return firebaseApp;
}

function getMessaging() {
  const app = initFirebase();
  if (!app) return null;
  return admin.messaging(app);
}

module.exports = { initFirebase, getMessaging };
