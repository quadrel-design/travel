#!/bin/bash

set -e

# Define your project ID and image names
PROJECT_ID="splitbase-7ec0f"
IMAGE_NAME_INVOICE_SERVICE="invoice-service" # This is the primary service we're fixing
TARGET_GCS_BUCKET_NAME="travel-files" # Your GCS bucket name
# IMAGE_NAME_GCS_BACKEND="gcs-backend" # Define if gcs-backend is a separate service name

# Create a unique tag for this build
BUILD_TAG=$(date +%s)

# Build and push the Docker image
# The image is built once and tagged.
echo "Building and pushing image for ${IMAGE_NAME_INVOICE_SERVICE} with tag: ${BUILD_TAG} and :latest"
docker buildx build \
  --no-cache \
  --platform linux/amd64 \
  -t "gcr.io/${PROJECT_ID}/${IMAGE_NAME_INVOICE_SERVICE}:${BUILD_TAG}" \
  -t "gcr.io/${PROJECT_ID}/${IMAGE_NAME_INVOICE_SERVICE}:latest" \
  . \
  --push

# Deploy to invoice-service using the unique BUILD_TAG and include GCS_BUCKET_NAME
echo "Deploying ${IMAGE_NAME_INVOICE_SERVICE} with image tag: ${BUILD_TAG}"
gcloud run deploy ${IMAGE_NAME_INVOICE_SERVICE} \
  --image "gcr.io/${PROJECT_ID}/${IMAGE_NAME_INVOICE_SERVICE}:${BUILD_TAG}" \
  --platform managed \
  --region us-central1 \
  --allow-unauthenticated \
  --set-env-vars="GOOGLE_CLOUD_PROJECT=${PROJECT_ID},GEMINI_API_KEY=AIzaSyBjbl2JxSq7A65TrGWIcK5uLlVpuq3f3bM,GCS_BUCKET_NAME=${TARGET_GCS_BUCKET_NAME}" # Ensure your API key is correct and securely managed

# If gcs-backend is a distinct service and still needs to be deployed from the same source:
# If it's the SAME service as invoice-service, this second deploy is redundant.
# Consider removing this block if invoice-service is your sole target for this codebase.
#
# IMAGE_NAME_GCS_BACKEND="gcs-backend" # Make sure this service name is correct if used
# echo "Deploying ${IMAGE_NAME_GCS_BACKEND} with image tag: ${BUILD_TAG}"
# gcloud run deploy ${IMAGE_NAME_GCS_BACKEND} \
#   --image "gcr.io/${PROJECT_ID}/${IMAGE_NAME_GCS_BACKEND}:${BUILD_TAG}" \ # This assumes gcs-backend image uses the same name path
#   --platform managed \
#   --region us-central1 \
#   --allow-unauthenticated \
#   --set-env-vars="GOOGLE_CLOUD_PROJECT=${PROJECT_ID}"

echo "Script completed."