#!/bin/bash

set -euxo pipefail

POSTGRES_ROLES=${POSTGRES_ROLES:-}

for role in $POSTGRES_ROLES; do
  echo "Creating role $role"
  psql -e -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOF
    CREATE ROLE "$role";
    GRANT ALL PRIVILEGES ON DATABASE "$POSTGRES_DB" TO "$role";
EOF
done
