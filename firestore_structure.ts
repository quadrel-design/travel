import * as admin from "firebase-admin";

admin.initializeApp({
  credential: admin.credential.applicationDefault(),
});
const db = admin.firestore();

async function getCollectionStructure(collectionPath: string, depth = 0): Promise<any> {
  const snapshot = await db.collection(collectionPath).limit(10).get();
  const structure: any = {};
  for (const doc of snapshot.docs) {
    const data = doc.data();
    for (const key of Object.keys(data)) {
      if (!structure[key]) structure[key] = typeof data[key];
    }
    const subcollections = await doc.ref.listCollections();
    for (const sub of subcollections) {
      structure[sub.id] = await getCollectionStructure(`${collectionPath}/${doc.id}/${sub.id}`, depth + 1);
    }
    if (depth === 0) break;
  }
  return structure;
}

(async () => {
  const collections = await db.listCollections();
  const dbStructure: any = {};
  for (const col of collections) {
    dbStructure[col.id] = await getCollectionStructure(col.id);
  }
  console.log(JSON.stringify(dbStructure, null, 2));
  process.exit(0);
})(); 