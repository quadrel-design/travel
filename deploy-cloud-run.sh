#!/bin/bash

# Deploy to Google Cloud Run
gcloud run deploy gcs-backend \
  --image gcr.io/splitbase-7ec0f/gcs-backend:latest \
  --platform managed \
  --region us-central1 \
  --allow-unauthenticated