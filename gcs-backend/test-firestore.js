console.log('Node.js script started!');
console.log('GOOGLE_CLOUD_PROJECT env var:', process.env.GOOGLE_CLOUD_PROJECT);

try {
  const {Firestore} = require('@google-cloud/firestore');
  console.log('Successfully required @google-cloud/firestore');
  const db = new Firestore();
  console.log('Firestore client initialized');
  db.collection('test-minimal').limit(1).get()
    .then(snap => {
      console.log('✅ Success! Firestore query executed. Document count:', snap.size);
      process.exit(0);
    })
    .catch(err => {
      console.error('❌ Firestore query error:', err);
      process.exit(1);
    });
} catch (e) {
  console.error('❌ CRITICAL ERROR:', e);
  process.exit(1);
} 