# Travel App API Documentation

This document describes the REST API endpoints for the Travel App backend. The backend handles project management, image processing (OCR and AI analysis), user subscriptions, and orchestrates image uploads to Google Cloud Storage (GCS).

## Authentication

All API endpoints require authentication using Firebase Auth. Include the Firebase ID token in the Authorization header:

```
Authorization: Bearer <firebase-id-token>
```

## Base URL

All API endpoints are prefixed with `/api`. For example, `/api/projects`.
The OCR and Analysis routes (`/ocr-invoice`, `/analyze-invoice`) are mounted at the root of `/api` (e.g. `/api/ocr-invoice`).

## Projects

Handles CRUD operations for user projects.

### List Projects

Retrieves all projects for the authenticated user.

- **URL**: `/projects`
- **Method**: `GET`
- **Auth required**: Yes
- **Response `200 OK`**:
  ```json
  [
    {
      "id": "uuid-project-1",
      "user_id": "firebase-user-uid",
      "title": "Summer Trip to Italy",
      "description": "Family vacation visiting Rome, Florence, and Venice.",
      "location": "Italy",
      "start_date": "2024-07-10T00:00:00.000Z",
      "end_date": "2024-07-24T00:00:00.000Z",
      "budget": 3500.00,
      "is_completed": false,
      "created_at": "2024-01-15T10:00:00.000Z",
      "updated_at": "2024-01-15T10:00:00.000Z"
    }
    // ... other projects
  ]
  ```

### Get Project

Retrieves a specific project by its ID.

- **URL**: `/projects/:projectId`
- **Method**: `GET`
- **Auth required**: Yes
- **URL Params**:
  - `projectId` (string, UUID): The ID of the project to retrieve.
- **Response `200 OK`**:
  ```json
  {
    "id": "uuid-project-1",
    "user_id": "firebase-user-uid",
    // ... other project fields as above
  }
  ```
- **Response `404 Not Found`**: If the project doesn't exist or doesn't belong to the user.

### Create Project

Creates a new project for the authenticated user.

- **URL**: `/projects`
- **Method**: `POST`
- **Auth required**: Yes
- **Request Body**:
  ```json
  {
    "title": "Business Trip to SF",
    "description": "Conference and client meetings.",
    "location": "San Francisco, CA",
    "start_date": "2024-08-05T00:00:00.000Z", // Optional
    "end_date": "2024-08-09T00:00:00.000Z",   // Optional
    "budget": 1200.50,                       // Optional
    "is_completed": false                    // Optional
  }
  ```
- **Response `201 Created`**:
  ```json
  {
    "id": "newly-created-project-uuid",
    "user_id": "firebase-user-uid",
    "title": "Business Trip to SF",
    // ... other fields, including defaults for optionals not provided
    "created_at": "2024-02-01T11:00:00.000Z",
    "updated_at": "2024-02-01T11:00:00.000Z"
  }
  ```

### Update Project

Updates an existing project. Only provided fields are updated.

- **URL**: `/projects/:projectId`
- **Method**: `PATCH`
- **Auth required**: Yes
- **URL Params**:
  - `projectId` (string, UUID): The ID of the project to update.
- **Request Body** (example - provide only fields to change):
  ```json
  {
    "description": "Updated: Conference and client meetings, plus a workshop.",
    "budget": 1350.00
  }
  ```
- **Response `200 OK`**:
  ```json
  {
    "id": "uuid-project-1",
    "user_id": "firebase-user-uid",
    // ... all project fields with updates applied
    "updated_at": "2024-02-01T12:30:00.000Z"
  }
  ```
- **Response `404 Not Found`**: If the project doesn't exist or doesn't belong to the user.

### Delete Project

Deletes a project and all its associated images and expenses (due to CASCADE constraints).

- **URL**: `/projects/:projectId`
- **Method**: `DELETE`
- **Auth required**: Yes
- **URL Params**:
  - `projectId` (string, UUID): The ID of the project to delete.
- **Response `204 No Content`**: On successful deletion.
- **Response `404 Not Found`**: If the project doesn't exist or doesn't belong to the user.

## Project Images

Manages images associated with a project. Images are first uploaded by the client directly to Google Cloud Storage (GCS) using a signed URL obtained from the `/api/gcs/generate-upload-url` endpoint. After successful GCS upload, the client posts the image metadata to this backend.

### List Project Images

Retrieves metadata for all images associated with a specific project.

- **URL**: `/projects/:projectId/images`
- **Method**: `GET`
- **Auth required**: Yes
- **URL Params**:
  - `projectId` (string, UUID): The ID of the project.
- **Response `200 OK`**:
  ```json
  [
    {
      "id": "client-generated-image-uuid-1",
      "projectId": "uuid-project-1",
      "userId": "firebase-user-uid",
      "status": "analysis_complete", // Current status (e.g., uploaded, pending_ocr, ocr_complete, analysis_running, analysis_complete, analysis_failed, ocr_failed)
      "imagePath": "users/firebase-user-uid/projects/uuid-project-1/images/client-generated-image-uuid-1/original_filename.jpg", // GCS object path
      "isInvoiceGuess": true,
      "ocrText": "Extracted text from OCR...",
      "ocrConfidence": 0.95,
      "invoiceAnalysis": {
        "totalAmount": 123.45,
        "currency": "USD",
        "date": "2024-07-15",
        "merchantName": "Example Cafe",
        "location": "Some City",
        "taxes": 10.50,
        "category": "food",
        "taxonomy": "food/restaurant/cafe"
      },
      "analyzedInvoiceDate": "2024-07-15T00:00:00.000Z",
      "invoiceSum": 123.45,
      "invoiceCurrency": "USD",
      "invoiceTaxes": 10.50,
      "errorMessage": null, // Or error message if processing failed
      "uploadedAt": "2024-02-01T14:00:00.000Z",
      "createdAt": "2024-02-01T14:00:00.000Z",
      "updatedAt": "2024-02-01T14:15:00.000Z",
      "originalFilename": "receipt_cafe.jpg",
      "contentType": "image/jpeg",
      "size": 102400 // bytes
    }
    // ... other images
  ]
  ```

### Get Project Image Metadata

Retrieves metadata for a specific image within a project.

- **URL**: `/projects/:projectId/images/:imageId`
- **Method**: `GET`
- **Auth required**: Yes
- **URL Params**:
  - `projectId` (string, UUID): The ID of the project.
  - `imageId` (string): The ID of the image (client-generated).
- **Response `200 OK`**:
  ```json
  {
    // ... single image object, same structure as in "List Project Images"
  }
  ```
- **Response `404 Not Found`**: If the project or image doesn't exist or doesn't belong to the user.

### Create Image Metadata Record (Post GCS Upload)

Registers metadata for an image that has already been uploaded to GCS by the client.

- **URL**: `/projects/:projectId/images`
- **Method**: `POST`
- **Auth required**: Yes
- **URL Params**:
  - `projectId` (string, UUID): The ID of the project this image belongs to.
- **Request Body**:
  ```json
  {
    "id": "client-generated-image-uuid-2", // REQUIRED: Client-generated UUID for the image
    "imagePath": "users/firebase-user-uid/projects/uuid-project-1/images/client-generated-image-uuid-2/new_receipt.png", // REQUIRED: Full GCS object path
    "originalFilename": "new_receipt.png", // REQUIRED
    "uploaded_at": "2024-02-01T15:00:00.000Z", // Optional: client's upload timestamp, defaults to now()
    "contentType": "image/png", // Optional but recommended
    "size": 204800 // Optional: size in bytes
  }
  ```
- **Response `201 Created`**:
  ```json
  {
    "id": "client-generated-image-uuid-2",
    "projectId": "uuid-project-1",
    "userId": "firebase-user-uid",
    "status": "uploaded", // Initial status
    "imagePath": "users/firebase-user-uid/projects/uuid-project-1/images/client-generated-image-uuid-2/new_receipt.png",
    // ... other fields will be null or default until OCR/analysis
    "originalFilename": "new_receipt.png",
    "contentType": "image/png",
    "size": 204800,
    "uploadedAt": "2024-02-01T15:00:00.000Z",
    "createdAt": "2024-02-01T15:00:05.000Z",
    "updatedAt": "2024-02-01T15:00:05.000Z"
  }
  ```
- **Response `400 Bad Request`**: If required fields are missing.
- **Response `404 Not Found`**: If the specified project doesn't exist.
- **Response `409 Conflict`**: If an image with the same ID already exists for this project.


### Delete Project Image

Deletes an image record from the database AND the corresponding file from Google Cloud Storage.

- **URL**: `/projects/:projectId/images/:imageId`
- **Method**: `DELETE`
- **Auth required**: Yes
- **URL Params**:
  - `projectId` (string, UUID): The ID of the project.
  - `imageId` (string): The ID of the image to delete.
- **Response `204 No Content`**: On successful deletion.
- **Response `404 Not Found`**: If the project or image doesn't exist.

### Update Image Analysis Details (Manual/Client-side Edit)

Allows updating parts of the analysis data for an image, typically after manual review or client-side editing.

- **URL**: `/projects/:projectId/images/:imageId/analysis`
- **Method**: `PATCH`
- **Auth required**: Yes
- **URL Params**:
  - `projectId` (string, UUID): The ID of the project.
  - `imageId` (string): The ID of the image.
- **Request Body** (Example - provide only fields to change from client-side model):
  ```json
  {
    "invoiceAnalysis": { // Full or partial Gemini-like analysis object
      "totalAmount": 150.75,
      "currency": "EUR",
      "date": "2024-07-16",
      "merchantName": "Updated Merchant Name",
      // ... other analysis fields ...
    },
    "isInvoiceGuess": true, // Client's assessment
    "status": "analysis_complete", // Or other relevant status
    "invoiceDate": "2024-07-16T00:00:00.000Z" // Date object for analyzed_invoice_date
  }
  ```
- **Response `200 OK`**: The updated image metadata object (same structure as "List Project Images").
- **Response `404 Not Found`**: If the project or image doesn't exist.

*(Note: OCR results update endpoint `/projects/:projectId/images/:imageId/ocr` also exists but is typically managed by the backend OCR process. If manual OCR text update is needed, its documentation can be detailed here too.)*

## OCR Processing

Handles Optical Character Recognition for an image. This is typically triggered by the backend after an image metadata record is created, or can be called if re-processing is needed.

### Perform OCR on an Invoice Image

- **URL**: `/ocr-invoice` (Note: Mounted at `/api/ocr-invoice`)
- **Method**: `POST`
- **Auth required**: Yes
- **Request Body**:
  ```json
  {
    "imageUrl": "gs://your-gcs-bucket-name/users/uid/projects/pid/images/imgid/filename.jpg", // GCS URI of the image
    "projectId": "project-uuid-to-which-image-belongs",
    "imageId": "image-uuid-to-update" // The ID of the image record in 'invoice_images' table
  }
  ```
- **Response `200 OK`**:
  ```json
  {
    "success": true,
    "status": "ocr_complete", // or "ocr_no_text", "ocr_failed"
    "message": "OCR successful",
    "ocrText": "The full extracted text from the image...",
    "ocrConfidence": 0.85 // Overall confidence if available (Vision API specific)
  }
  ```
- **Response `400 Bad Request`**: If required fields are missing or `imageData` is provided (not fully supported).
- **Response `500 Internal Server Error`**: If OCR process fails or DB update fails. The image status in DB will be updated to `ocr_failed` with an error message.

## AI Analysis (Gemini)

Handles analysis of OCR'd text to extract structured invoice data using Gemini. Typically triggered after successful OCR.

### Analyze Invoice Text

- **URL**: `/analyze-invoice` (Note: Mounted at `/api/analyze-invoice`)
- **Method**: `POST`
- **Auth required**: Yes
- **Request Body**:
  ```json
  {
    "ocrText": "The extensive text extracted by the OCR process...",
    "projectId": "project-uuid-context",
    "imageId": "image-uuid-to-update" // The ID of the image record in 'invoice_images' table
  }
  ```
- **Response `200 OK`**:
  ```json
  {
    "success": true,
    "message": "Analysis successful", // or "Analyzed, not an invoice"
    "isInvoice": true, // boolean: Gemini's assessment
    "data": { // Gemini's structured analysis
      "totalAmount": 199.99,
      "currency": "GBP",
      "date": "2024-06-20",
      "merchantName": "Tech Supplies Ltd.",
      "location": "London",
      "taxes": 20.00,
      "category": "electronics",
      "taxonomy": "business/equipment/electronics",
      "isInvoice": true // Redundant here, use outer isInvoice
    },
    "status": "analysis_complete" // or "analysis_not_invoice", "analysis_failed"
  }
  ```
- **Response `400 Bad Request`**: If required fields are missing.
- **Response `500 Internal Server Error`**: If analysis fails or DB update fails. The image status in DB will be updated to `analysis_failed` with an error message.


## GCS Operations (Google Cloud Storage)

Endpoints for managing GCS interactions, primarily for client-side uploads.

### Generate Signed Upload URL

Provides a short-lived, signed URL that the client can use to directly upload a file to GCS.

- **URL**: `/gcs/generate-upload-url`
- **Method**: `POST`
- **Auth required**: Yes
- **Request Body**:
  ```json
  {
    "filename": "users/firebase-user-uid/projects/project-uuid/images/image-uuid/my_receipt.jpg", // The desired GCS object path, including the filename. Ensure uniqueness and proper structure.
    "contentType": "image/jpeg" // The MIME type of the file to be uploaded.
  }
  ```
- **Response `200 OK`**:
  ```json
  {
    "url": "https://storage.googleapis.com/your-bucket-name/users/uid/...?X-Goog-Algorithm=..." // The signed URL
  }
  ```
- **Response `400 Bad Request`**: If `filename` or `contentType` is missing.
- **Response `500 Internal Server Error`**: If URL generation fails.

### Generate Signed Download URL

Provides a short-lived, signed URL to allow read access to a GCS object.

- **URL**: `/gcs/generate-download-url`
- **Method**: `GET`
- **Auth required**: Yes
- **Query Parameters**:
  - `filename` (string, required): The GCS object path of the file.
- **Response `200 OK`**:
  ```json
  {
    "url": "https://storage.googleapis.com/your-bucket-name/users/uid/...?X-Goog-Algorithm=..." // The signed URL
  }
  ```
- **Response `400 Bad Request`**: If `filename` query parameter is missing.
- **Response `404 Not Found`**: If the specified file does not exist in GCS.
- **Response `500 Internal Server Error`**: If URL generation fails.

## User Subscriptions

Manages user subscription status (e.g., 'pro' vs 'free') using Firebase Auth custom claims.

### Get Subscription Status

Retrieves the current subscription status for the authenticated user.

- **URL**: `/user/subscription-status`
- **Method**: `GET`
- **Auth required**: Yes
- **Response `200 OK`**:
  ```json
  {
    "subscription": "free" // or "pro"
  }
  ```

### Toggle Subscription

Toggles the authenticated user's subscription status between 'pro' and 'free'.

- **URL**: `/user/toggle-subscription`
- **Method**: `POST`
- **Auth required**: Yes
- **Response `200 OK`**:
  ```json
  {
    "success": true,
    "subscription": "pro" // The new status after toggling
  }
  ```

## Error Responses

Common error responses include:

- **`400 Bad Request`**: Missing required parameters or invalid data format.
  ```json
  { "error": "Descriptive error message" }
  ```
- **`401 Unauthorized`**: Missing, invalid, or expired Firebase ID token.
  ```json
  { "error": "Unauthorized: No token provided" }
  // or
  { "error": "Unauthorized: Token expired", "code": "TOKEN_EXPIRED" }
  ```
- **`403 Forbidden`**: User is authenticated but not authorized to perform the action (rarely used if ownership checks result in 404).
- **`404 Not Found`**: Resource not found (e.g., project, image).
  ```json
  { "error": "Project not found" }
  ```
- **`500 Internal Server Error`**: A server-side error occurred.
  ```json
  { "error": "Detailed error message from server" }
  // Or for authentication service issues:
  { "error": "Authentication service not configured." }
  ```
The specific error message will vary. For image processing failures (OCR, Analysis), the backend attempts to update the image's status and error_message field in the database. 