# Backend Service Layer

This directory contains service modules that encapsulate specific business logic, external API interactions, and complex data manipulations for the Travel App GCS Backend. They are utilized by the route handlers in the `routes/` directory.

## Service Modules

### `projectService.js`
- **Purpose**: The primary service for managing core application data related to projects and their associated images.
- **Functionality**: 
  - CRUD operations for user projects (creating, reading, updating, deleting projects).
  - CRUD operations for image metadata stored in the `invoice_images` table (saving metadata after GCS upload, retrieving image details, updating OCR/analysis results, deleting metadata).
  - Data transformation between database row format and API response format.
- **Dependencies**: PostgreSQL connection pool (`../config/db.js`).

### `geminiService.js`
- **Purpose**: Interacts with Google's Gemini AI for advanced text analysis.
- **Functionality**: 
  - Analyzes OCR text (typically from invoices/receipts) to extract structured data like total amount, date, merchant name, currency, taxes, category, etc.
  - Includes retry logic for API calls and robust JSON parsing.
- **Dependencies**: `@google/generative-ai`, `GEMINI_API_KEY` environment variable.

### `visionService.js`
- **Purpose**: Interfaces with Google Cloud Vision API for Optical Character Recognition (OCR).
- **Functionality**: 
  - Detects text in images (provided as a URL or buffer).
  - Extracts full text, individual text blocks, confidence scores, and bounding box information.
- **Dependencies**: `@google-cloud/vision` (uses Application Default Credentials).

### `userSubscriptionService.js`
- **Purpose**: Manages user subscription status (e.g., 'pro' vs 'free').
- **Functionality**: 
  - Gets, sets, and toggles user subscription status by manipulating Firebase Authentication custom claims.
- **Dependencies**: `firebase-admin` (assumes SDK is initialized).

### `postgresService.js` (Likely Deprecated)
- **Purpose**: Originally intended for direct PostgreSQL interactions, particularly for updating image records with OCR and analysis data.
- **Status**: **Likely Deprecated.** Its functionalities appear to be fully covered and superseded by `projectService.js` (specifically `projectService.updateImageOcrResults` and the general `projectService.updateImageMetadata`).
- **Recommendation**: Use `projectService.js` instead. This service is maintained for historical reference or until a full audit confirms it can be safely removed.
- **Dependencies**: PostgreSQL connection pool (`../config/db.js`).

### `gcsService.js` (Likely Deprecated)
- **Purpose**: Originally intended for direct Google Cloud Storage operations like generating signed URLs and deleting files.
- **Status**: **Likely Deprecated.** 
  - Signed URL generation is now handled directly within `routes/gcs.js`.
  - GCS file deletion is orchestrated by `routes/projects.js` as part of image record deletion.
- **Recommendation**: Use `routes/gcs.js` for signed URLs and rely on `routes/projects.js` for GCS file management tied to image records. This service is maintained for historical reference or until a full audit confirms it can be safely removed.
- **Dependencies**: `@google-cloud/storage`, `GCS_BUCKET_NAME` environment variable.

## General Usage Pattern

- Services are typically imported by route handlers in the `../routes/` directory.
- They aim to abstract away direct database queries or complex external API call logic from the route handlers.
- Error handling within services usually involves logging errors and then re-throwing them to be caught by the route handler, or returning a structured error/success object. 