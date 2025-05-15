/**
 * Project Routes
 * Provides REST API endpoints for project and invoice operations.
 */
const express = require('express');
const router = express.Router();
const multer = require('multer');
const { Storage } = require('@google-cloud/storage');
const firebaseAdmin = require('firebase-admin');
const path = require('path');

const projectService = require('../services/projectService');

// Initialize in-memory storage for multer
const storage = multer.memoryStorage();
const upload = multer({
  storage: storage,
  limits: { fileSize: 10 * 1024 * 1024 } // 10MB max file size
});

// Google Cloud Storage client
const storageBucketName = process.env.GCS_BUCKET_NAME || 'travel-app-invoices';
let storageClient;
let bucket;
try {
  storageClient = new Storage();
  bucket = storageClient.bucket(storageBucketName);
  console.log(`[Routes/Projects] Successfully connected to GCS bucket: ${storageBucketName}`);
} catch (error) {
  console.error(`[Routes/Projects] CRITICAL ERROR: Failed to initialize Google Cloud Storage client or bucket '${storageBucketName}':`, error);
  console.warn('[Routes/Projects] GCS operations will fail.');
}

// Firebase Admin SDK initialization check
if (firebaseAdmin.apps.length === 0) {
  console.warn('[Routes/Projects] Firebase Admin SDK has not been initialized. Authentication will fail.');
}

// Middleware to check if user is authenticated
const authenticateUser = async (req, res, next) => {
  if (firebaseAdmin.apps.length === 0) {
    console.error('[AuthMiddleware] Firebase Admin SDK not initialized. Cannot authenticate.');
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
    console.error('Error authenticating user:', error);
    if (error.code === 'auth/id-token-expired') {
      return res.status(401).json({ error: 'Unauthorized: Token expired', code: 'TOKEN_EXPIRED' });
    }
    if (error.code === 'auth/argument-error') {
      console.error('[AuthMiddleware] Firebase ID token verification failed. This might be due to an emulator issue or misconfiguration if not in production.');
    }
    return res.status(401).json({ error: 'Unauthorized: Invalid token' });
  }
};

// Apply authentication middleware to all routes in this router
router.use(authenticateUser);

/**
 * GET /
 * Get all projects for the authenticated user
 */
router.get('/', async (req, res) => {
  try {
    const userId = req.user.id;
    console.log(`[Routes/Projects] GET / - Attempting to fetch projects for user: ${userId}`);
    if (!projectService || typeof projectService.getUserProjects !== 'function') {
      console.error('[Routes/Projects] projectService.getUserProjects is not available!');
      return res.status(500).json({ error: 'Project service not configured correctly.' });
    }
    const projects = await projectService.getUserProjects(userId);
    
    const projectsWithParsedBudget = projects.map(project => ({
      ...project,
      budget: project.budget !== null && project.budget !== undefined ? parseFloat(project.budget) : null
    }));
    
    res.status(200).json(projectsWithParsedBudget);
  } catch (error) {
    console.error('[Routes/Projects] GET / - ERROR CAUGHT:', error);
    console.error('[Routes/Projects] Error stack:', error.stack);
    res.status(500).json({ error: 'Failed to fetch projects' });
  }
});

/**
 * GET /:projectId
 * Get a project by ID
 */
router.get('/:projectId', async (req, res) => {
  try {
    const userId = req.user.id;
    const projectId = req.params.projectId;
    console.log(`[Routes/Projects] GET /${projectId} - Attempting to fetch project for user: ${userId}`);
    if (!projectService || typeof projectService.getProjectById !== 'function') {
      console.error('[Routes/Projects] projectService.getProjectById is not available!');
      return res.status(500).json({ error: 'Project service not configured correctly.' });
    }
    const project = await projectService.getProjectById(projectId, userId);
    if (!project) {
      return res.status(404).json({ error: 'Project not found' });
    }
    
    project.budget = project.budget !== null && project.budget !== undefined ? parseFloat(project.budget) : null;
    
    res.status(200).json(project);
  } catch (error) {
    console.error(`[Routes/Projects] Error fetching project ${req.params.projectId}:`, error);
    res.status(500).json({ error: 'Failed to fetch project' });
  }
});

/**
 * POST /
 * Create a new project
 */
router.post('/', async (req, res) => {
  try {
    const userId = req.user.id;
    console.log(`[Routes/Projects] POST / - Attempting to create project for user: ${userId}`);
    if (!projectService || typeof projectService.createProject !== 'function') {
      console.error('[Routes/Projects] projectService.createProject is not available!');
      return res.status(500).json({ error: 'Project service not configured correctly.' });
    }
    const projectData = {
      ...req.body,
      user_id: userId
    };
    
    if (projectData.budget !== null && projectData.budget !== undefined) {
      projectData.budget = parseFloat(projectData.budget);
      if (isNaN(projectData.budget)) {
        projectData.budget = 0;
      }
    }
    
    const project = await projectService.createProject(projectData);
    
    project.budget = project.budget !== null && project.budget !== undefined ? parseFloat(project.budget) : null;
    if (isNaN(project.budget)) {
      project.budget = null;
    }
    
    res.status(201).json(project);
  } catch (error) {
    console.error('[Routes/Projects] Error creating project:', error);
    res.status(500).json({ error: 'Failed to create project' });
  }
});

/**
 * PATCH /:projectId
 * Update a project
 */
router.patch('/:projectId', async (req, res) => {
  try {
    const userId = req.user.id;
    const projectId = req.params.projectId;
    console.log(`[Routes/Projects] PATCH /${projectId} - Attempting to update project for user: ${userId}`);
    if (!projectService || typeof projectService.updateProject !== 'function') {
      console.error('[Routes/Projects] projectService.updateProject is not available!');
      return res.status(500).json({ error: 'Project service not configured correctly.' });
    }
    const projectData = req.body;
    
    if (projectData.budget !== null && projectData.budget !== undefined) {
      projectData.budget = parseFloat(projectData.budget);
      if (isNaN(projectData.budget)) {
        projectData.budget = 0;
      }
    }
    
    const project = await projectService.updateProject(projectId, projectData, userId);
    
    project.budget = project.budget !== null && project.budget !== undefined ? parseFloat(project.budget) : null;
    if (isNaN(project.budget)) {
      project.budget = null;
    }
    
    res.status(200).json(project);
  } catch (error) {
    console.error(`[Routes/Projects] Error updating project ${req.params.projectId}:`, error);
    
    if (error.message.includes('not found')) {
      return res.status(404).json({ error: 'Project not found' });
    }
    
    res.status(500).json({ error: 'Failed to update project' });
  }
});

/**
 * DELETE /:projectId
 * Delete a project
 */
router.delete('/:projectId', async (req, res) => {
  try {
    const userId = req.user.id;
    const projectId = req.params.projectId;
    console.log(`[Routes/Projects] DELETE /${projectId} - Attempting to delete project for user: ${userId}`);
    if (!projectService || typeof projectService.deleteProject !== 'function') {
      console.error('[Routes/Projects] projectService.deleteProject is not available!');
      return res.status(500).json({ error: 'Project service not configured correctly.' });
    }
    await projectService.deleteProject(projectId, userId);
    res.status(204).send();
  } catch (error) {
    console.error(`[Routes/Projects] Error deleting project ${req.params.projectId}:`, error);
    
    if (error.message.includes('not found')) {
      return res.status(404).json({ error: 'Project not found' });
    }
    
    res.status(500).json({ error: 'Failed to delete project' });
  }
});

/**
 * GET /:projectId/images
 * Get all images for a project
 */
router.get('/:projectId/images', async (req, res) => {
  try {
    const userId = req.user.id;
    const projectId = req.params.projectId;
    console.log(`[Routes/Projects] GET /${projectId}/images - Attempting to fetch images for user: ${userId}`);
    if (!projectService || typeof projectService.getProjectImages !== 'function') {
      console.error('[Routes/Projects] projectService.getProjectImages is not available!');
      return res.status(500).json({ error: 'Project service not configured correctly.' });
    }
    const images = await projectService.getProjectImages(projectId, userId);
    res.status(200).json(images);
  } catch (error) {
    console.error(`[Routes/Projects] Error fetching images for project ${req.params.projectId}:`, error);
    res.status(500).json({ error: 'Failed to fetch project images' });
  }
});

/**
 * GET /:projectId/images/:imageId
 * Get an image by ID
 */
router.get('/:projectId/images/:imageId', async (req, res) => {
  try {
    const userId = req.user.id;
    const projectId = req.params.projectId;
    const imageId = req.params.imageId;
    console.log(`[Routes/Projects] GET /${projectId}/images/${imageId} - Attempting to fetch image for user: ${userId}`);
    if (!projectService || typeof projectService.getInvoiceImageById !== 'function') {
      console.error('[Routes/Projects] projectService.getInvoiceImageById is not available!');
      return res.status(500).json({ error: 'Project service not configured correctly.' });
    }
    const image = await projectService.getInvoiceImageById(projectId, imageId, userId);
    if (!image) {
      return res.status(404).json({ error: 'Image not found' });
    }
    
    res.status(200).json(image);
  } catch (error) {
    console.error(`[Routes/Projects] Error fetching image ${req.params.imageId}:`, error);
    res.status(500).json({ error: 'Failed to fetch image' });
  }
});

/**
 * POST /:projectId/images
 * Upload an image for a project. 
 * Expects JSON body with metadata of a file already uploaded to GCS.
 */
router.post('/:projectId/images', async (req, res) => {
  try {
    const userId = req.user.id;
    const projectId = req.params.projectId;
    
    // Extract metadata sent by the Flutter app
    const { 
      id: imageIdFromClient, // This is the imageId generated by Flutter client
      imagePath,             // This is the GCS object path (e.g., users/uid/projects/pid/...)
      originalFilename,      // Original name of the file
      uploaded_at,           // Timestamp from client
      contentType,           // MIME type of the file
      size                   // Size of the file in bytes
    } = req.body;

    console.log(`[Routes/Projects] POST /${projectId}/images - DB record creation for GCS path: ${imagePath}`);

    if (!imagePath || !projectId || !imageIdFromClient || !originalFilename) {
      return res.status(400).json({ error: 'Missing required image metadata (imageIdFromClient, projectId, imagePath, originalFilename).' });
    }

    // Verify project ownership (optional, but good)
    if (!projectService || typeof projectService.getProjectById !== 'function') {
        console.error('[Routes/Projects] projectService.getProjectById is not available!');
        return res.status(500).json({ error: 'Project service not configured correctly.' });
    }
    const project = await projectService.getProjectById(projectId, userId);
    if (!project) {
      return res.status(404).json({ error: 'Project not found or not owned by user, cannot create image record.' });
    }

    const imageData = {
      id: imageIdFromClient, 
      projectId: projectId,
      gcsPath: imagePath, 
      status: 'uploaded', 
      originalFilename: originalFilename,
      size: size, // Make sure Flutter sends this if you need it
      contentType: contentType, // Make sure Flutter sends this if you need it
      uploaded_at: uploaded_at ? new Date(uploaded_at) : new Date(),
    };
    
    if (!projectService || typeof projectService.saveImageMetadata !== 'function') {
      console.error('[Routes/Projects] projectService.saveImageMetadata is not available!');
      return res.status(500).json({ error: 'Project service not configured correctly to save image metadata.' });
    }
    
    const savedImage = await projectService.saveImageMetadata(imageData, userId);
    
    console.log(`[Routes/Projects] Successfully created DB record for imageId: ${savedImage.id}`);
    res.status(201).json(savedImage);

  } catch (error) {
    console.error(`[Routes/Projects] Error creating image DB record for project ${req.params.projectId}:`, error);
    if (error.code === '23505') { // Example for unique constraint violation in PostgreSQL
        return res.status(409).json({ error: 'Conflict: Image record might already exist or ID is duplicated.', details: error.detail });
    }
    res.status(500).json({ error: 'Failed to create image record in database' });
  }
});

/**
 * DELETE /:projectId/images/:imageId
 * Delete an image (both from GCS and database)
 */
router.delete('/:projectId/images/:imageId', async (req, res) => {
  try {
    const userId = req.user.id;
    const projectId = req.params.projectId;
    const imageId = req.params.imageId;
    console.log(`[Routes/Projects] DELETE /${projectId}/images/${imageId} - Attempting to delete image for user: ${userId}`);

    // 1. Get image metadata to find GCS path
    if (!projectService || typeof projectService.getInvoiceImageById !== 'function' || typeof projectService.deleteImageMetadata !== 'function') {
      console.error('[Routes/Projects] Project service methods for image deletion are not available!');
      return res.status(500).json({ error: 'Project service not configured correctly.' });
    }
    const image = await projectService.getInvoiceImageById(projectId, imageId, userId);
    if (!image) {
      return res.status(404).json({ error: 'Image not found or not owned by user.' });
    }

    // 2. Delete from GCS if bucket and path are valid
    if (bucket && image.imagePath && image.imagePath.startsWith(`gs://${storageBucketName}/`)) {
      const gcsFilename = image.imagePath.substring(`gs://${storageBucketName}/`.length);
      try {
        console.log(`[Routes/Projects] Deleting image from GCS: ${gcsFilename}`);
        await bucket.file(gcsFilename).delete();
        console.log(`[Routes/Projects] Successfully deleted ${gcsFilename} from GCS.`);
      } catch (gcsError) {
        console.error(`[Routes/Projects] Error deleting ${gcsFilename} from GCS:`, gcsError);
        // Decide if this is a critical failure. 
        // The DB entry will still be deleted. Client might see a broken image if GCS delete fails but DB succeeds.
        // For now, log and continue to DB deletion.
      }
    } else {
      console.warn(`[Routes/Projects] Could not delete from GCS. Bucket not init or invalid imagePath: ${image.imagePath}`);
    }

    // 3. Delete from database
    await projectService.deleteImageMetadata(imageId, projectId, userId);
    
    res.status(204).send();

  } catch (error) {
    console.error(`[Routes/Projects] Error deleting image ${req.params.imageId}:`, error);
    res.status(500).json({ error: 'Failed to delete image' });
  }
});

/**
 * PATCH /:projectId/images/:imageId/ocr
 * Update OCR results for an image
 */
router.patch('/:projectId/images/:imageId/ocr', async (req, res) => {
  try {
    const userId = req.user.id;
    const projectId = req.params.projectId;
    const imageId = req.params.imageId;
    
    const ocrData = req.body;
    
    const image = await projectService.updateImageOcrResults(
      projectId, 
      imageId, 
      ocrData, 
      userId
    );
    
    res.status(200).json(image);
  } catch (error) {
    console.error(`Error updating OCR results for image ${req.params.imageId}:`, error);
    
    if (error.message.includes('not found')) {
      return res.status(404).json({ error: 'Image not found' });
    }
    
    res.status(500).json({ error: 'Failed to update OCR results' });
  }
});

/**
 * PATCH /:projectId/images/:imageId/analysis
 * Update analysis details for an image
 */
router.patch('/:projectId/images/:imageId/analysis', async (req, res) => {
  try {
    const userId = req.user.id;
    const projectId = req.params.projectId;
    const imageId = req.params.imageId;
    
    const receivedAnalysisData = req.body; // Data from Flutter app

    // Prepare the data for projectService.updateImageMetadata
    const dataForDbUpdate = {
      projectId: projectId, // For internal checks within updateImageMetadata if needed
      gemini_analysis_json: receivedAnalysisData.invoiceAnalysis,
      is_invoice: receivedAnalysisData.isInvoiceGuess,
      analysis_processed_at: receivedAnalysisData.lastProcessedAt, // Ensure Flutter sends this key
      status: receivedAnalysisData.status,
      // analyzed_invoice_date is expected by updateImageMetadata if present
      // Flutter sends 'invoiceDate', map it.
      analyzed_invoice_date: receivedAnalysisData.invoiceDate 
    };

    // Remove undefined keys to prevent them from being set as null in the DB
    // unless specifically intended. The updateImageMetadata service handles this.
    // For example, if invoiceDate wasn't sent, analyzed_invoice_date will be undefined here.

    console.log(`[Routes/Projects] Updating analysis for image ${imageId}. Data for DB:`, JSON.stringify(dataForDbUpdate, null, 2));
    
    const image = await projectService.updateImageMetadata( // Corrected service call
      imageId, 
      dataForDbUpdate, 
      userId
    );
    
    res.status(200).json(image);
  } catch (error) {
    console.error(`Error updating analysis details for image ${req.params.imageId}:`, error);
    
    if (error.message.includes('not found')) {
      return res.status(404).json({ error: 'Image not found' });
    }
    
    res.status(500).json({ error: 'Failed to update analysis details' });
  }
});

module.exports = router; 