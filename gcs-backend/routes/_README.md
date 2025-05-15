# Backend API Routes

This directory contains the Express.js route handlers for the Travel App GCS Backend. Each file groups related API endpoints by their primary resource or functionality.

All routes defined herein generally expect Firebase ID tokens for authentication, which is typically handled by an `authenticateUser` middleware within each route file (TODO: Refactor to a centralized middleware).

## Route Modules

### `projects.js`
- **Mounted at**: `/api/projects`
- **Functionality**: Manages core project data and associated image metadata.
  - CRUD operations for projects (e.g., `/`, `/:projectId`).
  - CRUD operations for image metadata records linked to projects (e.g., `/:projectId/images`, `/:projectId/images/:imageId`). Image files themselves are uploaded client-side to GCS using signed URLs.
  - Endpoints for updating OCR and analysis results for specific images (e.g., `/:projectId/images/:imageId/ocr`, `/:projectId/images/:imageId/analysis`), usually invoked by other backend processes or for manual client edits.
- **Dependencies**: `projectService`, Google Cloud Storage client (for deleting image files).

### `gcs.js`
- **Mounted at**: `/api/gcs`
- **Functionality**: Handles direct interactions with Google Cloud Storage, primarily for generating signed URLs.
  - `POST /generate-upload-url`: Provides a v4 signed URL for clients to upload files directly to GCS.
  - `GET /generate-download-url`: Provides a v4 signed URL for clients to download files directly from GCS.
  - `POST /delete`: (Minimal implementation) Intended for deleting files from GCS; currently logs but doesn't perform GCS deletion.
- **Dependencies**: Google Cloud Storage client.

### `ocr.js`
- **Mounted at**: `/api` (e.g., actual route is `/api/ocr-invoice`)
- **Functionality**: Performs Optical Character Recognition on images.
  - `POST /ocr-invoice`: Accepts a GCS image URL, project ID, and image ID. It fetches the image, sends it to Google Cloud Vision API for text extraction, and updates the image's metadata in the database (`invoice_images` table via `projectService`) with the OCR results and status.
- **Dependencies**: `visionService`, `projectService`, `axios`.

### `analysis.js`
- **Mounted at**: `/api` (e.g., actual route is `/api/analyze-invoice`)
- **Functionality**: Analyzes extracted OCR text using Google's Gemini AI to identify invoice details.
  - `POST /analyze-invoice`: Accepts OCR text, project ID, and image ID. It sends the text to Gemini for analysis, then updates the image's metadata in the database (`invoice_images` table via `projectService`) with the structured invoice data (total, date, merchant, etc.) and status.
- **Dependencies**: `geminiService`, `projectService`.

### `userSubscription.js`
- **Mounted at**: `/api/user`
- **Functionality**: Manages user subscription status (e.g., 'pro' vs 'free').
  - `POST /toggle-subscription`: Toggles the user's subscription status in Firebase Auth custom claims.
  - `GET /subscription-status`: Retrieves the user's current subscription status from Firebase Auth custom claims.
- **Dependencies**: `userSubscriptionService`, Firebase Admin SDK.

## General Route Conventions

1.  **Authentication**: Most routes apply an `authenticateUser` middleware to verify Firebase ID tokens.
2.  **Service Delegation**: Business logic is delegated to corresponding modules in the `services/` directory.
3.  **Error Handling**: Routes include try-catch blocks for error handling and aim to provide consistent JSON error responses.
4.  **Database Interaction**: Primarily through `projectService` for operations on `projects` and `invoice_images` tables.

Each endpoint includes validation of incoming requests, appropriate error handling, and structured responses. 