const express = require('express');
const cors = require('cors');
const { Storage } = require('@google-cloud/storage');
const app = express();
app.use(cors());
app.use(express.json());

const storage = new Storage({ keyFilename: 'service-account.json' });
const bucket = storage.bucket('travel-files');

// Generate signed upload URL
app.post('/generate-upload-url', async (req, res) => {
  const { filename, contentType } = req.body;
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

app.listen(3030, () => console.log('Server running on port 3030'));