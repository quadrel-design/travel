# Travel App Backend

This directory contains the backend server for the Travel application, built with Node.js and Express. It provides API endpoints for file storage, OCR processing, text analysis, and user subscription management.

## Main Files

### `index.js`
The main entry point for the Express application. It initializes database connections, sets up middleware, and mounts the various route handlers. The server handles CORS, environment variables via dotenv, and exposes a health check endpoint.

### `Dockerfile`
Contains the Docker configuration for containerizing the application, used for deployment to Google Cloud Run.

### `build-push-deploy.sh`
A shell script for automating the build, push, and deployment process to Google Cloud.

### `package.json`
Defines the project dependencies and scripts for running, building, and deploying the application.

## Directory Structure

### [`services/`](services/README.md)
Contains service modules that encapsulate business logic and external API interactions.

### [`routes/`](routes/README.md)
Contains Express route handlers for the various API endpoints.

## Environment Variables

The application uses the following environment variables:
- `PORT`: The port the server will listen on (defaults to 8080)
- `DB_USER`, `DB_HOST`, `DB_NAME`, `DB_PASSWORD`, `DB_PORT`: PostgreSQL connection details
- `GOOGLE_CLOUD_PROJECT`: The GCP project ID
- `GOOGLE_APPLICATION_CREDENTIALS`: Path to the service account credentials (optional when using ADC)

## Running Locally

1. Install dependencies: `npm install`
2. Set up environment variables in a `.env` file
3. Start the server: `npm start`

## Deployment

The application is deployed to Google Cloud Run using the provided build script:

```bash
./build-push-deploy.sh
``` 