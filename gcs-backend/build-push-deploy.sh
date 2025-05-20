#!/bin/bash

set -e

# Define your project ID and shared image name
PROJECT_ID="${GCP_PROJECT_ID:-splitbase-7ec0f}"
APP_IMAGE_NAME="travel-app-shared" # Single image for both services
TARGET_GCS_BUCKET_NAME="travel-files" # Your GCS bucket name for invoice-service

# --- Database Connection Parameters for Pre-flight Check ---
DB_USER_VALUE="travel_user"
DB_HOST_VALUE="37.148.202.133"
DB_NAME_VALUE="travel_db"
# ---

# --- IMPORTANT: Replace these with your actual Secret Manager secret names ---
DB_PASSWORD_SECRET_NAME="gcs-backend-db-password" # e.g., "gcs-backend-db-password"
GEMINI_API_KEY_SECRET_NAME="shared-gemini-api-key" # e.g., "shared-gemini-api-key"
# ---

# ---- Pre-flight Database Connection Test ----
echo "🚀 Starting pre-flight database connection test..."

echo "Fetching database password from Secret Manager..."
DB_PASSWORD_VALUE=$(gcloud secrets versions access latest --secret="$DB_PASSWORD_SECRET_NAME" --project="$PROJECT_ID")

if [ -z "$DB_PASSWORD_VALUE" ]; then
  echo "❌ ERROR: Failed to fetch database password from Secret Manager."
  exit 1
fi

# Export variables for postgres-deploy-tasks.sh
export DB_USER_VALUE
export DB_HOST_VALUE
export DB_NAME_VALUE
export DB_PASSWORD_VALUE
export PGPASSWORD="$DB_PASSWORD_VALUE"

echo "Attempting to connect to PostgreSQL database: $DB_NAME_VALUE at $DB_HOST_VALUE as $DB_USER_VALUE..."
export PGPASSWORD="$DB_PASSWORD_VALUE"
if psql -h "$DB_HOST_VALUE" -U "$DB_USER_VALUE" -d "$DB_NAME_VALUE" -c "\\q" > /dev/null 2>&1; then
  echo "✅ Pre-flight database connection test PASSED."
else
  echo "❌ ERROR: Pre-flight database connection test FAILED. Please check database credentials, network connectivity, and PostgreSQL server status."
  unset PGPASSWORD # Clear password from environment
  exit 1
fi
# Do not unset PGPASSWORD here if the sub-script needs it and we rely on it being set.
# The sub-script will unset it.
echo "---- Pre-flight check completed. ----"
# ---- End of Pre-flight Database Connection Test ----

# Create a unique tag for this build
BUILD_TAG=$(date +%s)

# Build and push the Docker image
echo "Building and pushing image for ${APP_IMAGE_NAME} with tag: ${BUILD_TAG} and :latest"
docker buildx build \
  --platform linux/amd64 \
  -t "gcr.io/${PROJECT_ID}/${APP_IMAGE_NAME}:${BUILD_TAG}" \
  -t "gcr.io/${PROJECT_ID}/${APP_IMAGE_NAME}:latest" \
  -f Dockerfile \
  . \
  --push

# Deploy to gcs-backend
echo "Deploying gcs-backend with image tag: ${BUILD_TAG}"
gcloud run deploy gcs-backend \
  --image "gcr.io/${PROJECT_ID}/${APP_IMAGE_NAME}:${BUILD_TAG}" \
  --platform managed \
  --region us-central1 \
  --allow-unauthenticated \
  --set-env-vars="GOOGLE_CLOUD_PROJECT=${PROJECT_ID},DB_USER=travel_user,DB_HOST=37.148.202.133,DB_NAME=travel_db,DB_PORT=5432,GCS_BUCKET_NAME=${TARGET_GCS_BUCKET_NAME}" \
  --update-secrets="DB_PASSWORD=${DB_PASSWORD_SECRET_NAME}:latest,GEMINI_API_KEY=${GEMINI_API_KEY_SECRET_NAME}:latest"

# Execute PostgreSQL specific tasks
echo "Executing PostgreSQL deployment tasks..."
SCRIPT_DIR=$(dirname "$0")
POSTGRES_TASKS_SCRIPT_PATH="${SCRIPT_DIR}/postgres-deploy-tasks.sh"

if [ -f "${POSTGRES_TASKS_SCRIPT_PATH}" ]; then
  bash "${POSTGRES_TASKS_SCRIPT_PATH}"
else
  echo "❌ ERROR: postgres-deploy-tasks.sh not found at ${POSTGRES_TASKS_SCRIPT_PATH}."
  echo "   (SCRIPT_DIR was determined as: ${SCRIPT_DIR})"
  exit 1
fi

unset PGPASSWORD # Clear password from environment after sub-script execution
echo "Continuing with the rest of the deployment..."

echo "Script completed."