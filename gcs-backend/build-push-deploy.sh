#!/bin/bash

set -e

# Define your project ID and shared image name
PROJECT_ID="splitbase-7ec0f"
APP_IMAGE_NAME="travel-app-shared" # Single image for both services
TARGET_GCS_BUCKET_NAME="travel-files" # Your GCS bucket name for invoice-service

# --- IMPORTANT: Replace these with your actual Secret Manager secret names ---
DB_PASSWORD_SECRET_NAME="gcs-backend-db-password" # e.g., "gcs-backend-db-password"
GEMINI_API_KEY_SECRET_NAME="shared-gemini-api-key" # e.g., "shared-gemini-api-key"
# ---

# Create a unique tag for this build
BUILD_TAG=$(date +%s)

# Build and push the Docker image
echo "Building and pushing image for ${APP_IMAGE_NAME} with tag: ${BUILD_TAG} and :latest"
docker buildx build \
  --no-cache \
  --platform linux/amd64 \
  -t "gcr.io/${PROJECT_ID}/${APP_IMAGE_NAME}:${BUILD_TAG}" \
  -t "gcr.io/${PROJECT_ID}/${APP_IMAGE_NAME}:latest" \
  . \
  --push

# Deploy to gcs-backend
echo "Deploying gcs-backend with image tag: ${BUILD_TAG}"
gcloud run deploy gcs-backend \
  --image "gcr.io/${PROJECT_ID}/${APP_IMAGE_NAME}:${BUILD_TAG}" \
  --platform managed \
  --region us-central1 \
  --allow-unauthenticated \
  --set-env-vars="GOOGLE_CLOUD_PROJECT=${PROJECT_ID},DB_USER=travel_user,DB_HOST=37.148.202.133,DB_NAME=travel_db,DB_PORT=5432,DB_PASSWORD=secret:${DB_PASSWORD_SECRET_NAME}:latest,GEMINI_API_KEY=secret:${GEMINI_API_KEY_SECRET_NAME}:latest"

# Deploy to invoice-service
echo "Deploying invoice-service with image tag: ${BUILD_TAG}"
gcloud run deploy invoice-service \
  --image "gcr.io/${PROJECT_ID}/${APP_IMAGE_NAME}:${BUILD_TAG}" \
  --platform managed \
  --region us-central1 \
  --allow-unauthenticated \
  --set-env-vars="GOOGLE_CLOUD_PROJECT=${PROJECT_ID},GEMINI_API_KEY=secret:${GEMINI_API_KEY_SECRET_NAME}:latest,GCS_BUCKET_NAME=${TARGET_GCS_BUCKET_NAME}"

echo "Script completed."