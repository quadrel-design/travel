/**
 * @file sseService.js
 * Manages Server-Sent Event (SSE) connections and broadcasting for real-time updates.
 */

const logger = require('../config/logger');
// const projectService = require('../services/projectService'); // No longer used
const invoiceService = require('../services/invoiceService'); // Changed from imageService

const activeSseConnections = {}; // In-memory store: { projectId: [{res, userId}, {res, userId}, ...] }
const lastSentProjectImages = {}; // NEW: { projectId: JSON_stringified_image_list }

/**
 * Adds a new client response object to the list of active SSE connections for a project.
 * Sends initial images to the newly connected client.
 * Handles client disconnection to remove them from the list.
 * @param {string} projectId - The ID of the project.
 * @param {string} userId - The ID of the user making the connection.
 * @param {import('express').Response} res - The Express response object for the client.
 */
async function addSseClient(projectId, userId, res) { // Added userId and made async
  if (!activeSseConnections[projectId]) {
    activeSseConnections[projectId] = [];
  }
  // Store both res and userId for potential future use (e.g., more granular disconnect logging or checks)
  activeSseConnections[projectId].push({ res, userId });
  logger.info(`[SSE] Client connected for project ${projectId} by user ${userId}. Total clients for project: ${activeSseConnections[projectId].length}`);

  // Send initial images to this new client
  try {
    const images = await invoiceService.getProjectImages(projectId, userId);
    // In the backend, the event is 'imagesUpdated' for both initial and subsequent.
    // The client was already adapted to handle 'initialImages' or 'imagesUpdated' with the same payload structure.
    // We will send { "images": [...] } as the payload for the data field.
    const ssePayload = { images: images || [] }; 
    const sseMessage = `event: imagesUpdated\ndata: ${JSON.stringify(ssePayload)}\n\n`;
    res.write(sseMessage);
    lastSentProjectImages[projectId] = JSON.stringify(ssePayload); // Store what was just sent

    if (images && images.length > 0) {
      logger.info(`[SSE] Sent initial ${images.length} images to newly connected client for project ${projectId}`);
    } else {
      logger.info(`[SSE] No initial images found or project is empty for project ${projectId}. Sent empty array.`);
    }
  } catch (error) {
    logger.error(`[SSE] Error fetching or sending initial images for project ${projectId}, user ${userId}:`, error);
    // Optionally send an error event to the client
    if (!res.writableEnded) { // Check if we can still write
      try {
        res.write(`event: error\ndata: ${JSON.stringify({ message: "Failed to load initial images.", details: error.message })}\n\n`);
        logger.info(`[SSE] Sent error event to client for project ${projectId} due to initial image load failure.`);
      } catch (writeError) {
        logger.error(`[SSE] Critical: Error writing error event to SSE client for project ${projectId}:`, writeError);
      }
    }
    // If initial send fails, clear lastSentProjectImages for this project to ensure next real update goes through
    delete lastSentProjectImages[projectId];
  }

  // Start Keep-Alive
  const keepAliveInterval = setInterval(() => {
    if (res.writableEnded) { // Check if client is still connected
      logger.info(`[SSE] Keep-alive for project ${projectId}, user ${userId}: Client disconnected (writableEnded is true). Clearing interval.`);
      clearInterval(keepAliveInterval);
      return;
    }
    try {
      logger.info(`[SSE] Sending keep-alive ping to project ${projectId}, user ${userId}.`);
      res.write(':keep-alive\n\n'); // SSE comment as keep-alive
    } catch (e) {
      logger.warn(`[SSE] Error writing keep-alive for project ${projectId}, user ${userId} (client likely disconnected abruptly):`, e.message);
      clearInterval(keepAliveInterval); 
      // No need to manually remove client here, res.on('close') will handle it.
    }
  }, 25000); // Every 25 seconds

  res.on('close', () => {
    clearInterval(keepAliveInterval); // Stop keep-alive for this client
    // Filter out the client based on the response object identity
    activeSseConnections[projectId] = activeSseConnections[projectId].filter(clientEntry => clientEntry.res !== res);
    if (activeSseConnections[projectId].length === 0) {
      delete activeSseConnections[projectId];
      delete lastSentProjectImages[projectId]; // Clear last sent cache when no clients are left
    }
    logger.info(`[SSE] Client disconnected for project ${projectId} by user ${userId}. Remaining clients for project: ${activeSseConnections[projectId] ? activeSseConnections[projectId].length : 0}`);
  });
}

/**
 * Sends an SSE message to all connected clients for a specific project.
 * @param {string} projectId - The ID of the project.
 * @param {string} eventName - The name of the SSE event (e.g., 'imagesUpdated').
 * @param {any} data - The data to send (will be JSON.stringified).
 */
function sendSseUpdateToProject(projectId, eventName, data) {
  if (!activeSseConnections[projectId] || activeSseConnections[projectId].length === 0) {
    logger.info(`[SSE] No active clients for project ${projectId} to send event '${eventName}'.`);
    return;
  }

  // Ensure data is always an object { images: [...] } for imagesUpdated event
  let payloadToSend = data;
  if (eventName === 'imagesUpdated') {
    payloadToSend = { images: data || [] };
  }
  const dataJson = JSON.stringify(payloadToSend);

  // NEW CHECK: Only send if data is different from last sent data for this project
  if (eventName === 'imagesUpdated' && lastSentProjectImages[projectId] === dataJson) {
    logger.info(`[SSE] Event 'imagesUpdated' for project ${projectId} - data is identical to last sent. Suppressing update.`);
    return;
  }

  const sseMessage = `event: ${eventName}\ndata: ${dataJson}\n\n`;

  logger.info(`[SSE] Sending event '${eventName}' to ${activeSseConnections[projectId].length} clients for project ${projectId}.`);
  activeSseConnections[projectId].forEach(clientEntry => {
    try {
      clientEntry.res.write(sseMessage);
    } catch (error) {
      logger.error(`[SSE] Error writing to client for project ${projectId}, user ${clientEntry.userId}:`, { message: error.message, stack: error.stack });
      // Optionally remove client if write fails, though 'close' event should handle most cases
    }
  });

  if (eventName === 'imagesUpdated') {
    lastSentProjectImages[projectId] = dataJson; // Update last sent data
  }
}

module.exports = {
  addSseClient,
  sendSseUpdateToProject,
}; 