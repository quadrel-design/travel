/**
 * @file sseService.js
 * Manages Server-Sent Event (SSE) connections and broadcasting for real-time updates.
 */

const logger = require('../config/logger');

const activeSseConnections = {}; // In-memory store: { projectId: [res, res, ...] }

/**
 * Adds a new client response object to the list of active SSE connections for a project.
 * Handles client disconnection to remove them from the list.
 * @param {string} projectId - The ID of the project.
 * @param {import('express').Response} res - The Express response object for the client.
 */
function addSseClient(projectId, res) {
  if (!activeSseConnections[projectId]) {
    activeSseConnections[projectId] = [];
  }
  activeSseConnections[projectId].push(res);
  logger.info(`[SSE] Client connected for project ${projectId}. Total clients for project: ${activeSseConnections[projectId].length}`);

  res.on('close', () => {
    activeSseConnections[projectId] = activeSseConnections[projectId].filter(clientRes => clientRes !== res);
    if (activeSseConnections[projectId].length === 0) {
      delete activeSseConnections[projectId];
    }
    logger.info(`[SSE] Client disconnected for project ${projectId}. Remaining clients for project: ${activeSseConnections[projectId] ? activeSseConnections[projectId].length : 0}`);
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

  const sseMessage = `event: ${eventName}\ndata: ${JSON.stringify(data)}\n\n`;

  logger.info(`[SSE] Sending event '${eventName}' to ${activeSseConnections[projectId].length} clients for project ${projectId}.`);
  activeSseConnections[projectId].forEach(resClient => {
    try {
      resClient.write(sseMessage);
    } catch (error) {
      logger.error(`[SSE] Error writing to client for project ${projectId}:`, error);
      // Optionally remove client if write fails, though 'close' event should handle most cases
    }
  });
}

module.exports = {
  addSseClient,
  sendSseUpdateToProject,
}; 