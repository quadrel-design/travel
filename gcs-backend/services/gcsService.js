/**
 * @fileoverview Google Cloud Storage (GCS) Service (Likely Deprecated).
 * This module provides functions to generate signed URLs for uploading/downloading files
 * and to delete files from Google Cloud Storage.
 * 
 * @deprecated This service module appears to be redundant. 
 * - Signed URL generation is handled directly within `routes/gcs.js`.
 * - File deletion from GCS is typically orchestrated by `routes/projects.js` when an image record is deleted,
 *   which may call `projectService.js` or handle GCS interaction directly.
 * It is recommended to use the functionalities in those respective route files. This file is kept for historical
 * reference or until a full audit confirms it can be safely removed.
 * 
 * @module services/gcsService
 */

const { Storage } = require('@google-cloud/storage');

// Initialize GCS Storage client.
// In Cloud Run, it automatically uses the service's runtime service account.
const storage = new Storage();

// Get bucket name from environment variable or use a default
const bucketName = process.env.GCS_BUCKET_NAME;
if (!bucketName) {
  console.warn('GCS_BUCKET_NAME environment variable is not set. Using default "travel-files". This might be an issue in production.');
}
const GCS_BUCKET_NAME = bucketName || 'travel-files'; // Fallback for safety, but ideally always set via env

console.log('GCS Service: GOOGLE_CLOUD_PROJECT:', process.env.GOOGLE_CLOUD_PROJECT);
// GOOGLE_APPLICATION_CREDENTIALS should be undefined in Cloud Run when not using key files.
console.log('GCS Service: GOOGLE_APPLICATION_CREDENTIALS:', process.env.GOOGLE_APPLICATION_CREDENTIALS);

/**
 * Generate a signed upload URL for a file.
 * @async
 * @deprecated Prefer using the equivalent functionality in `routes/gcs.js` (`POST /api/gcs/generate-upload-url`).
 * @param {string} filename
 * @param {string} contentType
 * @returns {Promise<string>}
 */
async function generateUploadUrl(filename, contentType) {
  if (!GCS_BUCKET_NAME) throw new Error("GCS_BUCKET_NAME is not configured.");
  const bucket = storage.bucket(GCS_BUCKET_NAME);
  const options = {
    version: 'v4',
    action: 'write',
    expires: Date.now() + 15 * 60 * 1000, // 15 minutes
    contentType,
  };
  const [url] = await bucket.file(filename).getSignedUrl(options);
  return url;
}

/**
 * Generate a signed download URL for a file.
 * @async
 * @deprecated Prefer using the equivalent functionality in `routes/gcs.js` (`GET /api/gcs/generate-download-url`).
 * @param {string} filename
 * @returns {Promise<string>}
 */
async function generateDownloadUrl(filename) {
  if (!GCS_BUCKET_NAME) throw new Error("GCS_BUCKET_NAME is not configured.");
  const bucket = storage.bucket(GCS_BUCKET_NAME);
  const options = {
    version: 'v4',
    action: 'read',
    expires: Date.now() + 15 * 60 * 1000, // 15 minutes
  };
  const [url] = await bucket.file(filename).getSignedUrl(options);
  return url;
}

/**
 * Delete a file from GCS.
 * @async
 * @deprecated File deletion from GCS should be handled as part of the image deletion logic in `routes/projects.js`,
 *             which is responsible for both GCS file removal and database record deletion.
 * @param {string} fileName
 * @returns {Promise<void>}
 */
async function deleteFile(fileName) {
  if (!GCS_BUCKET_NAME) throw new Error("GCS_BUCKET_NAME is not configured.");
  const bucket = storage.bucket(GCS_BUCKET_NAME);
  await bucket.file(fileName).delete();
}

module.exports = {
  generateUploadUrl,
  generateDownloadUrl,
  deleteFile,
}; 