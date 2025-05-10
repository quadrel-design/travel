const { Storage } = require('@google-cloud/storage');
const path = require('path');

const serviceAccountPath = path.join(__dirname, '../service-account.json');
const storage = new Storage({ keyFilename: serviceAccountPath });
const bucket = storage.bucket('travel-files');

async function generateUploadUrl(filename, contentType) {
  const [url] = await bucket.file(filename).getSignedUrl({
    version: 'v4',
    action: 'write',
    expires: Date.now() + 15 * 60 * 1000, // 15 minutes
    contentType,
  });
  return url;
}

async function generateDownloadUrl(filename) {
  const [url] = await bucket.file(filename).getSignedUrl({
    version: 'v4',
    action: 'read',
    expires: Date.now() + 15 * 60 * 1000, // 15 minutes
  });
  return url;
}

async function deleteFile(fileName) {
  await bucket.file(fileName).delete();
  return true;
}

module.exports = {
  generateUploadUrl,
  generateDownloadUrl,
  deleteFile,
}; 