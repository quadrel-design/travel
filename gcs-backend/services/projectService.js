/**
 * @fileoverview Project Service Module.
 * This module provides functions to interact with project-related data in the PostgreSQL database.
 * It handles CRUD operations for projects and their associated images (metadata).
 * It includes helper functions for data transformation between database and API formats.
 * All functions assume that the PostgreSQL connection pool (`pool`) has been initialized and is available.
 * It also performs user authorization checks where applicable by ensuring operations are performed
 * by the owner of the data.
 * @module services/projectService
 */
const pool = require('../config/db'); // Import the pool
// const { sendSseUpdateToProject } = require('./sseService'); // Removed for lazy loading
const logger = require('../config/logger'); // Added for logging
const { NotFoundError, NotAuthorizedError } = require('../utils/customErrors');

if (!pool) {
  // This check is more for immediate feedback during development.
  // The db.js itself has more robust logging if pool creation fails.
  const errorMessage = "projectService: CRITICAL ERROR - PostgreSQL pool was NOT imported or is undefined!";
  logger.error(errorMessage);
  // Depending on the application's error handling strategy, you might:
  // 1. Throw an error to halt startup (safer for production if DB is essential).
  // throw new Error(errorMessage);
  // 2. Allow the app to start but this service will be non-functional (as it is now).
  //    Operations calling this service would then fail at runtime.
  logger.warn('projectService: Service will be non-functional as the DB pool is unavailable.');
}

// console.log('projectService: DB pool imported. Service getting initialized.'); // Redundant with logger
logger.info('projectService: DB pool imported. Service getting initialized.');

const projectService = {
  /**
   * @async
   * @function getUserProjects
   * @summary Get all projects for a specific user.
   * @description Retrieves all projects associated with the given `userId` from the database,
   * ordered by creation date in descending order.
   * 
   * @param {string} userId - The UUID of the user whose projects are to be fetched.
   * @returns {Promise<Array<object>>} A promise that resolves to an array of project objects.
   *                                   Each project object contains all fields from the `projects` table.
   * @throws {Error} If the database pool is not available or if the query fails.
   */
  getUserProjects: async (userId) => {
    if (!pool) { logger.error('[ProjectService] DB Pool not available for getUserProjects'); throw new Error('DB Connection Error'); }
    const query = {
      text: 'SELECT * FROM projects WHERE user_id = $1 ORDER BY created_at DESC',
      values: [userId],
    };
    
    try {
      logger.info(`[ProjectService] Fetching projects for user ${userId}`);
      const res = await pool.query(query);
      return res.rows;
    } catch (err) {
      logger.error('[ProjectService] Error fetching user projects:', { error: err.message, stack: err.stack });
      throw err;
    }
  },

  /**
   * @async
   * @function getProjectById
   * @summary Get a specific project by its ID for a given user.
   * @description Retrieves a single project from the database based on its `projectId`,
   * ensuring that it belongs to the specified `userId`.
   * 
   * @param {string} projectId - The UUID of the project to fetch.
   * @param {string} userId - The UUID of the user who should own the project.
   * @returns {Promise<object>} A promise that resolves to the project object if found and owned by the user.
   * @throws {NotFoundError} If the project is not found.
   * @throws {NotAuthorizedError} If the user is not authorized to access the project.
   * @throws {Error} If the database pool is not available or if the query fails.
   */
  getProjectById: async (projectId, userId) => {
    if (!pool) { 
      logger.error('[ProjectService] DB Pool not available for getProjectById'); 
      throw new Error('DB Connection Error'); 
    }
    
    // First, check if the project exists
    const projectExistenceQuery = {
      text: 'SELECT * FROM projects WHERE id = $1',
      values: [projectId],
    };
    
    let project;
    try {
      logger.info(`[ProjectService] Checking existence of project ${projectId}`);
      const res = await pool.query(projectExistenceQuery);
      project = res.rows[0];
    } catch (err) {
      logger.error(`[ProjectService] Error checking project existence ${projectId}:`, { error: err.message, stack: err.stack });
      throw err; // Re-throw database errors
    }

    if (!project) {
      logger.warn(`[ProjectService] Project ${projectId} not found.`);
      throw new NotFoundError(`Project with id ${projectId} not found.`);
    }

    // Then, check if the project belongs to the user
    if (project.user_id !== userId) {
      logger.warn(`[ProjectService] User ${userId} not authorized for project ${projectId}. Project owned by ${project.user_id}.`);
      throw new NotAuthorizedError(`User ${userId} is not authorized to access project ${projectId}.`);
    }
    
    logger.info(`[ProjectService] Fetched project ${projectId} for user ${userId}`);
    return project; // Returns the project if found and owned by the user
  },

  /**
   * @async
   * @function createProject
   * @summary Create a new project for a user.
   * @description Inserts a new project record into the database. The project ID is generated
   * automatically using `gen_random_uuid()`. Default values are used for optional fields
   * if not provided in `projectData`.
   * 
   * @param {object} projectData - Data for the new project.
   * @param {string} projectData.user_id - The UUID of the user creating the project.
   * @param {string} projectData.title - Title of the project.
   * @param {string} [projectData.description=''] - Description of the project.
   * @param {string} [projectData.location=''] - Location of the project.
   * @param {string|Date} [projectData.start_date=NOW()] - Start date of the project.
   * @param {string|Date} [projectData.end_date=NOW()+7days] - End date of the project.
   * @param {number} [projectData.budget=0.0] - Budget for the project.
   * @param {boolean} [projectData.is_completed=false] - Completion status of the project.
   * @returns {Promise<object>} A promise that resolves to the newly created project object.
   * @throws {Error} If the database pool is not available or if the query fails.
   */
  createProject: async (projectData) => {
    if (!pool) { logger.error('[ProjectService] DB Pool not available for createProject'); throw new Error('DB Connection Error'); }
    const { 
      user_id, 
      title, 
      description, 
      location, 
      start_date, 
      end_date, 
      budget, 
      is_completed 
    } = projectData;

    // Use PostgreSQL's gen_random_uuid() function to generate the ID
    const query = {
      text: `INSERT INTO projects(
              id, user_id, title, description, location, start_date, end_date, budget, is_completed
            ) VALUES(gen_random_uuid(), $1, $2, $3, $4, $5, $6, $7, $8) 
            RETURNING *`,
      values: [
        user_id,
        title,
        description || '',
        location || '',
        start_date || new Date(),
        end_date || new Date(new Date().setDate(new Date().getDate() + 7)), // Default to 7 days from now
        budget || 0.0,
        is_completed || false
      ],
    };
    
    try {
      logger.info(`[ProjectService] Creating new project for user ${user_id} with title '${title}'`);
      const res = await pool.query(query);
      return res.rows[0];
    } catch (err) {
      logger.error('[ProjectService] Error creating project:', { error: err.message, data: projectData, stack: err.stack });
      throw err;
    }
  },

  /**
   * @async
   * @function updateProject
   * @summary Update an existing project.
   * @description Updates specific fields of an existing project in the database.
   * Only fields present in `projectData` are updated. The `updated_at` timestamp is always updated.
   * Ensures the project belongs to the specified `userId` before updating.
   * 
   * @param {string} projectId - The UUID of the project to update.
   * @param {object} projectData - An object containing the fields to update.
   * @param {string} userId - The UUID of the user who owns the project.
   * @returns {Promise<object>} A promise that resolves to the updated project object.
   * @throws {Error} If the project is not found, not owned by the user, if the DB pool is unavailable, or if the query fails.
   */
  updateProject: async (projectId, projectData, userId) => {
    if (!pool) { logger.error('[ProjectService] DB Pool not available for updateProject'); throw new Error('DB Connection Error'); }

    // First, verify the project exists and the user is authorized.
    // This will throw NotFoundError or NotAuthorizedError if applicable.
    await projectService.getProjectById(projectId, userId);

    const {
      title,
      description,
      location,
      start_date,
      end_date,
      budget,
      is_completed
    } = projectData;

    const columnsToUpdate = [];
    const values = [];
    let placeholderIndex = 1;

    if (title !== undefined) {
      columnsToUpdate.push(`title = $${placeholderIndex++}`);
      values.push(title);
    }
    if (description !== undefined) {
      columnsToUpdate.push(`description = $${placeholderIndex++}`);
      values.push(description);
    }
    if (location !== undefined) {
      columnsToUpdate.push(`location = $${placeholderIndex++}`);
      values.push(location);
    }
    if (start_date !== undefined) {
      columnsToUpdate.push(`start_date = $${placeholderIndex++}`);
      values.push(start_date);
    }
    if (end_date !== undefined) {
      columnsToUpdate.push(`end_date = $${placeholderIndex++}`);
      values.push(end_date);
    }
    if (budget !== undefined) {
      columnsToUpdate.push(`budget = $${placeholderIndex++}`);
      values.push(budget);
    }
    if (is_completed !== undefined) {
      columnsToUpdate.push(`is_completed = $${placeholderIndex++}`);
      values.push(is_completed);
    }

    let queryText;

    if (columnsToUpdate.length === 0) {
      // No actual data fields to update, so this is a "touch" operation to update `updated_at`
      logger.info(`[ProjectService] No specific fields to update for project ${projectId}. Touching updated_at.`);
      queryText = `UPDATE projects SET updated_at = NOW() WHERE id = $${placeholderIndex++} RETURNING *`;
      // Values array will only contain projectId for the WHERE clause
    } else {
      // Add updated_at to the columns to be updated
    columnsToUpdate.push(`updated_at = NOW()`);
      queryText = `UPDATE projects SET ${columnsToUpdate.join(', ')} 
             WHERE id = $${placeholderIndex++}
             RETURNING *`;
      // Values array contains actual field values AND then projectId for the WHERE clause
    }

    // Add projectId to values for the WHERE clause
    values.push(projectId);
    // userId is no longer needed here for the WHERE clause as authorization is done by getProjectById
    
    const query = {
      text: queryText,
      values: values,
    };
    
    try {
      logger.debug(`[ProjectService] Updating project ${projectId}. Query: ${queryText.replace(/\n/g, ' ').trim()}, Values: ${JSON.stringify(values)}`);
      if (columnsToUpdate.length > 0) { // Log fields only if there were specific fields apart from just touch
         const actualFields = Object.keys(projectData).filter(k => projectData[k] !== undefined);
         if (actualFields.length > 0) {
            logger.info(`[ProjectService] Updating project ${projectId}. Fields: ${actualFields.join(', ')}`);
         }
      }
      const res = await pool.query(query);
      
      if (res.rows.length === 0) {
        // This case should ideally not be reached if getProjectById succeeded and the ID is correct for the UPDATE.
        // It might indicate the project was deleted between the auth check and the update.
        logger.error(`[ProjectService] Project ${projectId} was not updated (no rows returned), though it existed prior to update attempt.`);
        // Throwing a generic error here as the state is unexpected.
        // If getProjectById passed, NotFoundError or NotAuthorizedError shouldn't be the cause.
        throw new Error(`Project with id ${projectId} could not be updated. It may have been deleted or an issue occurred.`);
      }
      return res.rows[0];
    } catch (err) {
      logger.error(`[ProjectService] Error updating project ${projectId}:`, { error: err.message, stack: err.stack });
      throw err;
    }
  },

  /**
   * @async
   * @function deleteProject
   * @summary Delete a project.
   * @description Deletes a project from the database, ensuring it belongs to the specified `userId`.
   * Associated images and expenses are expected to be deleted via CASCADE constraints in the DB schema.
   * 
   * @param {string} projectId - The UUID of the project to delete.
   * @param {string} userId - The UUID of the user who owns the project.
   * @returns {Promise<object>} A promise that resolves to an object indicating deletion status (e.g., { id: projectId, deleted: true }).
   * @throws {Error} If the project is not found or not owned by the user.
   */
  deleteProject: async (projectId, userId) => {
    if (!pool) { logger.error('[ProjectService] DB Pool not available for deleteProject'); throw new Error('DB Connection Error'); }

    // First, verify the project exists and the user is authorized.
    // This will throw NotFoundError or NotAuthorizedError if applicable.
    await projectService.getProjectById(projectId, userId);
    
    const query = {
      text: 'DELETE FROM projects WHERE id = $1 RETURNING id', // No need for user_id in WHERE, getProjectById handled auth
      values: [projectId],
    };
    
    try {
      logger.info(`[ProjectService] Deleting project ${projectId} for user ${userId}`);
      const res = await pool.query(query);
      
      if (res.rowCount === 0) {
        // This should not happen if getProjectById succeeded.
        // It might indicate the project was deleted between the check and this delete operation.
        logger.warn(`[ProjectService] Project ${projectId} not found for deletion, though it existed prior to delete attempt.`);
        // We could throw NotFoundError here again, or a more generic error.
        // For consistency with how updateProject now handles it (though it's also an edge case there).
        throw new NotFoundError(`Project with id ${projectId} could not be deleted. It may have already been deleted.`);
      }
      logger.info(`[ProjectService] Project ${projectId} deleted successfully.`);
      return { id: projectId, deleted: true }; // Return confirmation
    } catch (err) {
      // Catch specific errors from getProjectById if they weren't caught by the router yet,
      // or catch DB errors from the DELETE query.
      if (err instanceof NotFoundError || err instanceof NotAuthorizedError) {
        throw err; // Re-throw custom errors
      }
      logger.error(`[ProjectService] Error deleting project ${projectId}:`, { error: err.message, stack: err.stack });
      throw err; // Re-throw other errors (e.g., DB connection issues)
    }
  },
};

module.exports = projectService;

// Ensure all methods check for pool availability if it might be undefined at module load time.
// A more robust approach might involve a central service initialization that ensures pool is ready before services are used. 