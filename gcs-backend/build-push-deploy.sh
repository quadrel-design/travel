#!/bin/bash

set -e

# Define your project ID and shared image name
PROJECT_ID="splitbase-7ec0f"
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

echo "Attempting to connect to PostgreSQL database: $DB_NAME_VALUE at $DB_HOST_VALUE as $DB_USER_VALUE..."
export PGPASSWORD="$DB_PASSWORD_VALUE"
if psql -h "$DB_HOST_VALUE" -U "$DB_USER_VALUE" -d "$DB_NAME_VALUE" -c "\q" > /dev/null 2>&1; then
  echo "✅ Pre-flight database connection test PASSED."
else
  echo "❌ ERROR: Pre-flight database connection test FAILED. Please check database credentials, network connectivity, and PostgreSQL server status."
  unset PGPASSWORD # Clear password from environment
  exit 1
fi
unset PGPASSWORD # Clear password from environment
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

echo "Applying database permissions for travel_user..."

# SQL commands to grant necessary privileges
# These will be executed by DB_USER_VALUE (travel_user).
# Default privileges will apply to new objects created by DB_USER_VALUE.
SQL_GRANT_COMMANDS="
GRANT CONNECT ON DATABASE \"${DB_NAME_VALUE}\" TO \"${DB_USER_VALUE}\";
GRANT USAGE ON SCHEMA public TO \"${DB_USER_VALUE}\";
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO \"${DB_USER_VALUE}\";
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO \"${DB_USER_VALUE}\";

ALTER DEFAULT PRIVILEGES FOR ROLE \"${DB_USER_VALUE}\" IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO \"${DB_USER_VALUE}\";
ALTER DEFAULT PRIVILEGES FOR ROLE \"${DB_USER_VALUE}\" IN SCHEMA public GRANT USAGE, SELECT ON SEQUENCES TO \"${DB_USER_VALUE}\";
"

# Execute the SQL commands using the DB_USER_VALUE (travel_user) credentials
# DB_PASSWORD_VALUE was fetched during the pre-flight check.
echo "Attempting to apply permissions to database '$DB_NAME_VALUE' on host '$DB_HOST_VALUE' as user '$DB_USER_VALUE'..."
export PGPASSWORD="$DB_PASSWORD_VALUE" # Use password for travel_user
if psql -h "$DB_HOST_VALUE" -U "$DB_USER_VALUE" -d "$DB_NAME_VALUE" -c "$SQL_GRANT_COMMANDS"; then
  echo "✅ Database permissions successfully applied by user '$DB_USER_VALUE'."
else
  echo "❌ Failed to apply database permissions as user '$DB_USER_VALUE'."
  echo "   Ensure '$DB_USER_VALUE' has rights to grant these permissions (e.g., ownership or GRANT OPTION)."
  echo "   The ALTER DEFAULT PRIVILEGES commands will now only apply to objects created by '$DB_USER_VALUE'."
  unset PGPASSWORD # Clear password from environment
  exit 1 # Exit if permissions fail
fi
unset PGPASSWORD # Clear password from environment

echo "Continuing with the rest of the deployment..."

# Deploy to invoice-service -- THIS ENTIRE BLOCK WILL BE REMOVED
# echo "Deploying invoice-service with image tag: ${BUILD_TAG}"
# gcloud run deploy invoice-service \
#   --image "gcr.io/${PROJECT_ID}/${APP_IMAGE_NAME}:${BUILD_TAG}" \
#   --platform managed \
#   --region us-central1 \
#   --allow-unauthenticated \
#   --set-env-vars="GOOGLE_CLOUD_PROJECT=${PROJECT_ID},GCS_BUCKET_NAME=${TARGET_GCS_BUCKET_NAME}" \
#   --update-secrets="GEMINI_API_KEY=${GEMINI_API_KEY_SECRET_NAME}:latest"

echo "Script completed."