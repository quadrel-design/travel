const express = require('express');
const router = express.Router();
const gcsService = require('../services/gcsService');

// Generate signed upload URL
router.post('/generate-upload-url', async (req, res) => {
  const { filename, contentType } = req.body;
  try {
    const url = await gcsService.generateUploadUrl(filename, contentType);
    res.json({ url });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Generate signed download URL
router.get('/generate-download-url', async (req, res) => {
  const { filename } = req.query;
  try {
    const url = await gcsService.generateDownloadUrl(filename);
    res.json({ url });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Delete file from GCS
router.post('/delete', async (req, res) => {
  const { fileName } = req.body;
  if (!fileName) {
    return res.status(400).json({ error: 'fileName is required' });
  }
  try {
    await gcsService.deleteFile(fileName);
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router; 