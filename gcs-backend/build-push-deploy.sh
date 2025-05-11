#!/bin/bash

set -e

# Build and push the Docker image
TAG=$(date +%s)
docker buildx build --platform linux/amd64 -t gcr.io/splitbase-7ec0f/invoice-service:$TAG -t gcr.io/splitbase-7ec0f/gcs-backend:$TAG . --push

# Deploy to invoice-service

gcloud run deploy invoice-service \
  --image gcr.io/splitbase-7ec0f/invoice-service:$TAG \
  --platform managed \
  --region us-central1 \
  --allow-unauthenticated \
  --set-env-vars=GOOGLE_CLOUD_PROJECT=splitbase-7ec0f

# Deploy to gcs-backend

gcloud run deploy gcs-backend \
  --image gcr.io/splitbase-7ec0f/gcs-backend:$TAG \
  --platform managed \
  --region us-central1 \
  --allow-unauthenticated \
  --set-env-vars=GOOGLE_CLOUD_PROJECT=splitbase-7ec0f