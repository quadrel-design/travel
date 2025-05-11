#!/bin/bash

set -e

PROJECT_ID="splitbase-7ec0f"
IMAGE_NAME="gcs-backend"
REGION="us-central1"

# Build and push the Docker image
docker buildx build --platform linux/amd64 -t gcr.io/$PROJECT_ID/$IMAGE_NAME:latest . --push

# Deploy to Google Cloud Run
gcloud run deploy $IMAGE_NAME \
  --image gcr.io/$PROJECT_ID/$IMAGE_NAME:latest \
  --platform managed \
  --region $REGION \
  --allow-unauthenticated 