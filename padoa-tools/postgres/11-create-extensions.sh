#!/bin/bash

set -euxo pipefail

psql -e -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname template1 <<-EOF
  CREATE OR REPLACE PROCEDURE "pg_catalog".install_all_extensions_public()
    AS
    \$\$
      -- postgis
      CREATE EXTENSION IF NOT EXISTS postgis;
      CREATE EXTENSION IF NOT EXISTS fuzzystrmatch;
      CREATE EXTENSION IF NOT EXISTS postgis_topology;
      CREATE EXTENSION IF NOT EXISTS postgis_tiger_geocoder;
      -- pg_rrule
      CREATE EXTENSION IF NOT EXISTS pg_rrule;
    \$\$
    LANGUAGE sql;

  CALL install_all_extensions_public();
EOF

psql -e -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOF
  CREATE OR REPLACE PROCEDURE "pg_catalog".install_all_extensions_public()
    AS
    \$\$
      -- postgis
      CREATE EXTENSION IF NOT EXISTS postgis;
      CREATE EXTENSION IF NOT EXISTS fuzzystrmatch;
      CREATE EXTENSION IF NOT EXISTS postgis_topology;
      CREATE EXTENSION IF NOT EXISTS postgis_tiger_geocoder;
      -- pg_rrule
      CREATE EXTENSION IF NOT EXISTS pg_rrule;
    \$\$
    LANGUAGE sql;

  CALL install_all_extensions_public();
EOF
