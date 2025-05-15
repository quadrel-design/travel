require('dotenv').config();

const express = require('express');
const cors = require('cors');
const { Storage } = require('@google-cloud/storage');
const app = express();
app.use(cors());
app.use(express.json());

const storage = new Storage({ keyFilename: 'service-account.json' });
const bucket = storage.bucket('travel-files'); // Use your bucket name

// Generate signed upload URL
app.post('/generate-upload-url', async (req, res) => {
  let { filename, contentType } = req.body;
  // Hardcode for debugging
  contentType = 'image/jpeg';
  console.log('[GCS DEBUG] Generating signed URL for:', filename, 'with contentType:', contentType);
  try {
    const [url] = await bucket.file(filename).getSignedUrl({
      version: 'v4',
      action: 'write',
      expires: Date.now() + 15 * 60 * 1000, // 15 minutes
      contentType,
    });
    res.json({ url });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Generate signed download URL
app.get('/generate-download-url', async (req, res) => {
  const { filename } = req.query;
  try {
    const [url] = await bucket.file(filename).getSignedUrl({
      version: 'v4',
      action: 'read',
      expires: Date.now() + 15 * 60 * 1000, // 15 minutes
    });
    res.json({ url });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Delete file from GCS
app.delete('/delete/:filename(*)', async (req, res) => {
  const filename = req.params.filename;
  try {
    await bucket.file(filename).delete();
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// (Optional) Direct download endpoint (prefer signed URLs for production)
app.get('/download/:filename(*)', async (req, res) => {
  const filename = req.params.filename;
  try {
    const file = bucket.file(filename);
    file.createReadStream().on('error', (err) => {
      res.status(500).json({ error: err.message });
    }).pipe(res);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

const PORT = process.env.PORT || 8080;
app.listen(PORT, () => console.log(`Server running on port ${PORT}`)); 