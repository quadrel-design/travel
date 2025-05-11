#!/bin/bash

set -e

# Build and push the Docker image
docker buildx build --platform linux/amd64 -t gcr.io/splitbase-7ec0f/gcs-backend:latest . --push

# Deploy to Google Cloud Run with the project ID env var
gcloud run deploy gcs-backend \
  --image gcr.io/splitbase-7ec0f/gcs-backend:latest \
  --platform managed \
  --region us-central1 \
  --allow-unauthenticated \
  --set-env-vars=GOOGLE_CLOUD_PROJECT=splitbase-7ec0f