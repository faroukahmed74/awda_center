/**
 * Firestore cleanup script: delete all data except admin users.
 * Keeps only users who have role "admin"; deletes all other users and clears listed collections.
 *
 * Run from scripts/: npm install && node clear_firestore_keep_admins.js
 * Set GOOGLE_APPLICATION_CREDENTIALS to your Firebase service account JSON path.
 */

const admin = require('firebase-admin');

const COLLECTIONS_TO_CLEAR = [
  'appointments',
  'sessions',
  'patient_profiles',
  'patient_documents',
  'doctors',
  'doctor_availability',
  'rooms',
  'income_records',
  'expense_records',
  'center_requirements',
  'admin_todos',
  'audit_log',
  'invites',
];

function isAdmin(doc) {
  const d = doc.data() || {};
  const roles = d.roles || (d.role ? [d.role] : []);
  const role = d.role;
  return Array.isArray(roles) ? roles.includes('admin') : role === 'admin';
}

async function main() {
  if (!admin.apps.length) {
    try {
      admin.initializeApp();
    } catch (e) {
      console.error('Initialize Firebase Admin with GOOGLE_APPLICATION_CREDENTIALS or a key file.');
      process.exit(1);
    }
  }
  const db = admin.firestore();

  console.log('1. Deleting non-admin users...');
  const usersSnap = await db.collection('users').get();
  const toDelete = usersSnap.docs.filter((doc) => !isAdmin(doc)).map((doc) => doc.ref);
  for (const ref of toDelete) {
    await ref.delete();
  }
  console.log('   Deleted', toDelete.length, 'non-admin user(s).');

  console.log('2. Clearing collections...');
  const batchSize = 500;
  for (const name of COLLECTIONS_TO_CLEAR) {
    let total = 0;
    let snapshot = await db.collection(name).limit(batchSize).get();
    while (!snapshot.empty) {
      const batch = db.batch();
      snapshot.docs.forEach((d) => batch.delete(d.ref));
      await batch.commit();
      total += snapshot.size;
      snapshot = await db.collection(name).limit(batchSize).get();
    }
    console.log('   Cleared', name + ':', total, 'doc(s).');
  }

  console.log('Done. Only admin users remain in Firestore.');
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
