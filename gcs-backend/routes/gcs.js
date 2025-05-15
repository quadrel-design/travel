/**
 * @fileoverview Google Cloud Storage (GCS) Operation Routes.
 * Provides API endpoints for interacting with Google Cloud Storage, primarily for generating
 * signed URLs that allow clients to directly upload or download files.
 * This facilitates secure client-side interaction with GCS buckets without exposing service account keys.
 * All routes require Firebase authentication.
 * The GCS bucket name is configured via the `GCS_BUCKET_NAME` environment variable.
 * @module routes/gcs
 * @basepath /api/gcs
 */

const express = require('express');
const router = express.Router();
const { Storage } = require('@google-cloud/storage');
const firebaseAdmin = require('firebase-admin');

// Initialize GCS Storage client
let storage;
let bucket;
const bucketName = process.env.GCS_BUCKET_NAME;

if (!bucketName) {
  console.error('[Routes/GCS] CRITICAL: GCS_BUCKET_NAME environment variable is not set. GCS operations will fail.');
  // router will still be exported, but routes will fail
} else {
  try {
    storage = new Storage();
    bucket = storage.bucket(bucketName);
    console.log(`[Routes/GCS] GCS Storage client and bucket '${bucketName}' initialized successfully.`);
  } catch (error) {
    console.error(`[Routes/GCS] CRITICAL ERROR initializing GCS Storage client or bucket '${bucketName}':`, error);
    // GCS operations will fail
    storage = null;
    bucket = null;
  }
}

console.log(`[Routes/GCS] Module loaded. Bucket name configured: ${bucketName ? bucketName : 'NOT SET - OPERATIONS WILL FAIL'}`);

// Middleware to check if user is authenticated
const authenticateUser = async (req, res, next) => {
  if (firebaseAdmin.apps.length === 0) {
    console.error('[Routes/GCS][AuthMiddleware] Firebase Admin SDK not initialized. Cannot authenticate.');
    return res.status(500).json({ error: 'Authentication service not configured.' });
  }
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({ error: 'Unauthorized: No token provided' });
    }

    const token = authHeader.split(' ')[1];
    const decodedToken = await firebaseAdmin.auth().verifyIdToken(token);
    
    req.user = {
      id: decodedToken.uid,
      email: decodedToken.email
    };
    
    next();
  } catch (error) {
    console.error('[Routes/GCS] Error authenticating user:', error);
    if (error.code === 'auth/id-token-expired') {
      return res.status(401).json({ error: 'Unauthorized: Token expired', code: 'TOKEN_EXPIRED' });
    }
    if (error.code === 'auth/argument-error') {
      console.error('[Routes/GCS][AuthMiddleware] Firebase ID token verification failed.');
    }
    return res.status(401).json({ error: 'Unauthorized: Invalid token' });
  }
};

// Apply authentication middleware to all routes
router.use(authenticateUser);

/**
 * @route POST /api/gcs/generate-upload-url
 * @summary Generate a v4 signed URL for client-side file upload to GCS.
 * @description Creates a short-lived (15 minutes) signed URL that grants write access to a specific GCS object path.
 * The client can use this URL with an HTTP PUT request to upload the file directly to GCS.
 * This is the preferred method for uploading files from the client.
 *
 * @body {string} filename - The desired GCS object path, including the filename (e.g., `users/firebase-uid/projects/project-id/images/image-id/original_file.jpg`).
 *                           It is crucial that this path is unique and correctly structured as per application requirements.
 * @body {string} contentType - The MIME type of the file to be uploaded (e.g., `image/jpeg`, `application/pdf`).
 *
 * @returns {object} 200 - JSON object containing the signed URL.
 *   @example response - 200 - Success
 *   {
 *     "url": "https://storage.googleapis.com/your-bucket-name/your-filename.jpg?X-Goog-Algorithm=..."
 *   }
 * @returns {Error} 400 - If `filename` or `contentType` is missing in the request body.
 * @returns {Error} 500 - If the GCS bucket is not initialized or if there's an error generating the signed URL.
 */
router.post('/generate-upload-url', async (req, res) => {
  console.log('[Routes/GCS] /generate-upload-url POST hit. Request body:', req.body);

  if (!bucket) {
    console.error('[Routes/GCS] GCS bucket is not initialized. Cannot generate upload URL.');
    return res.status(500).json({ error: 'Server configuration error: File storage service not available.' });
  }

  const { filename, contentType } = req.body;

  if (!filename || !contentType) {
    return res.status(400).json({ error: 'Filename and contentType are required in the request body.' });
  }

  const options = {
    version: 'v4',
    action: 'write',
    expires: Date.now() + 15 * 60 * 1000, // 15 minutes
    contentType: contentType,
  };

  try {
    console.log(`[Routes/GCS] Attempting to generate signed URL for: gs://${bucketName}/${filename}`);
    const [url] = await bucket.file(filename).getSignedUrl(options);
    console.log(`[Routes/GCS] Signed URL generated successfully for ${filename}`);
    res.status(200).json({ url: url });
  } catch (err) {
    console.error('[Routes/GCS] Error generating signed URL:', err);
    res.status(500).json({ error: 'Could not create signed URL.', details: err.message });
  }
});

/**
 * @route GET /api/gcs/generate-download-url
 * @summary Generate a v4 signed URL for client-side file download from GCS.
 * @description Creates a short-lived (15 minutes) signed URL that grants read access to a specific GCS object.
 * The client can use this URL with an HTTP GET request to download the file directly from GCS.
 *
 * @query {string} filename - The GCS object path of the file to download (e.g., `users/firebase-uid/projects/project-id/images/image-id/original_file.jpg`).
 *
 * @returns {object} 200 - JSON object containing the signed URL for download.
 *   @example response - 200 - Success
 *   {
 *     "url": "https://storage.googleapis.com/your-bucket-name/your-filename.jpg?X-Goog-Algorithm=..."
 *   }
 * @returns {Error} 400 - If the `filename` query parameter is missing.
 * @returns {Error} 404 - If the specified file (filename) does not exist in the GCS bucket.
 * @returns {Error} 500 - If the GCS bucket is not initialized or if there's an error generating the signed URL.
 */
router.get('/generate-download-url', async (req, res) => {
  console.log('[Routes/GCS] /generate-download-url GET hit. Query params:', req.query);

  if (!bucket) {
    console.error('[Routes/GCS] GCS bucket is not initialized. Cannot generate download URL.');
    return res.status(500).json({ error: 'Server configuration error: File storage service not available.' });
  }

  const { filename } = req.query;

  if (!filename) {
    return res.status(400).json({ error: 'Filename query parameter is required.' });
  }

  const options = {
    version: 'v4',
    action: 'read',
    expires: Date.now() + 15 * 60 * 1000, // 15 minutes
  };

  try {
    console.log(`[Routes/GCS] Attempting to generate signed READ URL for: gs://${bucketName}/${filename}`);
    const [url] = await bucket.file(filename).getSignedUrl(options);
    console.log(`[Routes/GCS] Signed READ URL generated successfully for ${filename}`);
    res.status(200).json({ url: url });
  } catch (err) {
    console.error('[Routes/GCS] Error generating signed READ URL:', err);
    if (err.code === 404 || (err.message && err.message.includes('No such object'))) {
      return res.status(404).json({ error: 'File not found in GCS.', details: err.message });
    }
    res.status(500).json({ error: 'Could not create signed READ URL.', details: err.message });
  }
});

/**
 * @route POST /api/gcs/delete
 * @summary Delete a file from GCS. (MINIMAL IMPLEMENTATION - GCS Deletion Inactive)
 * @description Intended to delete a file from Google Cloud Storage. Currently, this endpoint logs the request
 * but **does not actually perform the GCS file deletion**. It returns a success-like message indicating this.
 * TODO: Implement actual GCS file deletion logic (e.g., `await bucket.file(filename).delete();`).
 *
 * @body {string} filename - The GCS object path of the file to be deleted.
 *
 * @returns {object} 200 - A message indicating the minimal operation was called.
 * @returns {Error} 400 - If `filename` is missing in the request body.
 * @returns {Error} 500 - If the GCS bucket is not initialized.
 */
router.post('/delete', async (req, res) => {
  console.log('[Routes/GCS] /delete POST hit. Body:', req.body);
  if (!bucket) {
    console.error('[Routes/GCS] GCS bucket is not initialized. Cannot delete file.');
    return res.status(500).json({ error: 'Server configuration error: File storage service not available.' });
  }

  const { filename } = req.body;
  if (!filename) {
    return res.status(400).json({ error: 'Filename is required in the request body to delete.' });
  }
  console.warn(`[Routes/GCS] Minimal /delete called for ${filename}. Actual GCS deletion NOT YET IMPLEMENTED here.`);
  // TODO: Implement actual GCS file deletion
  // try {
  //   await bucket.file(filename).delete();
  //   console.log(`[Routes/GCS] Successfully deleted gs://${bucketName}/${filename} from GCS.`);
  //   res.status(200).json({ message: `File ${filename} deleted successfully.` });
  // } catch (err) {
  //   console.error(`[Routes/GCS] Error deleting file ${filename} from GCS:`, err);
  //   if (err.code === 404) {
  //     return res.status(404).json({ error: 'File not found in GCS.', details: err.message });
  //   }
  //   res.status(500).json({ error: 'Could not delete file from GCS.', details: err.message });
  // }
  res.status(200).json({ message: "MINIMAL delete OK - actual GCS deletion not implemented in this route yet" });
});

/**
 * @route GET /api/gcs/signed-url
 * @summary Generate a v4 signed URL for GCS object access (Read-only).
 * @deprecated This route is redundant with `/api/gcs/generate-download-url`. Consider using that instead or removing this one.
 * @description Creates a short-lived (15 minutes) signed URL that grants read access to a specific GCS object.
 *
 * @query {string} path - The GCS object path of the file (equivalent to `filename` in the other route).
 *
 * @returns {object} 200 - JSON object containing the signed URL for download.
 * @returns {Error} 400 - If the `path` query parameter is missing.
 * @returns {Error} 404 - If the specified file does not exist in GCS.
 * @returns {Error} 500 - If the GCS bucket is not initialized or if there's an error generating the URL.
 */
router.get('/signed-url', async (req, res) => {
  console.log('[Routes/GCS] /signed-url GET hit. Query params:', req.query);
  if (!bucket) {
    console.error('[Routes/GCS] GCS bucket is not initialized. Cannot generate signed URL.');
    return res.status(500).json({ error: 'Server configuration error: File storage service not available.' });
  }
  const { path } = req.query;
  if (!path) return res.status(400).json({ error: 'Missing path query parameter' });

  const options = {
    version: 'v4',
    action: 'read',
    expires: Date.now() + 15 * 60 * 1000, // 15 minutes
  };
  try {
    console.log(`[Routes/GCS] Attempting to generate signed READ URL for: gs://${bucketName}/${path}`);
    const [url] = await bucket.file(path).getSignedUrl(options);
    console.log(`[Routes/GCS] Signed READ URL generated successfully for ${path}`);
    res.json({ url });
  } catch (err) {
    console.error('[Routes/GCS] Error generating signed READ URL via /signed-url:', err);
    if (err.code === 404 || (err.message && err.message.includes('No such object'))) {
      return res.status(404).json({ error: 'File not found in GCS.', details: err.message });
    }
    res.status(500).json({ error: err.message });
  }
});

console.log('[Routes/GCS] Routes defined, exporting router.');
module.exports = router; 