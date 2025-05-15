# Travel App API - Progress Summary and TODO

## Project Overview
The Travel App is being migrated from Firestore to PostgreSQL. The backend is a Node.js REST API that interfaces with both PostgreSQL for data and Google Cloud Storage for file management.

## Completed Tasks

### Environment Configuration Fixes
- ✓ Fixed dotenv configuration by moving `require('dotenv').config()` to the top of both server files
- ✓ Resolved PostgreSQL connection issues by using the password directly instead of attempting base64 decoding
- ✓ Configured appropriate environment variables for database connection

### Database Schema Fixes
- ✓ Resolved incompatible data type issues in foreign key constraints
- ✓ Improved schema.sql to use separate DO blocks with proper error handling for foreign key constraints
- ✓ Enhanced database initialization script (db-init.js) to better handle SQL splitting and execution
- ✓ Enabled pgcrypto extension for UUID generation
- ✓ Implemented proper UUID generation for projects using PostgreSQL

### Authentication Fixes
- ✓ Added proper Firebase Admin SDK initialization in index.js
- ✓ Implemented robust service account file handling with fallbacks
- ✓ Updated Cloud Run service with correct GOOGLE_APPLICATION_CREDENTIALS environment variable
- ✓ Mounted service account file correctly for Firebase authentication
- ✓ Fixed authentication issue - API was returning "Unauthorized: Invalid token" (401) errors when using Firebase tokens

### API Fixes
- ✓ Fixed budget parsing in API responses to ensure numeric values are returned (resolving type error in Flutter app)
- ✓ Fixed budget handling for null/undefined values to prevent server errors when fetching projects
- ✓ Fixed project creation - Fixed 500 Internal Server Error when creating new projects
- ✓ Fixed database authentication issue - Corrected the PostgreSQL password in Secret Manager by removing URL-encoded character
- ✓ Resolved backend startup crashes due to SyntaxErrors and incorrect Express route handling.
- ✓ Fixed TypeError related to Express middleware by correcting route imports.
- ✓ Aligned image upload flow: Backend now accepts JSON metadata for GCS pre-uploaded files.
- ✓ Ensured Flutter client sends all required metadata (originalFilename, contentType, size) for image record creation.
- ✓ Resolved database schema mismatches for image metadata (analyzed_invoice_date, original_filename, size, content_type).

### Deployment and Configuration
- ✓ Created Dockerfile for containerizing the application
- ✓ Built and pushed Docker image to Google Container Registry
- ✓ Deployed to Google Cloud Run at https://travel-api-213342165039.us-central1.run.app
- ✓ Set up necessary environment variables in Cloud Run
- ✓ Created Secret Manager secret for service-account.json
- ✓ Mounted service account credentials to the Cloud Run container
- ✓ Granted appropriate IAM permissions for secret access
- ✓ Updated mobile app API endpoint configuration from `https://invoice-service-qzlk3xulxq-uc.a.run.app` to `https://travel-api-213342165039.us-central1.run.app`
- ✓ Fixed connection issues showing in the app logs
- ✓ Ensured database schema is initialized on application startup.

## Pending Tasks

### Refactoring & Code Health
- [ ] Refactor `authenticateUser` middleware: Currently duplicated in multiple route files (`ocr.js`, `analysis.js`, `projects.js`, `gcs.js`, `userSubscription.js`). Centralize into a single middleware in `gcs-backend/middleware/` and import where needed.
- [ ] Review and potentially remove `gcs-backend/services/postgresService.js`: Appears redundant with `projectService.js`. Confirm no usages and delete if safe.
- [ ] Review and potentially remove `gcs-backend/services/gcsService.js`: Appears redundant with `routes/gcs.js` and GCS deletion logic in `routes/projects.js`. Confirm no usages and delete if safe.
- [ ] `routes/gcs.js`: The `/api/gcs/delete` endpoint has a TODO to implement actual GCS file deletion. Address this or remove the endpoint if GCS deletion is handled elsewhere (e.g., via `routes/projects.js`).
- [ ] `routes/gcs.js`: The `/api/gcs/signed-url` endpoint is marked as redundant with `/api/gcs/generate-download-url`. Decide to merge or remove.

### Documentation
- [✓] Review and update JSDocs for all files in `gcs-backend/` (routes, services, config, index.js).
- [✓] Review and update all `README.md` files in `gcs-backend/` (root, routes/, services/).

### AI/Analysis Functionality
- [ ] Review and confirm full analyzeText functionality post-OCR.
- [ ] Further troubleshoot integration between OCR and Gemini API for invoice analysis if needed.
- [ ] Improve error handling in analysis pipeline.

### Database Improvements
- [ ] Enable SSL for PostgreSQL connections (more secure for production)
- [ ] Consider moving PostgreSQL database credentials to Secret Manager for enhanced security (currently uses environment variables via `process.env` in `db.js`).
- [ ] Implement a proper database migration system for future schema changes
- [ ] Create database backups and restore process
- [ ] Fix PostgreSQL `pg_hba.conf` to allow connections for database management tasks
- [ ] `config/schema.sql`: The `invoice_images` table has columns like `analyzed_total_amount`, `analyzed_currency`, `analyzed_merchant_name`, `analyzed_merchant_location`. These seem to be from an older naming convention or potentially duplicative of fields like `invoice_sum`, `invoice_currency` that are populated from `gemini_analysis_json`. Review and consolidate if necessary for clarity and to avoid confusion.

### Security Enhancements
- [ ] Implement rate limiting to prevent API abuse
- [ ] Set up Firebase App Check to ensure requests come from legitimate clients
- [ ] Audit and improve authentication checks across all endpoints
- [ ] Review IAM permissions and implement least privilege
- [ ] Create a dedicated service account with minimal permissions for the Cloud Run service (currently using default Compute Engine service account with broad permissions)

### Infrastructure
- [ ] Set up a custom domain name instead of Cloud Run URL
- [ ] Configure proper CORS settings for production
- [ ] Implement CDN for static assets if needed

### CI/CD Pipeline
- [ ] Create GitHub Actions workflow for automatic deployment
- [ ] Add automated tests to the CI/CD pipeline
- [ ] Set up staging environment

### Monitoring and Logging
- [ ] Configure Cloud Monitoring alerts for errors and performance
- [ ] Set up structured logging
- [ ] Create dashboard for API usage and performance metrics

### Mobile App Updates
- [ ] Remove any hardcoded localhost URLs
- [ ] Test all functionality with the new backend

## Technical Context

### Architecture
- **Backend**: Node.js Express REST API 
- **Database**: PostgreSQL (hosted at 37.148.202.133)
- **Authentication**: Firebase Authentication with proper Admin SDK initialization
- **Storage**: Google Cloud Storage
- **AI Analysis**: Google Cloud Vision API for OCR, Gemini API for analysis

### Key Files and Directories
- `gcs-backend/index.js`: Main server file for the PostgreSQL backend, includes Firebase Admin initialization
- `index.js`: Root server file for file operations
- `gcs-backend/config/schema.sql`: Database schema definition
- `gcs-backend/config/db-init.js`: Database initialization script
- `gcs-backend/routes/`: API route definitions
- `gcs-backend/services/`: Service implementations including PostgreSQL and Firebase

### Database Structure
- `projects`: Main table storing travel project data (UUID primary keys)
- `invoice_images`: Stores GCS path, OCR, and analysis data for uploaded invoices/receipts (primary key `id UUID`)
- (Deprecated/Removed from docs) `invoices_metadata`: This table was not found in the current `gcs-backend/config/schema.sql` and appears to be from an older design.
- (To Verify) `expenses`: This table was not found in `gcs-backend/config/schema.sql`. Verify its status; if not part of the current `gcs-backend` PostgreSQL schema, it should be removed from this documentation or its context clarified.

### Environment Variables
- `DB_HOST`: PostgreSQL host (37.148.202.133)
- `DB_NAME`: Database name (travel_db)
- `DB_USER`: Database user (travel_user)
- `DB_PASSWORD`: Database password (XXXXX)
- `DB_PORT`: Database port (5432)
- `GOOGLE_CLOUD_PROJECT`: GCP project ID (splitbase-7ec0f)
- `GOOGLE_APPLICATION_CREDENTIALS`: Path to service account JSON file

### Authentication Flow
- The API uses Firebase Authentication
- Client apps obtain a Firebase ID token and include it in the Authorization header
- Server verifies the token using Firebase Admin SDK

### Deployment Details
- Deployed to Google Cloud Run: https://travel-api-213342165039.us-central1.run.app
- Service account credentials mounted at /secrets/service-account.json
- GOOGLE_APPLICATION_CREDENTIALS environment variable set to /secrets/service-account.json
- Firebase Admin SDK initialized with service account from mounted secret
- Environment variables configured in Cloud Run service

## Notes for Future Development
- The codebase is transitioning from Firestore to PostgreSQL, so some code paths may still reference Firestore
- The service-account.json file is required for Firebase Authentication and GCS access
- The PostgreSQL schema uses DO blocks which must be executed as complete blocks (not split by semicolons)
- API routes in the mobile app will need to be updated to the new Cloud Run endpoint 