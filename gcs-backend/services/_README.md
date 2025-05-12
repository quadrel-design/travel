# Services

This directory contains service modules that encapsulate business logic and external API interactions for the Travel application backend.

## File Overview

### `postgresService.js`
Provides a service layer for interacting with the PostgreSQL database. It includes methods for user management, project operations, invoice handling, and expense tracking. Uses a connection pool for efficient database access and implements parameterized queries for security.

### `gcsService.js`
Handles interactions with Google Cloud Storage, providing methods for file uploads, downloads, and management. Used primarily for storing and retrieving invoice images and other user documents.

### `visionService.js`
Interfaces with Google Cloud Vision API to provide OCR (Optical Character Recognition) functionality for extracting text from invoice images. Includes methods for detecting text, analyzing document structure, and processing image content.

### `geminiService.js`
Integrates with Google's Gemini AI model to provide advanced text analysis capabilities. Used for parsing and extracting structured data from OCR results, categorizing expenses, and providing insights from invoice text.

### `userSubscriptionService.js`
Manages user subscription state using Firebase Auth custom claims. Provides methods for checking subscription status, toggling between free and pro tiers, and updating user entitlements.

## Usage Pattern

These services follow a consistent pattern:
1. Each service is initialized with necessary dependencies (e.g., database connections, API clients)
2. Services expose public methods that encapsulate specific business operations
3. Error handling is standardized, with appropriate logging and status codes
4. Services maintain separation of concerns, focusing on specific functional areas

The services are consumed by route handlers, which pass through user requests to the appropriate service methods. 