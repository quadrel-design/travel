#!/bin/bash

set -e

# These variables are now expected to be set in the environment by the calling script:
# PROJECT_ID (though not directly used in psql command here if DB vars are set)
# DB_PASSWORD_SECRET_NAME (no longer needed)
# DB_HOST_VALUE
# DB_USER_VALUE
# DB_NAME_VALUE
# PGPASSWORD (should be set to DB_PASSWORD_VALUE)

echo "🚀 Starting PostgreSQL deployment tasks..."

# Check if required environment variables are set
if [ -z "$DB_HOST_VALUE" ] || [ -z "$DB_USER_VALUE" ] || [ -z "$DB_NAME_VALUE" ] || [ -z "$PGPASSWORD" ]; then
  echo "❌ ERROR: Required database connection environment variables (DB_HOST_VALUE, DB_USER_VALUE, DB_NAME_VALUE, PGPASSWORD) are not set."
  exit 1
fi

echo "Using DB Host: $DB_HOST_VALUE, DB User: $DB_USER_VALUE, DB Name: $DB_NAME_VALUE for PostgreSQL tasks."
echo "DB Password has been inherited via PGPASSWORD."


echo "Applying database permissions for ${DB_USER_VALUE}..."

# SQL commands to grant necessary privileges
SQL_GRANT_COMMANDS="
GRANT CONNECT ON DATABASE \"${DB_NAME_VALUE}\" TO \"${DB_USER_VALUE}\";
GRANT USAGE ON SCHEMA public TO \"${DB_USER_VALUE}\";
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO \"${DB_USER_VALUE}\";
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO \"${DB_USER_VALUE}\";

ALTER DEFAULT PRIVILEGES FOR ROLE \"${DB_USER_VALUE}\" IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO \"${DB_USER_VALUE}\";
ALTER DEFAULT PRIVILEGES FOR ROLE \"${DB_USER_VALUE}\" IN SCHEMA public GRANT USAGE, SELECT ON SEQUENCES TO \"${DB_USER_VALUE}\";
"

# Execute the SQL commands
echo "Attempting to apply permissions to database '$DB_NAME_VALUE' on host '$DB_HOST_VALUE' as user '$DB_USER_VALUE' (PostgreSQL tasks script)..."
# PGPASSWORD is already exported by the parent script
if psql -h "$DB_HOST_VALUE" -U "$DB_USER_VALUE" -d "$DB_NAME_VALUE" -c "$SQL_GRANT_COMMANDS"; then
  echo "✅ Database permissions successfully applied by user '$DB_USER_VALUE' (PostgreSQL tasks script)."
else
  echo "❌ Failed to apply database permissions as user '$DB_USER_VALUE' (PostgreSQL tasks script)."
  echo "   Ensure '$DB_USER_VALUE' has rights to grant these permissions (e.g., ownership or GRANT OPTION)."
  echo "   The ALTER DEFAULT PRIVILEGES commands will now only apply to objects created by '$DB_USER_VALUE'."
  # unset PGPASSWORD # Parent script will handle unsetting PGPASSWORD
  exit 1 # Exit if permissions fail
fi
# unset PGPASSWORD # Parent script handles unsetting

echo "✅ PostgreSQL deployment tasks completed successfully." 