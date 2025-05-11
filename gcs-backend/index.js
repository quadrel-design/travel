const express = require('express');
const cors = require('cors');
const app = express();
app.use(cors());
app.use(express.json());

app.use(require('./routes/gcs'));
app.use(require('./routes/ocr'));
app.use(require('./routes/analysis'));

// Add this route for root path
app.get('/', (req, res) => {
  res.send('API is running!');
});

const PORT = process.env.PORT || 8080;
app.listen(PORT, () => console.log(`Server running on port ${PORT}`));