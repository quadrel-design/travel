/**
 * GCS Routes
 * Handles signed URL generation, file upload, download, and deletion.
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
 * Generate a signed upload URL for a file.
 * @route POST /generate-upload-url
 * @body {string} filename The desired path/name for the file in GCS.
 * @body {string} contentType The content type of the file to be uploaded.
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
 * Generate a signed download URL for a file.
 * @route GET /generate-download-url
 * @query {string} filename The GCS path/name of the file.
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
 * Delete file from GCS. (Still Minimal - actual deletion logic needed)
 * @route POST /delete
 * @body {string} filename The GCS path/name of the file to delete.
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
 * Generate a signed URL for accessing a GCS object. (Redundant with /generate-download-url, consider merging or removing one)
 * @route GET /signed-url
 * @query {string} path - The path to the object in the GCS bucket
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