# Travel App GCS Backend

This directory contains the Node.js and Express backend for the Travel application. It serves as the primary API for managing projects, handling image uploads (via Google Cloud Storage), performing Optical Character Recognition (OCR) on images, analyzing extracted text using Google's Gemini AI, and managing user data and subscriptions via Firebase.

## Core Functionality

*   **Project Management**: CRUD operations for user travel projects.
*   **Image Handling**:
    *   Generates signed URLs for client-side uploads directly to Google Cloud Storage (GCS).
    *   Stores image metadata (including GCS path) in the PostgreSQL database.
*   **OCR Processing**: Uses Google Cloud Vision API to extract text from uploaded images.
*   **Invoice Analysis**: Leverages Google's Gemini AI to parse OCR'd text, identify if it's an invoice, and extract key details (total amount, date, merchant, etc.).
*   **User Authentication**: Integrates with Firebase Authentication. API requests are authenticated using Firebase ID tokens.
*   **User Subscriptions**: Manages user subscription tiers (e.g., 'free', 'pro') using Firebase Auth custom claims.
*   **Database**: Utilizes a PostgreSQL database for storing project, image metadata, and expense information.

## Main Components & Files

### `index.js`
The main entry point for the Express application. It:
*   Initializes the Firebase Admin SDK.
*   Loads environment variables (using `dotenv` for local development).
*   Sets up the PostgreSQL database connection pool (from `config/db.js`).
*   **Initializes/updates the database schema** by executing `config/schema.sql` via `config/db-init.js` on startup.
*   Configures Express middleware (CORS, JSON parsing).
*   Mounts all API route handlers.
*   Starts the HTTP server.

### `Dockerfile`
Defines the Docker image for containerizing the application, enabling deployment to Google Cloud Run.

### `build-push-deploy.sh`
A shell script that automates:
*   Pre-flight database connection checks.
*   Fetching secrets (DB password, Gemini API Key) from Google Secret Manager.
*   Building and pushing the Docker image to Google Container Registry (GCR).
*   Deploying the new image version to Google Cloud Run (`gcs-backend` service).
*   Executing PostgreSQL deployment tasks (e.g., setting permissions via `postgres-deploy-tasks.sh`).

### `postgres-deploy-tasks.sh`
A helper script executed by `build-push-deploy.sh` to apply necessary permissions for the database user in PostgreSQL.

### `package.json`
Lists project dependencies (e.g., Express, Firebase Admin, Google Cloud client libraries for Storage, Vision, Generative AI, PostgreSQL) and defines npm scripts (`start`, `dev`, `test`).

### `API_DOCUMENTATION.md`
Provides detailed documentation for the API endpoints. (Self-note: This file will also need review and update).

## Directory Structure

*   **`config/`**: Contains database configuration (`db.js`), the database schema (`schema.sql`), and the schema initialization script (`db-init.js`).
*   **`routes/`**: Defines Express route handlers for different API resources (e.g., projects, OCR, analysis, GCS operations, user subscriptions). See `routes/README.md` (if it exists, or create one).
*   **`services/`**: Contains service modules that encapsulate business logic and interactions with external services (e.g., Google Cloud Vision, Gemini AI, Firebase, PostgreSQL). See `services/README.md` (if it exists, or create one).
*   **`middleware/`**: (Currently empty) Intended for shared Express middleware, such as authentication handlers.

## Environment Variables

The application relies on several environment variables, typically set via Cloud Run service configuration or a local `.env` file for development:

*   `PORT`: The port the server listens on (defaults to 8080).
*   `DB_HOST`, `DB_USER`, `DB_NAME`, `DB_PORT`: PostgreSQL connection details.
*   `DB_PASSWORD`: PostgreSQL password (typically injected as a secret).
*   `GEMINI_API_KEY`: API key for Google's Gemini AI (typically injected as a secret).
*   `GCS_BUCKET_NAME`: The name of the Google Cloud Storage bucket used for image uploads.
*   `GOOGLE_CLOUD_PROJECT`: The GCP project ID.
*   `NODE_ENV`: Set to `production` in Cloud Run.

*Note: `GOOGLE_APPLICATION_CREDENTIALS` is generally not needed when running on Cloud Run if the service account has the appropriate IAM permissions (Application Default Credentials are used).*

## Running Locally

1.  **Prerequisites**: Node.js, npm, access to a PostgreSQL database, Firebase project setup, Google Cloud project with GCS, Vision API, and Generative AI API enabled.
2.  Clone the repository.
3.  Navigate to the `gcs-backend` directory.
4.  Install dependencies: `npm install`
5.  Create a `.env` file in the `gcs-backend` directory and populate it with the necessary environment variables (see list above).
6.  Ensure your PostgreSQL database is running and accessible with the credentials in `.env`. The schema will be applied on first run via `config/db-init.js`.
7.  Start the server: `npm run dev` (uses nodemon) or `npm start`.

## Deployment

The application is designed for deployment to Google Cloud Run. The `build-push-deploy.sh` script handles this process. Ensure you have the Google Cloud SDK installed and configured, and that the necessary secrets are stored in Secret Manager.

```bash
./build-push-deploy.sh
```

## Key Changes & Migration Notes

This backend has undergone a migration from an older Firestore-based approach for some parts. Key changes include:
*   **Database**: Shift from Firestore to PostgreSQL for primary data storage (projects, image metadata, expenses).
*   **Image Handling**: Moved from backend-processed uploads to client-side uploads directly to GCS, orchestrated with signed URLs generated by this backend. `invoiceId` is no longer a primary image identifier; a client-generated `imageId` (UUID) is used.
*   **Authentication**: Standardized on Firebase ID tokens for API authentication.
*   **Schema Initialization**: Database schema is now applied automatically at startup.

// Test comment to trigger CI workflow 