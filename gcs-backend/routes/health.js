const express = require('express');
const router = express.Router();

/**
 * @route GET /api/health
 * @description Health check endpoint for the API.
 * @access Public
 */
router.get('/health', (req, res) => {
  res.status(200).json({ 
    status: 'healthy', 
    timestamp: new Date().toISOString() 
  });
});

module.exports = router; 