/**
 * GCS Routes
 * Handles signed URL generation, file upload, download, and deletion.
 */

const express = require('express');
const router = express.Router();
const { Storage } = require('@google-cloud/storage');

// Initialize GCS Storage client
const storage = new Storage();
// IMPORTANT: Define your GCS bucket name.
// It's best to use an environment variable for this.
const bucketName = process.env.GCS_BUCKET_NAME;

console.log(`[GCS_ROUTES.JS] Module loaded. Bucket name configured: ${bucketName ? bucketName : 'NOT SET'}`);

/**
 * Generate a signed upload URL for a file.
 * @route POST /generate-upload-url
 * @body {string} filename The desired path/name for the file in GCS.
 * @body {string} contentType The content type of the file to be uploaded.
 */
router.post('/generate-upload-url', async (req, res) => {
  console.log('[GCS_ROUTES.JS] /generate-upload-url POST hit. Request body:', req.body);

  if (!bucketName) {
    console.error('[GCS_ROUTES.JS] GCS_BUCKET_NAME environment variable is not set.');
    return res.status(500).json({ error: 'Server configuration error: Bucket name not set.' });
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
    console.log(`[GCS_ROUTES.JS] Attempting to generate signed URL for: gs://${bucketName}/${filename}`);
    const [url] = await storage.bucket(bucketName).file(filename).getSignedUrl(options);
    console.log(`[GCS_ROUTES.JS] Signed URL generated successfully for ${filename}`);
    res.status(200).json({ url: url });
  } catch (err) {
    console.error('[GCS_ROUTES.JS] Error generating signed URL:', err);
    res.status(500).json({ error: 'Could not create signed URL.', details: err.message });
  }
});

/**
 * Generate a signed download URL for a file.
 * @route GET /generate-download-url
 * @query {string} filename The GCS path/name of the file.
 */
router.get('/generate-download-url', async (req, res) => {
  console.log('[GCS_ROUTES.JS] /generate-download-url GET hit. Query params:', req.query);

  if (!bucketName) {
    console.error('[GCS_ROUTES.JS] GCS_BUCKET_NAME environment variable is not set for download URL.');
    return res.status(500).json({ error: 'Server configuration error: Bucket name not set.' });
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
    console.log(`[GCS_ROUTES.JS] Attempting to generate signed READ URL for: gs://${bucketName}/${filename}`);
    const [url] = await storage.bucket(bucketName).file(filename).getSignedUrl(options);
    console.log(`[GCS_ROUTES.JS] Signed READ URL generated successfully for ${filename}`);
    res.status(200).json({ url: url });
  } catch (err) {
    console.error('[GCS_ROUTES.JS] Error generating signed READ URL:', err);
    // Check for common errors like object not found
    if (err.code === 404 || (err.message && err.message.includes('No such object'))) {
      return res.status(404).json({ error: 'File not found in GCS.', details: err.message });
    }
    res.status(500).json({ error: 'Could not create signed READ URL.', details: err.message });
  }
});

/**
 * Delete file from GCS. (Still Minimal)
 * @route POST /delete
 */
router.post('/delete', (req, res) => {
  console.log('[GCS_ROUTES.JS] MINIMAL - /delete POST hit!');
   if (!bucketName) {
    console.error('[GCS_ROUTES.JS] GCS_BUCKET_NAME environment variable is not set for delete.');
    return res.status(500).json({ error: 'Server configuration error: Bucket name not set.' });
  }
  res.status(200).json({ message: "MINIMAL delete OK" });
});

// Endpoint: GET /api/gcs/signed-url?path=...
// Returns a fresh signed URL for the given GCS object path
router.get('/signed-url', async (req, res) => {
  const { path } = req.query;
  if (!path) return res.status(400).json({ error: 'Missing path' });

  try {
    const options = {
      version: 'v4',
      action: 'read',
      expires: Date.now() + 15 * 60 * 1000, // 15 minutes
    };
    const [url] = await storage.bucket(bucketName).file(path).getSignedUrl(options);
    res.json({ url });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

console.log('[GCS_ROUTES.JS] Routes defined, exporting router.');
module.exports = router; 