# Routes

This directory contains Express route handlers for the Travel application backend API endpoints. Each file defines a set of related routes that handle specific functionality.

## File Overview

### `gcs.js`
Defines endpoints for Google Cloud Storage interactions, allowing clients to upload, download, and manage files. Includes routes for signed URL generation, file listing, and storage metadata. Mounted at `/api/gcs` and leverages the gcsService for business logic.

### `ocr.js`
Implements routes for Optical Character Recognition (OCR) functionality, enabling the extraction of text from images. These endpoints accept image data and return structured text information using Google Cloud Vision API through the visionService. Handles various image formats and provides options for document analysis.

### `analysis.js`
Provides endpoints for advanced text analysis of OCR results using Gemini AI. These routes accept extracted text and return structured data like vendor information, line items, totals, and dates. Used for processing invoice data after OCR has been performed.

### `userSubscription.js`
Contains routes for managing user subscription status, primarily the toggle between free and pro tiers. Mounted at `/api/user` and implements functionality to update Firebase Auth custom claims based on subscription changes. Uses userSubscriptionService for business logic implementation.

## Route Pattern

Routes follow these conventions:
1. Each route file is organized by functional area
2. Routes are mounted at specific base paths in index.js
3. Authentication and authorization checks are performed at the route level
4. Routes delegate business logic to appropriate service modules
5. Consistent error handling and response formatting is implemented across all routes

Each endpoint includes validation of incoming requests, appropriate error handling, and structured responses. 